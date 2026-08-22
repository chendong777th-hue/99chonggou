import 'dart:async';

/// Debounced local draft text for the open chat page.
class ChatDraftController {
  String? text;
  Timer? _debounce;
  int _writeGeneration = 0;
  int get writeGeneration => _writeGeneration;

  void _diag(String event, {int? length, int? generation}) {
    print('[ChatInputDiag] draft=$event len=${length ?? -1} '
        'generation=${generation ?? _writeGeneration}');
  }

  static const Duration debounceDuration = Duration(milliseconds: 250);

  void setTextImmediate(String? value) {
    final trimmed = value?.trim() ?? '';
    text = trimmed.isEmpty ? null : value;
  }

  void onChanged(
    String value, {
    required void Function(String raw, int generation) persist,
  }) {
    setTextImmediate(value);
    _diag('changed', length: value.length);
    _debounce?.cancel();
    final generation = _writeGeneration;
    _diag('debounce_scheduled', length: value.length, generation: generation);
    _debounce = Timer(debounceDuration, () {
      if (generation == _writeGeneration) {
        _diag('debounce_fire', length: value.length, generation: generation);
        persist(value, generation);
      } else {
        _diag('debounce_stale_drop',
            length: value.length, generation: generation);
      }
    });
  }

  void cancelDebounce() {
    _debounce?.cancel();
    _debounce = null;
  }

  void clear() {
    _writeGeneration++;
    _diag('clear', generation: _writeGeneration);
    cancelDebounce();
    text = null;
  }

  void dispose() {
    cancelDebounce();
  }
}
