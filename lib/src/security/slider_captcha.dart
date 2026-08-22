import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tencent_cloud_chat_demo/src/api/api_client.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';

class SliderCaptchaResult {
  const SliderCaptchaResult({
    required this.token,
    required this.backgroundBytes,
    required this.backgroundImage,
    required this.width,
    required this.height,
    required this.targetX,
    required this.targetY,
    required this.gapX,
    required this.gapY,
    required this.gapWidth,
    required this.gapHeight,
    required this.fakeGaps,
  });

  final String token;
  final Uint8List backgroundBytes;
  final ui.Image backgroundImage;
  final int width;
  final int height;
  final int targetX;
  final int targetY;
  final int gapX;
  final int gapY;
  final int gapWidth;
  final int gapHeight;
  final List<SliderGapRect> fakeGaps;
}

class SliderGapRect {
  const SliderGapRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final int x;
  final int y;
  final int width;
  final int height;

  factory SliderGapRect.fromJson(dynamic raw) {
    final map = _asMap(raw);
    return SliderGapRect(
      x: _readInt(map, const ['x']) ?? 0,
      y: _readInt(map, const ['y']) ?? 0,
      width: _readInt(map, const ['width']) ?? 50,
      height: _readInt(map, const ['height']) ?? 50,
    );
  }
}

class SliderCaptchaApi {
  SliderCaptchaApi._();

  static final SliderCaptchaApi instance = SliderCaptchaApi._();

  Dio get _dio => ApiClient.instance.dio;

  Future<SliderCaptchaResult> init() async {
    final res = await _dio.get<dynamic>('/auth/slider/init');
    final data = _unwrapMap(res.data);
    final headerToken = _readHeader(res.headers, 'X-Captcha-Token');
    final token = headerToken.isNotEmpty
        ? headerToken
        : (_readString(data, const ['token']) ?? '');
    final width = _readHeaderInt(res.headers, 'X-Captcha-Width') ?? 320;
    final height = _readHeaderInt(res.headers, 'X-Captcha-Height') ?? 170;
    final background = _readString(data, const ['background']) ?? '';
    final backgroundBytes = _decodeBackgroundBytes(background);
    if (token.isEmpty) {
      throw const FormatException('slider token is empty');
    }
    if (backgroundBytes.isEmpty) {
      throw const FormatException('slider background is empty');
    }
    final targetX = _readInt(data, const ['targetX', 'gapX']) ?? 0;
    final targetY = _readInt(data, const ['targetY', 'gapY']) ?? 0;
    final gapX = _readInt(data, const ['gapX', 'targetX']) ?? targetX;
    final gapY = _readInt(data, const ['gapY', 'targetY']) ?? targetY;
    final gapWidth = _readInt(data, const ['gapWidth']) ?? 50;
    final gapHeight = _readInt(data, const ['gapHeight']) ?? 50;
    final backgroundImage = await _decodeUiImage(backgroundBytes);
    return SliderCaptchaResult(
      token: token,
      backgroundBytes: backgroundBytes,
      backgroundImage: backgroundImage,
      width: width <= 0 ? 320 : width,
      height: height <= 0 ? 170 : height,
      targetX: targetX,
      targetY: targetY,
      gapX: gapX,
      gapY: gapY,
      gapWidth: gapWidth <= 0 ? 50 : gapWidth,
      gapHeight: gapHeight <= 0 ? 50 : gapHeight,
      fakeGaps: _readFakeGaps(data['fakeGaps']),
    );
  }

  Future<bool> verify({
    required String token,
    required int x,
    int? y,
  }) async {
    final res = await _dio.post(
      '/auth/slider/verify',
      data: {
        'token': token,
        'x': x,
        if (y != null) 'y': y,
      },
    );
    final data = _unwrapMap(res.data);
    final rawSuccess = data['success'] ?? data['ok'] ?? data['passed'];
    if (rawSuccess is bool) return rawSuccess;
    if (rawSuccess is num) return rawSuccess != 0;
    final successText = rawSuccess?.toString().toLowerCase().trim();
    if (successText == 'true' || successText == '1' || successText == 'ok') {
      return true;
    }
    final code = data['code']?.toString();
    return code == '0' || code?.toUpperCase() == 'OK';
  }
}

String _sliderErrorMessage(Object error, {required bool loading}) {
  String raw = '';
  if (error is DioError) {
    final data = error.response?.data;
    if (data is Map) {
      for (final key in const ['message', 'msg', 'error', 'desc', 'detail']) {
        final value = data[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          raw = value.toString().trim();
          break;
        }
      }
      final inner = data['data'];
      if (raw.isEmpty && inner is Map) {
        for (final key in const ['message', 'msg', 'error', 'desc', 'detail']) {
          final value = inner[key];
          if (value != null && value.toString().trim().isNotEmpty) {
            raw = value.toString().trim();
            break;
          }
        }
      }
    }
    raw = raw.isNotEmpty ? raw : error.message.trim();
  } else {
    raw = error.toString();
  }
  final lower = raw.toLowerCase();
  if (lower.contains('invalid or expired token') ||
      ((lower.contains('invalid') || lower.contains('expired')) &&
          lower.contains('token'))) {
    return '验证已过期，请重新验证';
  }
  if (lower.contains('too many') || lower.contains('rate limit')) {
    return '请求太频繁，请稍后再试';
  }
  return loading ? '滑块验证加载失败，请重试' : '验证失败，请重试';
}

Future<bool> showSliderCaptcha(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => const SliderCaptchaDialog(),
  );
  return result == true;
}

enum _CaptchaStage { loading, idle, dragging, verifying, success, failure }

class SliderCaptchaDialog extends StatefulWidget {
  const SliderCaptchaDialog({super.key});

  @override
  State<SliderCaptchaDialog> createState() => _SliderCaptchaDialogState();
}

class _SliderCaptchaDialogState extends State<SliderCaptchaDialog> {
  SliderCaptchaResult? _challenge;
  _CaptchaStage _stage = _CaptchaStage.loading;
  String? _error;
  double _x = 0;
  SliderGapRect? _selectedFakeGap;
  double _fakeGapRotation = 0;

  static const double _panelWidth = 320;
  static const double _sliderHeight = 48;
  static const double _thumbWidth = 58;

  bool get _loading => _stage == _CaptchaStage.loading;
  bool get _verifying => _stage == _CaptchaStage.verifying;
  bool get _locked =>
      _loading ||
      _stage == _CaptchaStage.verifying ||
      _stage == _CaptchaStage.success ||
      _stage == _CaptchaStage.failure;

  double _maxXFor(double panelWidth) => panelWidth - _thumbWidth;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _challenge = null;
      _stage = _CaptchaStage.loading;
      _error = null;
      _x = 0;
      _selectedFakeGap = null;
      _fakeGapRotation = 0;
    });
    try {
      final challenge = await SliderCaptchaApi.instance.init();
      final random = math.Random();
      final selectedFakeGap = challenge.fakeGaps.isEmpty
          ? null
          : challenge.fakeGaps[random.nextInt(challenge.fakeGaps.length)];
      if (!mounted) return;
      setState(() {
        _challenge = challenge;
        _stage = _CaptchaStage.idle;
        _selectedFakeGap = selectedFakeGap;
        _fakeGapRotation =
            selectedFakeGap == null ? 0 : (random.nextDouble() * math.pi * 2);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _CaptchaStage.idle;
        _error = _sliderErrorMessage(e, loading: true);
      });
    }
  }

  Future<void> _verify(double panelWidth, double imageHeight) async {
    final challenge = _challenge;
    if (challenge == null || _locked) return;
    final submitX = _submitX(panelWidth, imageHeight, challenge);
    final submitY = challenge.targetY;
    setState(() {
      _stage = _CaptchaStage.verifying;
      _error = null;
    });
    try {
      final ok = await SliderCaptchaApi.instance.verify(
        token: challenge.token,
        x: submitX,
        y: submitY,
      );
      if (!mounted) return;
      if (ok) {
        setState(() {
          _stage = _CaptchaStage.success;
          _error = null;
        });
        HapticFeedback.mediumImpact();
        await Future<void>.delayed(const Duration(milliseconds: 900));
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop(true);
        }
        return;
      }
      await _failThenReload('未对准，请重试');
    } catch (e) {
      if (!mounted) return;
      await _failThenReload(_sliderErrorMessage(e, loading: false));
    }
  }

  Future<void> _failThenReload(String message) async {
    setState(() {
      _stage = _CaptchaStage.failure;
      _error = message.trim().isEmpty ? '未对准，请重试' : message.trim();
      _x = 0;
    });
    HapticFeedback.lightImpact();
    await Future<void>.delayed(const Duration(milliseconds: 950));
    if (mounted) await _load();
  }

  int _submitX(
    double panelWidth,
    double imageHeight,
    SliderCaptchaResult challenge,
  ) {
    final displayX = _pieceDisplayX(panelWidth, imageHeight, challenge);
    final maxDisplayX = math.max(
      1.0,
      panelWidth - _pieceDisplayWidth(panelWidth, challenge),
    );
    final scaledX =
        displayX / maxDisplayX * (challenge.width - challenge.gapWidth);
    return scaledX.round();
  }

  double _imageHeightFor(double panelWidth) {
    final challenge = _challenge;
    final width = (challenge?.width ?? 320).clamp(1, 10000);
    final height = (challenge?.height ?? 170).clamp(1, 10000);
    return panelWidth * height / width;
  }

  double _pieceDisplayWidth(double panelWidth, SliderCaptchaResult challenge) {
    return panelWidth * challenge.gapWidth / challenge.width;
  }

  double _pieceDisplayHeight(
      double imageHeight, SliderCaptchaResult challenge) {
    return imageHeight * challenge.gapHeight / challenge.height;
  }

  double _pieceDisplayX(
    double panelWidth,
    double imageHeight,
    SliderCaptchaResult challenge,
  ) {
    final trackRange = _maxXFor(panelWidth);
    if (trackRange <= 0) return 0;
    final imageRange = math.max(
      0.0,
      panelWidth - _pieceDisplayWidth(panelWidth, challenge),
    );
    final normalized = _x.clamp(0, trackRange) / trackRange;
    return normalized * imageRange;
  }

  double _pieceDisplayY(double imageHeight, SliderCaptchaResult challenge) {
    return imageHeight * challenge.targetY / challenge.height;
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final panelWidth = math
        .min(_panelWidth, screenWidth - 48)
        .clamp(280.0, _panelWidth)
        .toDouble();
    final imageHeight = _imageHeightFor(panelWidth);
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: panelWidth + 32,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: BoxDecoration(
            color: AppColors.card(dark: dark),
            borderRadius: BorderRadius.circular(3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.45 : 0.2),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(dark),
              const SizedBox(height: 14),
              SizedBox(
                width: panelWidth,
                height: imageHeight,
                child: _buildCaptchaImage(panelWidth, imageHeight, dark),
              ),
              const SizedBox(height: 14),
              _buildSlider(panelWidth, imageHeight, dark),
              const SizedBox(height: 10),
              _buildFooter(dark),
              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(
                  _error!,
                  style:
                      const TextStyle(color: Color(0xFFE53935), fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool dark) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '安全验证',
                style: TextStyle(
                  color: AppColors.text(dark: dark),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '拖动下方滑块完成拼图',
                style: TextStyle(
                  color: AppColors.subText(dark: dark),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _verifying
              ? null
              : () => Navigator.of(context, rootNavigator: true).pop(false),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              Icons.close,
              color: AppColors.subText(dark: dark),
              size: 30,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCaptchaImage(
    double panelWidth,
    double imageHeight,
    bool dark,
  ) {
    final challenge = _challenge;
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (challenge == null) {
      return _buildImagePlaceholder(dark);
    }
    final pieceWidth = _pieceDisplayWidth(panelWidth, challenge);
    final pieceHeight = _pieceDisplayHeight(imageHeight, challenge);
    final pieceX = _pieceDisplayX(panelWidth, imageHeight, challenge);
    final pieceY = _pieceDisplayY(imageHeight, challenge);
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: Stack(
        fit: StackFit.expand,
        children: [
          RawImage(
            image: challenge.backgroundImage,
            width: panelWidth,
            height: imageHeight,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: _CaptchaScenePainter(
                challenge: challenge,
                fakeGap: _selectedFakeGap,
                fakeGapRotation: _fakeGapRotation,
              ),
            ),
          ),
          Positioned(
            left: pieceX,
            top: pieceY,
            width: pieceWidth,
            height: pieceHeight,
            child: IgnorePointer(
              child: CustomPaint(
                painter: _PuzzlePiecePainter(challenge: challenge),
              ),
            ),
          ),
          if (_stage == _CaptchaStage.verifying)
            _buildImageStatusOverlay(
              icon: const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              text: '验证中...',
              color: const Color(0xFF2B8CFF),
              backgroundColor: dark
                  ? const Color(0x66000000)
                  : const Color(0x66FFFFFF),
            ),
          if (_stage == _CaptchaStage.failure)
            _buildImageStatusOverlay(
              icon: const Icon(Icons.error_outline,
                  color: Color(0xFFE53935), size: 34),
              text: '未对准，请重试',
              color: const Color(0xFFE53935),
              backgroundColor: dark
                  ? const Color(0x77000000)
                  : const Color(0x77FFFFFF),
            ),
          if (_stage == _CaptchaStage.success)
            _buildImageStatusOverlay(
              icon: const Icon(Icons.check_circle,
                  color: Color(0xFF19C37D), size: 64),
              text: '验证成功',
              color: const Color(0xFF19C37D),
              backgroundColor: dark
                  ? const Color(0x88000000)
                  : const Color(0x88FFFFFF),
            ),
        ],
      ),
    );
  }

  Widget _buildImageStatusOverlay({
    required Widget icon,
    required String text,
    required Color color,
    required Color backgroundColor,
  }) {
    return Container(
      color: backgroundColor,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(height: 8),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder(bool dark) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt(dark: dark),
        border: Border.all(color: AppColors.line(dark: dark)),
      ),
      child: Text(
        '点击刷新重新加载验证图片',
        style: TextStyle(
          color: AppColors.subText(dark: dark),
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildFooter(bool dark) {
    final muted = AppColors.subText(dark: dark);
    return Row(
      children: [
        Text(
          '安全验证 · 保护账号安全',
          style: TextStyle(color: muted, fontSize: 13),
        ),
        const Spacer(),
        IconButton(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 34, height: 34),
          onPressed: _locked ? null : _load,
          icon: Icon(Icons.refresh, color: muted),
        ),
        Icon(Icons.info_outline, color: muted),
      ],
    );
  }

  Widget _buildSlider(double panelWidth, double imageHeight, bool dark) {
    final currentX = _x.clamp(0, _maxXFor(panelWidth)).toDouble();
    final isDragging = _stage == _CaptchaStage.dragging;
    final isFailure = _stage == _CaptchaStage.failure;
    final isSuccess = _stage == _CaptchaStage.success;
    final canDrag = !_locked && _challenge != null;
    final activeColor = isSuccess
        ? const Color(0xFF19C37D)
        : (isFailure ? const Color(0xFFE53935) : const Color(0xFF2B8CFF));
    final trackIdle = AppColors.surfaceAlt(dark: dark);
    final trackDragging =
        dark ? const Color(0xFF1A2A3D) : const Color(0xFFEAF4FF);
    final trackBorder = isDragging
        ? const Color(0xFF2B8CFF)
        : AppColors.line(dark: dark);
    final hintColor = isSuccess
        ? const Color(0xFF19C37D)
        : AppColors.subText(dark: dark);
    final fillBlend = dark ? AppColors.card(dark: true) : Colors.white;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: canDrag
          ? (detail) {
              setState(() {
                _stage = _CaptchaStage.dragging;
                _error = null;
              });
              HapticFeedback.selectionClick();
            }
          : null,
      onHorizontalDragUpdate: canDrag
          ? (detail) {
              setState(() {
                _x = (_x + detail.delta.dx)
                    .clamp(0, _maxXFor(panelWidth))
                    .toDouble();
              });
            }
          : null,
      onHorizontalDragEnd:
          canDrag ? (_) => _verify(panelWidth, imageHeight) : null,
      onHorizontalDragCancel: canDrag
          ? () {
              setState(() {
                _stage = _CaptchaStage.idle;
              });
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: panelWidth,
        height: _sliderHeight,
        decoration: BoxDecoration(
          color: isDragging ? trackDragging : trackIdle,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: trackBorder),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Center(
                child: Text(
                  _sliderText,
                  style: TextStyle(
                    color: hintColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: isFailure
                  ? const Duration(milliseconds: 320)
                  : const Duration(milliseconds: 80),
              curve: Curves.easeOutCubic,
              left: 0,
              top: 0,
              bottom: 0,
              width:
                  (currentX + _thumbWidth / 2).clamp(0, panelWidth).toDouble(),
              child: Container(
                decoration: BoxDecoration(
                  color: Color.lerp(activeColor, fillBlend, .78),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: isFailure
                  ? const Duration(milliseconds: 320)
                  : const Duration(milliseconds: 80),
              curve: Curves.easeOutCubic,
              left: currentX,
              top: 0,
              bottom: 0,
              width: _thumbWidth,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSuccess ? const Color(0xFF19C37D) : activeColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: dark ? 0.35 : 0.13),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: _sliderIcon,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _sliderText {
    switch (_stage) {
      case _CaptchaStage.loading:
        return '加载验证中...';
      case _CaptchaStage.dragging:
        return '松开完成验证';
      case _CaptchaStage.verifying:
        return '验证中...';
      case _CaptchaStage.success:
        return '验证成功';
      case _CaptchaStage.failure:
        return '未对准，请重试';
      case _CaptchaStage.idle:
        return '向右滑动完成验证';
    }
  }

  Widget get _sliderIcon {
    switch (_stage) {
      case _CaptchaStage.verifying:
        return const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        );
      case _CaptchaStage.success:
        return const Icon(Icons.check, color: Colors.white, size: 30);
      case _CaptchaStage.failure:
        return const Icon(Icons.close, color: Colors.white, size: 26);
      case _CaptchaStage.loading:
      case _CaptchaStage.idle:
      case _CaptchaStage.dragging:
        return const Icon(
          Icons.keyboard_double_arrow_right_rounded,
          color: Colors.white,
          size: 32,
        );
    }
  }
}

Uint8List _decodeBackgroundBytes(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return Uint8List(0);
  final commaIndex = trimmed.indexOf(',');
  final base64Part = trimmed.startsWith('data:') && commaIndex >= 0
      ? trimmed.substring(commaIndex + 1)
      : trimmed;
  try {
    return base64Decode(base64Part);
  } catch (_) {
    return Uint8List(0);
  }
}

Future<ui.Image> _decodeUiImage(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  return frame.image;
}

String _readHeader(Headers headers, String name) {
  final direct = headers.value(name)?.trim();
  if (direct != null && direct.isNotEmpty) return direct;
  final lowerName = name.toLowerCase();
  for (final entry in headers.map.entries) {
    if (entry.key.toLowerCase() != lowerName || entry.value.isEmpty) continue;
    final value = entry.value.first.trim();
    if (value.isNotEmpty) return value;
  }
  return '';
}

int? _readHeaderInt(Headers headers, String name) {
  return int.tryParse(_readHeader(headers, name));
}

Map<String, dynamic> _unwrapMap(dynamic raw) {
  final root = _asMap(raw);
  final data = root['data'];
  if (data is Map) return Map<String, dynamic>.from(data);
  return root;
}

Map<String, dynamic> _asMap(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return const {};
}

String? _readString(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return null;
}

int? _readInt(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value == null) continue;
    if (value is int) return value;
    if (value is num) return value.toInt();
    final parsed = int.tryParse(value.toString().trim());
    if (parsed != null) return parsed;
  }
  return null;
}

List<SliderGapRect> _readFakeGaps(dynamic raw) {
  if (raw is! List) return const <SliderGapRect>[];
  return raw.map(SliderGapRect.fromJson).toList();
}

Path _buildPuzzlePath(Rect rect) {
  final x = rect.left;
  final y = rect.top;
  final w = rect.width;
  final h = rect.height;
  final path = Path();
  path.moveTo(x + w * 0.25, y);
  path.lineTo(x + w * 0.75, y);
  path.lineTo(x + w, y + h * 0.5);
  path.lineTo(x + w * 0.75, y + h);
  path.lineTo(x + w * 0.25, y + h);
  path.lineTo(x, y + h * 0.5);
  path.close();
  return path;
}

class _CaptchaScenePainter extends CustomPainter {
  const _CaptchaScenePainter({
    required this.challenge,
    required this.fakeGap,
    required this.fakeGapRotation,
  });

  final SliderCaptchaResult challenge;
  final SliderGapRect? fakeGap;
  final double fakeGapRotation;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / challenge.width;
    final scaleY = size.height / challenge.height;
    final gapRect = Rect.fromLTWH(
      challenge.gapX * scaleX,
      challenge.gapY * scaleY,
      challenge.gapWidth * scaleX,
      challenge.gapHeight * scaleY,
    );
    canvas.drawPath(
      _buildPuzzlePath(gapRect.shift(const Offset(2, 2))),
      Paint()..color = const Color(0x59000000),
    );
    final gapPath = _buildPuzzlePath(gapRect);
    canvas.drawPath(
      gapPath,
      Paint()..color = const Color(0x73000000),
    );
    canvas.drawPath(
      gapPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0x99D8DDE6),
    );
    final item = fakeGap;
    if (item != null) {
      final fakeRect = Rect.fromLTWH(
        item.x * scaleX,
        item.y * scaleY,
        item.width * scaleX,
        item.height * scaleY,
      );
      final fakePath = _buildPuzzlePath(fakeRect);
      canvas.save();
      canvas.translate(fakeRect.center.dx, fakeRect.center.dy);
      canvas.rotate(fakeGapRotation);
      canvas.translate(-fakeRect.center.dx, -fakeRect.center.dy);
      canvas.drawPath(
        fakePath,
        Paint()..color = const Color(0x8A666666),
      );
      canvas.drawPath(
        fakePath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0x80636363),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _CaptchaScenePainter oldDelegate) {
    return oldDelegate.challenge != challenge ||
        oldDelegate.fakeGap != fakeGap ||
        oldDelegate.fakeGapRotation != fakeGapRotation;
  }
}

class _PuzzlePiecePainter extends CustomPainter {
  const _PuzzlePiecePainter({required this.challenge});

  final SliderCaptchaResult challenge;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = _buildPuzzlePath(rect);
    canvas.save();
    canvas.clipPath(path);
    canvas.drawImageRect(
      challenge.backgroundImage,
      Rect.fromLTWH(
        challenge.targetX.toDouble(),
        challenge.targetY.toDouble(),
        challenge.gapWidth.toDouble(),
        challenge.gapHeight.toDouble(),
      ),
      rect,
      Paint(),
    );
    canvas.restore();
    canvas.drawShadow(path, const Color(0x80000000), 8, true);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0x80000000),
    );
  }

  @override
  bool shouldRepaint(covariant _PuzzlePiecePainter oldDelegate) {
    return oldDelegate.challenge != challenge;
  }
}
