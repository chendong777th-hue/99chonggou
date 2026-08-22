/// 会话页「+」菜单等挂到根 Overlay 的条目，路由切换时需主动移除以免挡点击。
class SearchEntryOverlay {
  SearchEntryOverlay._();

  static final Set<void Function()> _dismissCallbacks = {};

  static void register(void Function() dismiss) {
    _dismissCallbacks.add(dismiss);
  }

  static void unregister(void Function() dismiss) {
    _dismissCallbacks.remove(dismiss);
  }

  static void dismissAll() {
    final copy = List<void Function()>.from(_dismissCallbacks);
    for (final cb in copy) {
      try {
        cb();
      } catch (_) {}
    }
  }
}
