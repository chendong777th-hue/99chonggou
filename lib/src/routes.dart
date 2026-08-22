import 'package:flutter/material.dart';

class Routes extends ChangeNotifier {
  static String _pageType = "";
  Routes._internal();

  static late final Routes _instance = Routes._internal();

  factory Routes() {
    return _instance;
  }

  String get pageType {
    return _pageType;
  }

  void directToHomePage() {
    _pageType = "homePage";
    _notifySafely();
  }

  void directToLoginPage() {
    _pageType = "loginPage";
    _notifySafely();
  }

  void _notifySafely() {
    try {
      notifyListeners();
    } catch (_) {}
  }

  @override
  void dispose() {
    _pageType = "";
  }
}
