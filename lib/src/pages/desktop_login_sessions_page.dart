import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/api/device_api.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/services/desktop_login_session_service.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';
import 'package:tencent_cloud_chat_demo/src/utils/desktop_login_platform.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_empty_state.dart';
import 'package:tencent_cloud_chat_demo/utils/dio_error_message.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';

/// 电脑 / 网页端登录详情（仅桌面类在线会话 + 踢下线）。
class DesktopLoginSessionsPage extends StatefulWidget {
  const DesktopLoginSessionsPage({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push<void>(
      AppMaterialPageRoute(
        builder: (_) => const DesktopLoginSessionsPage(),
      ),
    );
  }

  @override
  State<DesktopLoginSessionsPage> createState() =>
      _DesktopLoginSessionsPageState();
}

class _DesktopLoginSessionsPageState extends State<DesktopLoginSessionsPage> {
  bool _loading = true;
  bool _busy = false;
  String? _kickId;

  DesktopLoginSessionService get _service =>
      DesktopLoginSessionService.instance;

  @override
  void initState() {
    super.initState();
    _reload(initial: true);
  }

  Future<void> _reload({bool initial = false}) async {
    if (initial) {
      setState(() => _loading = true);
    }
    await _service.refresh(reason: 'detail_page', force: true);
    if (!mounted) {
      return;
    }
    setState(() => _loading = false);
    if (_service.devices.value.isEmpty) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _kick(UserDevice device) async {
    if (_busy) {
      return;
    }
    final i18n = AppI18n.of(context);
    final title = _deviceTitle(device);
    final confirmed = await AppDialog.confirm(
      title: i18n.t(
        zhHans: '退出登录',
        zhHant: '退出登入',
        en: 'Sign out',
        ja: 'ログアウト',
        ko: '로그아웃',
      ),
      message: i18n.format(
        zhHans: '确定将「{title}」强制下线吗？',
        zhHant: '確定將「{title}」強制下線嗎？',
        en: 'Sign out "{title}"?',
        ja: '「{title}」を強制ログアウトしますか？',
        ko: '「{title}」을(를) 강제 로그아웃할까요?',
        vars: {'title': title},
      ),
      cancelText: i18n.t(
        zhHans: '取消',
        zhHant: '取消',
        en: 'Cancel',
        ja: 'キャンセル',
        ko: '취소',
      ),
      confirmText: i18n.t(
        zhHans: '退出',
        zhHant: '退出',
        en: 'Sign out',
        ja: 'ログアウト',
        ko: '로그아웃',
      ),
      destructive: true,
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      _busy = true;
      _kickId = device.deviceId;
    });
    try {
      await DeviceApi.instance.kickDevice(device.deviceId);
      if (!mounted) {
        return;
      }
      ToastUtils.toast(
        i18n.t(
          zhHans: '已退出该设备',
          zhHant: '已退出該裝置',
          en: 'Device signed out',
          ja: '端末をログアウトしました',
          ko: '기기가 로그아웃되었습니다',
        ),
      );
      await _reload();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ToastUtils.toast(
        e is DioError
            ? DioErrorMessage.forApp(e)
            : DioErrorMessage.sanitizeUserText(
                e.toString(),
                fallback: i18n.t(
                  zhHans: '操作失败',
                  zhHant: '操作失敗',
                  en: 'Failed',
                  ja: '失敗しました',
                  ko: '실패했습니다',
                ),
              ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _kickId = null;
        });
      }
    }
  }

  String _deviceTitle(UserDevice device) {
    final model = device.model?.trim() ?? '';
    if (model.isNotEmpty) {
      return model;
    }
    return desktopPlatformDisplayName(device.platform);
  }

  IconData _iconFor(String platform) {
    switch (platform.trim().toLowerCase()) {
      case 'web':
        return Icons.language_rounded;
      case 'windows':
        return Icons.desktop_windows_outlined;
      case 'macos':
        return Icons.laptop_mac_outlined;
      default:
        return Icons.computer_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    return Scaffold(
      backgroundColor: AppTokens.backgroundLight,
      appBar: AppBar(
        title: Text(
          i18n.t(
            zhHans: '电脑端登录',
            zhHant: '電腦端登入',
            en: 'Desktop sessions',
            ja: 'パソコンログイン',
            ko: '데스크톱 로그인',
          ),
        ),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ValueListenableBuilder<List<UserDevice>>(
              valueListenable: _service.devices,
              builder: (context, list, _) {
                if (list.isEmpty) {
                  return AppEmptyState(
                    message: i18n.t(
                      zhHans: '暂无电脑端在线',
                      zhHant: '暫無電腦端在線',
                      en: 'No desktop sessions online',
                      ja: 'パソコンのログインはありません',
                      ko: '온라인 데스크톱 세션이 없습니다',
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final device = list[index];
                    final kicking = _kickId == device.deviceId;
                    return ListTile(
                      leading: Icon(
                        _iconFor(device.platform),
                        color: AppTokens.ink500,
                      ),
                      title: Text(_deviceTitle(device)),
                      subtitle: Text(
                        [
                          desktopPlatformDisplayName(device.platform),
                          device.isOnline ? '活跃' : '已登录',
                        ].join(' · '),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTokens.ink400,
                        ),
                      ),
                      trailing: TextButton(
                        onPressed: _busy ? null : () => _kick(device),
                        child: kicking
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                i18n.t(
                                  zhHans: '退出登录',
                                  zhHant: '退出登入',
                                  en: 'Sign out',
                                  ja: 'ログアウト',
                                  ko: '로그아웃',
                                ),
                                style: const TextStyle(color: Color(0xFFDC2626)),
                              ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
