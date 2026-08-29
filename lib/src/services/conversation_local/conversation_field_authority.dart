import 'conversation_mutation_event.dart';

/// Field-specific source authority used by the shadow reducer.
///
/// Version ordering is evaluated before this rank. Authority only decides
/// conflicts at the same logical version; it must not let a cache beat a newer
/// server generation.
class ConversationFieldAuthority {
  const ConversationFieldAuthority._();

  static bool prefersIncoming({
    required ConversationMutationField field,
    required ConversationMutationSource incomingSource,
    required int incomingVersion,
    required ConversationMutationSource existingSource,
    required int existingVersion,
  }) {
    final incomingAuthority = rank(field, incomingSource);
    final existingAuthority = rank(field, existingSource);
    if (incomingAuthority <= 0) {
      return false;
    }
    final sourceFirst = switch (field) {
      ConversationMutationField.name ||
      ConversationMutationField.avatar ||
      ConversationMutationField.membership =>
        true,
      _ => false,
    };
    if (sourceFirst && incomingAuthority != existingAuthority) {
      return incomingAuthority > existingAuthority;
    }
    if (incomingVersion != existingVersion) {
      return incomingVersion > existingVersion;
    }
    return incomingAuthority > existingAuthority;
  }

  static int rank(
    ConversationMutationField field,
    ConversationMutationSource source,
  ) {
    return switch (field) {
      ConversationMutationField.lastMessage ||
      ConversationMutationField.unread ||
      ConversationMutationField.order =>
        _sdkConversationRank(source),
      ConversationMutationField.draft =>
        source == ConversationMutationSource.localIntent ? 100 : 0,
      ConversationMutationField.pin => switch (source) {
          ConversationMutationSource.sdkRealtime => 100,
          ConversationMutationSource.localIntent => 90,
          ConversationMutationSource.sdkPage => 80,
          ConversationMutationSource.snapshot => 20,
          _ => 0,
        },
      ConversationMutationField.name ||
      ConversationMutationField.avatar =>
        _metadataRank(source),
      ConversationMutationField.membership => switch (source) {
          ConversationMutationSource.membershipExplicit => 100,
          ConversationMutationSource.sdkMetadata => 80,
          ConversationMutationSource.remoteMetadata => 70,
          ConversationMutationSource.localCache => 10,
          _ => 0,
        },
      ConversationMutationField.archive ||
      ConversationMutationField.folder ||
      ConversationMutationField.mute =>
        source == ConversationMutationSource.localIntent ? 100 : 0,
    };
  }

  static int _sdkConversationRank(ConversationMutationSource source) {
    return switch (source) {
      ConversationMutationSource.sdkRealtime => 100,
      ConversationMutationSource.sdkPage => 80,
      ConversationMutationSource.snapshot => 20,
      // A local read barrier patches unread in the same logical version
      // domain as the message it cleared. New SDK messages still win, while
      // an older snapshot cannot resurrect the cleared badge.
      ConversationMutationSource.localIntent => 90,
      _ => 0,
    };
  }

  static int _metadataRank(ConversationMutationSource source) {
    return switch (source) {
      ConversationMutationSource.userExplicitMetadata => 100,
      ConversationMutationSource.sdkMetadata => 90,
      ConversationMutationSource.remoteMetadata => 80,
      ConversationMutationSource.sdkRealtime => 30,
      ConversationMutationSource.sdkPage => 25,
      ConversationMutationSource.snapshot => 20,
      ConversationMutationSource.localCache => 10,
      _ => 0,
    };
  }
}
