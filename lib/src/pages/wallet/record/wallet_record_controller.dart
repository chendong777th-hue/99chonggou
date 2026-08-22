import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';

import '../order/wallet_pending_recovery_service.dart';
import '../wallet_repository.dart';
import '../wallet_repository_provider.dart';
import 'wallet_record_models.dart';

class WalletRecordController extends ChangeNotifier {
  final WalletRepository _repo;
  WalletRecordController({
    WalletRepository? repo,
  }) : _repo = repo ?? createWalletRepository();

  bool loading = false;
  String err = '';
  HistoryRecordFilter filter = HistoryRecordFilter.all;

  List<WalletRecordDto> list = [];
  bool _dead = false;

  Future<void> load() async {
    if (loading) return;

    loading = true;
    err = '';
    notifyListeners();

    try {
      await _refreshPending();
      list = await _repo.getWalletRecordsByFilter(filter);
    } catch (_) {
      err = AppI18n.current.t(
        zhHans: '记录加载失败，请稍后重试',
        zhHant: '記錄載入失敗，請稍後再試',
        en: 'Failed to load records. Please try again later.',
        ja: '履歴の読み込みに失敗しました。しばらくしてからもう一度お試しください。',
        ko: '기록을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.',
      );
      list = [];
    } finally {
      loading = false;
      if (!_dead) notifyListeners();
    }
  }

  Future<void> _refreshPending() async {
    await WalletPendingRecoveryService.instance.recover(
      reason: 'wallet_record',
      force: true,
    );
  }

  void setFilter(HistoryRecordFilter v) {
    if (filter == v) return;
    filter = v;
    load();
  }

  @override
  void dispose() {
    _dead = true;
    super.dispose();
  }
}
