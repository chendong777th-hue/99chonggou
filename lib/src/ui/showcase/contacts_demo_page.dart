import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';
import 'package:tencent_cloud_chat_demo/src/ui/components/app_avatar.dart';
import 'package:tencent_cloud_chat_demo/src/ui/components/app_search_bar.dart';

class ContactsDemoPage extends StatelessWidget {
  const ContactsDemoPage({Key? key}) : super(key: key);

  static const _quickActions = [
    (Icons.person_add_alt_outlined, '新的朋友', AppTokens.brand500),
    (Icons.group_add_outlined, '加入群聊', AppTokens.brand500),
    (Icons.bookmark_border_rounded, '我的收藏', AppTokens.brand500),
    (Icons.tag_rounded, '频道', AppTokens.brand500),
  ];

  static const _contacts = [
    ('A', [
      ('Alex Chen', '产品设计师 · 99chat', true),
      ('Anna Nguyen', 'Customer Success Lead', false),
    ]),
    ('E', [
      ('Emily Chen', 'Brand Designer', true),
    ]),
    ('H', [
      ('Helen Park', 'iOS Engineer', false),
    ]),
    ('L', [
      ('Linus Wang', 'Engineering Manager', true),
    ]),
    ('M', [
      ('Marcus Reed', 'CEO · 99chat', false),
    ]),
    ('S', [
      ('Sarah Kim', 'Head of Design', true),
      ('Sophia Liu', 'Product Marketing', false),
    ]),
    ('T', [
      ('Tom Müller', 'Backend Engineer', false),
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTokens.surface,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: AppSearchBar(hint: '搜索联系人', readOnly: true, onTap: () {}),
            ),
          ),
          SliverToBoxAdapter(child: _buildQuickActions()),
          ..._contacts.map((g) => _buildContactGroup(g.$1, g.$2)).toList(),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
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
      title: Text('通讯录', style: AppTokens.title.copyWith(fontSize: 22)),
      actions: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTokens.ink25,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.person_add_outlined, size: 18, color: AppTokens.ink700),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTokens.surface,
        borderRadius: BorderRadius.circular(AppTokens.rLg),
        border: Border.all(color: AppTokens.divider, width: 1),
      ),
      child: Row(
        children: _quickActions
            .map((a) => Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTokens.brand50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(a.$1, size: 22, color: a.$3),
                      ),
                      const SizedBox(height: 8),
                      Text(a.$2, style: AppTokens.caption.copyWith(fontSize: 12)),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildContactGroup(String letter, List<(String, String, bool)> items) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Text(
              letter,
              style: AppTokens.label.copyWith(fontSize: 12, color: AppTokens.ink400),
            ),
          ),
          ...items.map((c) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    AppAvatar(name: c.$1, size: 40, showOnline: c.$3),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.$1, style: AppTokens.bodyStrong.copyWith(fontSize: 14)),
                          const SizedBox(height: 2),
                          Text(c.$2, style: AppTokens.caption.copyWith(fontSize: 12)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 18, color: AppTokens.ink300),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
