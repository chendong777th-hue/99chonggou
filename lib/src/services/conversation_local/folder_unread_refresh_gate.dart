import 'dart:async';

import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_flags.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_gate_log.dart';

/// 进程级 folder_unread 单飞闸门。
///
/// 禁止「每个 join 都 whenComplete → 再 schedule」——那会在高频 notify 下
/// 同步/准同步炸出数十万 `folder_unread_single_flight_join` 冻死 UI。
///
/// 合约：忙时只置 [pending]；结束后若 pending，用 [scheduleMicrotask] **只补跑一次**。
/// [tryClaimFlight] 在开跑前同步占坑，禁止双 Tab 同时通过。
class FolderUnreadRefreshGate {
  FolderUnreadRefreshGate._();

  static Future<void>? _inFlight;
  static bool _pending = false;
  static int _flightGen = 0;
  static int _joinLogGen = -1;

  /// 测试计数。
  static int joinLogCountForTest = 0;
  static int pendingKickCountForTest = 0;
  static int claimFailCountForTest = 0;

  static bool get hasInFlightForTest => _inFlight != null;

  static bool get hasPendingForTest => _pending;

  static void resetForTest() {
    _inFlight = null;
    _pending = false;
    _flightGen = 0;
    _joinLogGen = -1;
    joinLogCountForTest = 0;
    pendingKickCountForTest = 0;
    claimFailCountForTest = 0;
  }

  /// 若正忙：置 pending，并（按 flag）每飞行世代最多打一条 join 日志。
  /// 返回 `true` 表示调用方应直接 return，勿再开跑。
  static bool markJoinIfBusy() {
    if (_inFlight == null) {
      return false;
    }
    _pending = true;
    _logJoinOnce();
    return true;
  }

  static void _logJoinOnce() {
    final logOnce =
        ConversationPerfFlags.folderUnreadSingleFlightJoinLogOncePerFlight;
    if (!logOnce || _joinLogGen != _flightGen) {
      _joinLogGen = _flightGen;
      joinLogCountForTest++;
      ConversationPerfGateLog.log('folder_unread_single_flight_join');
    }
  }

  /// 同步占坑：成功返回当前飞行 Future；失败（已有飞行）置 pending 并返回 null。
  static Future<void>? tryClaimFlight(Completer<void> done) {
    if (!ConversationPerfFlags.folderUnreadAtomicClaimEnabled) {
      attachInFlight(done.future);
      return done.future;
    }
    if (_inFlight != null) {
      _pending = true;
      claimFailCountForTest++;
      _logJoinOnce();
      return null;
    }
    _inFlight = done.future;
    _flightGen++;
    return done.future;
  }

  /// 登记本轮 in-flight（非原子路径；优先用 [tryClaimFlight]）。
  static void attachInFlight(Future<void> task) {
    _inFlight = task;
    _flightGen++;
  }

  /// in-flight 结束：仅当 [task] 仍是当前飞行时清状态；
  /// 若有 pending，清 pending 并 microtask 触发 [onPendingKick] **一次**。
  static void onFlightFinished(
    Future<void> task, {
    required void Function() onPendingKick,
  }) {
    if (!identical(_inFlight, task)) {
      return;
    }
    _inFlight = null;
    if (!_pending) {
      return;
    }
    _pending = false;
    pendingKickCountForTest++;
    scheduleMicrotask(onPendingKick);
  }
}
