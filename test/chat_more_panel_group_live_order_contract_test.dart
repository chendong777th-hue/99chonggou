import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('group live icon is tinted and occupies the eighth group slot', () {
    final chatSource = File('lib/src/chat.dart').readAsStringSync();
    final panelSource = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKitTextField/tim_uikit_more_panel.dart',
    ).readAsStringSync();

    expect(
      chatSource.contains(
        "MorePanelStyles.pngIcon(theme, 'assets/chat_more/group_live.png')",
      ),
      isTrue,
    );
    expect(panelSource.contains('color: iconColor(theme)'), isTrue);
    expect(
      panelSource.contains('colorBlendMode: BlendMode.srcIn'),
      isTrue,
    );

    final configStart =
        chatSource.indexOf('MorePanelConfig _buildMorePanelConfig');
    expect(configStart, greaterThanOrEqualTo(0));
    final configSource = chatSource.substring(configStart);
    final contact =
        configSource.indexOf('_buildContactCardMorePanelItems(theme)');
    final favorite =
        configSource.indexOf('_buildFavoriteMorePanelItems(theme)');
    final wallet = configSource.indexOf('_buildWalletMorePanelItems(theme)');
    final groupLive = configSource.indexOf('...groupLiveItems,');
    expect(contact, greaterThanOrEqualTo(0));
    expect(favorite, greaterThan(contact));
    expect(wallet, greaterThan(favorite));
    expect(groupLive, greaterThan(wallet));
  });

  test('creating group live is not gated by local owner/admin role', () {
    final chatSource = File('lib/src/chat.dart').readAsStringSync();
    final authorizeSource = File(
      'lib/src/pages/group_live/group_live_authorize_page.dart',
    ).readAsStringSync();

    final menuStart =
        chatSource.indexOf('List<MorePanelItem> _buildGroupLiveMorePanelItems');
    expect(menuStart, greaterThanOrEqualTo(0));
    final menuEnd = chatSource.indexOf('Future<void> _openGroupLiveSchedule', menuStart);
    expect(menuEnd, greaterThan(menuStart));
    final menuSource = chatSource.substring(menuStart, menuEnd);
    expect(menuSource.contains('isManagerRole'), isFalse);
    expect(menuSource.contains('_groupLiveMenuVisible'), isFalse);

    expect(chatSource.contains('_resolveGroupLiveMenuVisibleFromLocal'), isFalse);
    expect(authorizeSource.contains('_canManageGroupLive'), isFalse);
    expect(
      authorizeSource.contains('notGroupAdminForManagement()'),
      isFalse,
    );
  });
}
