import 'api_wallet_repository.dart';
import 'wallet_repository.dart';

const bool kWalletUseMock = bool.fromEnvironment(
  'WALLET_USE_MOCK',
  defaultValue: false,
);

WalletRepository? _walletRepository;

void configureWalletRepository(WalletRepository repo) {
  _walletRepository = repo;
}

void clearWalletRepositoryForTest() {
  _walletRepository = null;
}

WalletRepository createWalletRepository() {
  final repo = _walletRepository;
  if (repo != null) return repo;

  if (kWalletUseMock) {
    return MockWalletRepository();
  }

  return const ApiWalletRepository();
}
