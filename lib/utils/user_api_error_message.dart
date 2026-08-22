import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:tencent_cloud_chat_demo/src/api/auth_api.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/utils/dio_error_message.dart';

class UserApiErrorMessage {
  UserApiErrorMessage._();

  static AppI18n get _i => AppI18n.current;

  static String _messageOrFallback(String? message, String fallback) {
    return DioErrorMessage.sanitizeUserText(message, fallback: fallback);
  }

  static String _networkOrFallback(DioError e, String fallback) {
    if (DioErrorMessage.isNetworkRelated(e)) {
      return DioErrorMessage.forApp(e);
    }
    return fallback;
  }

  static String fromSearch(DioError e) {
    final data = e.response?.data;
    if (data is Map) {
      final code = data['code']?.toString();
      switch (code) {
        case 'USER_NOT_FOUND':
          return _i.t(
            zhHans: '未找到该用户',
            zhHant: '未找到該用戶',
            en: 'User not found',
            ja: 'ユーザーが見つかりません',
            ko: '사용자를 찾을 수 없습니다',
          );
        case 'INVALID_INPUT':
          return _i.t(
            zhHans: '请输入有效手机号或 UID',
            zhHant: '請輸入有效手機號或 UID',
            en: 'Enter a valid phone number or UID',
            ja: '有効な電話番号または UID を入力してください',
            ko: '유효한 휴대폰 번호 또는 UID를 입력하세요',
          );
        case 'SEARCH_BLOCKED':
          final retryAfter = data['retryAfter'];
          if (retryAfter is int && retryAfter > 0) {
            final hours = (retryAfter / 3600).ceil().clamp(1, 999);
            return _i.format(
              zhHans: '搜索次数过多，请 {hours} 小时后再试',
              zhHant: '搜尋次數過多，請 {hours} 小時後再試',
              en: 'Too many searches. Try again in {hours} hour(s)',
              ja: '検索回数が多すぎます。{hours} 時間後に再試行してください',
              ko: '검색 횟수가 너무 많습니다. {hours}시간 후 다시 시도하세요',
              vars: {'hours': hours.toString()},
            );
          }
          return _i.t(
            zhHans: '搜索次数过多，请稍后再试',
            zhHant: '搜尋次數過多，請稍後再試',
            en: 'Too many searches. Try again later',
            ja: '検索回数が多すぎます。しばらくしてから再試行してください',
            ko: '검색 횟수가 너무 많습니다. 나중에 다시 시도하세요',
          );
        default:
          final message = data['message']?.toString();
          if (message != null && message.isNotEmpty) {
            return _messageOrFallback(
              message,
              _i.t(
                zhHans: '搜索失败',
                zhHant: '搜尋失敗',
                en: 'Search failed',
                ja: '検索に失敗しました',
                ko: '검색 실패',
              ),
            );
          }
      }
    }
    return _networkOrFallback(
      e,
      _i.t(
        zhHans: '搜索失败',
        zhHant: '搜尋失敗',
        en: 'Search failed',
        ja: '検索に失敗しました',
        ko: '검색 실패',
      ),
    );
  }

  static String fromContactMatch(DioError e) {
    final data = e.response?.data;
    if (data is Map) {
      final code = data['code']?.toString();
      switch (code) {
        case 'INVALID_INPUT':
          return _i.t(
            zhHans: '通讯录手机号格式无效',
            zhHant: '通訊錄手機號格式無效',
            en: 'Invalid phone numbers in contacts',
            ja: '連絡先の電話番号形式が無効です',
            ko: '연락처 전화번호 형식이 올바르지 않습니다',
          );
        case 'TOO_MANY_PHONES':
          return _i.t(
            zhHans: '通讯录号码过多，请稍后再试',
            zhHant: '通訊錄號碼過多，請稍後再試',
            en: 'Too many contact numbers. Try again later',
            ja: '連絡先の件数が多すぎます。しばらくしてからお試しください',
            ko: '연락처 번호가 너무 많습니다. 나중에 다시 시도하세요',
          );
        case 'RATE_LIMITED':
          return _i.t(
            zhHans: '操作过于频繁，请稍后再试',
            zhHant: '操作過於頻繁，請稍後再試',
            en: 'Too many requests. Try again later',
            ja: '操作が多すぎます。しばらくしてからお試しください',
            ko: '요청이 너무 많습니다. 나중에 다시 시도하세요',
          );
        default:
          final message = data['message']?.toString();
          if (message != null && message.isNotEmpty) {
            return _messageOrFallback(
              message,
              _i.t(
                zhHans: '通讯录匹配失败',
                zhHant: '通訊錄匹配失敗',
                en: 'Failed to match contacts',
                ja: '連絡先の照合に失敗しました',
                ko: '연락처 매칭 실패',
              ),
            );
          }
      }
    }
    return _networkOrFallback(
      e,
      _i.t(
        zhHans: '通讯录匹配失败',
        zhHant: '通訊錄匹配失敗',
        en: 'Failed to match contacts',
        ja: '連絡先の照合に失敗しました',
        ko: '연락처 매칭 실패',
      ),
    );
  }

  /// 将加好友预检 / 申请接口返回的 reason 码转成用户可读文案。
  /// 未知码时返回 [fallback]（勿把后端英文码直接展示给用户）。
  static String fromAddFriendReasonCode(
    String? reason, {
    required String fallback,
  }) {
    final code = reason?.trim().toUpperCase() ?? '';
    if (code.isEmpty) {
      return fallback;
    }
    switch (code) {
      case 'ADD_FRIEND_VIA_CARD_DISABLED':
        return _i.t(
          zhHans: '对方未开放通过名片添加',
          zhHant: '對方未開放透過名片添加',
          en: 'This user does not allow adds via contact card.',
          ja: 'This user does not allow adds via contact card.',
          ko: 'This user does not allow adds via contact card.',
        );
      case 'ADD_FRIEND_VIA_QR_DISABLED':
      case 'ADD_FRIEND_VIA_QR_CODE_DISABLED':
        return _i.t(
          zhHans: '对方未开放通过二维码添加',
          zhHant: '對方未開放透過 QR 碼添加',
          en: 'This user does not allow adds via QR code.',
          ja: 'This user does not allow adds via QR code.',
          ko: 'This user does not allow adds via QR code.',
        );
      case 'ADD_FRIEND_VIA_GROUP_DISABLED':
        return _i.t(
          zhHans: '对方未开放通过群聊添加',
          zhHant: '對方未開放透過群聊添加',
          en: 'This user does not allow adds from group chats.',
          ja: 'This user does not allow adds from group chats.',
          ko: 'This user does not allow adds from group chats.',
        );
      case 'ADD_FRIEND_VIA_PHONE_DISABLED':
        return _i.t(
          zhHans: '对方未开放通过手机号添加',
          zhHant: '對方未開放透過手機號添加',
          en: 'This user does not allow adds via phone number.',
          ja: 'This user does not allow adds via phone number.',
          ko: 'This user does not allow adds via phone number.',
        );
      case 'ADD_FRIEND_VIA_UID_DISABLED':
      case 'ADD_FRIEND_VIA_SEARCH_DISABLED':
        return _i.t(
          zhHans: '对方未开放通过搜索添加',
          zhHant: '對方未開放透過搜尋添加',
          en: 'This user does not allow adds from search.',
          ja: 'This user does not allow adds from search.',
          ko: 'This user does not allow adds from search.',
        );
      default:
        // 纯大写蛇形码（后端枚举）不要原样露出；其它可读文案可透传。
        if (RegExp(r'^[A-Z][A-Z0-9_]+$').hasMatch(code)) {
          return fallback;
        }
        final original = reason?.trim() ?? '';
        return original.isNotEmpty ? original : fallback;
    }
  }

  static String fromFriendRequest(DioError e) {
    final body = _readErrorBody(e);
    final code = (body?['reason'] ??
            body?['code'] ??
            body?['errorCode'] ??
            body?['message'])
        ?.toString()
        .trim()
        .toUpperCase();
    final channelMapped = fromAddFriendReasonCode(code, fallback: '');
    if (channelMapped.isNotEmpty) {
      return channelMapped;
    }
    switch (code) {
      case 'ALREADY_FRIENDS':
        return _i.t(
          zhHans: '你们已经是好友',
          zhHant: '你們已經是好友',
          en: 'You are already friends',
          ja: 'You are already friends',
          ko: '이미 친구입니다',
        );
      case 'FRIEND_REQUEST_COOLDOWN':
        return _i.t(
          zhHans: '申请过于频繁，请 10 分钟后再试',
          zhHant: '申請過於頻繁，請 10 分鐘後再試',
          en: 'Friend request sent too frequently. Try again in 10 minutes.',
          ja: 'Friend request sent too frequently. Try again in 10 minutes.',
          ko: '친구 요청이 너무 잦습니다. 10분 후 다시 시도하세요.',
        );
      case 'INVALID_INPUT':
        return _i.t(
          zhHans: '参数错误，不能添加自己或用户不存在',
          zhHant: '參數錯誤，不能添加自己或用戶不存在',
          en: 'Invalid request. You cannot add yourself or the user does not exist.',
          ja: 'Invalid request. You cannot add yourself or the user does not exist.',
          ko: '잘못된 요청입니다. 자신을 추가할 수 없거나 사용자가 없습니다.',
        );
      case 'REQUEST_NOT_FOUND':
        return _i.t(
          zhHans: '申请不存在或已失效',
          zhHant: '申請不存在或已失效',
          en: 'The request does not exist or has expired.',
          ja: 'The request does not exist or has expired.',
          ko: '요청이 없거나 만료되었습니다.',
        );
      case 'REQUEST_ALREADY_HANDLED':
        return _i.t(
          zhHans: '申请已处理过',
          zhHant: '申請已處理過',
          en: 'This request has already been handled.',
          ja: 'This request has already been handled.',
          ko: '이미 처리된 요청입니다.',
        );
      case 'FRIEND_NOT_FOUND':
        return _i.t(
          zhHans: '好友不存在或已删除',
          zhHant: '好友不存在或已刪除',
          en: 'Friend not found or already removed.',
          ja: '友達が見つからないか、既に削除されています。',
          ko: '친구를 찾을 수 없거나 이미 삭제되었습니다.',
        );
    }
    final message = body?['message']?.toString().trim();
    if (message != null && message.isNotEmpty) {
      return _messageOrFallback(
        message,
        _i.t(
          zhHans: '添加失败，请稍后重试',
          zhHant: '添加失敗，請稍後重試',
          en: 'Failed to add friend. Try again later.',
          ja: '友だち追加に失敗しました。後でもう一度お試しください',
          ko: '친구 추가 실패. 나중에 다시 시도하세요',
        ),
      );
    }
    if (e.response?.statusCode == 429) {
      return _i.t(
        zhHans: '申请过于频繁，请稍后再试',
        zhHant: '申請過於頻繁，請稍後再試',
        en: 'Too many requests. Try again later.',
        ja: 'Too many requests. Try again later.',
        ko: '요청이 너무 많습니다. 나중에 다시 시도하세요.',
      );
    }
    return _i.t(
      zhHans: '添加失败，请稍后重试',
      zhHant: '添加失敗，請稍後重試',
      en: 'Failed to add friend. Try again later.',
      ja: '友だち追加に失敗しました。後でもう一度お試しください',
      ko: '친구 추가 실패. 나중에 다시 시도하세요',
    );
  }

  static String fromGroupPrivacy(DioError e) {
    final data = e.response?.data;
    String code = '';
    String message = '';
    if (data is Map) {
      code = (data['code'] ?? data['errorCode'] ?? data['errCode'])
          ?.toString()
          .trim()
          .toUpperCase() ??
          '';
      message = (data['message'] ?? data['msg'] ?? data['error'] ?? data['desc'])
          ?.toString()
          .trim() ??
          '';
    }
    switch (code) {
      case 'NOT_GROUP_ADMIN':
      case 'FORBIDDEN':
      case 'PERMISSION_DENIED':
        return _i.t(
          zhHans: '仅群主或管理员可修改',
          zhHant: '僅群主或管理員可修改',
          en: 'Only group owner or admin can change this',
          ja: 'Only group owner or admin can change this',
          ko: 'Only group owner or admin can change this',
        );
      case 'NOT_GROUP_MEMBER':
        return _i.t(
          zhHans: '您不是群成员',
          zhHant: '您不是群成員',
          en: 'You are not a group member',
          ja: 'You are not a group member',
          ko: 'You are not a group member',
        );
      case 'INVALID_INPUT':
      case 'BAD_REQUEST':
        return _i.t(
          zhHans: '参数无效',
          zhHant: '參數無效',
          en: 'Invalid parameters',
          ja: 'Invalid parameters',
          ko: 'Invalid parameters',
        );
      case 'UNAUTHORIZED':
      case 'TOKEN_EXPIRED':
      case 'TOKEN_INVALID':
      case 'INVALID_TOKEN':
        return _loginAgain();
    }

    final normalized = message.toLowerCase();
    if (normalized.contains('permission') ||
        normalized.contains('forbidden') ||
        normalized.contains('not_group_admin')) {
      return _i.t(
        zhHans: '仅群主或管理员可修改',
        zhHant: '僅群主或管理員可修改',
        en: 'Only group owner or admin can change this',
        ja: 'Only group owner or admin can change this',
        ko: 'Only group owner or admin can change this',
      );
    }
    if (normalized.contains('not_group_member')) {
      return _i.t(
        zhHans: '您不是群成员',
        zhHant: '您不是群成員',
        en: 'You are not a group member',
        ja: 'You are not a group member',
        ko: 'You are not a group member',
      );
    }
    if (e.response?.statusCode == 401) {
      return _loginAgain();
    }
    return _i.t(
      zhHans: '群隐私设置暂不可用',
      zhHant: '群隱私設定暫不可用',
      en: 'Group privacy settings are unavailable',
      ja: 'Group privacy settings are unavailable',
      ko: 'Group privacy settings are unavailable',
    );
  }

  static String fromPrivacy(DioError e) {
    final data = e.response?.data;
    if (data is Map) {
      final code = data['code']?.toString();
      if (code == 'INVALID_INPUT') {
        return _i.t(
          zhHans: '请完整填写所有开关',
          zhHant: '請完整填寫所有開關',
          en: 'Please configure all privacy switches',
          ja: 'すべてのスイッチを設定してください',
          ko: '모든 스위치를 설정해 주세요',
        );
      }
      if (code == 'USER_NOT_FOUND') {
        return _userNotFoundRelogin();
      }
      final message = data['message']?.toString();
      if (message != null && message.isNotEmpty) {
        return _messageOrFallback(message, _saveFailed());
      }
    }
    return _saveFailed();
  }

  static String fromNotificationSettings(DioError e) {
    final data = e.response?.data;
    if (data is Map) {
      final code = data['code']?.toString();
      if (code == 'INVALID_INPUT') {
        return _i.t(
          zhHans: '通知展示内容无效',
          zhHant: '通知展示內容無效',
          en: 'Invalid notification display option',
          ja: '通知の表示設定が無効です',
          ko: '알림 표시 설정이 올바르지 않습니다',
        );
      }
      if (code == 'USER_NOT_FOUND') {
        return _userNotFoundRelogin();
      }
      if (code == 'UNAUTHORIZED') {
        return _userNotFoundRelogin();
      }
      final message = data['message']?.toString();
      if (message != null && message.isNotEmpty) {
        return _messageOrFallback(message, _saveFailed());
      }
    }
    return _networkOrFallback(
      e,
      _i.t(
        zhHans: '通知设置保存失败',
        zhHant: '通知設定儲存失敗',
        en: 'Failed to save notification settings',
        ja: '通知設定の保存に失敗しました',
        ko: '알림 설정 저장에 실패했습니다',
      ),
    );
  }

  static String fromNicknameCheck({
    required String? reason,
    DateTime? nextChangeableAt,
  }) {
    switch (reason) {
      case 'NICKNAME_EXISTS':
        return _nicknameTaken();
      case 'NICKNAME_COOLDOWN':
        return formatCooldownHint(nextChangeableAt);
      case 'NICKNAME_CHECK_UNAVAILABLE':
        return _i.t(
          zhHans: '用户名校验失败，请稍后再试',
          zhHant: '用戶名校驗失敗，請稍後再試',
          en: 'Username check failed. Please try again later',
          ja: 'ユーザー名の確認に失敗しました。しばらくしてからもう一度お試しください',
          ko: '사용자 이름 확인에 실패했습니다. 잠시 후 다시 시도해 주세요',
        );
      default:
        return '';
    }
  }

  /// 昵称预检或保存接口 HTTP 失败时的提示（优先展示后端 code/message）。
  static String fromNicknameApi(DioError e, {bool checking = false}) {
    final body = _readErrorBody(e);
    if (body != null) {
      final code = body['code']?.toString();
      switch (code) {
        case 'INVALID_INPUT':
          return _nicknameLengthHint();
        case 'NICKNAME_EXISTS':
          return _nicknameTaken();
        case 'NICKNAME_COOLDOWN':
          return formatCooldownHint(
            MeResult.parseIsoDateTime(body['nextChangeableAt']),
          );
        case 'USER_NOT_FOUND':
          return _userNotFoundRelogin();
        case 'UNAUTHORIZED':
        case 'AUTH_EXPIRED':
        case 'TOKEN_EXPIRED':
        case 'TOKEN_INVALID':
        case 'INVALID_TOKEN':
        case 'LOGIN_EXPIRED':
        case 'SESSION_EXPIRED':
          return checking
              ? _i.t(
                  zhHans: '验证已过期，请重新验证',
                  zhHant: '驗證已過期，請重新驗證',
                  en: 'Verification expired. Please verify again',
                  ja: '認証の有効期限が切れました。もう一度認証してください',
                  ko: '인증이 만료되었습니다. 다시 인증해 주세요',
                )
              : _loginAgain();
        default:
          final message = body['message']?.toString();
          if (message != null && message.isNotEmpty) {
            final mapped = _mapEnglishBackendMessage(message, checking: checking);
            return mapped ?? message;
          }
          final springError = body['error']?.toString();
          if (springError != null && springError.isNotEmpty) {
            return _mapHttpStatusMessage(e.response?.statusCode, springError,
                checking: checking);
          }
      }
    }
    return _mapHttpStatusMessage(
      e.response?.statusCode,
      null,
      checking: checking,
    );
  }

  static String fromNicknameUpdate(DioError e) =>
      fromNicknameApi(e, checking: false);

  static bool isTokenExpiredError(DioError e) {
    final body = _readErrorBody(e);
    final code = body?['code']?.toString().trim().toUpperCase() ?? '';
    if (code == 'UNAUTHORIZED' ||
        code == 'AUTH_EXPIRED' ||
        code == 'TOKEN_EXPIRED' ||
        code == 'TOKEN_INVALID' ||
        code == 'INVALID_TOKEN' ||
        code == 'LOGIN_EXPIRED' ||
        code == 'SESSION_EXPIRED') {
      return true;
    }
    final message = body?['message']?.toString() ?? e.message ?? '';
    final lower = message.toLowerCase();
    return lower.contains('invalid or expired token') ||
        ((lower.contains('invalid') || lower.contains('expired')) &&
            lower.contains('token'));
  }

  static String fromNicknameCheckRequest(DioError e) =>
      fromNicknameApi(e, checking: true);

  static Map<String, dynamic>? _readErrorBody(DioError e) {
    final data = e.response?.data;
    Map<String, dynamic>? root;
    if (data is Map<String, dynamic>) {
      root = data;
    } else if (data is Map) {
      root = Map<String, dynamic>.from(data);
    } else if (data is String && data.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) {
          root = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }
    if (root == null) return null;
    final nested = root['data'] ?? root['result'] ?? root['payload'];
    if (nested is Map) {
      return <String, dynamic>{
        ...root,
        ...Map<String, dynamic>.from(nested),
      };
    }
    return root;
  }


  static String? _mapEnglishBackendMessage(
    String message, {
    required bool checking,
  }) {
    final lower = message.trim().toLowerCase();
    if (lower.isEmpty) return null;
    if (lower.contains('invalid or expired token') ||
        ((lower.contains('invalid') || lower.contains('expired')) &&
            lower.contains('token'))) {
      return checking
          ? _i.t(
              zhHans: '验证已过期，请重新验证',
              zhHant: '驗證已過期，請重新驗證',
              en: 'Verification expired. Please verify again',
              ja: '認証の有効期限が切れました。もう一度認証してください',
              ko: '인증이 만료되었습니다. 다시 인증해 주세요',
            )
          : _loginAgain();
    }
    if (lower == 'nickname_exists' ||
        lower.contains('nickname_exists') ||
        lower.contains('nickname already') ||
        lower.contains('username already')) {
      return _nicknameTaken();
    }
    if (lower.contains('too many') || lower.contains('rate limit')) {
      return _i.t(
        zhHans: '请求太频繁，请稍后再试',
        zhHant: '請求太頻繁，請稍後再試',
        en: 'Too many requests. Please try again later',
        ja: 'リクエストが多すぎます。しばらくしてからお試しください',
        ko: '요청이 너무 잦습니다. 잠시 후 다시 시도하세요',
      );
    }
    return null;
  }

  static String _mapHttpStatusMessage(
    int? status,
    String? fallback, {
    required bool checking,
  }) {
    switch (status) {
      case 400:
        return fallback ?? _nicknameLengthHint();
      case 401:
        return _i.t(
          zhHans: '登录已失效，请重新登录',
          zhHant: '登入已失效，請重新登入',
          en: 'Session expired. Please sign in again',
          ja: 'ログインの有効期限が切れました。再度ログインしてください',
          ko: '로그인이 만료되었습니다. 다시 로그인해 주세요',
        );
      case 403:
        return _i.t(
          zhHans: '登录状态无效或无权修改昵称，请重新登录',
          zhHant: '登入狀態無效或無權修改暱稱，請重新登入',
          en: 'Invalid session or no permission to change nickname. Please sign in again',
          ja: 'ログイン状態が無効か、ニックネームを変更する権限がありません。再度ログインしてください',
          ko: '로그인 상태가 유효하지 않거나 닉네임을 변경할 권한이 없습니다. 다시 로그인해 주세요',
        );
      case 404:
        return checking
            ? _i.t(
                zhHans: '昵称校验暂不可用，请稍后重试',
                zhHant: '暱稱校驗暫不可用，請稍後重試',
                en: 'Nickname check is temporarily unavailable. Please try again later.',
                ja: 'ニックネーム確認は現在利用できません。しばらくしてからお試しください。',
                ko: '닉네임 확인을 일시적으로 사용할 수 없습니다. 잠시 후 다시 시도해 주세요.',
              )
            : _i.t(
                zhHans: '昵称修改暂不可用，请稍后重试',
                zhHant: '暱稱修改暫不可用，請稍後重試',
                en: 'Nickname update is temporarily unavailable. Please try again later.',
                ja: 'ニックネーム変更は現在利用できません。しばらくしてからお試しください。',
                ko: '닉네임 변경을 일시적으로 사용할 수 없습니다. 잠시 후 다시 시도해 주세요.',
              );
      case 409:
        return fallback ??
            _i.t(
              zhHans: '昵称暂时无法修改',
              zhHant: '暱稱暫時無法修改',
              en: 'Nickname cannot be changed right now',
              ja: '現在ニックネームを変更できません',
              ko: '지금은 닉네임을 변경할 수 없습니다',
            );
      case 500:
      case 502:
      case 503:
        return _i.t(
          zhHans: '服务繁忙，请稍后再试',
          zhHant: '服務繁忙，請稍後再試',
          en: 'Service busy. Please try again later',
          ja: 'サービスが混み合っています。しばらくしてから再試行してください',
          ko: '서비스가 바쁩니다. 나중에 다시 시도하세요',
        );
      default:
        break;
    }
    if (fallback != null && fallback.isNotEmpty) {
      final mapped = _mapEnglishBackendMessage(fallback, checking: checking);
      return mapped ?? fallback;
    }
    return checking
        ? _i.t(
            zhHans: '昵称校验失败，请稍后再试',
            zhHant: '暱稱校驗失敗，請稍後再試',
            en: 'Nickname check failed. Please try again later',
            ja: 'ニックネーム確認に失敗しました。しばらくしてから再試行してください',
            ko: '닉네임 확인에 실패했습니다. 나중에 다시 시도하세요',
          )
        : _saveFailed();
  }


  static String? _walletMessageFallback(String? text) {
    final value = text?.trim() ?? '';
    if (value.isEmpty) return null;
    final lower = value.toLowerCase();
    if (value.contains('支付密码') ||
        value.contains('交易密码') ||
        value.contains('资金密码') ||
        lower.contains('pay pin') ||
        lower.contains('payment password') ||
        lower.contains('trade password')) {
      if (value.contains('锁定') || lower.contains('locked')) {
        return _i.t(
          zhHans: '支付密码已锁定',
          zhHant: '支付密碼已鎖定',
          en: 'Payment password locked',
          ja: '支払いパスワードがロックされています',
          ko: '결제 비밀번호가 잠겼습니다',
        );
      }
      if (value.contains('未设置') || lower.contains('not set')) {
        return _i.t(
          zhHans: '请先设置支付密码',
          zhHant: '請先設定支付密碼',
          en: 'Set a payment password first',
          ja: '先に支払いパスワードを設定してください',
          ko: '먼저 결제 비밀번호를 설정하세요',
        );
      }
      return _i.t(
        zhHans: '支付密码错误',
        zhHant: '支付密碼錯誤',
        en: 'Incorrect payment password',
        ja: '支払いパスワードが正しくありません',
        ko: '결제 비밀번호가 올바르지 않습니다',
      );
    }
    if (value.contains('余额不足') || lower.contains('insufficient balance')) {
      return _i.t(
        zhHans: '余额不足',
        zhHant: '餘額不足',
        en: 'Insufficient balance',
        ja: '残高不足',
        ko: '잔액이 부족합니다',
      );
    }
    if (value.contains('正在维护') ||
        value.contains('维护中') ||
        lower.contains('maintenance') ||
        lower.contains('under maintenance')) {
      return _i.t(
        zhHans: '正在维护',
        zhHant: '正在維護',
        en: 'Under maintenance',
        ja: 'メンテナンス中です',
        ko: '점검 중입니다',
      );
    }
    if (value.contains('重复提交') || lower.contains('duplicate submit')) {
      return _i.t(
        zhHans: '请勿重复提交',
        zhHant: '請勿重複提交',
        en: 'Please do not submit repeatedly',
        ja: '重複送信しないでください',
        ko: '중복 제출하지 마세요',
      );
    }
    return null;
  }

  static String fromWallet(DioError e) {
    final data = e.response?.data;
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final rawCode = map['code']?.toString().trim() ??
          map['errorCode']?.toString().trim() ??
          '';
      var code = rawCode.toUpperCase();
      if (code.isEmpty) {
        final inner = map['data'];
        if (inner is Map) {
          code = (inner['code'] ?? inner['errorCode'] ?? '')
              .toString()
              .trim()
              .toUpperCase();
        }
      }
      switch (code) {
        case 'PASSWORD_WRONG':
        case 'PAY_PIN_INVALID':
        case 'INVALID_PAY_PIN':
        case 'PAY_PIN_WRONG':
        case 'PAY_PASSWORD_WRONG':
        case 'PAY_PASSWORD_INVALID':
        case 'TRADE_PASSWORD_WRONG':
        case 'TRADE_PASSWORD_INVALID':
        case 'FUND_PASSWORD_WRONG':
          return _i.t(
            zhHans: '支付密码错误',
            zhHant: '支付密碼錯誤',
            en: 'Incorrect payment password',
            ja: '支払いパスワードが正しくありません',
            ko: '결제 비밀번호가 올바르지 않습니다',
          );
        case 'PASSWORD_LOCKED':
        case 'PAY_PIN_LOCKED':
          return _i.t(
            zhHans: '支付密码已锁定',
            zhHant: '支付密碼已鎖定',
            en: 'Payment password locked',
            ja: '支払いパスワードがロックされています',
            ko: '결제 비밀번호가 잠겼습니다',
          );
        case 'PAY_PIN_NOT_SET':
          return _i.t(
            zhHans: '请先设置支付密码',
            zhHant: '請先設定支付密碼',
            en: 'Set a payment password first',
            ja: '先に支払いパスワードを設定してください',
            ko: '먼저 결제 비밀번호를 설정하세요',
          );
        case 'INSUFFICIENT_BALANCE':
          return _i.t(
            zhHans: '余额不足',
            zhHant: '餘額不足',
            en: 'Insufficient balance',
            ja: '残高不足',
            ko: '잔액이 부족합니다',
          );
        case 'INSUFFICIENT_FEE':
        case 'FEE_EXCEEDS_AMOUNT':
          return _i.t(
            zhHans: '手续费余额不足',
            zhHant: '手續費餘額不足',
            en: 'Insufficient balance for fees',
            ja: '手数料の残高が不足しています',
            ko: '수수료 잔액이 부족합니다',
          );
        case 'INVALID_AMOUNT':
        case 'EXCHANGE_AMOUNT_TOO_SMALL':
        case 'WITHDRAW_MIN_NOT_MET':
          return _i.t(
            zhHans: '金额不正确',
            zhHant: '金額不正確',
            en: 'Invalid amount',
            ja: '金額が正しくありません',
            ko: '금액이 올바르지 않습니다',
          );
        case 'EXCHANGE_MAINTENANCE':
          return _i.t(
            zhHans: '正在维护',
            zhHant: '正在維護',
            en: 'Under maintenance',
            ja: 'メンテナンス中です',
            ko: '점검 중입니다',
          );
        case 'DUPLICATE_SUBMIT':
        case 'ALREADY_CLAIMED':
          return _i.t(
            zhHans: '请勿重复提交',
            zhHant: '請勿重複提交',
            en: 'Do not submit again',
            ja: '重複して送信しないでください',
            ko: '중복 제출하지 마세요',
          );
        case 'LIMIT_EXCEEDED':
          return _i.t(
            zhHans: '已超过每日限额',
            zhHant: '已超過每日限額',
            en: 'Daily withdrawal limit exceeded',
            ja: '日々の出金限度を超えています',
            ko: '일일 출금 한도를 초과했습니다',
          );
        case 'INVALID_RECEIVER':
        case 'RECIPIENT_NOT_FOUND':
          return _i.t(
            zhHans: '收款人无效',
            zhHant: '收款人無效',
            en: 'Invalid recipient',
            ja: '受取人が無効です',
            ko: '수취인이 유효하지 않습니다',
          );
        case 'RATE_UNAVAILABLE':
          return _i.t(
            zhHans: '汇率暂不可用，请稍后再试',
            zhHant: '匯率暫不可用，請稍後再試',
            en: 'Exchange rate unavailable. Try again later',
            ja: '為替レートが利用できません。しばらくしてから再試行してください',
            ko: '환율을 사용할 수 없습니다. 나중에 다시 시도하세요',
          );
        case 'RED_PACKET_EXPIRED':
          return _i.t(
            zhHans: '红包已过期',
            zhHant: '紅包已過期',
            en: 'Red packet expired',
            ja: '红包の有効期限が切れました',
            ko: '红包이 만료되었습니다',
          );
        case 'RED_PACKET_EMPTY':
          return _i.t(
            zhHans: '红包已领完',
            zhHant: '紅包已領完',
            en: 'Red packet fully claimed',
            ja: '红包はすべて受け取られました',
            ko: '红包이 모두 수령되었습니다',
          );
        case 'INVALID_TRON_ADDRESS':
          return _i.t(
            zhHans: 'TRON 地址无效',
            zhHant: 'TRON 地址無效',
            en: 'Invalid TRON address',
            ja: 'TRON アドレスが無効です',
            ko: 'TRON 주소가 유효하지 않습니다',
          );
        default:
          final message = _walletMessageFallback(
            map['message']?.toString() ??
                map['msg']?.toString() ??
                map['error']?.toString(),
          );
          if (message != null && message.isNotEmpty) {
            return message;
          }
      }
    }
    final fallback = _walletMessageFallback(e.message);
    if (fallback != null && fallback.isNotEmpty) {
      return fallback;
    }
    if (DioErrorMessage.isNetworkRelated(e)) {
      return DioErrorMessage.forApp(e);
    }
    if (e.response?.statusCode == 401) {
      return _loginAgain();
    }
    if (e.response?.statusCode == 404) {
      return _i.t(
        zhHans: '钱包服务暂未开通，请联系管理员',
        zhHant: '錢包服務暫未開通，請聯繫管理員',
        en: 'Wallet service is not enabled. Contact an administrator',
        ja: 'ウォレットサービスはまだ有効になっていません。管理者にお問い合わせください',
        ko: '지갑 서비스가 아직 활성화되지 않았습니다. 관리자에게 문의하세요',
      );
    }
    return _i.t(
      zhHans: '钱包操作失败，请稍后再试',
      zhHant: '錢包操作失敗，請稍後再試',
      en: 'Wallet operation failed. Please try again later',
      ja: 'ウォレット操作に失敗しました。しばらくしてから再試行してください',
      ko: '지갑 작업에 실패했습니다. 나중에 다시 시도하세요',
    );
  }

  static String fromStarredFriend(DioError e) {
    final data = e.response?.data;
    if (data is Map) {
      final code = data['code']?.toString();
      switch (code) {
        case 'INVALID_INPUT':
          return _i.t(
            zhHans: '好友 ID 无效',
            zhHant: '好友 ID 無效',
            en: 'Invalid friend ID',
            ja: '友達 ID が無効です',
            ko: '친구 ID가 유효하지 않습니다',
          );
        case 'CANNOT_STAR_SELF':
          return _i.t(
            zhHans: '不能星标自己',
            zhHant: '不能星標自己',
            en: 'You cannot star yourself',
            ja: '自分をスター付きにすることはできません',
            ko: '자신을 즐겨찾기할 수 없습니다',
          );
        case 'USER_NOT_FOUND':
          return _i.t(
            zhHans: '未找到该用户',
            zhHant: '未找到該用戶',
            en: 'User not found',
            ja: 'ユーザーが見つかりません',
            ko: '사용자를 찾을 수 없습니다',
          );
        default:
          final message = data['message']?.toString();
          if (message != null && message.isNotEmpty) {
            return _messageOrFallback(message, _operationFailed());
          }
      }
    }
    if (e.response?.statusCode == 401) {
      return _loginAgain();
    }
    return _networkOrFallback(e, _operationFailed());
  }

  static String formatCooldownHint(DateTime? nextChangeableAt) {
    if (nextChangeableAt == null) {
      return _i.t(
        zhHans: '7 天内仅可修改一次昵称',
        zhHant: '7 天內僅可修改一次暱稱',
        en: 'Nickname can only be changed once every 7 days',
        ja: 'ニックネームは7日に1回のみ変更できます',
        ko: '닉네임은 7일에 한 번만 변경할 수 있습니다',
      );
    }
    final local = nextChangeableAt.toLocal();
    final formatted = DateFormat('yyyy-MM-dd HH:mm').format(local);
    return _i.format(
      zhHans: '{time} 后可再次修改昵称',
      zhHant: '{time} 後可再次修改暱稱',
      en: 'You can change your nickname again after {time}',
      ja: '{time} 以降に再度ニックネームを変更できます',
      ko: '{time} 이후에 다시 닉네임을 변경할 수 있습니다',
      vars: {'time': formatted},
    );
  }

  static String _loginAgain() => _i.t(
        zhHans: '请重新登录',
        zhHant: '請重新登入',
        en: 'Please sign in again',
        ja: '再度ログインしてください',
        ko: '다시 로그인해 주세요',
      );

  static String _operationFailed() => _i.t(
        zhHans: '操作失败',
        zhHant: '操作失敗',
        en: 'Operation failed',
        ja: '操作に失敗しました',
        ko: '작업에 실패했습니다',
      );

  static String _saveFailed() => _i.t(
        zhHans: '保存失败',
        zhHant: '儲存失敗',
        en: 'Save failed',
        ja: '保存に失敗しました',
        ko: '저장에 실패했습니다',
      );

  static String _userNotFoundRelogin() => _i.t(
        zhHans: '用户不存在，请重新登录',
        zhHant: '用戶不存在，請重新登入',
        en: 'User not found. Please sign in again',
        ja: 'ユーザーが存在しません。再度ログインしてください',
        ko: '사용자가 존재하지 않습니다. 다시 로그인해 주세요',
      );

  static String _nicknameTaken() => _i.t(
        zhHans: '用户名已存在',
        zhHant: '用戶名已存在',
        en: 'Username already exists',
        ja: 'ユーザー名は既に存在します',
        ko: '사용자 이름이 이미 존재합니다',
      );

  static String _nicknameLengthHint() => _i.t(
        zhHans: '昵称长度为 2-22 个字符',
        zhHant: '暱稱長度為 2-22 個字元',
        en: 'Nickname must be 2–22 characters',
        ja: 'ニックネームは2〜22文字で入力してください',
        ko: '닉네임은 2~22자여야 합니다',
      );
}
