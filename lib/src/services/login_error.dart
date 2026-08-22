enum LoginErrorType {
  businessAuthFailed,
  deviceVerificationFailed,
  fetchProfileFailed,
  fetchUserSigFailed,
  imLoginFailed,
  conversationBootstrapFailed,
  callLoginFailed,
  sessionExpired,
  kickedOffline,
  restoreFailed,
}

class LoginError {
  const LoginError({
    required this.type,
    this.message,
    this.cause,
    this.stackTrace,
  });

  final LoginErrorType type;
  final String? message;
  final Object? cause;
  final StackTrace? stackTrace;
}
