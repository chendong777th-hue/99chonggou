import 'package:azlistview_all_platforms/azlistview_all_platforms.dart';
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list_for_us/scrollable_positioned_list_for_us.dart';
import 'package:tencent_cloud_chat_demo/src/pages/life_payment/life_payment_theme.dart';

/// 城市选择列表条目（供 AzListView 使用）。
class LifePaymentCityIndexItem<T> extends ISuspensionBean {
  LifePaymentCityIndexItem({
    required this.tagIndex,
    required this.data,
  });

  final String tagIndex;
  final T data;

  @override
  String getSuspensionTag() => tagIndex;
}

/// 与通讯录 [AZListViewContainer] 同一套右侧字母索引（IndexBar + 触感 + 气泡提示）。
///
/// 通过 [ItemScrollController.jumpTo] 跳转，不依赖离屏 GlobalKey，滑动时列表会即时跟随。
class LifePaymentCityIndexBar extends StatefulWidget {
  const LifePaymentCityIndexBar({
    super.key,
    required this.onSelect,
    this.availableInitials = const <String>[],
    this.dark = false,
  });

  /// 选中字母回调（已解析到最近可用分组）。
  final ValueChanged<String> onSelect;

  /// 当前列表实际存在的首字母。
  final List<String> availableInitials;

  /// 是否深色主题。
  final bool dark;

  /// 通讯录同款完整 26 字母（不含 #）。
  static const List<String> alphabet = <String>[
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
  ];

  /// 与通讯录 IndexBar 同宽，列表右侧预留。
  static const double barWidth = kIndexBarWidth;

  /// 将点选字母映射到最近可用分组。
  static String? resolveInitial(
    String tag,
    Iterable<String> available,
  ) {
    final keys = available.toList();
    if (keys.isEmpty) return null;
    if (keys.contains(tag)) return tag;
    for (final key in keys) {
      if (key.compareTo(tag) >= 0) return key;
    }
    return keys.last;
  }

  /// 跳到指定分组首条（与通讯录 AzListView 内部 jumpTo 一致）。
  static void jumpToTag({
    required ItemScrollController controller,
    required List<ISuspensionBean> data,
    required String tag,
  }) {
    if (!controller.isAttached) return;
    final index = data.indexWhere((item) => item.getSuspensionTag() == tag);
    if (index < 0) return;
    controller.jumpTo(index: index, alignment: 0);
  }

  @override
  State<LifePaymentCityIndexBar> createState() =>
      _LifePaymentCityIndexBarState();
}

class _LifePaymentCityIndexBarState extends State<LifePaymentCityIndexBar> {
  late final IndexBarDragListener _dragListener = IndexBarDragListener.create();
  String? _lastTag;

  @override
  void initState() {
    super.initState();
    _dragListener.dragDetails.addListener(_onDragDetails);
  }

  @override
  void dispose() {
    _dragListener.dragDetails.removeListener(_onDragDetails);
    super.dispose();
  }

  void _onDragDetails() {
    final details = _dragListener.dragDetails.value;
    final tag = details.tag;
    if (tag == null || tag.isEmpty) return;
    final action = details.action;
    if (action != IndexBarDragDetails.actionDown &&
        action != IndexBarDragDetails.actionUpdate) {
      if (action == IndexBarDragDetails.actionEnd ||
          action == IndexBarDragDetails.actionUp ||
          action == IndexBarDragDetails.actionCancel) {
        _lastTag = null;
      }
      return;
    }
    if (tag == _lastTag) return;
    _lastTag = tag;
    final resolved = LifePaymentCityIndexBar.resolveInitial(
      tag,
      widget.availableInitials,
    );
    if (resolved != null) widget.onSelect(resolved);
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    return Align(
      alignment: Alignment.centerRight,
      child: IndexBar(
        data: LifePaymentCityIndexBar.alphabet,
        width: kIndexBarWidth,
        itemHeight: kIndexBarItemHeight,
        indexBarDragListener: _dragListener,
        options: IndexBarOptions(
          hapticFeedback: true,
          textStyle: TextStyle(
            fontSize: 12,
            color: LifePaymentTheme.subText(dark),
            fontWeight: FontWeight.w500,
          ),
          downTextStyle: TextStyle(
            fontSize: 12,
            color: dark ? Colors.white : const Color(0xFF333333),
            fontWeight: FontWeight.w600,
          ),
          downColor: dark
              ? const Color(0xFF2A2D33)
              : const Color(0xFFEEEEEE),
          indexHintDecoration: BoxDecoration(
            color: dark ? const Color(0xE6222428) : Colors.black87,
            borderRadius: const BorderRadius.all(Radius.circular(6)),
          ),
          indexHintTextStyle: const TextStyle(
            fontSize: 24,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
