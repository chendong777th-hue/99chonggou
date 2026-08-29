import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/android_performance_profile.dart';

void main() {
  test('performance tier follows Android memory class', () {
    expect(
      AndroidPerformanceProfile.tierForMemoryClass(192),
      AndroidPerformanceTier.low,
    );
    expect(
      AndroidPerformanceProfile.tierForMemoryClass(256),
      AndroidPerformanceTier.medium,
    );
    expect(
      AndroidPerformanceProfile.tierForMemoryClass(384),
      AndroidPerformanceTier.normal,
    );
  });

  test('low and medium tiers reduce chat and viewport warm budgets', () {
    expect(
      AndroidPerformanceProfile.chatHistoryCacheExtentForTier(
        AndroidPerformanceTier.low,
      ),
      250,
    );
    expect(
      AndroidPerformanceProfile.chatHistoryCacheExtentForTier(
        AndroidPerformanceTier.medium,
      ),
      320,
    );
    expect(
      AndroidPerformanceProfile.chatHistoryActiveScrollCacheExtentForTier(
        AndroidPerformanceTier.low,
      ),
      120,
    );
    expect(
      AndroidPerformanceProfile.chatHistoryActiveScrollCacheExtentForTier(
        AndroidPerformanceTier.normal,
      ),
      160,
    );
    expect(
      AndroidPerformanceProfile.conversationViewportWarmCountForTier(
        AndroidPerformanceTier.low,
      ),
      0,
    );
    expect(
      AndroidPerformanceProfile.conversationViewportWarmCountForTier(
        AndroidPerformanceTier.medium,
      ),
      6,
    );
    expect(
      AndroidPerformanceProfile.conversationWarmConcurrencyForTier(
        AndroidPerformanceTier.normal,
      ),
      1,
    );
  });

  test('conversation feed cache extent is tighter than chat history', () {
    expect(
      AndroidPerformanceProfile.conversationFeedCacheExtentForTier(
        AndroidPerformanceTier.low,
      ),
      240,
    );
    expect(
      AndroidPerformanceProfile.conversationFeedCacheExtentForTier(
        AndroidPerformanceTier.medium,
      ),
      360,
    );
    expect(
      AndroidPerformanceProfile.conversationFeedCacheExtentForTier(
        AndroidPerformanceTier.normal,
      ),
      480,
    );
  });
}
