import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_responsive.dart';
import 'package:tencent_cloud_chat_demo/src/ui/components/app_search_bar.dart';
import 'package:tencent_cloud_chat_demo/src/ui/components/conversation_tile.dart';
import 'package:tencent_cloud_chat_demo/src/ui/showcase/chat_room_demo_page.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';

class ConversationListDemoPage extends StatelessWidget {
  const ConversationListDemoPage({Key? key}) : super(key: key);

  static final _items = <Map<String, dynamic>>[
    {
      'name': 'Product · Design Sync',
      'msg': 'Sarah: 已经把最新的 design tokens 同步到 figma 了',
      'time': '15:42',
      'unread': 3,
      'pinned': true,
      'online': true,
    },
    {
      'name': 'Linus Wang',
      'msg': '👋 周会改到周三下午三点可以吗？',
      'time': '14:08',
      'unread': 1,
      'online': true,
    },
    {
      'name': 'Engineering — Backend',
      'msg': 'Tom: 部署完成，CI 全绿',
      'time': '13:50',
      'unread': 12,
    },
    {
      'name': 'Stripe Notifications',
      'msg': '本月账单已生成，共 \$1,248.50',
      'time': '12:31',
    },
    {
      'name': 'Emily Chen',
      'msg': '[图片]',
      'time': '11:20',
      'online': true,
    },
    {
      'name': '99chat 团队',
      'msg': '欢迎加入 99chat！开始你的第一次对话吧。',
      'time': '昨天',
    },
    {
      'name': 'Marcus · CEO',
      'msg': '好的，我下周回到 SF 后我们再细聊',
      'time': '昨天',
    },
    {
      'name': 'Anna Nguyen',
      'msg': '已收到合同，今天会签好回传',
      'time': '周三',
    },
    {
      'name': 'Design Critique',
      'msg': 'Helen: 这个版本登录态的处理方式我蛮喜欢的',
      'time': '5月15日',
    },
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
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: AppSearchBar(
                hint: '搜索消息、联系人或频道',
                readOnly: true,
                onTap: () {},
              ),
            ),
          ),
          SliverToBoxAdapter(child: _StatusStrip()),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final m = _items[i];
                return Column(
                  children: [
                    ConversationTile(
                      name: m['name'] as String,
                      lastMessage: m['msg'] as String,
                      time: m['time'] as String,
                      unreadCount: (m['unread'] ?? 0) as int,
                      isPinned: (m['pinned'] ?? false) as bool,
                      isOnline: (m['online'] ?? false) as bool,
                      onTap: () => Navigator.push(
                        context,
                        AppMaterialPageRoute(
                          builder: (_) => ChatRoomDemoPage(
                            name: m['name'] as String,
                            online: (m['online'] ?? false) as bool,
                          ),
                        ),
                      ),
                    ),
                    if (i < _items.length - 1)
                      Padding(
                        padding: EdgeInsets.only(
                          left: context.isDesktopFormFactor ? 68 : 72,
                        ),
                        child: Divider(height: 1, color: AppTokens.divider),
                      ),
                  ],
                );
              },
              childCount: _items.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
      floatingActionButton: _Fab(),
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
      title: Row(
        children: [
          Text('消息', style: AppTokens.title.copyWith(fontSize: 22)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTokens.brand50,
              borderRadius: BorderRadius.circular(AppTokens.rPill),
            ),
            child: Text(
              '16',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTokens.brand500,
              ),
            ),
          ),
        ],
      ),
      actions: [
        _circleIcon(Icons.search_rounded),
        const SizedBox(width: 8),
        _circleIcon(Icons.add_circle_outline_rounded),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _circleIcon(IconData icon) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppTokens.ink25,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: AppTokens.ink700),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  static const _stories = [
    ('Sarah', true),
    ('Linus', true),
    ('Tom', false),
    ('Emily', true),
    ('Marcus', false),
    ('Anna', false),
    ('Helen', true),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemBuilder: (_, i) {
          final s = _stories[i];
          return Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: s.$2
                        ? [AppTokens.brand400, AppTokens.brand500]
                        : [AppTokens.ink100, AppTokens.ink200],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.all(2),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  padding: const EdgeInsets.all(2),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTokens.brand50,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      s.$1.substring(0, 1),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTokens.brand500,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                s.$1,
                style: AppTokens.caption.copyWith(fontSize: 11),
              ),
            ],
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemCount: _stories.length,
      ),
    );
  }
}

class _Fab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: AppTokens.shadowBrand,
      ),
      child: FloatingActionButton(
        onPressed: () {},
        backgroundColor: AppTokens.brand500,
        elevation: 0,
        shape: const CircleBorder(),
        child: const Icon(Icons.edit_rounded, color: Colors.white, size: 22),
      ),
    );
  }
}
