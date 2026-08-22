import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_demo/config.dart';

class AvatarSelectPage extends StatefulWidget {
  static const String avatarFaceUrl = "https://im.sdk.qcloud.com/download/tuikit-resource/avatar/avatar_%s.png";
  static const int avatarFaceCount = 26;

  final TIMUIKitProfileController? controller;
  final String selectedAvatarUrl;

  const AvatarSelectPage({Key? key, required this.controller, required this.selectedAvatarUrl}) : super(key: key);

  @override
  State<StatefulWidget> createState() => AvatarSelectPageState();
}

class AvatarSelectPageState extends State<AvatarSelectPage> {
  late final List<String> _avatarURLList;
  late String _selectedAvatarUrl;

  @override
  void initState() {
    super.initState();
    _avatarURLList = [];
    _selectedAvatarUrl = widget.selectedAvatarUrl;
    for (int i = 0; i < AvatarSelectPage.avatarFaceCount; i++) {
      _avatarURLList.add(AvatarSelectPage.avatarFaceUrl.replaceAll("%s", (i + 1).toString()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final isWideScreen =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;

    return Scaffold(
      appBar: isWideScreen
          ? null
          : AppBar(
              iconTheme: IconThemeData(
                color: theme.primaryColor ?? const Color(0xFF1E90FF),
              ),
              shadowColor: theme.weakDividerColor,
              elevation: 1,
              title: Text(
                i18n.t(
                  zhHans: '选择头像',
                  zhHant: '選擇頭像',
                  en: 'Choose Avatar',
                  ja: 'アバターを選択',
                  ko: '아바타 선택',
                ),
                style: const TextStyle(fontSize: IMDemoConfig.appBarTitleFontSize),
              ),
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    theme.lightPrimaryColor ?? CommonColor.lightPrimaryColor,
                    theme.primaryColor ?? CommonColor.primaryColor
                  ]),
                ),
              ),
        actions: [
          TextButton(
            onPressed: () {
              _submitAvatar();
            },
            child: Text(
              i18n.t(
                zhHans: '确定',
                zhHant: '確定',
                en: 'OK',
                ja: '確定',
                ko: '확인',
              ),
              style: TextStyle(
                color: theme.white,
                fontSize: IMDemoConfig.appBarTitleFontSize,
              ),
            ),
          )
        ],
      ),
      body: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4, // 设置每行显示的网格数量
          childAspectRatio: 1.0, // 设置网格宽高比
        ),
        itemCount: _avatarURLList.length, // 数据源
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedAvatarUrl = _avatarURLList[index];
              });
            },
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                border: Border.all(
                  color:
                  _selectedAvatarUrl == _avatarURLList[index] ? const Color(0xFF1E90FF) : Colors.transparent,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Image.network(
                _avatarURLList[index],
                fit: BoxFit.cover,
              ),
            ),
          );
        }
      ),
    );
  }

  Future<void> _submitAvatar() async {
    if (_selectedAvatarUrl.isNotEmpty) {
      if (widget.controller == null) {
        Navigator.of(context).pop(_selectedAvatarUrl);
        return;
      }
      final result = await widget.controller?.updateAvatar(_selectedAvatarUrl);
      if (result?.code == 0) {
        Navigator.of(context).pop(_selectedAvatarUrl);
      }
    }
  }
}
