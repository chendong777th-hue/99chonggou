import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/provider/local_setting.dart';
import 'package:tencent_cloud_chat_demo/src/services/network_status_service.dart';

/// 聊天页顶部细条：IM 未连接或系统离线时提示（不替代 UIKit 失败叹号）。
class ChatConnectStatusStrip extends StatelessWidget {
  const ChatConnectStatusStrip({super.key});

  bool _shouldShow(ConnectStatus imStatus, NetworkReachability network) {
    if (network == NetworkReachability.offline) return true;
    if (imStatus == ConnectStatus.connecting ||
        imStatus == ConnectStatus.failed) {
      return true;
    }
    return false;
  }

  String _message(AppI18n i18n, ConnectStatus imStatus, NetworkReachability network) {
    if (network == NetworkReachability.offline) {
      return i18n.t(
        zhHans: '当前无网络，文字/图片/视频可能发送失败',
        zhHant: '目前無網路，文字/圖片/影片可能傳送失敗',
        en: 'You are offline. Text and media may fail to send.',
        ja: 'オフラインです。テキストやメディアの送信に失敗する場合があります。',
        ko: '오프라인 상태입니다. 텍스트·미디어 전송이 실패할 수 있습니다.',
      );
    }
    if (imStatus == ConnectStatus.connecting) {
      return i18n.t(
        zhHans: '正在连接，请稍后再发消息',
        zhHant: '正在連線，請稍後再發訊息',
        en: 'Connecting. Please wait before sending.',
        ja: '接続中です。しばらくしてから送信してください。',
        ko: '연결 중입니다. 잠시 후 다시 보내 주세요.',
      );
    }
    return i18n.t(
      zhHans: '连接异常，消息可能发送失败',
      zhHant: '連線異常，訊息可能傳送失敗',
      en: 'Connection issue. Messages may fail to send.',
      ja: '接続に問題があります。送信に失敗する場合があります。',
      ko: '연결에 문제가 있습니다. 메시지 전송이 실패할 수 있습니다.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LocalSetting>(
      builder: (context, settings, _) {
        return ValueListenableBuilder<NetworkReachability>(
          valueListenable: NetworkStatusService.instance.status,
          builder: (context, network, _) {
            final imStatus = settings.connectStatusForUi;
            if (!_shouldShow(imStatus, network)) {
              return const SizedBox.shrink();
            }

            final i18n = AppI18n.of(context);
            return Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Material(
                color: const Color(0xFFFFF5D8),
                elevation: 2,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _message(i18n, imStatus, network),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF8A5A00),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
