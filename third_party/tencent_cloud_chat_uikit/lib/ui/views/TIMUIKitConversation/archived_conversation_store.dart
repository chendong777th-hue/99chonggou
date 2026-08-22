import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/core_services_implements.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/common_utils.dart';

/// 归档会话范围：单聊与群聊独立存储。
enum ConversationArchiveScope {
  c2c,
  group,
}

const String archivedConversationIDsC2cStorageKey =
    "archivedConversationIDs_c2c";
const String archivedConversationIDsGroupStorageKey =
    "archivedConversationIDs_group";
const String archivedConversationIDsLegacyStorageKey =
    "archivedConversationIDs";
const String archivedConversationIDsMigratedStorageKey =
    "archivedConversationIDs_scoped_migrated";

const String _archivedConversationIDsC2cScopedPrefix =
    'archivedConversationIDs_c2c_v2_';
const String _archivedConversationIDsGroupScopedPrefix =
    'archivedConversationIDs_group_v2_';
const String _archivedConversationAccountMigratedPrefix =
    'archivedConversationIDs_account_migrated_v2_';

typedef ArchivedConversationAccountScopeResolver = String Function();

ArchivedConversationAccountScopeResolver? _testAccountScopeResolver;

@visibleForTesting
void setArchivedConversationAccountScopeResolverForTest(
  ArchivedConversationAccountScopeResolver? resolver,
) {
  _testAccountScopeResolver = resolver;
}

final ValueNotifier<Set<String>> archivedConversationC2cIDsNotifier =
    ValueNotifier<Set<String>>(<String>{});
final ValueNotifier<Set<String>> archivedConversationGroupIDsNotifier =
    ValueNotifier<Set<String>>(<String>{});

/// 兼容旧代码：合并单聊与群聊归档 ID（勿用于按范围过滤）。
final ValueNotifier<Set<String>> archivedConversationIDsNotifier =
    ValueNotifier<Set<String>>(<String>{});

String? _loadedAccountScope;
bool _c2cLoadedForScope = false;
bool _groupLoadedForScope = false;

void _syncLegacyMergedArchivedNotifier() {
  archivedConversationIDsNotifier.value = {
    ...archivedConversationC2cIDsNotifier.value,
    ...archivedConversationGroupIDsNotifier.value,
  };
}

String accountScopeForArchivedConversations() {
  final resolver = _testAccountScopeResolver;
  if (resolver != null) {
    final scoped = resolver().trim();
    if (scoped.isNotEmpty) {
      return scoped;
    }
  }
  try {
    setupServiceLocator();
    final userId = serviceLocator<CoreServicesImpl>().loginInfo.userID.trim();
    if (userId.isEmpty) {
      return '_guest';
    }
    return userId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  } catch (_) {
    return '_guest';
  }
}

String archivedConversationIDsStorageKeyFor(ConversationArchiveScope scope) {
  final accountScope = accountScopeForArchivedConversations();
  switch (scope) {
    case ConversationArchiveScope.c2c:
      return '$_archivedConversationIDsC2cScopedPrefix$accountScope';
    case ConversationArchiveScope.group:
      return '$_archivedConversationIDsGroupScopedPrefix$accountScope';
  }
}

ValueNotifier<Set<String>> archivedConversationIDsNotifierFor(
  ConversationArchiveScope scope,
) {
  switch (scope) {
    case ConversationArchiveScope.c2c:
      return archivedConversationC2cIDsNotifier;
    case ConversationArchiveScope.group:
      return archivedConversationGroupIDsNotifier;
  }
}

bool isGroupConversationForArchive(V2TimConversation conversation) {
  return conversation.type == 2 ||
      (TencentUtils.checkString(conversation.groupID)?.isNotEmpty ?? false);
}

ConversationArchiveScope archiveScopeForConversation(
  V2TimConversation conversation,
) {
  return isGroupConversationForArchive(conversation)
      ? ConversationArchiveScope.group
      : ConversationArchiveScope.c2c;
}

ConversationArchiveScope archiveScopeForConversationID(String conversationID) {
  return conversationID.startsWith("group_")
      ? ConversationArchiveScope.group
      : ConversationArchiveScope.c2c;
}

Future<void> _migrateLegacyArchivedConversationIDsIfNeeded() async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(archivedConversationIDsMigratedStorageKey) == true) {
    return;
  }
  final legacy =
      prefs.getStringList(archivedConversationIDsLegacyStorageKey) ?? <String>[];
  final c2cIDs = <String>{
    ...(prefs.getStringList(archivedConversationIDsC2cStorageKey) ?? <String>[]),
  };
  final groupIDs = <String>{
    ...(prefs.getStringList(archivedConversationIDsGroupStorageKey) ??
        <String>[]),
  };
  for (final id in legacy) {
    if (archiveScopeForConversationID(id) == ConversationArchiveScope.group) {
      groupIDs.add(id);
    } else {
      c2cIDs.add(id);
    }
  }
  await prefs.setStringList(
    archivedConversationIDsC2cStorageKey,
    c2cIDs.toList(),
  );
  await prefs.setStringList(
    archivedConversationIDsGroupStorageKey,
    groupIDs.toList(),
  );
  await prefs.setBool(archivedConversationIDsMigratedStorageKey, true);
}

Future<void> _migrateGlobalArchivedConversationIDsToAccountIfNeeded(
  SharedPreferences prefs,
  String accountScope,
) async {
  final migratedKey = '$_archivedConversationAccountMigratedPrefix$accountScope';
  if (prefs.getBool(migratedKey) == true) {
    return;
  }
  await _migrateLegacyArchivedConversationIDsIfNeeded();

  final globalC2c =
      prefs.getStringList(archivedConversationIDsC2cStorageKey) ?? <String>[];
  final globalGroup = prefs.getStringList(
        archivedConversationIDsGroupStorageKey,
      ) ??
      <String>[];

  final scopedC2cKey = '$_archivedConversationIDsC2cScopedPrefix$accountScope';
  final scopedGroupKey =
      '$_archivedConversationIDsGroupScopedPrefix$accountScope';

  final hasScopedC2c = prefs.containsKey(scopedC2cKey);
  final hasScopedGroup = prefs.containsKey(scopedGroupKey);
  if (!hasScopedC2c && globalC2c.isNotEmpty) {
    await prefs.setStringList(scopedC2cKey, globalC2c);
  }
  if (!hasScopedGroup && globalGroup.isNotEmpty) {
    await prefs.setStringList(scopedGroupKey, globalGroup);
  }

  await prefs.setBool(migratedKey, true);
}

void _resetLoadedScopeIfAccountChanged() {
  final scope = accountScopeForArchivedConversations();
  if (_loadedAccountScope == scope) {
    return;
  }
  _loadedAccountScope = scope;
  _c2cLoadedForScope = false;
  _groupLoadedForScope = false;
  archivedConversationC2cIDsNotifier.value = <String>{};
  archivedConversationGroupIDsNotifier.value = <String>{};
  _syncLegacyMergedArchivedNotifier();
}

/// 登出时仅清空内存态，保留各账号本地缓存。
void clearArchivedConversationSessionState() {
  _loadedAccountScope = null;
  _c2cLoadedForScope = false;
  _groupLoadedForScope = false;
  archivedConversationC2cIDsNotifier.value = <String>{};
  archivedConversationGroupIDsNotifier.value = <String>{};
  _syncLegacyMergedArchivedNotifier();
}

Future<Set<String>> loadArchivedConversationIDs(
  ConversationArchiveScope scope,
) async {
  _resetLoadedScopeIfAccountChanged();
  if (scope == ConversationArchiveScope.c2c && _c2cLoadedForScope) {
    return archivedConversationC2cIDsNotifier.value;
  }
  if (scope == ConversationArchiveScope.group && _groupLoadedForScope) {
    return archivedConversationGroupIDsNotifier.value;
  }

  final prefs = await SharedPreferences.getInstance();
  final accountScope = accountScopeForArchivedConversations();
  await _migrateGlobalArchivedConversationIDsToAccountIfNeeded(
    prefs,
    accountScope,
  );

  final ids = prefs.getStringList(archivedConversationIDsStorageKeyFor(scope)) ??
      <String>[];
  final value = ids.toSet();
  archivedConversationIDsNotifierFor(scope).value = value;
  if (scope == ConversationArchiveScope.c2c) {
    _c2cLoadedForScope = true;
  } else {
    _groupLoadedForScope = true;
  }
  _syncLegacyMergedArchivedNotifier();
  return value;
}

Future<void> saveArchivedConversationIDs(
  ConversationArchiveScope scope,
  Set<String> ids,
) async {
  _resetLoadedScopeIfAccountChanged();
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList(
    archivedConversationIDsStorageKeyFor(scope),
    ids.toList(),
  );
  archivedConversationIDsNotifierFor(scope).value = ids;
  if (scope == ConversationArchiveScope.c2c) {
    _c2cLoadedForScope = true;
  } else {
    _groupLoadedForScope = true;
  }
  _syncLegacyMergedArchivedNotifier();
}

Future<void> ensureArchivedConversationIDsLoaded() async {
  await loadArchivedConversationIDs(ConversationArchiveScope.c2c);
  await loadArchivedConversationIDs(ConversationArchiveScope.group);
}

Future<void> addArchivedConversation(
  V2TimConversation conversation,
) async {
  final scope = archiveScopeForConversation(conversation);
  final ids = {...archivedConversationIDsNotifierFor(scope).value};
  ids.add(conversation.conversationID);
  await saveArchivedConversationIDs(scope, ids);
}

Future<void> removeArchivedConversation(
  V2TimConversation conversation,
) async {
  final scope = archiveScopeForConversation(conversation);
  final ids = {...archivedConversationIDsNotifierFor(scope).value};
  ids.remove(conversation.conversationID);
  await saveArchivedConversationIDs(scope, ids);
}

Future<void> updateArchivedConversations(
  List<V2TimConversation> conversations, {
  required bool archived,
}) async {
  final idsByScope = <ConversationArchiveScope, Set<String>>{
    ConversationArchiveScope.c2c: {
      ...archivedConversationC2cIDsNotifier.value,
    },
    ConversationArchiveScope.group: {
      ...archivedConversationGroupIDsNotifier.value,
    },
  };
  for (final conversation in conversations) {
    final scope = archiveScopeForConversation(conversation);
    if (archived) {
      idsByScope[scope]!.add(conversation.conversationID);
    } else {
      idsByScope[scope]!.remove(conversation.conversationID);
    }
  }
  for (final scope in ConversationArchiveScope.values) {
    await saveArchivedConversationIDs(scope, idsByScope[scope]!);
  }
}
