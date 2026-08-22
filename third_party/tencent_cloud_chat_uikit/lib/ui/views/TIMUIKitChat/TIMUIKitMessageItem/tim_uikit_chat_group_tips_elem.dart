import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_full_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_tips_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_tips_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_tips_operator_live_cache.dart';
import 'package:tencent_cloud_chat_demo/utils/group_tips_message_helper.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/avatar.dart';

class TIMUIKitGroupTipsElem extends StatefulWidget {
  final V2TimGroupTipsElem groupTipsElem;
  final List<V2TimGroupMemberFullInfo?> groupMemberList;
  final V2TimMessage? message;

  const TIMUIKitGroupTipsElem({
    Key? key,
    required this.groupMemberList,
    required this.groupTipsElem,
    this.message,
  }) : super(key: key);

  @override
  State<TIMUIKitGroupTipsElem> createState() => _TIMUIKitGroupTipsElemState();
}

class _TIMUIKitGroupTipsElemState extends TIMUIKitState<TIMUIKitGroupTipsElem> {
  String groupTipsAbstractText = "";
  String? _groupFaceUrl;
  late final VoidCallback _liveCacheListener;

  bool get _isPendingAdministratorTip {
    final message = widget.message;
    if (message == null) {
      return false;
    }
    return GroupTipsMessageHelper.isPendingAdministratorMemberTip(message);
  }

  @override
  void didUpdateWidget(covariant TIMUIKitGroupTipsElem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groupTipsElem != widget.groupTipsElem ||
        oldWidget.groupMemberList != widget.groupMemberList ||
        oldWidget.message != widget.message) {
      getText();
    }
  }

  @override
  void initState() {
    super.initState();
    _groupFaceUrl =
        MessageUtils.groupTipsGroupFaceUrl(widget.groupTipsElem);
    _liveCacheListener = () {
      if (!mounted) {
        return;
      }
      getText();
    };
    GroupTipsOperatorLiveCache.instance.revision
        .addListener(_liveCacheListener);
    getText();
  }

  @override
  void dispose() {
    GroupTipsOperatorLiveCache.instance.revision
        .removeListener(_liveCacheListener);
    super.dispose();
  }

  Future<void> getText() async {
    final message = widget.message;
    if (message != null) {
      final resolved = GroupTipsMessageHelper.resolvedMemberTipPreview(message);
      if (resolved != null && resolved.trim().isNotEmpty) {
        if (!mounted) {
          return;
        }
        setState(() {
          groupTipsAbstractText = resolved;
        });
        return;
      }
      if (GroupTipsMessageHelper.isPendingAdministratorMemberTip(message)) {
        if (!mounted) {
          return;
        }
        setState(() {
          groupTipsAbstractText = '';
        });
        return;
      }
    }
    final newText = await MessageUtils.groupTipsMessageAbstract(
      widget.groupTipsElem,
      widget.groupMemberList,
      message: widget.message,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      groupTipsAbstractText = newText;
    });
  }

  Widget _buildTipsText(TUITheme theme) {
    final tipColor = theme.weakTextColor ?? hexToColor('888888');
    return Text(
      groupTipsAbstractText,
      textAlign: TextAlign.center,
      softWrap: true,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w400,
        color: tipColor,
        height: 1.16,
      ),
    );
  }

  Widget _buildTipsBody(TUITheme theme) {
    final faceUrl = _groupFaceUrl?.trim() ?? '';
    final text = _buildTipsText(theme);

    if (faceUrl.isEmpty) {
      return text;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        text,
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            width: 28,
            height: 28,
            child: Avatar(
              faceUrl: faceUrl,
              showName: '',
              type: 2,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    if (_isPendingAdministratorTip && groupTipsAbstractText.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    final TUITheme theme = value.theme;

    return MessageUtils.wrapMessageTips(_buildTipsBody(theme), theme);
  }
}
