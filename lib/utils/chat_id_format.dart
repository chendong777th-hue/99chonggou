import 'package:tencent_cloud_chat_uikit/ui/utils/c2c_peer_id.dart';

/// 99 号 UID（小写+数字）与社群短 ID（含大写字母）的展示、复制与搜索规范化。
class ChatIdFormat {
  ChatIdFormat._();

  /// 腾讯云 IM「默认分配」社群完整 ID 前缀（`@TGS#_@TGS#{short}`）。
  static const String communityFullPrefix = '@TGS#_@TGS#';

  /// 腾讯云 IM「自定义」社群前缀（控制台常见 `@TGS#_mc…`）。
  static const String customCommunityPrefix = '@TGS#_';

  /// 是否为自定义社群 ID：`@TGS#_…` 且不是 `@TGS#_@TGS#…`。
  ///
  /// 国内控制台「群组管理」里 Community 多为此形态（如 `@TGS#_mc2SX4NMM62CZ`）。
  static bool isCustomCommunityId(String? input) {
    final id = input?.trim() ?? '';
    if (id.isEmpty) {
      return false;
    }
    final upper = id.toUpperCase();
    return upper.startsWith('@TGS#_') && !upper.startsWith('@TGS#_@TGS#');
  }

  /// IM 透传的「单段」社群形态：`@TGS#{字母短码}`（如 `@TGS#c2SX4NMM62CZ`）。
  ///
  /// 后端原样转发 IM 群 ID，可能是 `@TGS#_@TGS#…` / `@TGS#_mc…` / `@TGS#c…` 等，
  /// 客户端必须原样保留，不得改写成另一种前缀。
  /// `@TGS#{数字…}` 仍是公开群，不在此列。
  static bool isSingleTgsCommunityId(String? input) {
    var id = input?.trim() ?? '';
    if (id.isEmpty) {
      return false;
    }
    if (id.length > 6 && id.toLowerCase().startsWith('group_')) {
      id = id.substring(6);
    }
    id = id.replaceFirst(RegExp(r'^@+'), '@');
    if (!id.startsWith('@')) {
      id = '@$id';
    }
    final upper = id.toUpperCase();
    if (upper.startsWith('@TGS#_') || !upper.startsWith('@TGS#')) {
      return false;
    }
    final short = id.substring('@TGS#'.length);
    return short.isNotEmpty &&
        !short.startsWith('_') &&
        isCommunityShortToken(short) &&
        !_startsWithDigitReg.hasMatch(short);
  }

  /// @Deprecated 旧名；请用 [isSingleTgsCommunityId]。
  static bool isBogusPublicStyleCommunityId(String? input) =>
      isSingleTgsCommunityId(input);

  /// 是否为社群形态群 ID。
  ///
  /// 含：`@TGS#_@TGS#…`、`@TGS#_mc…`、`@TGS#{字母短码}`。
  /// 公开群多为 `@TGS#{数字…}`（`#` 后无 `_` 且以数字开头），不在此列。
  static bool looksLikeCommunityGroupId(String? input) {
    var id = input?.trim() ?? '';
    if (id.isEmpty) {
      return false;
    }
    if (id.length > 6 && id.toLowerCase().startsWith('group_')) {
      id = id.substring(6);
    }
    final upper = id.toUpperCase();
    if (upper.startsWith('@TGS#_') || upper.startsWith('TGS#_')) {
      return true;
    }
    return isSingleTgsCommunityId(id);
  }

  /// 从本地群资料取 IM SDK 群 ID。
  ///
  /// - `@TGS#_@TGS#…`（IM 默认完整社群）→ **保留完整**（禁止剥成短后缀）
  /// - `@TGS#_mc…` → 原样
  /// - 短码 `m2…` → **原样**（迁移群业务真源，禁止加成 `@TGS#_@TGS#…`）
  /// - `mc…` → `@TGS#_mc…`
  static String imGroupIdFromRecord({
    required String groupId,
    String displayAlias = '',
  }) {
    final gid = groupId.trim();
    if (gid.isNotEmpty) {
      return normalizeGroupId(gid);
    }
    final alias = displayAlias.trim();
    if (alias.isNotEmpty) {
      return normalizeGroupId(alias);
    }
    return '';
  }

  /// 自建后端常见自定义段：`mc…`（对应控制台 `@TGS#_mc…`）。
  static bool isCustomCommunityToken(String token) {
    final t = token.trim();
    if (t.isEmpty || t.toUpperCase().contains('TGS#')) {
      return false;
    }
    return t.startsWith('mc') && isCommunityShortToken(t);
  }

  static String display(String? userID) {
    final id = rawUserUid(userID);
    if (id.isEmpty) {
      return '';
    }
    return '@$id';
  }

  /// 社群短 ID 展示：`@cCOZ5MMM62CJ`（从完整 ID 截取后缀）。
  static String displayCommunityShort(String? groupId) {
    final short = communityShortSuffix(groupId);
    if (short == null || short.isEmpty) {
      return '';
    }
    return '@$short';
  }

  /// 群 ID 展示形态（给用户看的，不是 IM SDK 入参）。
  ///
  /// - 短码 `m2…` / 完整社群 `@TGS#_@TGS#m2…` → `@m2…`
  /// - `@@TGS#…` → `@TGS#…`（去掉多余 `@`）
  /// - 其它含 `TGS#` 的后端原文 → 保证单个前导 `@`
  ///
  /// IM SDK 调用仍应使用 [normalizeGroupId] / [canonicalGroupStorageId]。
  static String displayGroupAlias(String? value, {String? groupIdFallback}) {
    for (final source in [value, groupIdFallback]) {
      final label = backendGroupIdLabel(source);
      if (label.isNotEmpty) {
        return label;
      }
    }
    return '';
  }

  /// REST `/group/{id}` 用的群 ID：与后端透传的 IM 原格式对齐。
  ///
  /// 后端不自造格式，原样转发 IM；可能是短码 / `@TGS#_@TGS#…` /
  /// `@TGS#_mc…` / `@TGS#c…`。此处只做轻量清洗（去 `group_`、合并 `@@`），
  /// **禁止**把一种 IM 前缀改写成另一种。多形态重试见 [apiGroupIdCandidates]。
  static String apiGroupId(String? input) {
    final raw = input?.trim() ?? '';
    if (raw.isEmpty) {
      return '';
    }
    final normalized = normalizeGroupId(raw);
    if (normalized.isEmpty) {
      return '';
    }
    return normalized;
  }

  /// REST `/group/{id}` 可依次尝试的群 ID（去重）。
  ///
  /// **原文优先**（后端透传的 IM 原格式），再补其它等价形态兜底。
  /// `@TGS#_mc…`：绝不伪造 `@TGS#_@TGS#mc…`。
  static List<String> apiGroupIdCandidates(String? input) {
    final ordered = <String>[];
    void addRaw(String? value) {
      final text = value?.trim() ?? '';
      if (text.isNotEmpty && !ordered.contains(text)) {
        ordered.add(text);
      }
    }

    final raw = input?.trim() ?? '';
    if (raw.isEmpty) {
      return ordered;
    }

    final normalized = normalizeGroupId(raw);
    // 1) 原文 / 轻量清洗结果优先
    addRaw(normalized);
    addRaw(raw);

    // 控制台自定义社群：只围绕 `@TGS#_mc…` 本身尝试。
    if (isCustomCommunityId(raw) || isCustomCommunityId(normalized)) {
      final suffix = communityShortSuffix(normalized);
      if (suffix != null && suffix.isNotEmpty) {
        addRaw(suffix);
        addRaw('@$suffix');
        addRaw('$customCommunityPrefix$suffix');
      }
      return ordered;
    }

    final short = communityShortSuffix(normalized) ?? groupEquivalenceToken(raw);
    if (short != null &&
        short.isNotEmpty &&
        !short.toUpperCase().contains('TGS#')) {
      addRaw(short);
      addRaw('@$short');
      if (isCustomCommunityToken(short)) {
        addRaw('$customCommunityPrefix$short');
      } else {
        // 兜底：其它 IM 形态（不覆盖原文优先级）
        addRaw('@TGS#$short');
        addRaw('$communityFullPrefix$short');
      }
    }

    addRaw(canonicalGroupStorageId(raw));
    return ordered;
  }

  /// IM SDK 群 ID 候选。
  ///
  /// - 输入已是 `@TGS#_@TGS#…` → **完整优先**（新建 IM 自动社群；短码兜底兼容迁移误加成）
  /// - 输入为裸短码 → **短码优先**（迁移群真源），完整形态最后兜底
  /// - `@TGS#_mc…` → 原样优先，禁止伪造 `@TGS#_@TGS#mc…`
  static List<String> imGroupIdCandidates(String? input) {
    final ordered = <String>[];
    void add(String? value) {
      final text = value?.trim() ?? '';
      if (text.isEmpty || ordered.contains(text)) {
        return;
      }
      ordered.add(text);
    }

    final raw = input?.trim() ?? '';
    if (raw.isEmpty) {
      return ordered;
    }
    var bare = raw;
    if (bare.length > 6 && bare.toLowerCase().startsWith('group_')) {
      bare = bare.substring(6);
    }
    final source = bare.isNotEmpty ? bare : raw;
    final api = apiGroupId(source);
    final normalized = normalizeGroupId(source);
    final upper = source.toUpperCase();
    final inputIsFullCommunity = upper.startsWith('@TGS#_@TGS#') ||
        upper.startsWith('TGS#_@TGS#');

    if (isCustomCommunityId(source) || isCustomCommunityId(normalized)) {
      add(normalized);
      add(source);
      add(raw);
      if (api.isNotEmpty) {
        add(api);
      }
      final suffix = communityShortSuffix(normalized);
      if (suffix != null && suffix.isNotEmpty) {
        add(suffix);
        add('$customCommunityPrefix$suffix');
      }
      return ordered;
    }

    if (inputIsFullCommunity) {
      // IM 双段完整社群：原文优先，短码 / 单段形态兜底
      add(normalized);
      add(source);
      add(raw);
      final short = communityShortSuffix(normalized);
      if (short != null &&
          short.isNotEmpty &&
          isCommunityShortToken(short) &&
          !isCustomCommunityToken(short)) {
        add(short);
        add('@TGS#$short');
      }
      return ordered;
    }

    if (isSingleTgsCommunityId(normalized) || isSingleTgsCommunityId(source)) {
      // IM 单段社群 `@TGS#c…`：原文优先，禁止改写成主形态
      add(normalized);
      add(source);
      add(raw);
      final short = communityShortSuffix(normalized);
      if (short != null &&
          short.isNotEmpty &&
          isCommunityShortToken(short) &&
          !isCustomCommunityToken(short)) {
        add(short);
        add('$communityFullPrefix$short');
      }
      return ordered;
    }

    // 迁移短码 / 其它：短码真源优先，完整形态兜底
    if (api.isNotEmpty && !api.toUpperCase().contains('TGS#')) {
      add(api);
    }
    add(normalized);
    add(source);
    add(raw);
    if (api.isNotEmpty) {
      add(api);
    }
    if (api.isNotEmpty && isCustomCommunityToken(api)) {
      add('$customCommunityPrefix$api');
    }
    if (api.isNotEmpty &&
        isCommunityShortToken(api) &&
        !isCustomCommunityToken(api)) {
      add('@TGS#$api');
      add('$communityFullPrefix$api');
    }
    return ordered;
  }

  /// 将任意群 ID 形态收成页面展示形态。
  static String backendGroupIdLabel(String? input) {
    final raw = input?.trim() ?? '';
    if (raw.isEmpty) {
      return '';
    }

    // 完整社群 `@TGS#_@TGS#m2…` → `@m2…`
    final upper = raw.toUpperCase();
    const fullPrefix = '@TGS#_@TGS#';
    if (upper.startsWith(fullPrefix)) {
      final short = raw.substring(fullPrefix.length).trim();
      if (short.isNotEmpty) {
        final token = short.startsWith('@') ? short.substring(1) : short;
        return '@$token';
      }
    }

    // `@TGS#c2…` / `@@TGS#c2…` → 展示 `@c2…`（IM 单段社群；界面用短别名）
    if (isSingleTgsCommunityId(raw)) {
      final normalizedAt = raw.replaceFirst(RegExp(r'^@+'), '@');
      final withAt =
          normalizedAt.startsWith('@') ? normalizedAt : '@$normalizedAt';
      final short = withAt.substring('@TGS#'.length);
      if (short.isNotEmpty) {
        return '@$short';
      }
    }

    // `@@TGS#…` / `@@@…` → 只保留一个前导 `@`
    var text = raw.replaceFirst(RegExp(r'^@+'), '@');
    if (text == '@') {
      return '';
    }

    if (text.toUpperCase().contains('TGS#')) {
      if (!text.startsWith('@')) {
        text = '@$text';
      }
      return text;
    }

    final token = text.startsWith('@') ? text.substring(1) : text;
    if (isCommunityShortToken(token)) {
      return '@$token';
    }
    return text;
  }

  /// 用户 UID（去掉 `@`）；社群请用 [normalizeGroupId]。
  static String raw(String? userID) => rawUserUid(userID);

  static String rawUserUid(String? input) {
    var trimmed = input?.trim() ?? '';
    if (trimmed.isEmpty) {
      return '';
    }
    if (trimmed.toLowerCase().startsWith('c2c_')) {
      trimmed = trimmed.substring(4).trim();
      if (trimmed.isEmpty) {
        return '';
      }
    }
    if (isIMGroupOrCommunityId(trimmed)) {
      return '';
    }
    if (trimmed.startsWith('@')) {
      return trimmed.substring(1);
    }
    return trimmed;
  }

  /// C2C 比对用：与 UIKit [C2cPeerId.normalize] 同一实现。
  static String canonicalC2cUserId(String? input) {
    return C2cPeerId.normalize(input);
  }

  /// 消息正文中可点击的 ID（完整社群/公开群优先，再 UID / 短码）。
  ///
  /// 与 UIKit [LinkUtils.chatIdMentionReg] 保持一致：完整社群
  /// `@TGS#_@TGS#…` 中间含 `@`，必须整段匹配。
  static final RegExp chatIdMentionInTextReg = RegExp(
    r'(?<![A-Za-z0-9.])@(?:'
    r'TGS#_@TGS#[A-Za-z0-9_]+'
    r'|TGS#[A-Za-z0-9_]+'
    r'|[a-z0-9_]{2,32}'
    r'|[A-Za-z0-9_]*[A-Z][A-Za-z0-9_]{0,31}'
    r')(?![A-Za-z0-9_#])',
    caseSensitive: false,
  );

  /// 群聊 @成员昵称：可含中文；后接空格、标点或文本结尾。
  static final RegExp groupAtMentionInTextReg = RegExp(
    r'(?<![A-Za-z0-9.])@([^\s@]+)'
    r'(?=\s|$|[，,。！？!?；;：:\.）\)】\]])',
  );

  static bool isChatIdMentionToken(String token) {
    final trimmed = token.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    if (isIMGroupOrCommunityId(trimmed)) {
      return true;
    }
    final t = trimmed.startsWith('@') ? trimmed.substring(1) : trimmed;
    return isUserUidToken(t) || isCommunityShortToken(t);
  }

  static final RegExp _userUidTokenReg = RegExp(r'^[a-z0-9_]+$');
  static final RegExp _communityShortAlnumReg = RegExp(r'^[A-Za-z0-9_]+$');
  static final RegExp _hasUpperCaseReg = RegExp(r'[A-Z]');
  static final RegExp _startsWithDigitReg = RegExp(r'^\d');

  /// 用户 UID：仅小写英文字母、数字、下划线。
  static bool isUserUidToken(String token) {
    final t = token.trim();
    if (t.isEmpty) {
      return false;
    }
    return _userUidTokenReg.hasMatch(t);
  }

  /// 社群短码：字母数字且含大写字母（与用户 UID 区分）。
  static bool isCommunityShortToken(String token) {
    final t = token.trim();
    if (t.isEmpty || t.toUpperCase().contains('TGS#')) {
      return false;
    }
    if (!_communityShortAlnumReg.hasMatch(t)) {
      return false;
    }
    return _hasUpperCaseReg.hasMatch(t);
  }

  /// 完整社群 ID 或 `@短码` / `短码`。
  static bool isIMGroupOrCommunityId(String? input) {
    final id = input?.trim() ?? '';
    if (id.isEmpty) {
      return false;
    }
    if (id.toUpperCase().contains('TGS#')) {
      return true;
    }
    final token = id.startsWith('@') ? id.substring(1) : id;
    return isCommunityShortToken(token);
  }

  /// 短码 → IM 可用形态。
  ///
  /// - `mc…` → `@TGS#_mc…`
  /// - 其它业务短码（如 `m2MUSSKN5C3`）→ **原样**（禁止加成 `@TGS#_@TGS#…`）
  static String communityFullIdFromShort(String shortSuffix) {
    final s = shortSuffix.trim();
    if (s.isEmpty) {
      return '';
    }
    if (s.toUpperCase().contains('TGS#')) {
      return normalizeGroupId(s);
    }
    if (isCustomCommunityToken(s)) {
      return '$customCommunityPrefix$s';
    }
    // 自建后端群真源就是短码本身（设备日志已证实）。
    return s;
  }

  static String? communityShortSuffix(String? input) {
    final full = normalizeGroupId(input);
    if (full.isEmpty) {
      return null;
    }
    if (isCommunityShortToken(full)) {
      return full;
    }
    if (full.startsWith(communityFullPrefix)) {
      return full.substring(communityFullPrefix.length);
    }
    // 自定义社群 `@TGS#_mc…` → 后缀 `mc…`（不要返回 `_mc…`）
    if (isCustomCommunityId(full)) {
      return full.substring(customCommunityPrefix.length);
    }
    if (full.toUpperCase().contains('TGS#') && full.startsWith('@')) {
      final hash = full.indexOf('#');
      if (hash >= 0 && hash + 1 < full.length) {
        return full.substring(hash + 1);
      }
    }
    return null;
  }

  /// 规范为 IM SDK 可用的群 ID（轻量清洗，不改写 IM 前缀族）。
  ///
  /// 后端透传 IM 原格式，可能是多种：
  /// - `@TGS#_@TGS#{token}` → 原样
  /// - `@TGS#_mc…` → 原样
  /// - `@TGS#{字母短码}` → 原样（IM 可能返回的单段形态）
  /// - 短码 `m2…` → 原样；`mc…` → `@TGS#_mc…`
  /// - 仅清洗：去 `group_`、合并 `@@`、补前导 `@`
  /// - 误加成 `@TGS#_@TGS#_mc…` → 还原 `@TGS#_mc…`
  ///
  /// 展示短别名请用 [displayGroupAlias]；跨形态重试用 candidates。
  static String normalizeGroupId(String? input) {
    var id = input?.trim() ?? '';
    if (id.isEmpty) {
      return id;
    }
    // 会话 ID 形态 `group_@TGS#_…` 不能直接喂给 IM SDK。
    if (id.length > 6 && id.toLowerCase().startsWith('group_')) {
      id = id.substring(6);
    }
    // `@@TGS#…` → `@TGS#…` 再继续判型
    if (id.startsWith('@@')) {
      id = id.replaceFirst(RegExp(r'^@+'), '@');
    }
    if (id.toUpperCase().contains('TGS#')) {
      if (!id.startsWith('@')) {
        id = '@$id';
      }
      final upper = id.toUpperCase();
      // `@TGS#_@TGS#…`：仅还原误加成的 `_mc…`，其余原样保留。
      if (upper.startsWith('@TGS#_@TGS#')) {
        final nested = id.substring(communityFullPrefix.length);
        if (nested.startsWith('_') &&
            isCustomCommunityToken(nested.substring(1))) {
          return '$customCommunityPrefix${nested.substring(1)}';
        }
        final short = nested.startsWith('@') ? nested.substring(1) : nested;
        if (isCustomCommunityToken(short)) {
          return '$customCommunityPrefix$short';
        }
        if (short.isEmpty) {
          return id;
        }
        return '$communityFullPrefix$short';
      }
      // `@TGS#_mc…` / `@TGS#{字母短码}` / `@TGS#{数字公开群}`：一律原样。
      return id;
    }
    final token = id.startsWith('@') ? id.substring(1) : id;
    if (isCommunityShortToken(token)) {
      if (_startsWithDigitReg.hasMatch(token)) {
        return '@TGS#$token';
      }
      // `mc…` → `@TGS#_mc…`；其它短码（m2…）保持原文。
      return communityFullIdFromShort(token);
    }
    return id;
  }

  static String? publicGroupFullIdFromShort(String shortSuffix) {
    final token = shortSuffix.trim();
    if (token.isEmpty || !_startsWithDigitReg.hasMatch(token)) {
      return null;
    }
    return '@TGS#$token';
  }

  /// 群本地灰字 / 存储 key 用的 canonical 群 ID。
  static String canonicalGroupStorageId(String? input) {
    var id = input?.trim() ?? '';
    if (id.isEmpty) {
      return id;
    }
    if (id.startsWith('group_')) {
      id = id.substring('group_'.length);
    }
    if (id.toUpperCase().contains('TGS#') ||
        isCommunityShortToken(id.startsWith('@') ? id.substring(1) : id)) {
      return normalizeGroupId(id);
    }
    return id;
  }

  /// 群 ID 等价 token（Public `@TGS#`、裸后缀、社群短码、`group_` 前缀）。
  static String? groupEquivalenceToken(String? input) {
    final canonical = canonicalGroupStorageId(input);
    if (canonical.isEmpty) {
      return null;
    }
    final short = communityShortSuffix(canonical);
    if (short != null && short.isNotEmpty) {
      return short;
    }
    var token = canonical;
    if (token.startsWith('@')) {
      token = token.substring(1);
    }
    if (token.toUpperCase().startsWith('TGS#') && token.length > 4) {
      return token.substring(4);
    }
    return token.isEmpty ? null : token;
  }

  /// 判断两个群 ID 是否指向同一群（兼容短码 / 完整 ID / group_ 前缀）。
  static bool groupIdsEquivalent(String? a, String? b) {
    final left = groupEquivalenceToken(a);
    final right = groupEquivalenceToken(b);
    if (left == null || right == null) {
      return canonicalGroupStorageId(a) == canonicalGroupStorageId(b);
    }
    return left == right;
  }

  /// IM 默认完整社群：`@TGS#_@TGS#{short}`。
  static bool isImDefaultCommunityId(String? input) {
    final id = normalizeGroupId(input);
    if (id.isEmpty) {
      return false;
    }
    return id.toUpperCase().startsWith(communityFullPrefix.toUpperCase());
  }

  /// 裸社群短码（无 `TGS#`）：如 `cJSFLQIM62CX`。易与完整社群会话并存成僵尸行。
  static bool isBareCommunityShortId(String? input) {
    final id = normalizeGroupId(input);
    if (id.isEmpty || id.toUpperCase().contains('TGS#')) {
      return false;
    }
    return isCommunityShortToken(id);
  }

  /// 群 ID 规范优先级：
  /// 业务裸短码 / 自定义 `@TGS#_mc…` > 其它含 TGS# > 误加成 `@TGS#_@TGS#`。
  static int groupIdCanonicalRank(String? input) {
    final raw = (input ?? '').trim();
    final id = normalizeGroupId(input);
    if (id.isEmpty) {
      return -1;
    }
    // 自定义社群控制台形态优先于裸 mc。
    if (isCustomCommunityId(id)) {
      return 4;
    }
    // 迁移群业务真源：裸短码（m2…/c…）高于误加成完整形态。
    if (isBareCommunityShortId(id)) {
      return 3;
    }
    if (id.toUpperCase().contains('TGS#') && !isImDefaultCommunityId(raw)) {
      return 2;
    }
    // 仍停留在 `@TGS#_@TGS#…` 原文时最低（normalize 后通常已剥短）。
    if (isImDefaultCommunityId(raw) || isImDefaultCommunityId(id)) {
      return 1;
    }
    return 0;
  }

  /// 同一群的两套 ID 中选存储/会话主键：优先短码真源，淘汰误加成完整行。
  ///
  /// 不等价时返回 [a]（调用方应保证传入等价对）；空串跳过。
  static String preferredGroupId(String? a, String? b) {
    final left = normalizeGroupId(a);
    final right = normalizeGroupId(b);
    if (left.isEmpty) {
      return right;
    }
    if (right.isEmpty) {
      return left;
    }
    if (!groupIdsEquivalent(left, right)) {
      return left;
    }
    // 用 normalize 前原文参与排序，才能识别「误加成完整」应让位短码。
    final leftRank = groupIdCanonicalRank(a);
    final rightRank = groupIdCanonicalRank(b);
    if (rightRank > leftRank) {
      return right;
    }
    if (leftRank > rightRank) {
      return left;
    }
    return left;
  }

  /// 同一群多套会话 ID 中应删除的 twin（保留 [preferredGroupConversationId]）。
  static List<String> obsoleteGroupConversationTwinIds(
    Iterable<String> conversationIds,
  ) {
    final byToken = <String, List<String>>{};
    for (final raw in conversationIds) {
      final id = raw.trim();
      if (id.isEmpty) {
        continue;
      }
      if (!id.toLowerCase().startsWith('group_') &&
          !isIMGroupOrCommunityId(id)) {
        continue;
      }
      final token = groupEquivalenceToken(id);
      if (token == null || token.isEmpty) {
        continue;
      }
      byToken.putIfAbsent(token, () => <String>[]).add(id);
    }
    final obsolete = <String>[];
    for (final group in byToken.values) {
      if (group.length < 2) {
        continue;
      }
      var keep = group.first;
      for (final other in group.skip(1)) {
        keep = preferredGroupConversationId(keep, other);
      }
      for (final id in group) {
        if (id != keep) {
          obsolete.add(id);
        }
      }
    }
    return obsolete;
  }

  /// 会话 ID（`group_…`）版本的 [preferredGroupId]。
  ///
  /// 非群会话（如 `c2c_…`）原样返回优先侧，绝不加成 `group_`。
  static String preferredGroupConversationId(String? a, String? b) {
    final leftRaw = (a ?? '').trim();
    final rightRaw = (b ?? '').trim();
    final leftIsGroup = leftRaw.toLowerCase().startsWith('group_') ||
        isIMGroupOrCommunityId(leftRaw);
    final rightIsGroup = rightRaw.toLowerCase().startsWith('group_') ||
        isIMGroupOrCommunityId(rightRaw);
    if (!leftIsGroup && !rightIsGroup) {
      return leftRaw.isNotEmpty ? leftRaw : rightRaw;
    }

    String bareOf(String? raw) {
      var s = (raw ?? '').trim();
      if (s.length > 6 && s.toLowerCase().startsWith('group_')) {
        s = s.substring(6);
      }
      return normalizeGroupId(s);
    }

    final preferred = preferredGroupId(bareOf(a), bareOf(b));
    if (preferred.isEmpty) {
      return leftRaw.isNotEmpty ? leftRaw : rightRaw;
    }
    return 'group_$preferred';
  }

  /// 与真源并存时应删除的僵尸会话 ID。
  ///
  /// - 短码真源 / `@TGS#_mc…` → 返回误加成 `group_@TGS#_@TGS#…`
  /// - 仍传入误加成完整形态 → 返回应保留的 `group_{short}` 的「对侧」完整行
  ///   （调用方通常已 normalize；此分支兼容未剥短的原文）
  static String? supersededBareShortConversationId(String? conversationOrGroupId) {
    final raw = (conversationOrGroupId ?? '').trim();
    if (raw.isEmpty) {
      return null;
    }
    var bare = raw;
    if (bare.length > 6 && bare.toLowerCase().startsWith('group_')) {
      bare = bare.substring(6);
    }
    final preferred = normalizeGroupId(bare);
    if (preferred.isEmpty) {
      return null;
    }
    // 自定义社群：清掉裸 mc 短码行。
    if (isCustomCommunityId(preferred)) {
      final short = communityShortSuffix(preferred);
      if (short == null || short.isEmpty || short == preferred) {
        return null;
      }
      return 'group_$short';
    }
    // 业务短码真源：清掉误加成完整行。
    if (isBareCommunityShortId(preferred)) {
      final bogusFull = '$communityFullPrefix$preferred';
      if (bogusFull == preferred) {
        return null;
      }
      return 'group_$bogusFull';
    }
    // 原文仍是误加成完整：对侧僵尸即其自身（由 prune 在「短码已存在」时删）。
    if (isImDefaultCommunityId(bare)) {
      final short = communityShortSuffix(bare);
      if (short == null || short.isEmpty) {
        return null;
      }
      return 'group_$communityFullPrefix$short';
    }
    return null;
  }

  /// 搜索群聊时依次尝试的 ID（只走完整 IM 群 ID，不再尝试短别名）。
  static List<String> groupIdLookupCandidates(String? input) {
    final trimmed = input?.trim() ?? '';
    if (trimmed.isEmpty) {
      return const [];
    }

    final out = <String>[];
    void add(String id) {
      final value = id.trim();
      if (value.isNotEmpty && !out.contains(value)) {
        out.add(value);
      }
    }

    if (trimmed.toUpperCase().contains('TGS#') ||
        isIMGroupOrCommunityId(trimmed)) {
      add(normalizeGroupId(trimmed));
      return out;
    }

    final token = trimmed.startsWith('@') ? trimmed.substring(1) : trimmed;
    if (token.isEmpty) {
      return out;
    }

    // 非社群短码：保留原始 token 尝试（兼容历史 Public 群 ID）。
    add(token);
    add('@$token');
    return out;
  }

  /// 搜索添加 / @ 提及 统一规范化。
  static String normalizeSearchKeyword(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    if (isIMGroupOrCommunityId(trimmed)) {
      return normalizeGroupId(trimmed);
    }
    if (trimmed.startsWith('@')) {
      final token = trimmed.substring(1);
      if (isCommunityShortToken(token)) {
        return normalizeGroupId(trimmed);
      }
      return token;
    }
    if (isCommunityShortToken(trimmed)) {
      return normalizeGroupId(trimmed);
    }
    return trimmed;
  }
}
