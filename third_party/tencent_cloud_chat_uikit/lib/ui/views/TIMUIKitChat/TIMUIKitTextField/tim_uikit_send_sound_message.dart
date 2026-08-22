// ignore_for_file:  avoid_print, unused_import

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_chat_separate_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/permission.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/sound_record.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/logger.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_callback.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme_view_model.dart';
import 'package:tencent_cloud_chat_uikit/ui/controllers/record_input_state.dart';

typedef _RecordInputState = RecordInputState;
typedef _RecordReleaseZone = RecordReleaseZone;
typedef _RecordOverlayMode = RecordOverlayMode;

class SendSoundMessage extends StatefulWidget {
  /// conversation ID
  final String conversationID;

  /// control the list to bottom
  final VoidCallback onDownBottom;

  /// the conversation type
  final ConvType conversationType;

  /// 与单行输入框内容区等高；默认 36（fontSize 16 + vertical padding 6×2 + isDense）。
  final double height;

  const SendSoundMessage(
      {required this.conversationID,
      required this.conversationType,
      Key? key,
      required this.onDownBottom,
      this.height = 36.0})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _SendSoundMessageState();
}

class _SendSoundMessageState extends TIMUIKitState<SendSoundMessage>
    with WidgetsBindingObserver {
  static const int _liveWaveformBarCount = 28;
  static const Color _recordActiveGreen = Color(0xFF95EC69);
  static const Color _recordGlowColor = Color(0xFF7EEBD3);
  static const Color _recordDarkPanel = Color(0xFF3A3D42);
  static const Color _recordMainInnerColor = Color(0xFF4A5C6B);
  static const Color _recordSideButtonColor = Color(0xFF4A4A4A);
  static const Color _recordCancelRed = Color(0xFFE07A7A);
  static const Color _recordCancelGlow = Color(0xFFE57373);
  static const Color _recordConvertTextGreen = Color(0xFF2E6B38);
  static const double _micButtonSize = 88;
  static const Color _idleMicTopColor = Color(0xFF4F6475);
  static const Color _idleMicBottomColor = Color(0xFF3D4F5C);
  static const Color _idleMicActiveTopColor = Color(0xFF5A7386);
  static const Color _idleMicActiveBottomColor = Color(0xFF455A6A);
  static const Color _micIconColor = Color(0xFF7EEBD3);
  static const double _recordMainButtonSize = 108;
  static const double _recordSideButtonSize = 56;
  static const double _recordPanelHeight = 248;
  static const double _convertReviewActionHeight = 58;
  static const double _convertReviewBottomPadding = 36;

  final TUIChatGlobalModel model = serviceLocator<TUIChatGlobalModel>();
  final TextEditingController _convertedTextController = TextEditingController();
  String soundTipsText = "";
  bool isRecording = false;
  bool isInit = false;
  bool isCancelSend = false;
  bool _convertToTextPending = false;
  _RecordOverlayMode _overlayMode = _RecordOverlayMode.recording;
  String? _pendingSoundPath;
  int _pendingDuration = 0;
  String _convertedText = '';
  bool _isTranscribing = false;
  bool _transcribeFailed = false;
  bool _isEditingConvertedText = false;
  bool _pointerDown = false;
  bool _isPressing = false;
  DateTime startTime = DateTime.now();
  List<StreamSubscription<Object>> subscriptions = [];
  Future<void>? _recorderInitFuture;
  Timer? _pressTimer;
  Timer? _recordStopFallbackTimer;
  _RecordInputState _recordState = _RecordInputState.idle;
  _RecordReleaseZone _releaseZone = _RecordReleaseZone.send;
  _RecordReleaseZone _gesturePeakZone = _RecordReleaseZone.send;
  bool _convertIntentAtRelease = false;
  DateTime _lastAmplitudeAt = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _levelFallbackTimer;
  double _fallbackPhase = 0;
  double volume = 0.1;
  double _smoothedVolume = 0;
  double _dynamicAmplitudeMax = 1200;
  int _debugAmplitudeSamples = 0;
  String? _recordConversationID;
  ConvType? _recordConversationType;
  OverlayEntry? overlayEntry;

  String get _centerHintText {
    switch (_releaseZone) {
      case _RecordReleaseZone.cancel:
        return '松开取消';
      case _RecordReleaseZone.convertText:
        return '松开后转文字';
      case _RecordReleaseZone.send:
        if (_recordState == _RecordInputState.preparing) {
          return '准备中...';
        }
        return '松开 发送';
    }
  }

  List<double> _liveWaveformHeights({int barCount = _liveWaveformBarCount}) {
    final normalized = max(0.0, min(volume, 1.0));
    final center = (barCount - 1) / 2;
    return List<double>.generate(barCount, (index) {
      final edgeFade = 1.0 - ((index - center).abs() / center).clamp(0.0, 1.0);
      if (edgeFade < 0.18) {
        return 0.14;
      }
      final base = 0.18 + 0.38 * sin(index * 0.58 + _fallbackPhase * 0.35);
      final pulse =
          normalized * edgeFade * (0.5 + 0.5 * sin(index * 0.92 + _fallbackPhase));
      return max(0.14, min(1.0, max(base, pulse)));
    });
  }

  Widget _buildWaveformBars({
    required int barCount,
    required Color color,
    double maxHeight = 24,
    double barWidth = 3,
  }) {
    final bars = _liveWaveformHeights(barCount: barCount);
    return SizedBox(
      height: maxHeight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(barCount, (index) {
          final barHeight = max(4.0, maxHeight * bars[index]);
          return Container(
            width: barWidth,
            height: barHeight,
            margin: EdgeInsets.symmetric(horizontal: barWidth * 0.45),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(barWidth / 2),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCompactWaveformPill() {
    return Container(
      width: _recordSideButtonSize,
      height: _recordSideButtonSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _recordActiveGreen,
        borderRadius: BorderRadius.circular(14),
      ),
      child: _buildWaveformBars(
        barCount: 5,
        color: const Color(0xFF2E2E2E),
        maxHeight: 26,
        barWidth: 2.8,
      ),
    );
  }

  Widget _buildRecordingMainButton({required bool glowing}) {
    return Container(
      width: _recordMainButtonSize + 16,
      height: _recordMainButtonSize + 16,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: glowing
            ? [
                BoxShadow(
                  color: _recordGlowColor.withValues(alpha: 0.55),
                  blurRadius: 22,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Container(
        width: _recordMainButtonSize,
        height: _recordMainButtonSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _recordMainInnerColor.withValues(alpha: 0.92),
          border: Border.all(
            color: glowing ? _recordGlowColor : const Color(0xFF5A6D7C),
            width: glowing ? 3 : 2,
          ),
        ),
        child: const CustomPaint(
          painter: _DiamondDotsPainter(),
        ),
      ),
    );
  }

  Widget _buildRecordingSideButton({
    required bool active,
    required Widget child,
    Color? activeGlowColor,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: _recordSideButtonSize,
      height: _recordSideButtonSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _recordSideButtonColor.withValues(alpha: active ? 0.95 : 0.82),
        boxShadow: active && activeGlowColor != null
            ? [
                BoxShadow(
                  color: activeGlowColor.withValues(alpha: 0.75),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: child,
    );
  }

  Widget _buildRecordingStatusArea(_RecordControlsLayout layout) {
    switch (_releaseZone) {
      case _RecordReleaseZone.cancel:
        return Positioned(
          left: layout.cancelCenter.dx - 36,
          top: layout.statusTopY,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: _recordSideButtonSize,
                height: _recordSideButtonSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _recordCancelRed,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: _buildWaveformBars(
                  barCount: 5,
                  color: Colors.white,
                  maxHeight: 26,
                  barWidth: 2.8,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '松开取消',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.1,
                ),
              ),
            ],
          ),
        );
      case _RecordReleaseZone.convertText:
        return Positioned(
          left: 20,
          right: 20,
          top: layout.statusTopY,
          child: Container(
            height: _recordSideButtonSize,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: _recordActiveGreen,
              borderRadius: BorderRadius.circular(_recordSideButtonSize / 2),
            ),
            child: Row(
              children: [
                const Text(
                  '松开后转文字',
                  style: TextStyle(
                    color: _recordConvertTextGreen,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                _buildWaveformBars(
                  barCount: 7,
                  color: const Color(0xFF2E2E2E),
                  maxHeight: 26,
                ),
              ],
            ),
          ),
        );
      case _RecordReleaseZone.send:
        return Positioned(
          left: layout.mainCenter.dx - _recordSideButtonSize / 2,
          top: layout.statusTopY,
          child: _buildCompactWaveformPill(),
        );
    }
  }

  Widget _buildRecordingControlsPanel(BuildContext overlayContext) {
    final bottomInset = MediaQuery.paddingOf(overlayContext).bottom;
    final cancelActive = _releaseZone == _RecordReleaseZone.cancel;
    final convertActive = _releaseZone == _RecordReleaseZone.convertText;
    final sendActive = _releaseZone == _RecordReleaseZone.send;
    final layout = _RecordControlsLayout(
      panelSize: Size(
        MediaQuery.sizeOf(overlayContext).width,
        _recordPanelHeight + bottomInset,
      ),
      bottomInset: bottomInset,
    );

    return ColoredBox(
      color: _recordDarkPanel,
      child: SizedBox(
        height: layout.panelSize.height,
        width: double.infinity,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            _buildRecordingStatusArea(layout),
            Positioned(
              left: layout.cancelCenter.dx - _recordSideButtonSize / 2,
              top: layout.cancelCenter.dy - _recordSideButtonSize / 2,
              child: _buildRecordingSideButton(
                active: cancelActive,
                activeGlowColor: _recordCancelGlow,
                child: Icon(
                  Icons.close_rounded,
                  color: Colors.white.withValues(alpha: cancelActive ? 1 : 0.72),
                  size: 28,
                ),
              ),
            ),
            Positioned(
              left: layout.mainCenter.dx - (_recordMainButtonSize + 16) / 2,
              top: layout.mainCenter.dy - (_recordMainButtonSize + 16) / 2,
              child: _buildRecordingMainButton(glowing: sendActive),
            ),
            Positioned(
              left: layout.convertCenter.dx - _recordSideButtonSize / 2,
              top: layout.convertCenter.dy - _recordSideButtonSize / 2 - (convertActive ? 22 : 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (convertActive) ...[
                    const Text(
                      '转文字',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  _buildRecordingSideButton(
                    active: convertActive,
                    activeGlowColor: _recordGlowColor,
                    child: Text(
                      '文',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color:
                            Colors.white.withValues(alpha: convertActive ? 1 : 0.72),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConvertStatusBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _recordActiveGreen,
        borderRadius: BorderRadius.circular(26),
      ),
      child: _isTranscribing
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Color(0xFF2E2E2E),
                  ),
                ),
                const SizedBox(width: 12),
                _buildWaveformBars(
                  barCount: 7,
                  color: const Color(0xFF2E2E2E),
                  maxHeight: 22,
                ),
              ],
            )
          : _transcribeFailed
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cancel_outlined,
                      color: Color(0xFF2E2E2E),
                      size: 22,
                    ),
                    SizedBox(width: 8),
                    Text(
                      '转换失败',
                      style: TextStyle(
                        color: Color(0xFF2E2E2E),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              : GestureDetector(
                  onTap: () {
                    setState(() => _isEditingConvertedText = true);
                    overlayEntry?.markNeedsBuild();
                  },
                  child: _isEditingConvertedText
                      ? TextField(
                          controller: _convertedTextController,
                          autofocus: true,
                          maxLines: 3,
                          minLines: 1,
                          style: const TextStyle(
                            fontSize: 18,
                            height: 1.3,
                            color: Color(0xFF111111),
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isCollapsed: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onSubmitted: (_) {
                            setState(() {
                              _isEditingConvertedText = false;
                              _convertedText =
                                  _convertedTextController.text.trim();
                            });
                            overlayEntry?.markNeedsBuild();
                          },
                        )
                      : Text(
                          _convertedText.isEmpty ? ' ' : _convertedText,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            height: 1.3,
                            color: Color(0xFF111111),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
    );
  }

  Widget _buildConvertReviewAction({
    required Widget icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 88,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: _convertReviewActionHeight,
              height: _convertReviewActionHeight,
              decoration: BoxDecoration(
                color: const Color(0xFF4A4A4A).withValues(alpha: 0.95),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: icon,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConvertReviewControlsPanel(
    BuildContext overlayContext,
    TUIChatSeparateViewModel model,
  ) {
    final bottomInset = MediaQuery.paddingOf(overlayContext).bottom;
    final canSendText = !_isTranscribing &&
        !_transcribeFailed &&
        _convertedText.trim().isNotEmpty;

    return ColoredBox(
      color: _recordDarkPanel,
      child: SizedBox(
        height: _recordPanelHeight + bottomInset,
        width: double.infinity,
        child: Column(
          children: [
            _buildConvertStatusBanner(),
            const Spacer(),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, _convertReviewBottomPadding + bottomInset),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConvertReviewAction(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                    label: '取消',
                    onTap: () => unawaited(_dismissConvertReview()),
                  ),
                  _buildConvertReviewAction(
                    icon: _buildWaveformBars(
                      barCount: 4,
                      color: Colors.white,
                      maxHeight: 20,
                      barWidth: 2.5,
                    ),
                    label: '发送原语音',
                    onTap: _pendingSoundPath == null
                        ? null
                        : () => unawaited(_sendOriginalVoice(model)),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: canSendText
                        ? () => unawaited(_sendConvertedText(model))
                        : null,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: canSendText
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: _isTranscribing
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Color(0xFF666666),
                              ),
                            )
                          : Icon(
                              Icons.check_rounded,
                              size: 34,
                              color: canSendText
                                  ? _recordActiveGreen
                                  : const Color(0xFFB8B8B8),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingOverlay(BuildContext overlayContext) {
    final bottomInset = MediaQuery.paddingOf(overlayContext).bottom;
    final panelHeight = _recordPanelHeight + bottomInset;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.42)),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: panelHeight,
            child: _buildRecordingControlsPanel(overlayContext),
          ),
        ],
      ),
    );
  }

  Widget _buildConvertReviewOverlay(BuildContext overlayContext) {
    final model = Provider.of<TUIChatSeparateViewModel>(context, listen: false);
    final bottomInset = MediaQuery.paddingOf(overlayContext).bottom;
    final panelHeight = _recordPanelHeight + bottomInset;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_isEditingConvertedText) {
                  setState(() {
                    _isEditingConvertedText = false;
                    _convertedText = _convertedTextController.text.trim();
                  });
                  overlayEntry?.markNeedsBuild();
                }
              },
              child: Container(color: Colors.black.withValues(alpha: 0.42)),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: panelHeight,
            child: _buildConvertReviewControlsPanel(overlayContext, model),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordOverlay(BuildContext overlayContext) {
    if (_overlayMode == _RecordOverlayMode.convertReview) {
      return _buildConvertReviewOverlay(overlayContext);
    }
    return _buildRecordingOverlay(overlayContext);
  }

  Future<void> _enterConvertReviewMode({
    required String soundPath,
    required int duration,
    required TUIChatSeparateViewModel model,
  }) async {
    if (_overlayMode != _RecordOverlayMode.convertReview) {
      _overlayMode = _RecordOverlayMode.convertReview;
      _pendingSoundPath = soundPath;
      _pendingDuration = duration;
      _convertedText = '';
      _convertedTextController.clear();
      _isTranscribing = true;
      _transcribeFailed = false;
      _isEditingConvertedText = false;
      _isPressing = false;
      _pointerDown = false;
      isRecording = false;
      _recordState = _RecordInputState.idle;
      if (mounted) {
        setState(() {});
      }
      _showOverlay();
    } else {
      _pendingSoundPath = soundPath;
      _pendingDuration = duration;
      _isTranscribing = true;
      _transcribeFailed = false;
      overlayEntry?.markNeedsBuild();
    }

    final text = await model.transcribeLocalVoiceFile(
      soundPath,
      duration: duration,
      convID: _recordConversationID ?? widget.conversationID,
      convType: _recordConversationType ?? widget.conversationType,
    );
    if (!mounted || _overlayMode != _RecordOverlayMode.convertReview) {
      return;
    }
    _isTranscribing = false;
    _convertedText = text?.trim() ?? '';
    _convertedTextController.text = _convertedText;
    if (_convertedText.isEmpty) {
      _transcribeFailed = true;
    }
    if (mounted) {
      setState(() {});
    }
    overlayEntry?.markNeedsBuild();
  }

  void _prepareConvertReviewOverlay() {
    _overlayMode = _RecordOverlayMode.convertReview;
    _pendingSoundPath = null;
    _pendingDuration = 0;
    _convertedText = '';
    _convertedTextController.clear();
    _isTranscribing = true;
    _transcribeFailed = false;
    _isEditingConvertedText = false;
    _showOverlay();
    overlayEntry?.markNeedsBuild();
  }

  Future<void> _enterConvertReviewShortFailure(
    TUIChatSeparateViewModel model, {
    bool showToast = true,
  }) async {
    _recordStopFallbackTimer?.cancel();
    _convertToTextPending = false;
    _overlayMode = _RecordOverlayMode.convertReview;
    _pendingSoundPath = null;
    _pendingDuration = 0;
    _convertedText = '';
    _convertedTextController.clear();
    _isTranscribing = false;
    _transcribeFailed = true;
    _isEditingConvertedText = false;
    _isPressing = false;
    _pointerDown = false;
    isRecording = false;
    _recordState = _RecordInputState.idle;
    if (mounted) {
      setState(() {});
    }
    _showOverlay();
    overlayEntry?.markNeedsBuild();
    if (showToast) {
      onTIMCallback(TIMCallback(
        type: TIMCallbackType.INFO,
        infoRecommendText: '说话时间太短',
        infoCode: 6660404,
      ));
    }
  }

  void _scheduleRecordStopFallback(TUIChatSeparateViewModel model) {
    _recordStopFallbackTimer?.cancel();
    _recordStopFallbackTimer = Timer(const Duration(milliseconds: 600), () {
      if (!mounted ||
          (!_convertToTextPending && !_convertIntentAtRelease)) {
        return;
      }
      unawaited(_onRecorderStop(
        model: model,
        soundPath: null,
        recordDuration: null,
      ));
    });
  }

  Future<void> _onRecorderStop({
    required TUIChatSeparateViewModel model,
    String? soundPath,
    double? recordDuration,
  }) async {
    _recordStopFallbackTimer?.cancel();
    final convertPending = _convertToTextPending || _convertIntentAtRelease;
    final duration = recordDuration?.ceil() ?? 0;
    final hasValidFile =
        soundPath != null && soundPath.isNotEmpty && duration > 0;
    final shouldProcess = !isCancelSend &&
        (_recordState == _RecordInputState.stopping ||
            _recordState == _RecordInputState.recording ||
            convertPending);

    if (shouldProcess && hasValidFile) {
      await sendSound(
        path: soundPath,
        duration: duration,
        model: model,
      );
      if (_overlayMode != _RecordOverlayMode.convertReview) {
        _resetRecordUi(cancel: false);
      }
      return;
    }

    if (convertPending && !isCancelSend) {
      await _enterConvertReviewShortFailure(model);
      return;
    }

    if (_overlayMode != _RecordOverlayMode.convertReview) {
      _resetRecordUi(cancel: isCancelSend);
    }
  }

  Future<void> _dismissConvertReview() async {
    final model =
        Provider.of<TUIChatSeparateViewModel>(context, listen: false);
    await model.discardVoiceToTextPendingUpload();
    _overlayMode = _RecordOverlayMode.recording;
    _pendingSoundPath = null;
    _pendingDuration = 0;
    _convertedText = '';
    _convertedTextController.clear();
    _isTranscribing = false;
    _transcribeFailed = false;
    _isEditingConvertedText = false;
    _hideOverlay();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _sendOriginalVoice(TUIChatSeparateViewModel model) async {
    final path = _pendingSoundPath;
    final duration = _pendingDuration;
    if (path == null || duration <= 0) {
      await _dismissConvertReview();
      return;
    }
    final convID = _recordConversationID ?? widget.conversationID;
    final convType = _recordConversationType ?? widget.conversationType;
    final hadPendingUpload = model.hasVoiceToTextPendingUpload;
    model.acknowledgeVoiceToTextPendingUpload();
    _dismissConvertReviewWithoutRevoke();
    widget.onDownBottom();
    if (!hadPendingUpload) {
      MessageUtils.handleMessageError(
        model.sendSoundMessage(
          soundPath: path,
          duration: duration,
          convID: convID,
          convType: convType,
        ),
        context,
      );
    }
  }

  void _dismissConvertReviewWithoutRevoke() {
    _overlayMode = _RecordOverlayMode.recording;
    _pendingSoundPath = null;
    _pendingDuration = 0;
    _convertedText = '';
    _convertedTextController.clear();
    _isTranscribing = false;
    _transcribeFailed = false;
    _isEditingConvertedText = false;
    _hideOverlay();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _sendConvertedText(TUIChatSeparateViewModel model) async {
    final text = (_isEditingConvertedText
            ? _convertedTextController.text
            : _convertedText)
        .trim();
    if (text.isEmpty) {
      onTIMCallback(TIMCallback(
        type: TIMCallbackType.INFO,
        infoRecommendText: '请输入要发送的文字',
        infoCode: 6660426,
      ));
      return;
    }
    final convID = _recordConversationID ?? widget.conversationID;
    final convType = _recordConversationType ?? widget.conversationType;
    await model.discardVoiceToTextPendingUpload();
    _dismissConvertReviewWithoutRevoke();
    widget.onDownBottom();
    MessageUtils.handleMessageError(
      model.sendTextMessage(text: text, convID: convID, convType: convType),
      context,
    );
  }

  _RecordReleaseZone _resolveReleaseZone(Offset globalPosition, Size screenSize) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final panelHeight = _recordPanelHeight + bottomInset;
    final panelTop = screenSize.height - panelHeight;
    final layout = _RecordControlsLayout(
      panelSize: Size(screenSize.width, panelHeight),
      bottomInset: bottomInset,
    );
    final local = Offset(globalPosition.dx, globalPosition.dy - panelTop);

    if (layout.hitCancel(local)) {
      return _RecordReleaseZone.cancel;
    }
    if (layout.hitConvert(local)) {
      return _RecordReleaseZone.convertText;
    }
    return _RecordReleaseZone.send;
  }

  void _updateReleaseZone({
    required Offset globalPosition,
    required Offset localPosition,
  }) {
    final overlayVisible = overlayEntry?.mounted ?? false;
    if (!isRecording && !overlayVisible) {
      return;
    }

    final screenSize = MediaQuery.sizeOf(context);
    final nextZone = _resolveReleaseZone(globalPosition, screenSize);

    if (nextZone == _releaseZone && soundTipsText == _centerHintText) {
      return;
    }

    _releaseZone = nextZone;
    if (nextZone == _RecordReleaseZone.send) {
      _gesturePeakZone = _RecordReleaseZone.send;
    } else if (_releaseZonePriority(nextZone) >
        _releaseZonePriority(_gesturePeakZone)) {
      _gesturePeakZone = nextZone;
    }
    soundTipsText = _centerHintText;
    if (overlayVisible) {
      overlayEntry?.markNeedsBuild();
    } else if (mounted) {
      setState(() {});
    }
  }

  double? _extractAmplitudeNumber(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    final direct = double.tryParse(raw.trim());
    if (direct != null) {
      return direct;
    }
    final match = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(raw);
    if (match == null) {
      return null;
    }
    return double.tryParse(match.group(0)!);
  }

  double _normalizeAmplitude(String? raw) {
    final value = _extractAmplitudeNumber(raw);
    if (value == null || value.isNaN || value.isInfinite) {
      return 0;
    }

    double normalized;
    if (value <= 0) {
      // iOS 常返回负分贝值，普通说话可能落在 -45～-25。
      // 使用稍窄的有效区间和曲线放大，避免音量条长期只有 1 格。
      final lowerBound = (!kIsWeb && Platform.isIOS) ? -55.0 : -60.0;
      final curved = ((value.clamp(lowerBound, 0.0) - lowerBound) /
              (0.0 - lowerBound))
          .toDouble();
      normalized = (!kIsWeb && Platform.isIOS)
          ? pow(curved, 0.65).toDouble()
          : curved;
    } else if (value <= 1.0) {
      // 已经是 0～1。
      normalized = value;
    } else if (value <= 100.0) {
      // 部分平台返回 0～100 的百分制音量。
      normalized = value / 100.0;
    } else {
      // 原始振幅，如 0～32767。用动态最大值归一，避免长期满格或不动。
      _dynamicAmplitudeMax = max(_dynamicAmplitudeMax * 0.96, value);
      normalized = value / max(_dynamicAmplitudeMax, 1.0);
    }

    normalized = normalized.clamp(0.0, 1.0).toDouble();
    if (normalized < 0.03) {
      normalized = 0;
    }
    return normalized;
  }

  void _resetAmplitudeState() {
    volume = 0.1;
    _smoothedVolume = 0;
    _dynamicAmplitudeMax = 1200;
    _debugAmplitudeSamples = 0;
    _lastAmplitudeAt = DateTime.fromMillisecondsSinceEpoch(0);
  }

  void _applyAmplitudeSample(String? raw) {
    final normalized = _normalizeAmplitude(raw);
    _smoothedVolume = _smoothedVolume * 0.65 + normalized * 0.35;
    final minDisplayVolume = (!kIsWeb && Platform.isIOS) ? 0.12 : 0.1;
    final nextVolume = max(minDisplayVolume, min(_smoothedVolume, 1.0));

    if (kDebugMode && _debugAmplitudeSamples < 20) {
      _debugAmplitudeSamples += 1;
      debugPrint(
        'SendSoundMessage amplitude #$_debugAmplitudeSamples raw=$raw '
        'normalized=${normalized.toStringAsFixed(3)} '
        'smooth=${nextVolume.toStringAsFixed(3)}',
      );
    }

    volume = nextVolume;
  }

  void _startLevelFallbackTimer() {
    _levelFallbackTimer?.cancel();
    _levelFallbackTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (!mounted || _recordState != _RecordInputState.recording) {
        return;
      }
      final overlayVisible = overlayEntry?.mounted ?? false;
      if (!overlayVisible) {
        return;
      }
      final hasFreshAmplitude = DateTime.now().difference(_lastAmplitudeAt) <
          const Duration(milliseconds: 350);
      if (hasFreshAmplitude && _debugAmplitudeSamples > 0) {
        return;
      }
      _fallbackPhase += 0.8;
      final fallbackVolume = 0.16 + (sin(_fallbackPhase) + 1.0) * 0.12;
      volume = fallbackVolume.clamp(0.1, 0.42).toDouble();
      overlayEntry?.markNeedsBuild();
    });
  }

  void _stopLevelFallbackTimer() {
    _levelFallbackTimer?.cancel();
    _levelFallbackTimer = null;
    _fallbackPhase = 0;
  }

  void _ensureOverlayEntry() {
    if (overlayEntry != null) {
      return;
    }
    overlayEntry = OverlayEntry(
      builder: (overlayContext) {
        return Positioned.fill(
          child: _buildRecordOverlay(overlayContext),
        );
      },
    );
  }

  void _safeHideOverlay() {
    final entry = overlayEntry;
    if (entry == null || !entry.mounted) {
      return;
    }
    try {
      entry.remove();
    } catch (_) {
      // Overlay 可能已被父级销毁，忽略避免打断录音状态机。
    }
  }

  void _showOverlay() {
    _ensureOverlayEntry();
    final entry = overlayEntry;
    if (entry == null) {
      return;
    }
    if (!entry.mounted) {
      try {
        Overlay.of(context).insert(entry);
      } catch (_) {
        return;
      }
    } else {
      entry.markNeedsBuild();
    }
  }

  void _hideOverlay() {
    _safeHideOverlay();
  }

  /// 上次 onStop/异常未复位时，避免 _beginRecording 因 state!=idle 直接无响应。
  void _recoverStaleRecordStateIfNeeded() {
    if (_recordState == _RecordInputState.idle) {
      return;
    }
    if (isRecording || (overlayEntry?.mounted ?? false)) {
      return;
    }
    _pressTimer?.cancel();
    _pressTimer = null;
    _pointerDown = false;
    isRecording = false;
    _isPressing = false;
    isCancelSend = false;
    _recordState = _RecordInputState.idle;
    _recordConversationID = null;
    _recordConversationType = null;
  }

  void _precacheOverlayAssets() {}

  void _resetReleaseZone() {
    _releaseZone = _RecordReleaseZone.send;
    _gesturePeakZone = _RecordReleaseZone.send;
  }

  int _releaseZonePriority(_RecordReleaseZone zone) {
    switch (zone) {
      case _RecordReleaseZone.cancel:
        return 3;
      case _RecordReleaseZone.convertText:
        return 2;
      case _RecordReleaseZone.send:
        return 1;
    }
  }

  _RecordReleaseZone _intentReleaseZone() => _releaseZone;

  Future<void> _ensureRecorderReady(
    TUIChatSeparateViewModel model,
    TUITheme theme, {
    bool requestPermission = true,
  }) async {
    if (isInit) {
      return;
    }
    _recorderInitFuture ??= _initRecorder(model, theme, requestPermission);
    try {
      await _recorderInitFuture;
    } finally {
      if (!isInit) {
        _recorderInitFuture = null;
      }
    }
  }

  Future<void> _initRecorder(
    TUIChatSeparateViewModel model,
    TUITheme theme,
    bool requestPermission,
  ) async {
    if (isInit) {
      return;
    }
    if (requestPermission) {
      final hasMicrophonePermission = await Permissions.checkPermission(
        context,
        Permission.microphone.value,
        theme,
      );
      if (!hasMicrophonePermission || !mounted) {
        return;
      }
    }
    await initRecordSound(model);
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_pointerDown) {
      return;
    }
    _recoverStaleRecordStateIfNeeded();
    _resetReleaseZone();
    isCancelSend = false;
    _convertIntentAtRelease = false;
    _pointerDown = true;
    final model =
        Provider.of<TUIChatSeparateViewModel>(context, listen: false);
    final theme = Provider.of<TUIThemeViewModel>(context, listen: false).theme;
    // 切语音模式时已申请过麦克风；此处不阻塞弹权限框，只做预热。
    unawaited(_ensureRecorderReady(model, theme, requestPermission: false));
    setState(() {
      _isPressing = true;
    });
    unawaited(_beginRecording());
  }

  Future<void> _beginRecording() async {
    if (!_pointerDown || !mounted) {
      return;
    }
    _recoverStaleRecordStateIfNeeded();
    if (_recordState != _RecordInputState.idle) {
      if (isRecording || (overlayEntry?.mounted ?? false)) {
        return;
      }
      _recordState = _RecordInputState.idle;
    }
    final model =
        Provider.of<TUIChatSeparateViewModel>(context, listen: false);
    final theme = Provider.of<TUIThemeViewModel>(context, listen: false).theme;
    _recordConversationID = widget.conversationID;
    _recordConversationType = widget.conversationType;
    _recordState = _RecordInputState.preparing;

    final hasMicrophonePermission = await Permissions.checkPermission(
      context,
      Permission.microphone.value,
      theme,
    );
    if (!hasMicrophonePermission || !_pointerDown || !mounted) {
      _resetRecordUi(cancel: true);
      return;
    }

    await _ensureRecorderReady(model, theme, requestPermission: false);
    if (!_pointerDown || !mounted) {
      _resetRecordUi(cancel: true);
      return;
    }
    if (!isInit || !mounted || isRecording) {
      _resetRecordUi(cancel: true);
      if (!_pointerDown || !mounted) {
        return;
      }
      if (!isInit) {
        onTIMCallback(TIMCallback(
          type: TIMCallbackType.INFO,
          infoRecommendText: "语音输入不可用，请检查麦克风权限或稍后重试",
          infoCode: 6660405,
        ));
      }
      return;
    }
    startTime = DateTime.now();
    final started = await SoundPlayer.startRecord();
    if (!started) {
      _recordState = _RecordInputState.error;
      _resetRecordUi(cancel: true);
      onTIMCallback(TIMCallback(
        type: TIMCallbackType.INFO,
        infoRecommendText: "语音输入不可用，请检查麦克风权限或稍后重试",
        infoCode: 6660405,
      ));
    }
  }

  void _resetRecordUi({bool cancel = false}) {
    _recordStopFallbackTimer?.cancel();
    _convertIntentAtRelease = false;
    _pointerDown = false;
    _pressTimer?.cancel();
    _pressTimer = null;
    _stopLevelFallbackTimer();
    isCancelSend = cancel;
    if (cancel) {
      _convertToTextPending = false;
      if (_overlayMode == _RecordOverlayMode.convertReview) {
        _dismissConvertReview();
        return;
      }
    }
    try {
      _safeHideOverlay();
      if (!mounted) {
        isRecording = false;
        _isPressing = false;
        _recordConversationID = null;
        _recordConversationType = null;
        _recordState = _RecordInputState.idle;
        _resetReleaseZone();
        return;
      }
      setState(() {
        isRecording = false;
        _isPressing = false;
        _resetReleaseZone();
        soundTipsText = _centerHintText;
        _resetAmplitudeState();
      });
      overlayEntry?.markNeedsBuild();
    } finally {
      _recordConversationID = null;
      _recordConversationType = null;
      _recordState = _RecordInputState.idle;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_pointerDown) {
      return;
    }
    _updateReleaseZone(
      globalPosition: event.position,
      localPosition: event.localPosition,
    );
  }

  void _finishPointerSession({
    required Offset globalPosition,
    required Offset localPosition,
  }) {
    final wasRecording = isRecording || (overlayEntry?.mounted ?? false);
    final cancelRequested = isCancelSend;
    _updateReleaseZone(
      globalPosition: globalPosition,
      localPosition: localPosition,
    );
    final intentZone = _intentReleaseZone();
    final shouldCancel = intentZone == _RecordReleaseZone.cancel;
    final convertToText = intentZone == _RecordReleaseZone.convertText;
    _pointerDown = false;
    _pressTimer?.cancel();
    _pressTimer = null;

    if (!wasRecording) {
      _resetRecordUi(cancel: true);
      return;
    }

    isCancelSend = shouldCancel || cancelRequested;
    if (isCancelSend) {
      _recordStopFallbackTimer?.cancel();
      _convertToTextPending = false;
      _convertIntentAtRelease = false;
    } else if (convertToText) {
      _convertToTextPending = true;
      _convertIntentAtRelease = true;
      _prepareConvertReviewOverlay();
    } else {
      _convertToTextPending = false;
      _convertIntentAtRelease = false;
    }

    final elapsedMs = DateTime.now().difference(startTime).inMilliseconds;
    if (isRecording &&
        elapsedMs < 1000 &&
        !convertToText &&
        !isCancelSend) {
      isCancelSend = true;
      _convertToTextPending = false;
      onTIMCallback(TIMCallback(
          type: TIMCallbackType.INFO,
          infoRecommendText: "说话时间太短",
          infoCode: 6660404));
    }
    stop();
  }

  void _onPointerUp(PointerUpEvent event) {
    _finishPointerSession(
      globalPosition: event.position,
      localPosition: event.localPosition,
    );
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _finishPointerSession(
      globalPosition: event.position,
      localPosition: event.localPosition,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resetReleaseZone();
    soundTipsText = _centerHintText;
    // 按住说话时再初始化录音器，避免进入语音模式就抢占麦克风权限。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _precacheOverlayAssets();
      _ensureOverlayEntry();
      final model =
          Provider.of<TUIChatSeparateViewModel>(context, listen: false);
      final theme = Provider.of<TUIThemeViewModel>(context, listen: false).theme;
      unawaited(_ensureRecorderReady(model, theme, requestPermission: false));
      unawaited(SoundPlayer.prepareRecordSession());
    });
  }

  void stop() {
    if (_recordState == _RecordInputState.stopping ||
        _recordState == _RecordInputState.cancelled) {
      return;
    }
    _recordState =
        isCancelSend ? _RecordInputState.cancelled : _RecordInputState.stopping;
    _stopLevelFallbackTimer();
    if (!_convertToTextPending && _overlayMode != _RecordOverlayMode.convertReview) {
      _safeHideOverlay();
    }
    if (mounted) {
      setState(() {
        isRecording = false;
        _isPressing = false;
        _resetReleaseZone();
        soundTipsText = _centerHintText;
        _resetAmplitudeState();
      });
    }
    if ((_convertToTextPending || _convertIntentAtRelease) && mounted) {
      final model =
          Provider.of<TUIChatSeparateViewModel>(context, listen: false);
      _scheduleRecordStopFallback(model);
    }
    unawaited(SoundPlayer.stopRecord());
  }

  Future<void> sendSound(
      {required String path,
      required int duration,
      required TUIChatSeparateViewModel model}) async {
    if (!mounted) {
      outputLogger.i('skip send sound: widget disposed before recorder onStop');
      return;
    }
    final convID = _recordConversationID ?? widget.conversationID;
    final convType = _recordConversationType ?? widget.conversationType;

    if (duration > 0) {
      if (!isCancelSend) {
        if (convID.trim().isEmpty || convType == ConvType.none) {
          outputLogger.i(
            'skip send sound: invalid conversation target, convID=$convID, convType=$convType',
          );
          onTIMCallback(TIMCallback(
            type: TIMCallbackType.INFO,
            infoRecommendText: '当前会话已失效，请返回后重试',
            infoCode: 6660420,
          ));
          return;
        }
        final uniquePath =
            await SoundPlayer.copyRecordingToUniquePath(path) ?? path;
        if (!mounted) {
          return;
        }
        widget.onDownBottom();
        if (_convertToTextPending || _convertIntentAtRelease) {
          _convertToTextPending = false;
          _convertIntentAtRelease = false;
          await _enterConvertReviewMode(
            soundPath: uniquePath,
            duration: duration,
            model: model,
          );
          return;
        }
        MessageUtils.handleMessageError(
            model.sendSoundMessage(
                soundPath: uniquePath,
                duration: duration,
                convID: convID,
                convType: convType),
            context);
      } else {
        isCancelSend = false;
      }
    } else {
      if ((_convertToTextPending || _convertIntentAtRelease) && !isCancelSend) {
        await _enterConvertReviewShortFailure(model);
      } else if (!isCancelSend) {
        onTIMCallback(TIMCallback(
            type: TIMCallbackType.INFO,
            infoRecommendText: "说话时间太短",
            infoCode: 6660404));
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      return;
    }
    if (_pointerDown || isRecording || (overlayEntry?.mounted ?? false)) {
      isCancelSend = true;
      _convertToTextPending = false;
      _dismissConvertReview();
      unawaited(SoundPlayer.stopRecord());
      _resetRecordUi(cancel: true);
    }
  }

  @override
  dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pressTimer?.cancel();
    _stopLevelFallbackTimer();
    _recordStopFallbackTimer?.cancel();
    unawaited(SoundPlayer.stopRecord());
    _hideOverlay();
    _convertedTextController.dispose();
    overlayEntry?.dispose();
    overlayEntry = null;
    for (var subscription in subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  Future<void> initRecordSound(TUIChatSeparateViewModel model) async {
    if (isInit) {
      return;
    }
    final responseSubscription = SoundPlayer.responseListener((recordResponse) {
      final status = recordResponse.msg;
      if (status == "onStop") {
        unawaited(_onRecorderStop(
          model: model,
          soundPath: recordResponse.path,
          recordDuration: recordResponse.audioTimeLength,
        ));
      } else if (status == "onRecordFail") {
        unawaited(_onRecorderStop(
          model: model,
          soundPath: null,
          recordDuration: null,
        ));
      } else if (status == "onStart") {
        if (!_pointerDown ||
            _recordState == _RecordInputState.stopping ||
            _recordState == _RecordInputState.cancelled) {
          unawaited(SoundPlayer.stopRecord());
          return;
        }
        outputLogger.i("start record");
        HapticFeedback.mediumImpact();
        _recordState = _RecordInputState.recording;
        if (mounted) {
          setState(() {
            isRecording = true;
            _resetReleaseZone();
            soundTipsText = _centerHintText;
            _resetAmplitudeState();
          });
          _showOverlay();
          _startLevelFallbackTimer();
          overlayEntry?.markNeedsBuild();
        }
      } else {
        outputLogger.i(status.toString());
      }
    });
    final amplitudesResponseSubscription =
        SoundPlayer.responseFromAmplitudeListener((recordResponse) {
      if (!mounted) {
        return;
      }
      if (_recordState != _RecordInputState.recording ||
          !(overlayEntry?.mounted ?? false)) {
        return;
      }
      final now = DateTime.now();
      if (now.difference(_lastAmplitudeAt) < const Duration(milliseconds: 100)) {
        return;
      }
      _lastAmplitudeAt = now;
      _applyAmplitudeSample(recordResponse.msg);
      overlayEntry?.markNeedsBuild();
    });
    subscriptions = [responseSubscription, amplitudesResponseSubscription];
    await SoundPlayer.initSoundPlayer();
    if (!mounted) {
      return;
    }
    isInit = SoundPlayer.isInit;
    if (!isInit) {
      onTIMCallback(TIMCallback(
        type: TIMCallbackType.INFO,
        infoRecommendText: "语音输入不可用，请检查麦克风权限或稍后重试",
        infoCode: 6660405,
      ));
    }
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final TUITheme theme = value.theme;
    final panelColor =
        theme.weakBackgroundColor ?? theme.weakDividerColor ?? const Color(0xFFF3F3F3);
    final isActive = isRecording || _isPressing;
    final hintText = isActive ? '松开 结束' : '点击 或 长按 开始录音';

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      behavior: HitTestBehavior.opaque,
      child: ColoredBox(
        color: panelColor,
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                width: _micButtonSize,
                height: _micButtonSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isActive
                        ? const [
                            _idleMicActiveTopColor,
                            _idleMicActiveBottomColor,
                          ]
                        : const [
                            _idleMicTopColor,
                            _idleMicBottomColor,
                          ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isActive ? 0.18 : 0.12),
                      blurRadius: isActive ? 16 : 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.mic_rounded,
                  size: 42,
                  color: _micIconColor,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                hintText,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.2,
                  color: theme.weakTextColor ?? const Color(0xFF999999),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 录音中底部三按钮布局与命中区域。
class _RecordControlsLayout {
  _RecordControlsLayout({
    required this.panelSize,
    required this.bottomInset,
  });

  final Size panelSize;
  final double bottomInset;

  static const double _mainSize = 124;
  static const double _sideSize = 56;
  static const double _sideGap = 48;

  Offset get mainCenter => Offset(
        panelSize.width / 2,
        panelSize.height - bottomInset - 92,
      );

  Offset get cancelCenter => Offset(
        mainCenter.dx - _mainSize / 2 - _sideGap - _sideSize / 2,
        mainCenter.dy,
      );

  Offset get convertCenter => Offset(
        mainCenter.dx + _mainSize / 2 + _sideGap + _sideSize / 2,
        mainCenter.dy,
      );

  double get statusTopY => mainCenter.dy - _mainSize / 2 - 88;

  bool hitCancel(Offset local) =>
      (local - cancelCenter).distance <= _sideSize / 2 + 18;

  bool hitConvert(Offset local) =>
      (local - convertCenter).distance <= _sideSize / 2 + 18;
}

/// 录音主按钮中心菱形点阵。
class _DiamondDotsPainter extends CustomPainter {
  const _DiamondDotsPainter();

  static const List<Offset> _offsets = [
    Offset(0, -24),
    Offset(-12, -12),
    Offset(12, -12),
    Offset(-24, 0),
    Offset(0, 0),
    Offset(24, 0),
    Offset(-12, 12),
    Offset(12, 12),
    Offset(0, 24),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF2C3844);
    final center = Offset(size.width / 2, size.height / 2);
    for (final offset in _offsets) {
      canvas.drawCircle(center + offset, 3.2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

