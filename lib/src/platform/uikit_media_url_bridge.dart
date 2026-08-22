import 'package:tencent_cloud_chat_demo/utils/media_url_resolver.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/media_preview_video_utils.dart'
    as media_preview;

/// 将聊天媒体预览的网络 URL 解析与鉴权头注入 UIKit 播放器。
class UikitMediaUrlBridge {
  UikitMediaUrlBridge._();

  static void install() {
    media_preview.resolveMediaPreviewNetworkUrl = (url) {
      return MediaUrlResolver.resolve(url) ?? url;
    };
    media_preview.mediaPreviewNetworkUrlHeaders = MediaUrlResolver.authHeadersFor;
  }
}
