enum C2cSendCheckResult {
  allowed,
  blocked,
  unknown,
}

typedef C2cCanSendChecker = Future<C2cSendCheckResult> Function(
  String peerUserId,
);

/// Bridge from UIKit send path to app-side C2C friend relation checks.
class C2cFriendMessageGuardBridge {
  C2cFriendMessageGuardBridge._();

  static C2cCanSendChecker? checkSend;

  static void configure({C2cCanSendChecker? checker}) {
    checkSend = checker;
  }
}
