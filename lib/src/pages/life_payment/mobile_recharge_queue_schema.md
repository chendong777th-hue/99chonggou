# 生活缴费队列表建议

前端不直接操作数据库。前端调用后端接口创建订单，后端写入以下表；插件从后端拉取 `ready` 状态任务执行。

## life_payment_accounts

用于保存手机号、户号等档案。话费第一阶段只用 `mobile`。

前端判断“一个号码有没有充值记录”时，不查订单列表，直接查这张档案表：

- `verified = 1`：插件曾经成功完成过该号码充值，前端只需要确认号码。
- `verified = 0`：没有成功充值记录，前端必须填写姓名最后一个字并写入订单；插件执行时如果支付宝要求验证就取这个字段，不要求就跳过不用。
- `success_count` / `last_paid_at`：用于展示和风控。

```sql
CREATE TABLE life_payment_accounts (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  service_type VARCHAR(32) NOT NULL,
  account_no VARCHAR(64) NOT NULL,
  city_code VARCHAR(32) NULL,
  provider_code VARCHAR(64) NULL,
  provider_name VARCHAR(128) NULL,
  owner_last_char VARCHAR(8) NULL,
  verified TINYINT NOT NULL DEFAULT 0,
  success_count INT NOT NULL DEFAULT 0,
  first_verified_at DATETIME NULL,
  last_paid_at DATETIME NULL,
  last_order_no VARCHAR(64) NULL,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  UNIQUE KEY uk_life_payment_account (service_type, account_no, city_code, provider_code)
);
```

## life_payment_orders

统一订单表，后续水费、电费、燃气费都写这里。

```sql
CREATE TABLE life_payment_orders (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  order_no VARCHAR(64) NOT NULL UNIQUE,
  client_order_id VARCHAR(64) NOT NULL UNIQUE,
  service_type VARCHAR(32) NOT NULL,
  account_no VARCHAR(64) NOT NULL,
  city_code VARCHAR(32) NULL,
  provider_code VARCHAR(64) NULL,
  amount DECIMAL(12, 2) NOT NULL,
  payment_method VARCHAR(32) NOT NULL,
  verification_type VARCHAR(32) NULL,
  phone_confirmed TINYINT NOT NULL DEFAULT 0,
  owner_last_char VARCHAR(8) NULL,
  payment_status VARCHAR(32) NOT NULL DEFAULT 'paid',
  status VARCHAR(32) NOT NULL,
  plugin_status VARCHAR(64) NULL,
  fail_reason TEXT NULL,
  receipt TEXT NULL,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL
);
```

## life_payment_task_queue

插件只消费 `status = 'ready'` 的任务。失败可按 `retry_count` 和 `next_run_at` 重试。

```sql
CREATE TABLE life_payment_task_queue (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  task_no VARCHAR(64) NOT NULL UNIQUE,
  order_no VARCHAR(64) NOT NULL,
  service_type VARCHAR(32) NOT NULL,
  status VARCHAR(32) NOT NULL,
  priority INT NOT NULL DEFAULT 100,
  retry_count INT NOT NULL DEFAULT 0,
  locked_by VARCHAR(64) NULL,
  locked_at DATETIME NULL,
  next_run_at DATETIME NOT NULL,
  last_error TEXT NULL,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  KEY idx_life_payment_task_ready (status, next_run_at, priority),
  KEY idx_life_payment_task_order (order_no)
);
```

## 前端接口口径（与 `mobile_recharge_repository.dart` / `life_payment_repository.dart` 实现一致）

话费：

- `GET /life-payments/mobile/amount-options?phone={phone}`：按号码返回可充面额档位
- `GET /life-payments/accounts/profile?service_type=mobile&account_no={phone}`：查号码档案（`verified` / `need_owner_last_char` / `success_count`），404 视为无档案
- `POST /life-payments/mobile/orders`：创建充值订单
- `GET /life-payments/orders/{orderNo}`：轮询订单状态（话费/水电燃气共用）
- `POST /life-payments/orders/{orderNo}/owner-last-char`：订单进入 `need_owner_last_char` 后，前端弹框补交机主姓名最后一个字；后端更新 `life_payment_orders.owner_last_char` 与任务字段，并把任务重新置为 `ready`

水电燃气：

- `GET /life-payments/home`：首页聚合（`city_name` / `month_paid_amount` / `services`（含 `enabled` 与 `maintenance_message` 维护开关，前端已接入口拦截）/ `recent_orders`）
- `GET /life-payments/services`、`GET /life-payments/providers`
- `POST /life-payments/utility/queries` + `GET /life-payments/utility/queries/{queryNo}`：户号查询（插件真机执行，前端轮询）
- `POST /life-payments/utility/orders`：确认账单后下缴费单

`POST /life-payments/mobile/orders` 请求体（字段名以代码为准）：

```json
{
  "client_order_id": "mobile-<uuid v4>",
  "service_type": "mobile",
  "phone": "13182345092",
  "amount": 50,
  "pay_method": "coin_99",
  "pay_password": "******",
  "verification_type": "owner_last_char",
  "phone_confirmed": false,
  "owner_last_char": "冬"
}
```

- `pay_method`：`coin_99`（99 币）或 `usdt`
- `verification_type`：`phone_confirmed`（老户确认号码）或 `owner_last_char`（新户姓名验证）
- `owner_last_char`：仅新户携带；金额一律为整数元（执行端支付宝金额键盘仅支持整数）

后端收到后完成平台币/USDT扣款或冻结，再写 `life_payment_orders` 和 `life_payment_task_queue`。

写入插件任务时，只下发插件需要的信息：

```json
{
  "task_no": "task-001",
  "order_no": "mobile-001",
  "service_type": "mobile",
  "account_no": "13182345092",
  "amount": 50,
  "payment_status": "paid",
  "owner_last_char": "冬"
}
```

插件执行时只有遇到支付宝姓名验证页才使用 `owner_last_char`；如果页面不要求验证，这个字段不会被输入。

## 订单状态机总表（App / 后端 / 插件三方权威口径）

| order_status | 语义 | 产生方 | App 处理 |
|---|---|---|---|
| `ready` / `pending` | 已扣款，任务排队等插件领取 | 后端 | 轮询中，显示「排队中」 |
| `running` | 插件已领取执行中（20 秒/次心跳维持） | 插件 heartbeat | 轮询中，显示「执行中」 |
| `cashier_confirm` / `ready_to_pay` | 已到支付宝收银台，等待人工确认付款（防伪成功语义，绝不等于 success） | 插件 complete | 轮询中，显示「等待付款确认」 |
| `need_owner_last_char` | 支付宝要求姓名验证但任务缺字 | 插件 fail | 弹框补字 → `POST .../owner-last-char` → 任务重置 ready，继续轮询 |
| `success` | 充值/缴费真实完成 | 插件 complete | 终态，停止轮询 |
| `failed` | 终态失败，款项应原路退回 | 插件 fail | 终态，停止轮询 |
| `retryable_failed` | 可重试失败（如 adb 断连、页面识别失败），由后端按 `retry_count`/`next_run_at` 决定是否重派 | 插件 fail | 终态展示，停止轮询 |

App 轮询窗口：5 秒/次 × 48 次（4 分钟），覆盖「排队 + 真机执行（实测约 1 分钟）+ 人工确认」；超窗提示用户稍后在缴费记录查看，不误报失败。
