import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

enum AndroidPerformanceTier { low, medium, normal }

/// Android 进程可用堆分档。不要用设备标称内存：同为 8G 的旧机，应用
/// memoryClass 可能仍很小，才是真正会触发 GC / 图片解码抖动的预算。
class AndroidPerformanceProfile {
  AndroidPerformanceProfile._();

  static final AndroidPerformanceProfile instance =
      AndroidPerformanceProfile._();
  static const MethodChannel _channel =
      MethodChannel('android_performance_profile');

  /// 原生分档回来前先用 medium 预算，避免首屏按 normal 档预分配图片/列表缓存。
  AndroidPerformanceTier _tier =
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
          ? AndroidPerformanceTier.medium
          : AndroidPerformanceTier.normal;
  bool _initialized = false;

  AndroidPerformanceTier get tier => _tier;
  bool get initialized => _initialized;

  static AndroidPerformanceTier tierForMemoryClass(int memoryClassMb) {
    if (memoryClassMb > 0 && memoryClassMb <= 192) {
      return AndroidPerformanceTier.low;
    }
    if (memoryClassMb > 0 && memoryClassMb <= 256) {
      return AndroidPerformanceTier.medium;
    }
    return AndroidPerformanceTier.normal;
  }

  Future<void> initialize() async {
    if (_initialized ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'getPerformanceProfile',
      );
      final memoryClassMb = (raw?['memoryClass'] as num?)?.toInt() ?? 0;
      final lowRam = raw?['isLowRamDevice'] == true;
      _tier = lowRam
          ? AndroidPerformanceTier.low
          : tierForMemoryClass(memoryClassMb);
    } catch (_) {
      // 原生桥接不可用时保留正常档；不能阻塞启动。
    } finally {
      _initialized = true;
    }
  }

  int get imageCacheMaximumSize => switch (_tier) {
        AndroidPerformanceTier.low => 640,
        AndroidPerformanceTier.medium => 900,
        AndroidPerformanceTier.normal => 900,
      };

  int get imageCacheMaximumSizeBytes => switch (_tier) {
        AndroidPerformanceTier.low => 96 << 20,
        AndroidPerformanceTier.medium => 128 << 20,
        AndroidPerformanceTier.normal => 160 << 20,
      };

  int get virtualHydrateMaxPerType => switch (_tier) {
        AndroidPerformanceTier.low => 72,
        AndroidPerformanceTier.medium => 80,
        AndroidPerformanceTier.normal => 88,
      };

  int get virtualHydrateRadius => switch (_tier) {
        AndroidPerformanceTier.low => 20,
        AndroidPerformanceTier.medium => 24,
        AndroidPerformanceTier.normal => 28,
      };

  int get virtualHydrateSkipMargin => switch (_tier) {
        AndroidPerformanceTier.low => 16,
        AndroidPerformanceTier.medium => 18,
        AndroidPerformanceTier.normal => 22,
      };

  static double chatHistoryCacheExtentForTier(AndroidPerformanceTier tier) =>
      switch (tier) {
        AndroidPerformanceTier.low => 250,
        AndroidPerformanceTier.medium => 320,
        AndroidPerformanceTier.normal => 400,
      };

  double get chatHistoryCacheExtent => chatHistoryCacheExtentForTier(_tier);

  static double chatHistoryActiveScrollCacheExtentForTier(
    AndroidPerformanceTier tier,
  ) =>
      switch (tier) {
        AndroidPerformanceTier.low => 120,
        AndroidPerformanceTier.medium => 140,
        AndroidPerformanceTier.normal => 160,
      };

  double get chatHistoryActiveScrollCacheExtent =>
      chatHistoryActiveScrollCacheExtentForTier(_tier);

  static double conversationFeedCacheExtentForTier(
    AndroidPerformanceTier tier,
  ) =>
      switch (tier) {
        AndroidPerformanceTier.low => 120,
        AndroidPerformanceTier.medium => 140,
        AndroidPerformanceTier.normal => 160,
      };

  double get conversationFeedCacheExtent =>
      conversationFeedCacheExtentForTier(_tier);

  static int conversationViewportWarmCountForTier(
    AndroidPerformanceTier tier,
  ) =>
      switch (tier) {
        AndroidPerformanceTier.low => 0,
        AndroidPerformanceTier.medium => 6,
        AndroidPerformanceTier.normal => 6,
      };

  int get conversationViewportWarmCount =>
      conversationViewportWarmCountForTier(_tier);

  static int conversationWarmConcurrencyForTier(AndroidPerformanceTier tier) =>
      switch (tier) {
        AndroidPerformanceTier.low => 1,
        AndroidPerformanceTier.medium => 1,
        AndroidPerformanceTier.normal => 1,
      };

  int get conversationWarmConcurrency =>
      conversationWarmConcurrencyForTier(_tier);

  /// 进后台时释放未引用位图，减轻 Android GC 与恢复尖刺。
  void trimImageCacheForBackground() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  /// Android 全档关闭重动画/重特效，优先保滑动与进页帧率。
  bool get reduceHeavyVisualEffects =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}
