/// Shared, dependency-free arbitration primitives for mobile async work.
///
/// A token is valid only while its account, page, conversation and operation
/// generations are current. Callers must check [canCommit] immediately before
/// mutating UI or persistent state. This class does not cancel work; stale
/// work may finish for resource cleanup but cannot publish its result.
enum MobileCommitAuthority {
  fallback,
  remoteRequest,
  sdkEvent,
  localUserAction,
}

class MobileAsyncCommitToken {
  const MobileAsyncCommitToken({
    required this.operation,
    required this.key,
    required this.authGeneration,
    required this.pageGeneration,
    required this.conversationGeneration,
    required this.operationGeneration,
  });

  final String operation;
  final String key;
  final int authGeneration;
  final int pageGeneration;
  final int conversationGeneration;
  final int operationGeneration;
}

class MobileAsyncCommitStats {
  int staleDrops = 0;
  int duplicateDrops = 0;
  int authorityDrops = 0;

  void reset() {
    staleDrops = 0;
    duplicateDrops = 0;
    authorityDrops = 0;
  }
}

class _IdentityClaim {
  const _IdentityClaim(this.authority, this.revision);

  final MobileCommitAuthority authority;
  final int revision;
}

class MobileAsyncCommitGuard {
  int _authGeneration = 0;
  int _pageGeneration = 0;
  int _conversationGeneration = 0;
  final Map<String, int> _operationGenerations = <String, int>{};
  final Map<String, _IdentityClaim> _claims = <String, _IdentityClaim>{};

  final MobileAsyncCommitStats stats = MobileAsyncCommitStats();

  int get authGeneration => _authGeneration;
  int get pageGeneration => _pageGeneration;
  int get conversationGeneration => _conversationGeneration;

  int advanceAuth() {
    _authGeneration++;
    _pageGeneration++;
    _conversationGeneration++;
    _operationGenerations.clear();
    _claims.clear();
    return _authGeneration;
  }

  int advancePage() {
    _pageGeneration++;
    _conversationGeneration++;
    _operationGenerations.clear();
    _claims.clear();
    return _pageGeneration;
  }

  int advanceConversation() {
    _conversationGeneration++;
    _operationGenerations.clear();
    _claims.clear();
    return _conversationGeneration;
  }

  MobileAsyncCommitToken begin(String operation, {String key = ''}) {
    final operationKey = '$operation\u0000$key';
    final generation = (_operationGenerations[operationKey] ?? 0) + 1;
    _operationGenerations[operationKey] = generation;
    return MobileAsyncCommitToken(
      operation: operation,
      key: key,
      authGeneration: _authGeneration,
      pageGeneration: _pageGeneration,
      conversationGeneration: _conversationGeneration,
      operationGeneration: generation,
    );
  }

  bool canCommit(MobileAsyncCommitToken token) {
    final operationKey = '${token.operation}\u0000${token.key}';
    final valid = token.authGeneration == _authGeneration &&
        token.pageGeneration == _pageGeneration &&
        token.conversationGeneration == _conversationGeneration &&
        _operationGenerations[operationKey] == token.operationGeneration;
    if (!valid) stats.staleDrops++;
    return valid;
  }

  bool acceptIdentity(
    String identity, {
    required MobileCommitAuthority authority,
    int revision = 0,
  }) {
    final key = identity.trim();
    if (key.isEmpty) return false;
    final previous = _claims[key];
    if (previous != null &&
        (authority.index < previous.authority.index ||
            (authority == previous.authority && revision <= previous.revision))) {
      if (authority == previous.authority && revision <= previous.revision) {
        stats.duplicateDrops++;
      } else {
        stats.authorityDrops++;
      }
      return false;
    }
    _claims[key] = _IdentityClaim(authority, revision);
    return true;
  }

  void reset() {
    _authGeneration = 0;
    _pageGeneration = 0;
    _conversationGeneration = 0;
    _operationGenerations.clear();
    _claims.clear();
    stats.reset();
  }
}
