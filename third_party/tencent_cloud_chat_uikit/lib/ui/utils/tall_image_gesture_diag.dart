import 'package:tencent_cloud_chat_uikit/ui/utils/tall_image_gallery_scroll_gate.dart';

/// 长图全屏预览手势诊断。发布版同样 [print]，便于 Xcode 过滤
/// `[TALL_IMAGE_GESTURE]`。
class TallImageGestureDiag {
  TallImageGestureDiag._();

  /// 诊断完成后关闭。需要复现长图手势问题时再临时改为 true。
  static const bool enabled = false;

  static int _session = 0;
  static int _gestureSeq = 0;
  static int _sessionAtMs = 0;

  static String? _lastGateKey;
  static String? _lastGalleryScrollKey;
  static bool _loggedPageProbeThisGesture = false;
  static bool _loggedPageRejectThisGesture = false;

  /// 进入长图预览组件时调用。
  static void markMounted({
    required bool inPageView,
    required double displayW,
    required double displayH,
    required double viewportH,
  }) {
    if (!enabled) return;
    _session++;
    _gestureSeq = 0;
    _sessionAtMs = DateTime.now().millisecondsSinceEpoch;
    _lastGateKey = null;
    _lastGalleryScrollKey = null;
    log(
      'mount',
      extras: <String, Object?>{
        'inPageView': inPageView,
        'displayW': displayW.toStringAsFixed(1),
        'displayH': displayH.toStringAsFixed(1),
        'viewportH': viewportH.toStringAsFixed(1),
        'scrollable': displayH > viewportH + 1,
      },
    );
  }

  static int _elapsedMs() {
    if (_sessionAtMs <= 0) return -1;
    return DateTime.now().millisecondsSinceEpoch - _sessionAtMs;
  }

  static void log(
    String event, {
    Map<String, Object?> extras = const <String, Object?>{},
  }) {
    if (!enabled) return;
    final buffer = StringBuffer('[TALL_IMAGE_GESTURE] event=$event');
    if (_session > 0) {
      buffer.write(' session=$_session');
    }
    if (_gestureSeq > 0) {
      buffer.write(' g=$_gestureSeq');
    }
    final elapsed = _elapsedMs();
    if (elapsed >= 0) {
      buffer.write(' t+${elapsed}ms');
    }
    extras.forEach((key, value) {
      if (value == null) return;
      buffer.write(' $key=$value');
    });
    // ignore: avoid_print
    print(buffer.toString());
  }

  static void _resetGestureDedupe() {
    _loggedPageProbeThisGesture = false;
    _loggedPageRejectThisGesture = false;
  }

  static void pointerDown({
    required bool nearMinScale,
    required bool atTop,
    required double scale,
    required bool inPageView,
    double? tx,
    double? ty,
    double? boundsMinX,
    double? boundsMaxX,
    double? boundsMinY,
    double? boundsMaxY,
    bool? hasHorizontalScroll,
    bool? hasVerticalScroll,
    bool? gateAtLeft,
    bool? gateAtRight,
  }) {
    if (!enabled) return;
    _gestureSeq++;
    _resetGestureDedupe();
    log(
      'pointer_down',
      extras: <String, Object?>{
        'nearMin': nearMinScale,
        'atTop': atTop,
        'scale': scale.toStringAsFixed(3),
        'inPageView': inPageView,
        if (tx != null) 'tx': tx.toStringAsFixed(1),
        if (ty != null) 'ty': ty.toStringAsFixed(1),
        if (boundsMinX != null) 'bMinX': boundsMinX.toStringAsFixed(1),
        if (boundsMaxX != null) 'bMaxX': boundsMaxX.toStringAsFixed(1),
        if (boundsMinY != null) 'bMinY': boundsMinY.toStringAsFixed(1),
        if (boundsMaxY != null) 'bMaxY': boundsMaxY.toStringAsFixed(1),
        if (hasHorizontalScroll != null) 'hasH': hasHorizontalScroll,
        if (hasVerticalScroll != null) 'hasV': hasVerticalScroll,
        if (gateAtLeft != null) 'gateLeft': gateAtLeft,
        if (gateAtRight != null) 'gateRight': gateAtRight,
      },
    );
  }

  /// gate 状态变化时输出（去重，避免矩阵监听刷屏）。
  static void gateSync({
    required double scale,
    required double tx,
    required double minX,
    required double maxX,
    required bool atLeftEdge,
    required bool atRightEdge,
    required bool hasHorizontalScroll,
    String source = 'matrix',
  }) {
    if (!enabled) return;
    final key =
        '$source|${scale.toStringAsFixed(2)}|$tx|${atLeftEdge}_$atRightEdge|$hasHorizontalScroll';
    if (key == _lastGateKey) {
      return;
    }
    _lastGateKey = key;
    log(
      'gate_sync',
      extras: <String, Object?>{
        'src': source,
        'scale': scale.toStringAsFixed(3),
        'tx': tx.toStringAsFixed(1),
        'minX': minX.toStringAsFixed(1),
        'maxX': maxX.toStringAsFixed(1),
        'atLeft': atLeftEdge,
        'atRight': atRightEdge,
        'hasH': hasHorizontalScroll,
      },
    );
  }

  /// 图集层 canScrollPage 判定（结果变化时输出）。
  static void galleryCanScroll({
    required bool allow,
    required double baselineScale,
    TallImageGalleryScrollGate? gate,
    bool isTall = false,
    double? detailsScale,
    String source = 'gallery',
  }) {
    if (!enabled) return;
    final gateScale = gate?.scale.toStringAsFixed(3) ?? 'null';
    final key =
        '$source|$allow|$isTall|$gateScale|${gate?.atLeftEdge}_${gate?.atRightEdge}|${detailsScale?.toStringAsFixed(3)}';
    if (key == _lastGalleryScrollKey) {
      return;
    }
    _lastGalleryScrollKey = key;
    log(
      'gallery_scroll',
      extras: <String, Object?>{
        'allow': allow,
        'isTall': isTall,
        'baseline': baselineScale.toStringAsFixed(3),
        'gateScale': gateScale,
        'gateLeft': gate?.atLeftEdge,
        'gateRight': gate?.atRightEdge,
        'gateHasH': gate?.hasHorizontalScroll,
        if (detailsScale != null)
          'detailsScale': detailsScale.toStringAsFixed(3),
      },
    );
  }

  /// 每个手势首次探测翻页条件时输出完整判定链。
  static void pageRouteProbe({
    required bool allow,
    required String reason,
    required double totalDx,
    required double totalDy,
    required bool nearMinScale,
    required bool atHorizontalEdge,
    required bool canRouteForDelta,
    required bool pageRouteBlocked,
    bool zoomed = false,
  }) {
    if (!enabled || _loggedPageProbeThisGesture) {
      return;
    }
    _loggedPageProbeThisGesture = true;
    log(
      'page_probe',
      extras: <String, Object?>{
        'allow': allow,
        'reason': reason,
        'dx': totalDx.toStringAsFixed(1),
        'dy': totalDy.toStringAsFixed(1),
        'nearMin': nearMinScale,
        'atEdge': atHorizontalEdge,
        'canRouteDx': canRouteForDelta,
        'blocked': pageRouteBlocked,
        'zoomed': zoomed,
      },
    );
  }

  /// 翻页被拒绝时输出（每手势首条）。
  static void pageRouteReject({required String reason}) {
    if (!enabled || _loggedPageRejectThisGesture) {
      return;
    }
    _loggedPageRejectThisGesture = true;
    log('page_reject', extras: <String, Object?>{'reason': reason});
  }

  static void axisLock({
    required String axis,
    required double dx,
    required double dy,
    required bool nearMinScale,
    required bool atTop,
  }) {
    log(
      'axis_lock',
      extras: <String, Object?>{
        'axis': axis,
        'dx': dx.toStringAsFixed(1),
        'dy': dy.toStringAsFixed(1),
        'nearMin': nearMinScale,
        'atTop': atTop,
      },
    );
  }

  static void pageBegin({
    required double scale,
    double? totalDx,
    double? totalDy,
    bool? atEdge,
    double? tx,
    double? minX,
    double? maxX,
    String? trigger,
  }) {
    log(
      'page_begin',
      extras: <String, Object?>{
        'scale': scale.toStringAsFixed(3),
        if (totalDx != null) 'dx': totalDx.toStringAsFixed(1),
        if (totalDy != null) 'dy': totalDy.toStringAsFixed(1),
        if (atEdge != null) 'atEdge': atEdge,
        if (tx != null) 'tx': tx.toStringAsFixed(1),
        if (minX != null) 'minX': minX.toStringAsFixed(1),
        if (maxX != null) 'maxX': maxX.toStringAsFixed(1),
        if (trigger != null) 'trigger': trigger,
      },
    );
  }

  static void pageCancel({required String reason}) {
    log('page_cancel', extras: <String, Object?>{'reason': reason});
  }

  static void pageEnd({required bool cancelled}) {
    log(
      'page_end',
      extras: <String, Object?>{'cancelled': cancelled},
    );
  }

  static void dismissBegin({required double pullPx}) {
    log(
      'dismiss_begin',
      extras: <String, Object?>{'pullPx': pullPx.toStringAsFixed(1)},
    );
  }

  static void dismissEnd() {
    log('dismiss_end');
  }

  /// 每个手势只打首条竖滑，避免刷屏。
  static void scrollVerticalFirst({
    required double fromY,
    required double toY,
    required bool hitTop,
    required bool hitBottom,
  }) {
    log(
      'scroll_v',
      extras: <String, Object?>{
        'fromY': fromY.toStringAsFixed(1),
        'toY': toY.toStringAsFixed(1),
        'hitTop': hitTop,
        'hitBottom': hitBottom,
      },
    );
  }

  /// 每个手势只打首条放大平移，便于确认横/纵拖动是否生效。
  static void zoomPanFirst({
    required double fromX,
    required double fromY,
    required double toX,
    required double toY,
    required double scale,
    String? axisLock,
    bool? dampedZero,
  }) {
    log(
      'zoom_pan',
      extras: <String, Object?>{
        'fromX': fromX.toStringAsFixed(1),
        'fromY': fromY.toStringAsFixed(1),
        'toX': toX.toStringAsFixed(1),
        'toY': toY.toStringAsFixed(1),
        'scale': scale.toStringAsFixed(3),
        if (axisLock != null) 'axisLock': axisLock,
        if (dampedZero != null) 'dampedZero': dampedZero,
      },
    );
  }

  static void tap() => log('tap');

  static void doubleTap({
    required double fromScale,
    required double toScale,
    double? tx,
    double? ty,
  }) {
    log(
      'double_tap',
      extras: <String, Object?>{
        'from': fromScale.toStringAsFixed(3),
        'to': toScale.toStringAsFixed(3),
        if (tx != null) 'tx': tx.toStringAsFixed(1),
        if (ty != null) 'ty': ty.toStringAsFixed(1),
      },
    );
  }

  static void pointerUp({
    required String axis,
    required bool routedPage,
    required bool routedDismiss,
    required double panDist,
    double? scale,
    double? tx,
    double? ty,
    bool? gateAtLeft,
    bool? gateAtRight,
  }) {
    log(
      'pointer_up',
      extras: <String, Object?>{
        'axis': axis,
        'routedPage': routedPage,
        'routedDismiss': routedDismiss,
        'panDist': panDist.toStringAsFixed(1),
        if (scale != null) 'scale': scale.toStringAsFixed(3),
        if (tx != null) 'tx': tx.toStringAsFixed(1),
        if (ty != null) 'ty': ty.toStringAsFixed(1),
        if (gateAtLeft != null) 'gateLeft': gateAtLeft,
        if (gateAtRight != null) 'gateRight': gateAtRight,
      },
    );
  }
}
