// ignore_for_file: unnecessary_null_comparison

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_callback.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_group_profile_model.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/text_input_bottom_sheet.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

class GroupProfileNameCard extends StatefulWidget {
  const GroupProfileNameCard({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => GroupProfileNameCardState();

}

class GroupProfileNameCardState extends TIMUIKitState<GroupProfileNameCard>{
  final TextEditingController controller = TextEditingController();
  String? nameCard;
  bool _savingNameCard = false;

  Future<void> _setNameCard(
    TUIGroupProfileModel model,
    String nameCard,
  ) async {
    if (_savingNameCard) {
      return;
    }
    _savingNameCard = true;
    final response = await model.setNameCard(nameCard.trim());
    _savingNameCard = false;
    if (!mounted) {
      return;
    }
    if (response?.code == 0) {
      onTIMCallback(TIMCallback(
        type: TIMCallbackType.INFO,
        infoRecommendText: TIM_t("修改成功"),
        infoCode: 6660211,
      ));
      return;
    }
    onTIMCallback(TIMCallback(
      type: TIMCallbackType.INFO,
      infoRecommendText: response?.desc?.isNotEmpty == true
          ? response!.desc!
          : TIM_t("保存失败"),
      infoCode: 6660212,
    ));
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final TUITheme theme = value.theme;
    final isDesktopScreen =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    final model = Provider.of<TUIGroupProfileModel>(context);
    if (model == null) {
      return Container();
    }
    nameCard = model.getSelfNameCard();
    controller.text = nameCard ?? "";
    final itemBackgroundColor =
        theme.conversationItemBgColor ?? theme.wideBackgroundColor ?? Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          color: itemBackgroundColor,
          border: isDesktopScreen ? null : Border(
              bottom: BorderSide(
                  color:
                  theme.weakDividerColor ?? CommonColor.weakDividerColor))),
      child: GestureDetector(
        onTap: () async {
          if (!isDesktopScreen) {
            TextInputBottomSheet.showTextInputBottomSheet(
                context: context,
                title: TIM_t("修改我的群昵称"),
                tips: TIM_t("仅限中文、字母、数字和下划线，2-20个字"),
                onSubmitted: (String nameCard) {
                  _setNameCard(model, nameCard);
                },
                theme: theme);
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  margin: const EdgeInsets.only(right: 10),
                  child: Text(
                    TIM_t("我的群昵称"),
                    style: TextStyle(
                        fontSize: isDesktopScreen ? 14 : 16,
                        color: theme.darkTextColor),
                  ),
                ),
                if (!isDesktopScreen)
                  Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                              child: Text(
                                nameCard ?? "",
                                style: TextStyle(
                                    fontSize: isDesktopScreen ? 14 : 16,
                                    color: theme.darkTextColor),
                              )),
                          Icon(Icons.keyboard_arrow_right,
                              color: theme.weakTextColor)
                        ],
                      )),
              ],
            ),
            if (isDesktopScreen)
              Text(
                TIM_t("仅限中文、字母、数字和下划线，2-20个字"),
                style: TextStyle(color: theme.weakTextColor, fontSize: 12),
              ),
            if (isDesktopScreen)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                height: 30,
                child: TextField(
                    minLines: 1,
                    controller: controller,
                    maxLines: 1,
                    onSubmitted: (text) {
                      _setNameCard(model, text);
                    },
                    keyboardType: TextInputType.multiline,
                    autofocus: true,
                    textAlignVertical: TextAlignVertical.center,
                    textAlign: TextAlign.start,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(5.0),
                            borderSide: BorderSide(
                              color: theme.weakDividerColor ?? Colors.grey,
                            )),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(5.0),
                          borderSide: BorderSide(
                            color: theme.weakDividerColor ?? Colors.grey,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          //选中时外边框颜色
                          borderRadius: BorderRadius.circular(5.0),
                          borderSide: BorderSide(
                            color: theme.weakTextColor ?? Colors.grey,
                          ),
                        ),
                        hintStyle: const TextStyle(
                          color: Color(0xFFAEA4A3),
                        ),
                        hintText: TIM_t("修改我的群昵称"))),
              ),
          ],
        ),
      ),
    );
  }
}
