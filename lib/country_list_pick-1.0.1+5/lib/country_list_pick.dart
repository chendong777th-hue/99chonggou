// ignore_for_file: prefer_const_constructors_in_immutables, no_logic_in_create_state

import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/country_list_pick-1.0.1+5/lib/country_selection_theme.dart';
import 'package:tencent_cloud_chat_demo/country_list_pick-1.0.1+5/lib/selection_list.dart';
import 'package:tencent_cloud_chat_demo/country_list_pick-1.0.1+5/lib/support/code_countries_en.dart';
import 'package:tencent_cloud_chat_demo/country_list_pick-1.0.1+5/lib/support/code_country.dart';
import 'package:tencent_cloud_chat_demo/country_list_pick-1.0.1+5/lib/support/code_countrys.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/tim_uikit_wide_modal_operation_key.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/wide_popup.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';

const Map<String, String> _countryNamesZh = {
  'CN': '中国', 'HK': '中国香港', 'MO': '中国澳门', 'TW': '中国台湾',
  'US': '美国', 'CA': '加拿大', 'GB': '英国', 'AU': '澳大利亚',
  'NZ': '新西兰', 'SG': '新加坡', 'MY': '马来西亚', 'TH': '泰国',
  'VN': '越南', 'PH': '菲律宾', 'ID': '印度尼西亚', 'KH': '柬埔寨',
  'LA': '老挝', 'MM': '缅甸', 'JP': '日本', 'KR': '韩国',
  'IN': '印度', 'PK': '巴基斯坦', 'BD': '孟加拉国', 'NP': '尼泊尔',
  'AE': '阿联酋', 'SA': '沙特阿拉伯', 'QA': '卡塔尔', 'KW': '科威特',
  'TR': '土耳其', 'RU': '俄罗斯', 'DE': '德国', 'FR': '法国',
  'IT': '意大利', 'ES': '西班牙', 'PT': '葡萄牙', 'NL': '荷兰',
  'BE': '比利时', 'CH': '瑞士', 'SE': '瑞典', 'NO': '挪威',
  'DK': '丹麦', 'FI': '芬兰', 'IE': '爱尔兰', 'AT': '奥地利',
  'PL': '波兰', 'CZ': '捷克', 'GR': '希腊', 'HU': '匈牙利',
  'BR': '巴西', 'AR': '阿根廷', 'CL': '智利', 'CO': '哥伦比亚',
  'MX': '墨西哥', 'PE': '秘鲁', 'ZA': '南非', 'EG': '埃及',
  'NG': '尼日利亚', 'KE': '肯尼亚', 'MA': '摩洛哥',
};

String _countryNameZh(String? code, String nameEn) {
  final iso = (code ?? '').toUpperCase();
  return _countryNamesZh[iso] ?? nameEn;
}

class CountryListPick extends StatefulWidget {
   CountryListPick(
      {Key? key, this.onChanged,
      this.initialSelection,
      this.appBar,
      this.pickerBuilder,
      this.countryBuilder,
      this.theme,
      this.useUiOverlay = true,
      this.useSafeArea = false}) : super(key: key);

  final String? initialSelection;
  final ValueChanged<CountryCode?>? onChanged;
  final PreferredSizeWidget? appBar;
  final Widget Function(BuildContext context, CountryCode? countryCode)?
      pickerBuilder;
  final CountryTheme? theme;
  final Widget Function(BuildContext context, CountryCode countryCode)?
      countryBuilder;
  final bool useUiOverlay;
  final bool useSafeArea;

  @override
  _CountryListPickState createState() {
    final List<Map> jsonList = countriesEnglish;

    List elements = jsonList
        .map((s) {
          final code = s['code']?.toString() ?? '';
          final nameEn = s['name']?.toString() ?? '';
          return CountryCode(
            name: nameEn,
            nameEn: nameEn,
            nameZh: _countryNameZh(code, nameEn),
            code: code,
            dialCode: s['dial_code'],
            flagUri: 'flags/${code.toLowerCase()}.png',
          );
        })
        .toList();
    return _CountryListPickState(elements);
  }
}

class _CountryListPickState extends State<CountryListPick> {
  CountryCode? selectedItem;
  List elements = [];

  _CountryListPickState(this.elements);

  @override
  void initState() {
    if (widget.initialSelection != null) {
      selectedItem = elements.firstWhere(
          (e) =>
              (e.code.toUpperCase() ==
                  widget.initialSelection!.toUpperCase()) ||
              (e.dialCode == widget.initialSelection),
          orElse: () => elements[0] as CountryCode);
    } else {
      selectedItem = elements[0];
    }

    super.initState();
  }

  void _awaitFromSelectScreen(BuildContext context, PreferredSizeWidget? appBar,
      CountryTheme? theme) async {
    final isWideScreen = TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    if(isWideScreen){
      TUIKitWidePopup.showPopupWindow(
          context: context,
          operationKey: TUIKitWideModalOperationKey.chooseCountry,
          width: MediaQuery.of(context).size.width * 0.4,
          height: MediaQuery.of(context).size.width * 0.5,
          child: (onClose) => SelectionList(
            elements,
            selectedItem,
            appBar: widget.appBar ??
                (!isWideScreen ? AppBar(
                  backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
                  title: const Text('选择国家/地区'),
                ) : null),
            theme: theme,
            countryBuilder: widget.countryBuilder,
            useUiOverlay: widget.useUiOverlay,
            useSafeArea: widget.useSafeArea,
            onChange: (item){
              setState(() {
                selectedItem = item;
                widget.onChanged!(item);
              });
              onClose();
            },
          ));
    }else{
      final result = await Navigator.push(
          context,
          AppMaterialPageRoute(
            builder: (context) => SelectionList(
              elements,
              selectedItem,
              appBar: widget.appBar ??
                  AppBar(
                    backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
                    title: const Text('选择国家/地区'),
                  ),
              theme: theme,
              countryBuilder: widget.countryBuilder,
              useUiOverlay: widget.useUiOverlay,
              useSafeArea: widget.useSafeArea,
            ),
          ));

      setState(() {
        selectedItem = result ?? selectedItem;
        widget.onChanged!(result ?? selectedItem);
      });
    }

  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () {
        _awaitFromSelectScreen(context, widget.appBar, widget.theme);
      },
      child: widget.pickerBuilder != null
          ? widget.pickerBuilder!(context, selectedItem)
          : Flex(
              direction: Axis.horizontal,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (widget.theme?.isShowFlag ?? true == true)
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5.0),
                      child: Image.asset(
                        'lib/country_list_pick-1.0.1+5/${selectedItem!.flagUri!}',
                        width: 32.0,
                      ),
                    ),
                  ),
                if (widget.theme?.isShowCode ?? true == true)
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5.0),
                      child: Text(selectedItem.toString()),
                    ),
                  ),
                if (widget.theme?.isShowTitle ?? true == true)
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5.0),
                      child: Text(selectedItem!.toCountryStringOnly()),
                    ),
                  ),
                if (widget.theme?.isDownIcon ?? true == true)
                  const Flexible(
                    child: Icon(Icons.keyboard_arrow_down),
                  )
              ],
            ),
    );
  }
}
