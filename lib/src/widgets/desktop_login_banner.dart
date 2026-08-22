import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';

/// 消息列表搜索框下「已在××登录」横条（微信风）。
class DesktopLoginBanner extends StatelessWidget {
  const DesktopLoginBanner({
    super.key,
    required this.text,
    required this.onTap,
  });

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: text,
      child: Material(
        color: const Color(0xFFF7F7F7),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.desktop_windows_outlined,
                  size: 20,
                  color: AppTokens.ink500,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTokens.ink700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: AppTokens.ink300,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
