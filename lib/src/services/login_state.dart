import 'package:tencent_cloud_chat_demo/src/services/login_error.dart';

enum LoginPhase {
  loggedOut,
  businessAuthenticating,
  businessAuthenticated,
  homeEnteredSyncingIm,
  imConnecting,
  imReady,
  sessionRefreshing,
  deviceVerifying,
  sessionExpired,
  kickedOffline,
  failed,
}

class LoginState {
  const LoginState({
    required this.phase,
    required this.isBusinessAuthenticated,
    required this.isHomeEntered,
    required this.isImReady,
    required this.isRecovering,
    this.currentUserId,
    this.lastError,
  });

  factory LoginState.initial() {
    return const LoginState(
      phase: LoginPhase.loggedOut,
      isBusinessAuthenticated: false,
      isHomeEntered: false,
      isImReady: false,
      isRecovering: false,
    );
  }

  final LoginPhase phase;
  final bool isBusinessAuthenticated;
  final bool isHomeEntered;
  final bool isImReady;
  final bool isRecovering;
  final String? currentUserId;
  final LoginError? lastError;

  LoginState copyWith({
    LoginPhase? phase,
    bool? isBusinessAuthenticated,
    bool? isHomeEntered,
    bool? isImReady,
    bool? isRecovering,
    Object? currentUserId = _sentinel,
    Object? lastError = _sentinel,
  }) {
    return LoginState(
      phase: phase ?? this.phase,
      isBusinessAuthenticated:
          isBusinessAuthenticated ?? this.isBusinessAuthenticated,
      isHomeEntered: isHomeEntered ?? this.isHomeEntered,
      isImReady: isImReady ?? this.isImReady,
      isRecovering: isRecovering ?? this.isRecovering,
      currentUserId: identical(currentUserId, _sentinel)
          ? this.currentUserId
          : currentUserId as String?,
      lastError: identical(lastError, _sentinel)
          ? this.lastError
          : lastError as LoginError?,
    );
  }
}

const Object _sentinel = Object();
