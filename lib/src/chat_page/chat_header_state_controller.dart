import 'package:flutter/foundation.dart';

/// Lightweight state for the chat header title/avatar.
///
/// The chat page can update this without rebuilding the whole TIMUIKitChat tree.
class ChatHeaderStateController extends ChangeNotifier {
  String? _conversationFaceUrl;
  String? _titleText;

  String? get conversationFaceUrl => _conversationFaceUrl;

  String? get titleText => _titleText;

  void setSnapshot({
    required String? conversationFaceUrl,
    required String titleText,
    bool notify = true,
  }) {
    final normalizedFace = conversationFaceUrl?.trim();
    final normalizedTitle = titleText.trim();
    if (_conversationFaceUrl == normalizedFace &&
        _titleText == normalizedTitle) {
      return;
    }
    _conversationFaceUrl = normalizedFace;
    _titleText = normalizedTitle;
    if (notify) {
      notifyListeners();
    }
  }
}
