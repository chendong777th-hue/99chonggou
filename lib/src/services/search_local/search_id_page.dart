/// 本地搜索 ID 分页结果（Phase 3：先 ID，再 hydrate Entity）。
class SearchIdPage {
  const SearchIdPage({
    required this.ids,
    this.nextCursor,
    required this.hasMore,
  });

  final List<String> ids;
  final String? nextCursor;
  final bool hasMore;

  static const empty = SearchIdPage(
    ids: <String>[],
    nextCursor: null,
    hasMore: false,
  );
}
