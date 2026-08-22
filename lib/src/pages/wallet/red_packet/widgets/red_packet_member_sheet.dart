import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/provider/presence_provider.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/presence_subtitle.dart';
import 'package:tencent_cloud_chat_demo/utils/friend_mutual_utils.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_status.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_status.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_friendship_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/friendShip/friendship_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';

import '../red_packet_member.dart';

class RedPacketMemberSheet extends StatefulWidget {
  final List<RedPacketMember> members;

  const RedPacketMemberSheet({
    super.key,
    required this.members,
  });

  @override
  State<RedPacketMemberSheet> createState() => _RedPacketMemberSheetState();
}

class _RedPacketMemberSheetState extends State<RedPacketMemberSheet> {
  String kw = '';
  final TUIFriendShipViewModel _friendShipModel =
      serviceLocator<TUIFriendShipViewModel>();
  Map<String, V2TimUserStatus> _userStatusById = {};
  PresenceProvider? _presence;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _presence = Provider.of<PresenceProvider>(context, listen: false);
      _presence!.addListener(_onPresenceChanged);
      unawaited(_loadPresenceData());
    });
  }

  @override
  void dispose() {
    _presence?.removeListener(_onPresenceChanged);
    super.dispose();
  }

  void _onPresenceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadPresenceData() async {
    final ids = widget.members
        .map((member) => member.userId.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    if (ids.isEmpty) {
      return;
    }

    final presence = Provider.of<PresenceProvider>(context, listen: false);
    presence.ensure(ids);

    const chunkSize = 500;
    final merged = <String, V2TimUserStatus>{};
    final friendshipServices = serviceLocator<FriendshipServices>();
    for (var i = 0; i < ids.length; i += chunkSize) {
      final chunk = ids.sublist(i, min(i + chunkSize, ids.length));
      try {
        final statuses =
            await friendshipServices.getUserStatus(userIDList: chunk);
        for (final status in statuses) {
          final id = status.userID?.trim() ?? '';
          if (id.isNotEmpty) {
            merged[id] = status;
          }
        }
      } catch (_) {}
    }

    if (!mounted) {
      return;
    }
    setState(() => _userStatusById = merged);
  }

  bool _isImOnline(String userId) {
    return _userStatusById[userId]?.statusType == 1;
  }

  String _presenceLabel(String userId) {
    final presence = Provider.of<PresenceProvider>(context, listen: false);
    return presence.onlineLabelFor(
      userId: userId,
      imOnline: _isImOnline(userId),
      isMutualFriend: friendCanMessage(_friendShipModel, userId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final list = widget.members.where((e) {
      final v = kw.trim().toLowerCase();
      if (v.isEmpty) return true;
      return e.name.toLowerCase().contains(v) ||
          e.userId.toLowerCase().contains(v) ||
          e.qq.toLowerCase().contains(v);
    }).toList();

    return Container(
      height: 780.h,
      padding: EdgeInsets.fromLTRB(28.w, 24.h, 28.w, 22.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18.r)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              width: 76.w,
              height: 6.h,
              decoration: BoxDecoration(
                color: const Color(0xFFD8D8D8),
                borderRadius: BorderRadius.circular(99.r),
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              i18n.t(
                zhHans: '选择接收人',
                zhHant: '選擇接收人',
                en: 'Select Recipient',
                ja: '受取人を選択',
                ko: '수령인 선택',
              ),
              style: TextStyle(
                fontSize: 27.sp,
                color: const Color(0xFF111111),
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 22.h),
            Container(
              height: 58.h,
              padding: EdgeInsets.symmetric(horizontal: 18.w),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F5F7),
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: TextField(
                onChanged: (v) => setState(() => kw = v),
                decoration: InputDecoration(
                  icon: Icon(Icons.search_rounded,
                      size: 24.sp, color: const Color(0xFF8A8A8A)),
                  hintText: i18n.t(
                    zhHans: '搜索成员',
                    zhHant: '搜尋成員',
                    en: 'Search members',
                    ja: 'メンバーを検索',
                    ko: '멤버 검색',
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  hintStyle: TextStyle(
                      fontSize: 18.sp, color: const Color(0xFF999999)),
                ),
              ),
            ),
            SizedBox(height: 18.h),
            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: Text(
                        i18n.t(
                          zhHans: '暂无成员',
                          zhHant: '暫無成員',
                          en: 'No members found',
                          ja: 'メンバーがありません',
                          ko: '멤버가 없습니다',
                        ),
                        style: TextStyle(
                            fontSize: 18.sp, color: const Color(0xFF999999)),
                      ),
                    )
                  : ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1.h, color: const Color(0xFFEDEDED)),
                      itemBuilder: (_, i) {
                        final item = list[i];
                        final imOnline = _isImOnline(item.userId);
                        final presence = Provider.of<PresenceProvider>(
                          context,
                          listen: false,
                        );
                        final presenceLoading = presence.isLastSeenLoading(
                          userId: item.userId,
                          imOnline: imOnline,
                        );
                        final presenceLabel = presenceLoading
                            ? ''
                            : _presenceLabel(item.userId);
                        return InkWell(
                          onTap: () => Navigator.of(context).pop(item),
                          child: Container(
                            height: 88.h,
                            padding: EdgeInsets.symmetric(horizontal: 4.w),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10.r),
                                  child: Container(
                                    width: 54.w,
                                    height: 54.w,
                                    color: const Color(0xFFDDE8F5),
                                    child: item.avatar.isEmpty
                                        ? Icon(Icons.person_rounded,
                                            size: 32.sp,
                                            color: const Color(0xFF74879A))
                                        : Image.network(item.avatar,
                                            fit: BoxFit.cover),
                                  ),
                                ),
                                SizedBox(width: 16.w),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 20.sp,
                                            color: const Color(0xFF222222),
                                            fontWeight: FontWeight.w700),
                                      ),
                                      SizedBox(height: 6.h),
                                      PresenceSubtitle(
                                        label: presenceLabel,
                                        loading: presenceLoading,
                                        imOnline: imOnline,
                                        fontSize: 15,
                                        height: 1.2,
                                        onlineColor: const Color(0xFF1E90FF),
                                        offlineColor: const Color(0xFF999999),
                                        skeletonColor: const Color(0xFF999999),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded,
                                    size: 28.sp,
                                    color: const Color(0xFFBBBBBB)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
