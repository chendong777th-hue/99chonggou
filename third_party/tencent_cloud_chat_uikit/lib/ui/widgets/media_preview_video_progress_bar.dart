import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitMessageItem/tim_uikit_chat_videoplayer.dart';

/// 全屏视频预览底部可拖动进度条（与顶部/底部菜单同步显隐）。
class MediaPreviewVideoProgressBar extends StatefulWidget {
  const MediaPreviewVideoProgressBar({
    super.key,
    required this.playerKey,
  });

  final GlobalKey<TIMUIKitVideoPlayerState> playerKey;

  @override
  State<MediaPreviewVideoProgressBar> createState() =>
      _MediaPreviewVideoProgressBarState();
}

class _MediaPreviewVideoProgressBarState
    extends State<MediaPreviewVideoProgressBar> {
  dynamic _controller;
  bool _isDragging = false;
  double _dragValue = 0;
  bool _wasPlaying = false;
  bool _canShowProgress = false;
  Timer? _attachTimer;
  DateTime? _lastTickRebuild;

  static const Duration _progressRebuildInterval = Duration(milliseconds: 100);

  bool _isInitialized(dynamic controller) {
    final value = controller?.value;
    if (value == null) {
      return false;
    }
    try {
      if (value.initialized == true) {
        return true;
      }
    } catch (_) {}
    try {
      return value.isInitialized == true;
    } catch (_) {
      return false;
    }
  }

  Duration _durationOf(dynamic controller) =>
      controller?.value.duration ?? Duration.zero;

  Duration _positionOf(dynamic controller) =>
      controller?.value.position ?? Duration.zero;

  bool _isPlaying(dynamic controller) => controller?.value.isPlaying == true;

  bool _computeCanShow(dynamic controller) {
    if (controller == null || !_isInitialized(controller)) {
      return false;
    }
    return _durationOf(controller) > Duration.zero;
  }

  /// 根据当前 controller 刷新「能否展示」；有变化则 setState。
  void _syncCanShow() {
    final next = _computeCanShow(_controller);
    if (next == _canShowProgress) {
      return;
    }
    if (!mounted) {
      _canShowProgress = next;
      return;
    }
    setState(() => _canShowProgress = next);
  }

  @override
  void initState() {
    super.initState();
    _startAttachPolling();
  }

  @override
  void didUpdateWidget(covariant MediaPreviewVideoProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playerKey != widget.playerKey) {
      _detachController();
      _canShowProgress = false;
      _startAttachPolling();
    }
  }

  void _startAttachPolling() {
    _attachTimer?.cancel();
    _attachController();
    _syncCanShow();
    if (_canShowProgress) {
      _attachTimer = null;
      return;
    }
    _attachTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (!mounted) {
        _attachTimer?.cancel();
        _attachTimer = null;
        return;
      }
      _attachController();
      _syncCanShow();
      if (_canShowProgress) {
        // 可展示时必须先完成上面的 setState，再停表，避免卡在 shrink。
        _attachTimer?.cancel();
        _attachTimer = null;
      }
    });
  }

  void _attachController() {
    final next = widget.playerKey.currentState?.playbackController;
    if (next == _controller) {
      return;
    }
    _detachController();
    _controller = next;
    _controller?.addListener(_onPlaybackTick);
    if (mounted) {
      setState(() {});
    }
  }

  void _detachController() {
    _controller?.removeListener(_onPlaybackTick);
    _controller = null;
  }

  void _onPlaybackTick() {
    if (!mounted || _isDragging) {
      return;
    }
    final now = DateTime.now();
    if (_lastTickRebuild != null &&
        now.difference(_lastTickRebuild!) < _progressRebuildInterval) {
      // 节流期间仍同步「能否展示」，避免漏掉 initialized 跳变。
      final next = _computeCanShow(_controller);
      if (next != _canShowProgress) {
        _lastTickRebuild = now;
        setState(() => _canShowProgress = next);
      }
      return;
    }
    _lastTickRebuild = now;
    final next = _computeCanShow(_controller);
    setState(() => _canShowProgress = next);
  }

  @override
  void dispose() {
    _attachTimer?.cancel();
    _detachController();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$mm:$ss';
    }
    return '$mm:$ss';
  }

  double _progressFor(Duration position, Duration duration) {
    if (duration.inMilliseconds <= 0) {
      return 0;
    }
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (!_canShowProgress ||
        controller == null ||
        !_isInitialized(controller)) {
      return const SizedBox.shrink();
    }

    final duration = _durationOf(controller);
    if (duration <= Duration.zero) {
      return const SizedBox.shrink();
    }

    final position = _positionOf(controller);
    final sliderValue =
        _isDragging ? _dragValue : _progressFor(position, duration);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    const timeShadow = <Shadow>[
      Shadow(
        color: Color(0x8A000000),
        blurRadius: 3,
        offset: Offset(0, 1),
      ),
    ];

    return Positioned(
      left: 16,
      right: 16,
      bottom: bottomInset + 16 + 48 + 10,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Text(
                _formatDuration(
                  _isDragging
                      ? Duration(
                          milliseconds:
                              (sliderValue * duration.inMilliseconds).round(),
                        )
                      : position,
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontFeatures: [FontFeature.tabularFigures()],
                  shadows: timeShadow,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 14),
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white38,
                    thumbColor: Colors.white,
                    overlayColor: Colors.white24,
                  ),
                  child: Slider(
                    value: sliderValue,
                    onChangeStart: (_) {
                      _wasPlaying = _isPlaying(controller);
                      setState(() {
                        _isDragging = true;
                        _dragValue = sliderValue;
                      });
                      controller.pause();
                    },
                    onChanged: (value) {
                      setState(() => _dragValue = value);
                    },
                    onChangeEnd: (value) async {
                      final target = Duration(
                        milliseconds: (value * duration.inMilliseconds).round(),
                      );
                      await widget.playerKey.currentState?.seekPlaybackTo(target);
                      if (_wasPlaying) {
                        await controller.play();
                      }
                      if (mounted) {
                        setState(() => _isDragging = false);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _formatDuration(duration),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 12,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  shadows: timeShadow,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
