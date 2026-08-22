# 计划 018：收拢发出图片双气泡

> **执行者说明**：按步骤执行。每步验证通过后再进入下一步。命中任何 STOP 则停下并报告 — 不要临场发挥。完成后更新 `plans/README.md` 中本计划状态行。
>
> **漂移检查（先做）**：本工作区可能**没有 `.git`**。把下面「当前状态」摘录对照现文件。若符号或控制流已实质变化，先 STOP 并报告，再编码。

## 状态

- **优先级**：P0
- **工作量**：M
- **风险**：中（outgoing 关联不得把同秒不同图并成一条）
- **依赖**：无
- **类别**：bug
- **规划于**：工作树 2026-08-22（NO_GIT）
- **Issue**：省略
- **状态**：已完成（2026-08-22）— swap 收拢同一次发送的行；stable-id / path / localSeq 关联；契约测试为绿。

## 为什么重要

发图有时会出现**两条气泡**（乐观 SENDING + SDK 回执），过一会儿才**合成一条**。根因：

1. `_swapOutgoingMessage` 只按精确 `item.id == oldClientId` 替换；对不上就 `insert(0)` 并留下占位 → 双气泡。
2. `dedupe` / `_outgoingCorrelationKey` 按 random/id 建键 — 乐观 id ≠ SDK create id，对子收不拢。
3. 多图时 `_findOutgoingPlaceholderIndex` 拒绝模糊 FIFO；孤儿插入后等后续清理。

## 修复（已落地）

| 区域 | 变更 |
|------|------|
| `_swapOutgoingMessage` | 把匹配 old clientId / stable id / 新 id / msgID 的行收成一条；始终盖上 stable id；`replace: true` |
| `_outgoingCorrelationKey` | 优先 `chatOutgoingStableId`，再 random/id |
| `_outgoingMessagesCorrelate` | 也匹配 localSeq；一侧仍是占位时用 IMAGE path |
| `_findOutgoingPlaceholderIndex` | 匹配 stable id；候选中唯一的 IMAGE path |

## STOP

- **不要**只靠时间戳关联不同的图。
- 多个 IMAGE 占位没有 stable/path 时 **不要** FIFO 猜。
- **不要**改相册闪白（016）或打开解码（017）。

## 验证

```bash
flutter test \
  test/message_ordering_test.dart \
  test/outgoing_image_bubble_dedupe_contract_test.dart \
  test/chat_media_optimistic_send_contract_test.dart
```

期望：全部测试通过。
