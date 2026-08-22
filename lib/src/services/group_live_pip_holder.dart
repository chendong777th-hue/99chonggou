import 'package:awesome_video_player/awesome_video_player.dart';

/// Keeps the player alive after the inline watch UI closes for PiP playback.
class GroupLivePipHolder {
  GroupLivePipHolder._();

  static final GroupLivePipHolder instance = GroupLivePipHolder._();

  BetterPlayerController? _controller;
  void Function(BetterPlayerEvent)? _pipListener;

  bool retains(BetterPlayerController controller) =>
      identical(_controller, controller);

  void retain(BetterPlayerController controller) {
    if (identical(_controller, controller)) {
      return;
    }
    release();
    _controller = controller;
    void listener(BetterPlayerEvent event) {
      if (event.betterPlayerEventType == BetterPlayerEventType.pipStop) {
        release();
      }
    }

    _pipListener = listener;
    controller.addEventsListener(listener);
  }

  void release() {
    final controller = _controller;
    final listener = _pipListener;
    _controller = null;
    _pipListener = null;
    if (controller != null && listener != null) {
      controller.removeEventsListener(listener);
    }
    controller?.dispose(forceDispose: true);
  }
}
