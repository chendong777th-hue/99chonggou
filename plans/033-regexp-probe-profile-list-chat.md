# Plan 033: RegExpProbe on for profile + dump after list→chat open

> **Executor instructions**: Follow step by step. Verify each gate. STOP on
> drift. Update `plans/README.md` when done.
>
> **Drift check**: Confirm `RegExpProbe.enabledInProfile` exists in
> `third_party/tencent_cloud_chat_uikit/lib/ui/utils/regexp_probe.dart`.

## Status

- **Priority**: P0
- **Effort**: S
- **Risk**: LOW (profile-only logging)
- **Depends on**: none
- **Category**: perf / dx
- **Status**: DONE (2026-08-22) — `enabledInProfile=true`; dump reason
  `list_to_chat_didGetHistoricalMessageList`; playbook section in
  `docs/perf-hitch-capture.md`.

`docs/pro.md` shows Main `RegExp::Interpret` during scroll-list + open-chat,
but Instruments cannot name Dart sites. `RegExpProbe` already tags
`link.LinkText.scan` / `link.getURLMatches` / etc., yet `enabledInProfile`
is **false**, so dumps never fire in profile builds.

## Locked decisions

| Decision | Value |
|----------|--------|
| Release `enabled` | stays **false** |
| `enabledInProfile` | set **true** |
| Dump points | keep existing history dump; add dump+reset when chat route is ready / after first history batch if missing |
| Product code paths | no behavior change when probe off |

## Scope

- `third_party/tencent_cloud_chat_uikit/lib/ui/utils/regexp_probe.dart`
- `lib/src/chat.dart` (dump reasons only if needed)
- `docs/perf-hitch-capture.md` — add RegExpProbe filter steps
- `plans/README.md`

## Steps

1. Set `enabledInProfile = true`.
2. Ensure open-chat path dumps once with reason containing `list_to_chat` or
   keep `didGetHistoricalMessageList` and document it in playbook.
3. Playbook: profile run → scroll list → open chat → filter `[RegExpProbe]`.
4. `flutter test test/regexp_probe_test.dart`

## Done

- [ ] Profile builds collect probe sites
- [ ] Release still silent (`enabled == false`)
- [ ] Tests pass
