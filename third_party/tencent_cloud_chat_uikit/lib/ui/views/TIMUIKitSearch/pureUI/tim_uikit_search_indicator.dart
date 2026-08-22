import 'package:flutter/material.dart';
import 'package:tencent_chat_i18n_tool/language_json/strings.g.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_statelesswidget.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

enum SearchType { contact, group, history }

class TIMUIKitSearchIndicator extends TIMUIKitStatelessWidget {
  final List<SearchType> typeList;
  final ValueChanged<List<SearchType>> onChange;

  TIMUIKitSearchIndicator(
      {required this.typeList, required this.onChange, Key? key})
      : super(key: key);

  Widget renderItemBox(
      IconData icon, SearchType item, String label, bool isSelect, TUITheme theme) {
    return InkWell(
      onTap: () {
        if (isSelect) {
          typeList.remove(item);
        } else {
          typeList.add(item);
        }
        onChange(typeList);
      },
      child: Container(
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    icon,
                    color: theme.weakTextColor,
                    size: 30,
                  ),
                ),
                if (isSelect)
                  Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        height: 16,
                        width: 16,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: theme.primaryColor),
                        child: const Icon(
                          Icons.check,
                          size: 8,
                          color: Colors.white,
                        ),
                      ))
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: theme.textColor, fontSize: 13),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final tr = Translations.of(context);
    final theme = value.theme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Expanded(
                child: Text(tr.k_1ui0gai,
                    style: TextStyle(color: theme.weakTextColor, fontSize: 12)),
              )
            ],
          ),
          const SizedBox(height: 1),
          Divider(thickness: 0.8, color: theme.weakDividerColor),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            mainAxisSize: MainAxisSize.max,
            children: [
              renderItemBox(Icons.person, SearchType.contact, tr.k_03idjo0,
                  typeList.contains(SearchType.contact), theme),
              renderItemBox(Icons.people, SearchType.group, tr.k_002twmj,
                  typeList.contains(SearchType.group), theme),
              renderItemBox(Icons.message, SearchType.history, tr.k_176rzr7,
                  typeList.contains(SearchType.history), theme),
            ],
          )
        ],
      ),
    );
  }
}
