import 'history_proof.dart';

enum SdkCapabilityState {
  sdkDocSupported,
  consoleEnabled,
  codeIntegrated,
  runtimeVerified,
  partial,
  platformUnavailable,
}

class SdkCapabilityDescriptor {
  const SdkCapabilityDescriptor({
    required this.name,
    required this.platform,
    required this.state,
    this.evidenceRef,
    this.notes,
  });

  final String name;
  final ImPlatform platform;
  final SdkCapabilityState state;
  final String? evidenceRef;
  final String? notes;

  SdkCapabilityDescriptor copyWith({
    SdkCapabilityState? state,
    String? evidenceRef,
    String? notes,
  }) =>
      SdkCapabilityDescriptor(
        name: name,
        platform: platform,
        state: state ?? this.state,
        evidenceRef: evidenceRef ?? this.evidenceRef,
        notes: notes ?? this.notes,
      );

  String get key => '${platform.name}:$name';

  Map<String, Object?> toJson() => <String, Object?>{
        'name': name,
        'platform': platform.name,
        'state': state.name,
        'evidenceRef': evidenceRef,
        'notes': notes,
      };
}

/// Immutable capability matrix. Documentation support is not runtime proof.
class SdkCapabilityRegistry {
  SdkCapabilityRegistry(Iterable<SdkCapabilityDescriptor> descriptors)
      : _entries = <String, SdkCapabilityDescriptor>{
          for (final descriptor in descriptors) descriptor.key: descriptor,
        };

  const SdkCapabilityRegistry._(this._entries);

  final Map<String, SdkCapabilityDescriptor> _entries;

  Iterable<SdkCapabilityDescriptor> get entries =>
      List<SdkCapabilityDescriptor>.unmodifiable(_entries.values);

  SdkCapabilityDescriptor descriptorFor(
    String name,
    ImPlatform platform,
  ) {
    final normalized = name.trim();
    final descriptor = _entries['${platform.name}:$normalized'];
    if (descriptor == null) {
      throw StateError('Unknown SDK capability: ${platform.name}:$normalized');
    }
    return descriptor;
  }

  SdkCapabilityState stateFor(String name, ImPlatform platform) =>
      descriptorFor(name, platform).state;

  bool supports(String name, ImPlatform platform) {
    final state = stateFor(name, platform);
    return state != SdkCapabilityState.platformUnavailable &&
        state != SdkCapabilityState.partial;
  }

  SdkCapabilityRegistry update(
    String name,
    ImPlatform platform, {
    required SdkCapabilityState state,
    String? evidenceRef,
    String? notes,
  }) {
    final current = descriptorFor(name, platform);
    if (!_canTransition(current.state, state)) {
      throw StateError(
        'Invalid capability transition ${current.state.name} -> ${state.name}',
      );
    }
    final next = Map<String, SdkCapabilityDescriptor>.of(_entries)
      ..[current.key] = current.copyWith(
        state: state,
        evidenceRef: evidenceRef,
        notes: notes,
      );
    return SdkCapabilityRegistry._(
        Map<String, SdkCapabilityDescriptor>.unmodifiable(next));
  }

  static SdkCapabilityRegistry officialTencentHighestPackage() {
    const names = <String>[
      'message.send.text',
      'message.send.image',
      'message.send.video',
      'message.send.audio',
      'message.send.custom',
      'message.cloudCustomData',
      'history.local',
      'history.cloud',
      'search.local',
      'search.cloud',
      'search.cloudPlugin',
      'conversation.draft',
      'conversation.pin',
      'conversation.mute',
      'read.c2cTimestamp',
      'read.groupSequence',
      'history.groupLastMsgSeq',
    ];
    final descriptors = <SdkCapabilityDescriptor>[];
    for (final platform in ImPlatform.values) {
      if (platform == ImPlatform.unknown) continue;
      for (final name in names) {
        final unavailable = platform == ImPlatform.web &&
            (name == 'history.local' ||
                name == 'search.local' ||
                name == 'history.groupLastMsgSeq');
        descriptors.add(
          SdkCapabilityDescriptor(
            name: name,
            platform: platform,
            state: unavailable
                ? SdkCapabilityState.platformUnavailable
                : SdkCapabilityState.sdkDocSupported,
            notes: unavailable
                ? 'Official Web limitation; use cloud API or cloud search.'
                : 'Highest package and official SDK documentation confirmed.',
          ),
        );
      }
    }
    return SdkCapabilityRegistry(descriptors);
  }
}

bool _canTransition(SdkCapabilityState from, SdkCapabilityState to) {
  if (from == to) return true;
  if (from == SdkCapabilityState.platformUnavailable) return false;
  if (to == SdkCapabilityState.platformUnavailable) return false;
  if (to == SdkCapabilityState.partial) return true;
  if (from == SdkCapabilityState.partial) {
    return to == SdkCapabilityState.runtimeVerified;
  }
  const rank = <SdkCapabilityState, int>{
    SdkCapabilityState.sdkDocSupported: 0,
    SdkCapabilityState.consoleEnabled: 1,
    SdkCapabilityState.codeIntegrated: 2,
    SdkCapabilityState.runtimeVerified: 3,
  };
  return rank[to]! >= rank[from]!;
}
