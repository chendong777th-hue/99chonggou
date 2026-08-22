/// Page-local input accessory panel mutual-exclusion state (SSOT).
///
/// Owns keyboard / emoji / more / voice panel flags. Host widgets still drive
/// setState / focus; this class only centralizes the four-way exclusivity.
/// Derived open flag for list dismiss is synced to the text-field controller's
/// `isInputPanelOpen` — do not add a third parallel bool.
class InputPanelController {
  bool showMore = false;
  bool showSendSoundText = false;
  bool showEmojiPanel = false;
  bool showKeyboard = false;

  bool get isAnyAccessoryOpen =>
      showMore || showEmojiPanel || showSendSoundText;

  bool isAnyPanelOpen({required bool hasFocus}) =>
      isAnyAccessoryOpen || showKeyboard || hasFocus;

  void resetAll() {
    showMore = false;
    showEmojiPanel = false;
    showSendSoundText = false;
    showKeyboard = false;
  }

  void switchToKeyboard() {
    showEmojiPanel = false;
    showMore = false;
    showSendSoundText = false;
    showKeyboard = true;
  }

  void hideAccessoryPanels() {
    showMore = false;
    showEmojiPanel = false;
    showSendSoundText = false;
  }

  void hideAllPanels() {
    resetAll();
  }
}
