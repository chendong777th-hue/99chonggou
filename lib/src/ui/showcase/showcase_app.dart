import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_theme.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';
import 'package:tencent_cloud_chat_demo/src/ui/showcase/contacts_demo_page.dart';
import 'package:tencent_cloud_chat_demo/src/ui/showcase/conversation_list_demo_page.dart';
import 'package:tencent_cloud_chat_demo/src/ui/showcase/profile_demo_page.dart';

/// 高保真 UI 走查入口 — 独立于业务，可直接 runApp 预览。
class ShowcaseApp extends StatelessWidget {
  const ShowcaseApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '99chat · Design Showcase',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      home: const ShowcaseHomePage(),
    );
  }
}

class ShowcaseHomePage extends StatefulWidget {
  const ShowcaseHomePage({Key? key}) : super(key: key);

  @override
  State<ShowcaseHomePage> createState() => _ShowcaseHomePageState();
}

class _ShowcaseHomePageState extends State<ShowcaseHomePage> {
  int _index = 0;

  static const _pages = [
    ConversationListDemoPage(),
    ContactsDemoPage(),
    ProfileDemoPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: _NavBar(
        index: _index,
        onChanged: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const _NavBar({required this.index, required this.onChanged});

  static const _items = [
    (Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, '消息'),
    (Icons.contacts_outlined, Icons.contacts_rounded, '通讯录'),
    (Icons.person_outline_rounded, Icons.person_rounded, '我的'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: AppTokens.surface,
        border: Border(top: BorderSide(color: AppTokens.divider, width: 1)),
      ),
      padding: EdgeInsets.only(top: 8, bottom: 6 + bottom),
      child: Row(
        children: List.generate(_items.length, (i) {
          final selected = i == index;
          final item = _items[i];
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(i),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? AppTokens.brand50 : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppTokens.rPill),
                    ),
                    child: Icon(
                      selected ? item.$2 : item.$1,
                      size: 22,
                      color: selected ? AppTokens.brand500 : AppTokens.ink400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.$3,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? AppTokens.brand500 : AppTokens.ink400,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
