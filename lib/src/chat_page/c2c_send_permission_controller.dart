import 'package:flutter/foundation.dart';

/// C2C send permission UI state: null = checking, true/false = decided.
class C2cSendPermissionController extends ChangeNotifier {
  bool? _canMessage;
  bool trustedInitialCanMessage = false;
  int requestSeq = 0;
  VoidCallback? onTransitionToBlocked;

  bool? get canMessage => _canMessage;

  set canMessage(bool? value) {
    if (_canMessage == value) {
      return;
    }
    _canMessage = value;
    notifyListeners();
  }

  /// Server relation confirmed the peer cannot be messaged.
  ///
  /// This is the only path that fires [onTransitionToBlocked] for in-flight
  /// outgoing reconciliation.
  void applyRelationBlocked() {
    if (_canMessage == false) {
      return;
    }
    final wasAllowed = _canMessage != false;
    _canMessage = false;
    if (wasAllowed) {
      onTransitionToBlocked?.call();
    }
    notifyListeners();
  }

  bool isBlocked(bool isC2c) => isC2c && canMessage == false;

  bool isChecking(bool isC2c, bool hasPeer) =>
      isC2c && hasPeer && canMessage == null;

  void resetForNoPeer({required bool resetIfMissing}) {
    trustedInitialCanMessage = false;
    if (resetIfMissing) {
      canMessage = null;
    }
  }

  void applyTrustedHint() {
    trustedInitialCanMessage = true;
    canMessage = true;
  }

  void clearTrusted({required bool resetIfMissing}) {
    trustedInitialCanMessage = false;
    if (resetIfMissing) {
      canMessage = null;
    }
  }

  int nextRequestSeq() => ++requestSeq;

  bool applyResolved(bool? canSend) {
    if (canSend == null) {
      return false;
    }
    if (canMessage == canSend) {
      return false;
    }
    canMessage = canSend;
    return true;
  }
}
