import 'package:azlistview_all_platforms/azlistview_all_platforms.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme_view_model.dart';

class AZListViewContainer extends StatefulWidget {
  final List<ISuspensionBeanImpl>? memberList;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final Widget Function(BuildContext context, int index)? susItemBuilder;
  final bool isShowIndexBar;

  /// AzListView / ScrollablePositionedList 触底检测用（优先于 ScrollNotification）。
  final ItemPositionsListener? itemPositionsListener;

  const AZListViewContainer(
      {Key? key,
      required this.memberList,
      required this.itemBuilder,
      this.isShowIndexBar = true,
      this.susItemBuilder,
      this.itemPositionsListener})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _AZListViewContainerState();
}

class _AZListViewContainerState extends TIMUIKitState<AZListViewContainer> {
  List<ISuspensionBeanImpl>? _list;

  addShowSuspension(List<ISuspensionBeanImpl> curList) {
    for (int i = 0; i < curList.length; i++) {
      if (i == 0 || curList[i].tagIndex != curList[i - 1].tagIndex) {
        curList[i].isShowSuspension = true;
      }
    }
    return curList;
  }

  void _hideSuspension(List<ISuspensionBeanImpl> curList) {
    for (final item in curList) {
      item.isShowSuspension = false;
    }
  }

  List<ISuspensionBeanImpl> _prepareList(List<ISuspensionBeanImpl> source) {
    final list = List<ISuspensionBeanImpl>.from(source);
    if (widget.isShowIndexBar) {
      return addShowSuspension(list);
    }
    _hideSuspension(list);
    return list;
  }

  static Widget getSusItem(BuildContext context, String tag,
      {double susHeight = 40, bool isDesktopScreen = false}) {
    final theme = Provider.of<TUIThemeViewModel>(context).theme;
    return Container(
      height: isDesktopScreen ? 28 : susHeight,
      width: MediaQuery.of(context).size.width,
      padding: EdgeInsets.only(left: isDesktopScreen ? 20.0 : 16.0),
      color: Colors.transparent,
      alignment: Alignment.centerLeft,
      child: Text(
        tag,
        softWrap: true,
        style: TextStyle(
          fontSize: isDesktopScreen ? 11.0 : 14.0,
          fontWeight: isDesktopScreen ? FontWeight.w600 : FontWeight.w400,
          letterSpacing: isDesktopScreen ? 0.4 : 0,
          color: theme.weakTextColor,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _list = _prepareList(widget.memberList!);
  }

  @override
  void didUpdateWidget(covariant AZListViewContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    setState(() {
      _list = _prepareList(widget.memberList!);
    });
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final isDesktopScreen =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    return ChangeNotifierProvider.value(
        value: serviceLocator<TUIThemeViewModel>(),
        child: Consumer<TUIThemeViewModel>(
            builder: (context, tuiTheme, child) => Theme(
                  data: Theme.of(context).copyWith(
                    scrollbarTheme: ScrollbarThemeData(
                      thickness: WidgetStateProperty.all(
                        isDesktopScreen ? 6.0 : null,
                      ),
                      radius: const Radius.circular(4),
                      crossAxisMargin: isDesktopScreen ? 2 : 0,
                    ),
                  ),
                  child: AzListView(
                      physics: isDesktopScreen
                          ? const ClampingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            )
                          : const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                      data: _list!,
                      itemCount: _list!.length,
                      itemBuilder: widget.itemBuilder,
                      itemPositionsListener: widget.itemPositionsListener,
                      // 无字母索引时去掉悬浮头占位，避免假高度干扰触底判断。
                      susItemHeight: widget.isShowIndexBar ? kSusItemHeight : 0,
                      indexBarOptions: const IndexBarOptions(hapticFeedback: true),
                      indexBarData: (!isDesktopScreen && widget.isShowIndexBar)
                          ? SuspensionUtil.getTagIndexList(_list!)
                              .where((element) => element != "@")
                              .toList()
                          : [],
                      susItemBuilder: (BuildContext context, int index) {
                        if (!widget.isShowIndexBar) {
                          return const SizedBox.shrink();
                        }
                        if (widget.susItemBuilder != null) {
                          return widget.susItemBuilder!(context, index);
                        }
                        ISuspensionBeanImpl model = _list![index];
                        if (model.getSuspensionTag() == "@") {
                          return Container();
                        }
                        return getSusItem(
                          context,
                          model.getSuspensionTag(),
                          isDesktopScreen: isDesktopScreen,
                        );
                      }),
                )));
  }
}

class ISuspensionBeanImpl<T> extends ISuspensionBean {
  String tagIndex;
  T memberInfo;

  ISuspensionBeanImpl({required this.tagIndex, required this.memberInfo});

  @override
  String getSuspensionTag() => tagIndex;
}
