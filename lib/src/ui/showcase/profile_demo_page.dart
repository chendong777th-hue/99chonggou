import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';
import 'package:tencent_cloud_chat_demo/src/ui/components/app_avatar.dart';

class ProfileDemoPage extends StatelessWidget {
  const ProfileDemoPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTokens.surfaceAlt,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(child: _buildProfileCard()),
          SliverToBoxAdapter(child: _buildStatsRow()),
          SliverToBoxAdapter(child: const SizedBox(height: 20)),
          SliverToBoxAdapter(child: _buildSection(context)),
          SliverToBoxAdapter(child: const SizedBox(height: 12)),
          SliverToBoxAdapter(child: _buildPreferencesSection(context)),
          SliverToBoxAdapter(child: const SizedBox(height: 12)),
          SliverToBoxAdapter(child: _buildDangerSection(context)),
          SliverToBoxAdapter(child: const SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      backgroundColor: AppTokens.surface.withOpacity(0.85),
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: const SizedBox.expand(),
        ),
      ),
      titleSpacing: 20,
      title: Text('我的', style: AppTokens.title.copyWith(fontSize: 22)),
      actions: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTokens.ink25,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.settings_outlined, size: 18, color: AppTokens.ink700),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildProfileCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTokens.surface,
        borderRadius: BorderRadius.circular(AppTokens.rLg),
        border: Border.all(color: AppTokens.divider, width: 1),
      ),
      child: Row(
        children: [
          const AppAvatar(name: 'Alex Chen', size: 60, showOnline: true),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Alex Chen', style: AppTokens.title.copyWith(fontSize: 18)),
                const SizedBox(height: 4),
                Text('alex.chen@99chat.com', style: AppTokens.caption.copyWith(fontSize: 13)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTokens.brand50,
                    borderRadius: BorderRadius.circular(AppTokens.rPill),
                    border: Border.all(color: AppTokens.brand100, width: 1),
                  ),
                  child: Text(
                    'Pro 会员',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTokens.brand500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTokens.ink25,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.qr_code_rounded, size: 18, color: AppTokens.ink600),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppTokens.surface,
        borderRadius: BorderRadius.circular(AppTokens.rLg),
        border: Border.all(color: AppTokens.divider, width: 1),
      ),
      child: Row(
        children: [
          _stat('128', '联系人'),
          _divider(),
          _stat('36', '群组'),
          _divider(),
          _stat('2.4k', '消息'),
          _divider(),
          _stat('15', '收藏'),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: AppTokens.bodyStrong.copyWith(fontSize: 17)),
          const SizedBox(height: 2),
          Text(label, style: AppTokens.caption.copyWith(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 28, color: AppTokens.divider);
  }

  Widget _buildSection(BuildContext context) {
    return _card([
      _tile(Icons.person_outline_rounded, '个人信息', subtitle: '修改头像、昵称、签名'),
      _tileDivider(),
      _tile(Icons.shield_outlined, '账号与安全', subtitle: '密码、设备管理、两步验证'),
      _tileDivider(),
      _tile(Icons.notifications_none_rounded, '通知设置', subtitle: '消息提醒、免打扰'),
      _tileDivider(),
      _tile(Icons.cloud_outlined, '数据与存储', subtitle: '缓存管理、自动下载'),
    ]);
  }

  Widget _buildPreferencesSection(BuildContext context) {
    return _card([
      _tile(Icons.palette_outlined, '外观', trailing: _themeChip()),
      _tileDivider(),
      _tile(Icons.language_rounded, '语言', trailing: _valueText('简体中文')),
      _tileDivider(),
      _tile(Icons.text_fields_rounded, '字体大小', trailing: _valueText('标准')),
    ]);
  }

  Widget _buildDangerSection(BuildContext context) {
    return _card([
      _tile(Icons.help_outline_rounded, '帮助与反馈'),
      _tileDivider(),
      _tile(Icons.info_outline_rounded, '关于 99chat', trailing: _valueText('v1.0.0')),
      _tileDivider(),
      _tile(Icons.logout_rounded, '退出登录', color: AppTokens.danger),
    ]);
  }

  Widget _card(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTokens.surface,
        borderRadius: BorderRadius.circular(AppTokens.rLg),
        border: Border.all(color: AppTokens.divider, width: 1),
      ),
      child: Column(children: children),
    );
  }

  Widget _tile(IconData icon, String title, {String? subtitle, Widget? trailing, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color != null
                  ? color.withOpacity(0.08)
                  : AppTokens.brand50,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 18, color: color ?? AppTokens.brand500),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTokens.body.copyWith(
                    fontWeight: FontWeight.w500,
                    color: color ?? AppTokens.ink800,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle, style: AppTokens.caption.copyWith(fontSize: 12)),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing,
          if (color == null)
            const Icon(Icons.chevron_right_rounded, size: 18, color: AppTokens.ink300),
        ],
      ),
    );
  }

  Widget _tileDivider() {
    return const Padding(
      padding: EdgeInsets.only(left: 64),
      child: Divider(height: 1, color: AppTokens.divider),
    );
  }

  Widget _themeChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: AppTokens.ink25,
        borderRadius: BorderRadius.circular(AppTokens.rPill),
        border: Border.all(color: AppTokens.ink100, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.light_mode_outlined, size: 13, color: AppTokens.ink500),
          const SizedBox(width: 4),
          Text('浅色', style: AppTokens.caption.copyWith(fontSize: 12, color: AppTokens.ink600)),
        ],
      ),
    );
  }

  Widget _valueText(String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Text(text, style: AppTokens.caption.copyWith(fontSize: 13, color: AppTokens.ink400)),
    );
  }
}
