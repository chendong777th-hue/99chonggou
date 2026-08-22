import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_local_perf_flags.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/my_group_az_skeleton.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/az_list_view.dart';

/// 「我的群聊」专用：轻量 AZ 骨架 + revision 缓存，不经 Friendship 全量灌表。
class MyGroupListController extends ChangeNotifier {
  MyGroupListController._();

  static final MyGroupListController instance = MyGroupListController._();

  static const _discussNeedle = 'im_discuss_';

  final GroupLocalStore _store = GroupLocalStore.instance;

  List<MyGroupAzSkeleton> _skeletons = const [];
  List<ISuspensionBeanImpl<MyGroupAzSkeleton>> _azShowList = const [];
  int _totalCount = 0;
  int _boundRevision = -1;
  String _boundOwner = '';
  String _keyword = '';
  bool _loading = false;
  int _loadGen = 0;

  List<MyGroupAzSkeleton> get skeletons => _skeletons;

  List<ISuspensionBeanImpl<MyGroupAzSkeleton>> get azShowList => _azShowList;

  /// 非搜索：过滤后的群总数；搜索态仍保留该值供「共 N」语义，脚注用 [displayCount]。
  int get totalCount => _totalCount;

  /// 当前列表脚注数字：搜索用结果数，否则用 [totalCount]。
  int get displayCount =>
      _keyword.trim().isEmpty ? _totalCount : _skeletons.length;

  String get keyword => _keyword;

  bool get isLoading => _loading;

  bool get isEmpty => _skeletons.isEmpty;

  void clearSession() {
    _loadGen++;
    _skeletons = const [];
    _azShowList = const [];
    _totalCount = 0;
    _boundRevision = -1;
    _boundOwner = '';
    _keyword = '';
    _loading = false;
    notifyListeners();
  }

  /// 清搜索关键词；默认不读库。离页用 [reload]=false，避免对已销毁页无意义刷新。
  /// 若曾有关键词，会作废 revision 复用，防止空 keyword + 过滤骨架被当成完整列表。
  Future<void> clearSearch({bool reload = false}) async {
    final hadKeyword = _keyword.trim().isNotEmpty;
    if (!hadKeyword && !reload) {
      return;
    }
    _keyword = '';
    if (reload) {
      final owner = _store.currentOwnerUserId();
      await _reload(owner: owner, keyword: '');
      return;
    }
    if (hadKeyword) {
      _boundRevision = -1;
    }
  }

  /// 进页：revision/owner/keyword 未变且已有骨架则跳过读库。
  Future<void> ensureLoaded({bool force = false}) async {
    if (!GroupLocalPerfFlags.myGroupListAzOptimizeEnabled) {
      return;
    }
    final owner = _store.currentOwnerUserId();
    final revision = _store.listDataRevision;
    final canReuse = GroupLocalPerfFlags.myGroupListMemoryReuseEnabled &&
        !force &&
        owner.isNotEmpty &&
        owner == _boundOwner &&
        revision == _boundRevision &&
        _keyword.trim().isEmpty &&
        _azShowList.isNotEmpty;
    if (canReuse) {
      return;
    }
    await _reload(owner: owner, keyword: _keyword);
  }

  Future<void> setSearchKeyword(String keyword) async {
    final next = keyword.trim();
    if (next == _keyword.trim()) {
      return;
    }
    _keyword = next;
    final owner = _store.currentOwnerUserId();
    await _reload(owner: owner, keyword: _keyword);
  }

  Future<void> _reload({
    required String owner,
    required String keyword,
  }) async {
    final gen = ++_loadGen;
    _loading = true;
    notifyListeners();

    try {
      final needle = keyword.trim();
      // 搜索与非搜索均全量读骨架，不再截断 200。
      final raw = await _store.readAzSkeleton(
        ownerUserId: owner,
        keyword: needle,
        limit: null,
      );
      if (gen != _loadGen) {
        return;
      }

      final filtered = raw
          .where((e) => !_isDiscussGroup(e.groupId))
          .toList(growable: false);
      _skeletons = filtered;
      _azShowList = _buildAzBeans(filtered);
      if (needle.isEmpty) {
        _totalCount = filtered.length;
      } else if (_totalCount <= 0) {
        // 首次直接进搜索：补一次总数。
        final counted = await _store.countGroups(ownerUserId: owner);
        if (gen != _loadGen) {
          return;
        }
        _totalCount = counted;
      }
      _boundOwner = owner;
      _boundRevision = _store.listDataRevision;

      // 缺 tag 老数据后台写回；当前帧已用临时 tag，无需立刻再刷 UI。
      if (needle.isEmpty && owner.isNotEmpty) {
        unawaited(_store.ensureIndexTagsBackfilled(ownerUserId: owner));
      }
    } finally {
      if (gen == _loadGen) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  static bool _isDiscussGroup(String groupId) {
    return groupId.contains(_discussNeedle);
  }

  static List<ISuspensionBeanImpl<MyGroupAzSkeleton>> _buildAzBeans(
    List<MyGroupAzSkeleton> skeletons,
  ) {
    final out = <ISuspensionBeanImpl<MyGroupAzSkeleton>>[];
    for (final item in skeletons) {
      final tag = item.indexTag.trim().isNotEmpty
          ? item.indexTag
          : MyGroupAzSkeleton.computeIndexTag(
              groupName: item.groupName,
              groupId: item.groupId,
            );
      out.add(
        ISuspensionBeanImpl<MyGroupAzSkeleton>(
          memberInfo: item,
          tagIndex: tag,
        ),
      );
    }
    return out;
  }
}
