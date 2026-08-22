import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/api/auth_api.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/auth_localizations.dart';
import 'package:tencent_cloud_chat_demo/src/services/desktop_login_session_service.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';
import 'package:tencent_cloud_chat_demo/src/ui/auth_widgets.dart';
import 'package:tencent_cloud_chat_demo/utils/dio_error_message.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';

/// App：扫码后二次确认网页版登录。
class QrWebLoginConfirmPage extends StatefulWidget {
  const QrWebLoginConfirmPage({
    super.key,
    required this.sessionId,
    this.siteLabel,
  });

  final String sessionId;
  final String? siteLabel;

  @override
  State<QrWebLoginConfirmPage> createState() => _QrWebLoginConfirmPageState();
}

class _QrWebLoginConfirmPageState extends State<QrWebLoginConfirmPage> {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _siteLabel;

  AuthLocalizations get _strings => AuthLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _siteLabel = widget.siteLabel;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_registerScan());
    });
  }

  Future<void> _registerScan() async {
    final strings = _strings;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result =
          await AuthApi.instance.scanQrLoginSession(widget.sessionId);
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _siteLabel = result.siteLabel?.trim().isNotEmpty == true
            ? result.siteLabel
            : _siteLabel;
      });
    } on DioError catch (e) {
      if (!mounted) {
        return;
      }
      final unavailable = e.response?.statusCode == 404;
      setState(() {
        _loading = false;
        _error = unavailable
            ? strings.qrLoginUnavailable
            : DioErrorMessage.fromQrWebLogin(e, strings);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = strings.requestFailed;
      });
    }
  }

  Future<void> _confirm(bool approve) async {
    if (_busy) {
      return;
    }
    final strings = _strings;
    setState(() => _busy = true);
    try {
      await AuthApi.instance.confirmQrLoginSession(
        sessionId: widget.sessionId,
        approve: approve,
      );
      if (approve) {
        unawaited(
          DesktopLoginSessionService.instance.refresh(
            reason: 'qr_web_confirmed',
            force: true,
          ),
        );
      }
      if (!mounted) {
        return;
      }
      ToastUtils.toast(
        approve
            ? strings.qrWebLoginConfirmedToast
            : strings.qrWebLoginCancelledToast,
      );
      Navigator.of(context).pop(approve);
    } on DioError catch (e) {
      if (!mounted) {
        return;
      }
      final unavailable = e.response?.statusCode == 404;
      ToastUtils.toast(
        unavailable
            ? strings.qrLoginUnavailable
            : DioErrorMessage.fromQrWebLogin(e, strings),
      );
      setState(() => _busy = false);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ToastUtils.toast(strings.requestFailed);
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = _strings;
    final label = (_siteLabel ?? '').trim();
    return Scaffold(
      backgroundColor: AppTokens.backgroundLight,
      appBar: AppBar(
        title: Text(strings.qrWebLoginConfirmTitle),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _error!,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppTokens.ink500,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 24),
                        AuthPrimaryButton(
                          text: strings.qrLoginRefresh,
                          onPressed: _busy ? null : _registerScan,
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.desktop_windows_outlined,
                          size: 56,
                          color: AppTokens.brand600,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          strings.qrWebLoginConfirmTitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppTokens.ink900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          strings.qrWebLoginConfirmMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTokens.ink500,
                            height: 1.45,
                          ),
                        ),
                        if (label.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            label,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTokens.ink400,
                            ),
                          ),
                        ],
                        const Spacer(),
                        AuthPrimaryButton(
                          text: strings.qrWebLoginConfirmAction,
                          loadingText: strings.loggingIn,
                          loading: _busy,
                          onPressed: _busy ? null : () => _confirm(true),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _busy ? null : () => _confirm(false),
                          child: Text(strings.qrWebLoginCancelAction),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}
