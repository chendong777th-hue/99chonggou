import 'package:tencent_cloud_chat_demo/config.dart';
import 'package:tencent_cloud_chat_demo/src/api/api_client.dart';

/// 群游戏 H5 入口链接。
class GroupGameUrlBuilder {
  GroupGameUrlBuilder._();

  static const String h5Path = String.fromEnvironment(
    'GROUP_GAME_H5_PATH',
    defaultValue: '/h5/group-game',
  );

  static String build(String groupId) {
    final id = groupId.trim();
    final base = ApiClient.resolveBaseUrl().replaceAll(RegExp(r'/$'), '');
    final path = h5Path.startsWith('/') ? h5Path : '/$h5Path';
    final uri = Uri.parse('$base$path').replace(
      queryParameters: <String, String>{
        'groupId': id,
        if (IMDemoConfig.appName.isNotEmpty) 'app': IMDemoConfig.appName,
      },
    );
    return uri.toString();
  }
}
