# Plan 031: Disable live blur on message-menu reaction bar

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> any STOP condition is hit, stop and report — do not improvise. When done,
> update the status row for this plan in `plans/README.md`.
>
> **Drift check (run first)**: This workspace may have **no `.git`**. Compare
> every "Current state" excerpt against live files. If symbols or control flow
> changed materially, STOP and report before coding.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW (visual: reaction chip loses frosted glass; solid fill remains)
- **Depends on**: none (orthogonal to Plan 030; soft preference after 027 DONE)
- **Category**: perf
- **Planned at**: working tree 2026-08-22 (NO_GIT)
- **Issue**: omit
- **Status**: DONE (2026-08-22) — both reaction shells `useBackdropBlur: false`;
  contract test green.
set `useBackdropBlur: false` on the **action menu** shell. The **quick-reaction
bar** still constructs `_FrostedTooltipShell` **without** overriding
`useBackdropBlur`, so it defaults to **`true`** and applies
`ImageFilter.blur(sigmaX: 26, sigmaY: 26)` while the menu is open.

That is a leftover GPU composite cost on the same long-press surface 027 was
meant to lighten. Goal: reaction bar matches the action menu — solid tinted
shell, **no** live blur filter.

## Product decisions (locked)

| Decision | Value |
|----------|--------|
| Reaction bar chrome | Keep rounded shell + existing background color default (`_kTelegramMenuBackgroundColor` when `backgroundColor` is null) |
| Live blur on reaction bar | **Off** — pass `useBackdropBlur: false` at both call sites |
| Action menu shell | Leave as-is (`useBackdropBlur: false` already) |
| Full-screen scrim | Leave Plan 027 solid `ColoredBox` — do not touch controller scrim in this plan |
| Default of `_FrostedTooltipShell.useBackdropBlur` | May stay `true` for safety of any unknown caller; **both** reaction sites must pass `false` explicitly. Optionally change the default to `false` **only if** grep shows no other callers need blur — prefer explicit `false` at reaction sites first |

## Current state

File:
`third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_mobile_telegram_message_menu.dart`

### Action menu — already solid (do not regress)

~469–474 and ~611–616:

```dart
            child: _FrostedTooltipShell(
              borderRadius: BorderRadius.circular(12),
              padding: EdgeInsets.zero,
              // 操作菜单：微信深色横向网格（全屏已 blur，此处不再叠第二层）。
              backgroundColor: _kWeChatActionMenuBackgroundColor,
              useBackdropBlur: false,
```

(Comment text may still say “全屏已 blur” from before 027 — optional comment fix
only; do not restore blur.)

### Reaction bar — still defaults to blur (fix)

Super-long scroll layout ~525–537:

```dart
            if (showReaction)
              Positioned(
                left: reactionLeft,
                top: widget.safeTop,
                child: _applyPresent(
                  _FrostedTooltipShell(
                    borderRadius: BorderRadius.circular(24),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: _buildTooltip(
                      layout: TelegramMobileTooltipLayout.reactionBarOnly,
                    ),
                  ),
                ),
              ),
```

In-place layout ~589–603:

```dart
            if (widget.showQuickReactionBar && layout.reactionTop != null)
              Positioned(
                left: layout.reactionLeft,
                top: layout.reactionTop,
                child: KeyedSubtree(
                  key: _reactionMeasureKey,
                  child: _FrostedTooltipShell(
                    borderRadius: BorderRadius.circular(24),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: _buildTooltip(
                      layout: TelegramMobileTooltipLayout.reactionBarOnly,
                    ),
                  ),
                ),
              ),
```

### Shell implementation

~632–671: `useBackdropBlur` defaults to `true`; when true wraps child in
`BackdropFilter` + `ImageFilter.blur(sigmaX: 26, sigmaY: 26)`.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Analyze | `cd /Users/qiu/Downloads/9925banben && dart analyze third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_mobile_telegram_message_menu.dart test/message_context_menu_reaction_blur_contract_test.dart` | No errors |
| New contract | `cd /Users/qiu/Downloads/9925banben && flutter test test/message_context_menu_reaction_blur_contract_test.dart` | All pass |
| Keep 027 | `cd /Users/qiu/Downloads/9925banben && flutter test test/message_context_menu_scrim_contract_test.dart` | All pass |

## Scope

**In scope**:

- `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_mobile_telegram_message_menu.dart`
- `test/message_context_menu_reaction_blur_contract_test.dart` (create)
- `plans/README.md` (status row only)

**Out of scope**:

- Plan 030 snapshot / open ordering
- Controller full-screen scrim
- Tooltip item handlers / `tim_uikit_chat_message_tooltip.dart`
- Changing reaction sticker set or layout geometry
- Removing `_FrostedTooltipShell` class or `BackdropFilter` code path entirely
  (other future callers may still opt in)

## Git workflow

- No `.git` historically — do not `git init`.
- If git exists: branch `advisor/031-reaction-bar-no-backdrop-blur`,
  commit `perf(chat): disable blur on message menu reaction bar`.

## Steps

### Step 1: Pass `useBackdropBlur: false` on both reaction shells

In `tim_uikit_mobile_telegram_message_menu.dart`, at **both** reaction
`_FrostedTooltipShell(` sites (scrollable + in-place), add:

```dart
                    useBackdropBlur: false,
```

Place it next to `padding` / before `child`, matching the action-menu style.
Optional one-line comment: `// 与操作菜单一致：不再叠 live BackdropFilter。`

Do **not** change action-menu sites.

**Verify**:

```bash
rg -n "_FrostedTooltipShell\(" -A6 \
  third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_mobile_telegram_message_menu.dart
```

→ Every `_FrostedTooltipShell(` in this file (action + reaction) must show
`useBackdropBlur: false` in the following lines. No reaction site may omit it.

### Step 2: Contract test

Create `test/message_context_menu_reaction_blur_contract_test.dart`:

- Read the menu dart file as a string (same pattern as
  `test/message_context_menu_scrim_contract_test.dart`).
- Assert the file still contains `BackdropFilter` / `ImageFilter.blur` **inside
  `_FrostedTooltipShell`** (implementation may remain) — OR simply assert
  reaction-bar construction sites include `useBackdropBlur: false`.
- Stronger check: count occurrences of
  `layout: TelegramMobileTooltipLayout.reactionBarOnly` and assert that for
  each, a nearby preceding `useBackdropBlur: false` exists (e.g. search
  backwards within ~400 chars of each `reactionBarOnly` for
  `useBackdropBlur: false`).
- Assert action menu still has `useBackdropBlur: false` (no regression).

**Verify**:

```bash
cd /Users/qiu/Downloads/9925banben && flutter test \
  test/message_context_menu_reaction_blur_contract_test.dart \
  test/message_context_menu_scrim_contract_test.dart
```

→ all pass.

### Step 3: Analyze + mark DONE

Run `dart analyze` on the touched files. Set README row **031** to `DONE`.

## Test plan

- New contract test as Step 2.
- Manual (operator): long-press a message with reactions enabled — reaction
  chip row should look like a solid frosted-color bar (no live blur), menu
  still usable; 027 close-before-work unchanged.

## Done criteria

- [ ] Both reaction `_FrostedTooltipShell` sites pass `useBackdropBlur: false`
- [ ] Action menu sites still `useBackdropBlur: false`
- [ ] Contract tests above pass
- [ ] `dart analyze` on touched files: no errors
- [ ] No files outside Scope modified
- [ ] `plans/README.md` row 031 → DONE

## STOP conditions

- Reaction UI is no longer built via `_FrostedTooltipShell` (structure drifted)
  — rewrite the plan rather than inventing a new blur kill.
- Turning blur off makes the bar unreadable on some wallpaper and product asks
  for a **different solid** `backgroundColor` — report; do not re-enable blur
  to “fix” contrast without a color decision.
- Verification fails twice after a reasonable fix.

## Maintenance notes

- If someone later enables blur “for aesthetics” on the reaction bar, they undo
  this plan and fight 027’s hitch budget — require Instruments proof.
- Optional follow-up (not this plan): change `_FrostedTooltipShell` default to
  `useBackdropBlur: false` after grepping the whole package for other call
  sites.
