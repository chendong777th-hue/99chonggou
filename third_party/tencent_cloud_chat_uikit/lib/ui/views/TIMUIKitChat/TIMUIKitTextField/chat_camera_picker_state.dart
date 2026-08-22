import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wechat_camera_picker/wechat_camera_picker.dart';
import 'package:wechat_picker_library/wechat_picker_library.dart';

/// 聊天拍照页：长按录像时在顶部显示已录时长（微信风格）。
class ChatCameraPickerState extends CameraPickerState {
  Timer? _recordDurationTimer;

  @override
  void dispose() {
    _recordDurationTimer?.cancel();
    super.dispose();
  }

  @override
  Future<void> startRecordingVideo() async {
    await super.startRecordingVideo();
    if (isRecordingVideo) {
      _startRecordDurationTicker();
    }
  }

  @override
  Future<void> stopRecordingVideo() async {
    _stopRecordDurationTicker();
    await super.stopRecordingVideo();
  }

  void _startRecordDurationTicker() {
    _recordDurationTimer?.cancel();
    _recordDurationTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) {
        _stopRecordDurationTicker();
        return;
      }
      if (isRecordingVideo) {
        safeSetState(() {});
      } else {
        _stopRecordDurationTicker();
      }
    });
  }

  void _stopRecordDurationTicker() {
    _recordDurationTimer?.cancel();
    _recordDurationTimer = null;
  }

  static String formatRecordingDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildRecordingDurationBanner(BuildContext context) {
    if (!isRecordingVideo) {
      return const SizedBox.shrink();
    }
    final elapsed = recordStopwatch.elapsed;
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF3B30),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatRecordingDuration(elapsed),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget buildForegroundBody({
    required BuildContext context,
    required BoxConstraints constraints,
    DeviceOrientation? deviceOrientation,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        super.buildForegroundBody(
          context: context,
          constraints: constraints,
          deviceOrientation: deviceOrientation,
        ),
        _buildRecordingDurationBanner(context),
      ],
    );
  }
}
