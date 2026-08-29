import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/red_packet/red_packet_controller.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/red_packet/red_packet_member.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/transfer_controller.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/wallet_repository.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/wallet_store.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart';

void main() {
  tearDown(WalletStore.instance.clear);

  test('separates picker remark from public wallet name', () {
    const member = RedPacketMember(
      userId: 'user-1',
      name: '我的备注',
      publicName: '公开昵称',
    );

    expect(member.name, '我的备注');
    expect(member.publicNameOrFallback, '公开昵称');
  });

  test('legacy member falls back to its existing name for wallet payloads', () {
    const member = RedPacketMember(userId: 'user-1', name: '旧昵称');

    expect(member.publicNameOrFallback, '旧昵称');
  });

  test('group mapping displays remark and keeps public nickname', () {
    final member = RedPacketMember.fromGroupMember(
      V2TimGroupMemberFullInfo(
        userID: 'user-1',
        friendRemark: '我的备注',
        nameCard: '群名片',
        nickName: '公开昵称',
      ),
    );

    expect(member.name, '我的备注');
    expect(member.publicNameOrFallback, '公开昵称');
  });

  test('wallet controllers preserve the picker remark display name', () async {
    final repo = _RemarkWalletRepository();
    final redPacket = RedPacketController(repo: repo)
      ..setChatInfo(conversationId: 'remark-red-packet', group: true);
    final transfer = TransferController(repo: repo)
      ..setReceiver(
        userId: '',
        name: '',
        convId: 'remark-transfer',
        group: true,
      );

    final redPacketMembers = await redPacket.loadMembers();
    final transferMembers = await transfer.loadMembers();

    expect(redPacketMembers.single.name, '我的备注');
    expect(redPacketMembers.single.publicNameOrFallback, '公开昵称');
    expect(transferMembers.single.name, '我的备注');
    expect(transferMembers.single.publicNameOrFallback, '公开昵称');

    redPacket.dispose();
    transfer.dispose();
  });
}

class _RemarkWalletRepository extends MockWalletRepository {
  @override
  Future<List<RedPacketMember>> getRedPacketMembers(
    String conversationId,
  ) async {
    return const <RedPacketMember>[
      RedPacketMember(
        userId: 'user-1',
        name: '我的备注',
        publicName: '公开昵称',
      ),
    ];
  }
}
