# Perf hitch capture playbook

How to produce a **stack-bearing** profile for Display hitches so `/how` +
`/improve` can write real code plans. Do **not** open chat/menu “fix”
plans from Display-only exports (see archive `docs/pro-display-2026-08-22.md`).

## Goal

Capture the same user-visible hitch windows with:

1. Instruments **Display / Animation Hitches** (when frames missed), and
2. Instruments **Time Profiler** (what ran on Runner / Main),

plus a filled `docs/pro-scenario.md` for the same session.

Minimum acceptance: the Time Profiler export text contains at least one of
`dart::`, `Interpret`, or clearly named Dart/Flutter frames (or a “Heaviest
Stack” dump that names Runner symbols). Display-only tables alone are
**not** enough.

## RegExpProbe (list → chat)

Profile builds now set `RegExpProbe.enabledInProfile = true`. After you
scroll the conversation list and open a chat, filter device logs for:

```text
[RegExpProbe]
```

Expect a dump around history load, e.g.:

```text
[RegExpProbe] dump reason=list_to_chat_didGetHistoricalMessageList | link....
```

Record the top `site` names (calls / us) into `docs/pro-scenario.md`.
Release builds stay silent (`enabled == false`).

## Build

- Prefer a **profile** build of the iOS `Runner` target (Release-equivalent
  timing; still symbolicated enough for Dart).
- Debug builds inflate hitch noise — avoid for this playbook.
- Install on a physical device when possible (Simulator timing differs).
- Attach Instruments to the running `Runner` process (or launch via Instruments).

## Instruments template

Create or reuse a template that includes **both**:

| Instrument | Purpose |
|------------|---------|
| Animation Hitches / Display | Hitch table + Surface intervals |
| Time Profiler | Sample call stacks on Runner (Main / UI) |

Recording tips:

- Start recording, then run **one** scenario script below (do not mix scripts
  in one trace if you can avoid it).
- Keep the trace ~30–60s so Cluster A / D style windows still fit.
- After stop: export hitch table **and** Time Profiler heaviest stacks as
  text into the repo (`docs/pro-time-profiler.md` and/or update `docs/pro.md`
  under a clear `## Time Profiler` heading).

## Optional Flutter Timeline

Same gesture window, optional second capture:

```bash
flutter run --profile
```

Open DevTools → CPU Profiler / Performance (Timeline). Export or screenshot
the heavy frames that align with the hitch timestamps. Attach notes under
`docs/pro-scenario.md` → Cluster sections.

## Scenario scripts

Pick **one** per recording.

### Script OpenChat

1. App on home / conversation list (already logged in).
2. Tap **one** conversation (prefer image-heavy history if available).
3. Wait until the list settles (~3–5s).
4. Scroll up/down briefly.
5. Pop back to the list.
6. Stop Instruments.

Collect log lines matching `[ChatOpenPerf]` from
`lib/src/services/chat_open_perf_log.dart` into `docs/pro-scenario.md`.

### Script MenuOrMedia

1. Already inside a chat.
2. Either **long-press** a normal (non-super-long) text/image bubble until the
   action menu appears, **or** open a **fullscreen image** preview — pick one
   and write which in the scenario log.
3. Dismiss; wait ~2s.
4. Stop Instruments.

## Cluster windows to annotate

From the 2026-08-22 Display-only capture (`docs/pro-display-2026-08-22.md`),
label your narrative against these windows even if absolute timestamps shift:

| Cluster | Approx window | Notes from Display-only file |
|---------|---------------|------------------------------|
| **A** | ~`00:01.6`–`00:11` | Heaviest cluster (~475 ms hitch sum; peaks 75/83 ms) |
| **D** | ~`00:27`–`00:31` | Includes **150 ms** hitch @ ~`00:30.9` |

If your new recording uses a different script length, still mark “what I did
during the heaviest hitch peak” and “what I did during the late peak”.

## Export checklist

Before treating a capture as actionable for code plans:

- [ ] Time Profiler heaviest stacks exported as text
- [ ] At least one Dart/Flutter symbol visible (`dart::` / `Interpret` / named frames)
- [ ] Display hitch table still exported (may live in `docs/pro-display-latest.md`)
- [ ] `docs/pro-scenario.md` filled for the **same** session
- [ ] `[ChatOpenPerf]` excerpt attached if Script OpenChat was used
- [ ] Dated Display-only archive kept (`docs/pro-display-2026-08-22.md`)

Suggested layout after a successful capture:

```text
docs/pro-display-2026-08-22.md   # archived Display-only (incomplete)
docs/pro-display-latest.md       # optional new hitch table
docs/pro-time-profiler.md        # REQUIRED stacks
docs/pro-scenario.md             # REQUIRED narrative
docs/pro.md                      # optional merged summary pointing at the above
```

## Do not

- Do not file chat-open / menu / RegExp code plans from Display-only exports.
- Do not restore live full-screen `BackdropFilter` σ=22 “to fix hitches”.
- Do not re-enable list ORIGINAL image prefetch to “fix” open jank without
  stack proof (fights plans 017/024).
- Do not invent `dart::` stacks or mark plan 032 DONE without a real device
  Time Profiler export.
# 052 聊天页主线程基线

使用 Profile 构建采集以下固定指标：`history_merge_ms`、
`set_message_list_ms`、`group_metadata_apply_ms`、
`conversation_reload_ms`、`image_decode_ms`、`keyboard_layout_ms`。
探针默认关闭；仅采集时临时将 `ChatMainThreadPerf.localProfileEnabled` 设为
`true`，采集完成后恢复为 `false`。Release 构建始终不会输出。

每轮使用同一账号和同一组会话，依次执行：首次安装进入群聊、暖启动进入、
长历史群、图片密集群、打开键盘、发送一张图片和一个视频。同步保存 Flutter
控制台的 `[ChatMainPerf]` 行与 Instruments 的 Time Profiler、Core Animation
hitch 区间。日志只能包含 `metric/ms/count/source/convType`，不得添加消息正文、
用户或群标识、token。

记录每个场景的设备型号、系统版本、构建 SHA、样本次数、P50/P95/最大值，
并确认是否出现消息丢失、顺序变化、媒体内容变化。未获得真机结果前，不执行
053 或 054 的算法、线程迁移。
