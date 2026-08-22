import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

/// 群资料页成员头像预览区骨架：按预估人数智能 1 行 / 2 行。
class GroupMemberPreviewSkeleton {
  GroupMemberPreviewSkeleton._();

  static const int crossAxisCount = 5;
  static const int maxPreviewSlots = 10;

  /// 根据预估成员数与操作位（加/减）计算骨架行数。
  static int rowCount({
    required int estimatedMemberCount,
    required int actionSlotCount,
  }) {
    final maxMemberSlots = maxPreviewSlots - actionSlotCount;
    final memberSlots = estimatedMemberCount.clamp(0, maxMemberSlots);
    final totalSlots = memberSlots + actionSlotCount;
    if (totalSlots <= crossAxisCount) {
      return 1;
    }
    return 2;
  }

  static int slotCount({
    required int estimatedMemberCount,
    required int actionSlotCount,
  }) {
    final rows = rowCount(
      estimatedMemberCount: estimatedMemberCount,
      actionSlotCount: actionSlotCount,
    );
    final maxMemberSlots = maxPreviewSlots - actionSlotCount;
    final memberSlots = estimatedMemberCount.clamp(0, maxMemberSlots);
    final desired = memberSlots + actionSlotCount;
    if (desired > 0) {
      return desired.clamp(1, rows * crossAxisCount);
    }
    return (rows * crossAxisCount).clamp(1, maxPreviewSlots);
  }
}

class GroupMemberPreviewSkeletonGrid extends StatelessWidget {
  const GroupMemberPreviewSkeletonGrid({
    super.key,
    required this.theme,
    required this.estimatedMemberCount,
    this.actionSlotCount = 0,
    this.crossAxisCount = GroupMemberPreviewSkeleton.crossAxisCount,
    this.childAspectRatio = 0.96,
  });

  final TUITheme theme;
  final int estimatedMemberCount;
  final int actionSlotCount;
  final int crossAxisCount;
  final double childAspectRatio;

  Color get _baseColor {
    final fromTheme = theme.weakDividerColor ?? theme.weakTextColor;
    return (fromTheme ?? const Color(0xFF999999)).withValues(alpha: 0.22);
  }

  @override
  Widget build(BuildContext context) {
    final slotCount = GroupMemberPreviewSkeleton.slotCount(
      estimatedMemberCount: estimatedMemberCount,
      actionSlotCount: actionSlotCount,
    );
    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      childAspectRatio: childAspectRatio,
      children: List<Widget>.generate(
        slotCount,
        (_) => _MemberPreviewSkeletonItem(color: _baseColor),
      ),
    );
  }
}

class _MemberPreviewSkeletonItem extends StatelessWidget {
  const _MemberPreviewSkeletonItem({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 36,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ],
      ),
    );
  }
}
