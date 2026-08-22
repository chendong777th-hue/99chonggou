import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_responsive.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_flags.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

const String conversationArchivedEntryIconAsset = 'assets/img/archive_icon.png';
const String conversationGroupNoticeEntryIconAsset =
    'assets/img/group_notice_icon.png';
const double conversationSystemEntryAvatarSize = 52;

double conversationFeedAvatarSize(BuildContext context) =>
    AppResponsive.isDesktop(context) ? 40.0 : 44.0;

double conversationFeedRowExtent(BuildContext context) {
  final isDesktop = AppResponsive.isDesktop(context);
  final base = conversationFeedAvatarSize(context) + (isDesktop ? 20.0 : 22.0);
  final scaleExtra = math.min(
    8.0,
    math.max(0.0, AppResponsive.textScale(context) - 1.0) *
        (isDesktop ? 12.0 : 16.0),
  );
  return base + scaleExtra;
}

EdgeInsetsGeometry conversationFeedRowPadding(BuildContext context) =>
    AppResponsive.listRowPadding(
      context,
      mobileHorizontal: 16,
      desktopHorizontal: 16,
      mobileVertical: 8,
      desktopVertical: 8,
    );

double conversationFeedDividerInset(
  BuildContext context, {
  bool editing = false,
}) {
  final avatar = conversationFeedAvatarSize(context);
  return editing ? avatar + 64.0 : avatar + 28.0;
}

double conversationFeedTitleFontSize(BuildContext context) =>
    AppResponsive.isDesktop(context) ? 13.0 : 15.0;

double conversationFeedSubtitleFontSize(BuildContext context) =>
    AppResponsive.isDesktop(context) ? 12.0 : 13.0;

double conversationFeedTimestampFontSize(BuildContext context) => 11.0;

/// 会话行槽缓存是否需要因数据指纹或主题令牌失效而重建。
///
/// `DefTheme.darkTheme` / `blueTheme` 为稳定常量，[identical] 可区分深浅切换。
bool conversationFeedRowSlotNeedsRebuild({
  required String nextFingerprint,
  required String currentFingerprint,
  required Object? nextThemeToken,
  required Object? currentThemeToken,
}) {
  if (nextFingerprint != currentFingerprint) {
    return true;
  }
  return !identical(nextThemeToken, currentThemeToken);
}

/// 非当前 Tab 整表缓存是否可复用。主题 identity 或内容世代变化时必须重建，
/// 否则深浅切换后后台 Tab 会残留旧背景色，或消息更新后切 Tab 仍见旧列表。
bool conversationFeedInactiveTabCacheReusable({
  required bool hasCachedChild,
  required Object? cachedThemeToken,
  required Object? currentThemeToken,
  int? cachedContentRevision,
  int? currentContentRevision,
}) {
  if (!hasCachedChild) {
    return false;
  }
  if (!identical(cachedThemeToken, currentThemeToken)) {
    return false;
  }
  if (cachedContentRevision != null &&
      currentContentRevision != null &&
      cachedContentRevision != currentContentRevision) {
    return false;
  }
  return true;
}

/// 非活跃会话 Feed 是否直接复用整表缓存。活跃 Tab 恒不复用。
bool shouldReuseInactiveConversationFeed({
  required bool tabActive,
  required bool hasCachedChild,
  required Object? cachedThemeToken,
  required Object? currentThemeToken,
  int? cachedContentRevision,
  int? currentContentRevision,
}) {
  if (tabActive) {
    return false;
  }
  return conversationFeedInactiveTabCacheReusable(
    hasCachedChild: hasCachedChild,
    cachedThemeToken: cachedThemeToken,
    currentThemeToken: currentThemeToken,
    cachedContentRevision: cachedContentRevision,
    currentContentRevision: currentContentRevision,
  );
}

/// Virtual Feed can skip visible-list materialization and row-array rebuild
/// when list identity (order / membership / archive+notice chrome) is unchanged.
bool conversationFeedCanSkipVisibleMaterialization({
  required bool useVirtual,
  required bool folderFilterActive,
  required int structureRevision,
  required int lastStructureRevision,
  required bool includeArchivedEntry,
  required bool cachedIncludeArchived,
  required bool includeGroupNoticeEntry,
  required bool cachedIncludeGroupNotice,
  required bool groupNoticePinned,
  required bool cachedGroupNoticePinned,
  required int noticeSignature,
  required int cachedGroupNoticeSignature,
}) {
  if (!useVirtual || folderFilterActive) {
    return false;
  }
  if (lastStructureRevision < 0) {
    return false; // first build
  }
  if (structureRevision != lastStructureRevision) {
    return false;
  }
  return includeArchivedEntry == cachedIncludeArchived &&
      includeGroupNoticeEntry == cachedIncludeGroupNotice &&
      groupNoticePinned == cachedGroupNoticePinned &&
      noticeSignature == cachedGroupNoticeSignature;
}

bool conversationFeedCanSkipHydrateAfterChatReturn({
  required bool firstLiveHydrated,
  required bool lastLiveHydrated,
  required bool openedConversationInLiveWindow,
}) {
  return firstLiveHydrated &&
      lastLiveHydrated &&
      openedConversationInLiveWindow;
}

Duration conversationListRowPinAnimDuration({TargetPlatform? platform}) {
  final resolved = platform ?? defaultTargetPlatform;
  if (resolved == TargetPlatform.android) {
    return Duration.zero;
  }
  return ConversationPerfFlags.conversationRowPinAnimDuration;
}

Widget buildConversationListRowBackground({
  required Color color,
  required Widget child,
  required Duration animDuration,
  required double height,
  Key? animationKey,
}) {
  if (animDuration == Duration.zero) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ColoredBox(
        color: color,
        child: Align(
          alignment: Alignment.topCenter,
          child: child,
        ),
      ),
    );
  }
  return LayoutBuilder(
    builder: (context, constraints) {
      final expandHeight =
          constraints.hasBoundedHeight && constraints.maxHeight.isFinite;
      return AnimatedContainer(
        key: animationKey,
        duration: animDuration,
        curve: Curves.easeOutCubic,
        width: double.infinity,
        height: expandHeight ? constraints.maxHeight : null,
        alignment: Alignment.topCenter,
        color: color,
        child: child,
      );
    },
  );
}

Color conversationFeedItemBackground(
  TUITheme theme, {
  required bool pinned,
}) {
  final isDark = _conversationFeedUiIsDark(theme);
  if (!isDark) {
    return pinned
        ? (theme.conversationItemPinedBgColor ?? const Color(0xFFF3F4F6))
        : (theme.conversationItemBgColor ?? Colors.white);
  }
  if (pinned) {
    final pinnedColor = theme.conversationItemPinedBgColor;
    if (pinnedColor != null &&
        ThemeData.estimateBrightnessForColor(pinnedColor) == Brightness.dark) {
      return pinnedColor;
    }
    return const Color(0xFF1A1A1A);
  }
  // 深色非置顶贴齐页底，避免 surfaceDark 比页背景亮一档（单聊/群聊观感不一致）。
  return conversationFeedPageBackground(theme);
}

Color conversationFeedPageBackground(TUITheme theme) {
  if (!_conversationFeedUiIsDark(theme)) {
    return theme.weakBackgroundColor ?? Colors.white;
  }
  return theme.weakBackgroundColor ??
      theme.wideBackgroundColor ??
      const Color(0xFF0F0F0F);
}

bool _conversationFeedUiIsDark(TUITheme theme) {
  final base = theme.appbarBgColor ?? theme.wideBackgroundColor ?? Colors.white;
  return ThemeData.estimateBrightnessForColor(base) == Brightness.dark;
}

Widget buildConversationSystemEntryAvatar(
  String assetPath, {
  double size = conversationSystemEntryAvatarSize,
  double scale = 1.50,
}) {
  return SizedBox(
    width: size,
    height: size,
    child: ClipOval(
      child: Transform.scale(
        scale: scale,
        child: Image.asset(
          assetPath,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    ),
  );
}

/// 虚拟列表未水合行 / 整表冷启占位：圆头像块 + 两行灰条，避免小转圈。
Widget buildConversationFeedRowSkeleton(
  BuildContext context,
  TUITheme theme, {
  int variance = 0,
  double? height,
}) {
  final rowHeight = height ?? conversationFeedRowExtent(context);
  final lineColor = (theme.weakDividerColor ?? const Color(0xFFE5E6E9))
      .withValues(alpha: 0.35);
  final blockColor = (theme.weakDividerColor ?? const Color(0xFFE5E6E9))
      .withValues(alpha: 0.6);
  final titleWidth = 110.0 + (variance % 3) * 30.0;
  final subtitleWidth = 170.0 + (variance % 2) * 40.0;
  return SizedBox(
    height: rowHeight,
    child: Padding(
      padding: conversationFeedRowPadding(context),
      child: Row(
        children: [
          Container(
            width: conversationFeedAvatarSize(context),
            height: conversationFeedAvatarSize(context),
            decoration: BoxDecoration(
              color: blockColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: titleWidth,
                  height: 14,
                  decoration: BoxDecoration(
                    color: blockColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: subtitleWidth,
                  height: 12,
                  decoration: BoxDecoration(
                    color: lineColor,
                    borderRadius: BorderRadius.circular(999),
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
