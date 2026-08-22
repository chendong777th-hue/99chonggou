import 'dart:io';
import 'package:path_provider/path_provider.dart';

class CommonUtils {
  static Directory? _appFileDir;
  static Directory? _appCacheDir;
  static Directory? _externalCacheDir;

  static int? Function()? _getSDKAppID;
  static String Function()? _getLoginUser;

  static Future<bool> init({
    int? Function()? getSDKAppID,
    String Function()? getLoginUser
  }) async {
    _appFileDir ??= Platform.isAndroid ? await getApplicationSupportDirectory() : await getApplicationDocumentsDirectory();
    _appCacheDir = await getApplicationCacheDirectory();
    _externalCacheDir ??= Platform.isAndroid ? await getExternalStorageDirectory() : null;
    _getSDKAppID ??= getSDKAppID;
    _getLoginUser ??= getLoginUser;
    return true;
  }

  static Directory get appFileDir {
    if (_appFileDir == null) {
      throw Exception('app file directory not initialized. Call init() first.');
    }

    return _appFileDir!;
  }

  static Directory get appCacheDir {
    if (_appCacheDir == null) {
      throw Exception('app cache directory not initialized. Call init() first.');
    }

    return _appCacheDir!;
  }

  static Directory? get externalCacheDir {
    return _externalCacheDir;
  }

  static int? getSDKAppID() {
    return _getSDKAppID?.call();
  }
  
  static String getLoginUser() {
    return _getLoginUser?.call() ?? "";
  }
}