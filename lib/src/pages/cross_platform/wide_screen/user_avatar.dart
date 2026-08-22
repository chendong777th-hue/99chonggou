import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/provider/login_user_Info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/avatar.dart';

/// 侧栏头像：点击直接进入「我的」，不再弹出菜单（设置/反馈/关于已在「我的」内）。
class UserAvatar extends StatelessWidget {
  const UserAvatar({Key? key, required this.onChangeIndex}) : super(key: key);

  final ValueChanged<int> onChangeIndex;

  @override
  Widget build(BuildContext context) {
    final loginUserInfoModel = Provider.of<LoginUserInfo>(context);
    final V2TimUserFullInfo loginUserInfo = loginUserInfoModel.loginUserInfo;

    return Column(
      children: [
        GestureDetector(
          onTap: () => onChangeIndex(3),
          child: Container(
            margin: const EdgeInsets.only(bottom: 20, top: 40),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: SizedBox(
                width: 36,
                height: 36,
                child: Avatar(
                  faceUrl: loginUserInfo.faceUrl ?? "",
                  showName: loginUserInfo.nickName ?? "",
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
