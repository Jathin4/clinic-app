import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppProvider extends ChangeNotifier {
  String _page = 'dashboard';
  String _authPage = 'login';
  bool _isLoggedIn = false;
  Map<String, dynamic>? _user;
  bool _collapsed = false;
  bool _mobileSidebar = false;
  bool _isLoading = false;
  String _loadingMessage = 'Loading...';

  String get page => _page;
  String get authPage => _authPage;
  bool get isLoggedIn => _isLoggedIn;
  Map<String, dynamic>? get user => _user;
  bool get collapsed => _collapsed;
  bool get mobileSidebar => _mobileSidebar;
  bool get isLoading => _isLoading;
  String get loadingMessage => _loadingMessage;

  AppProvider() {
    _loadSavedSession();
  }

  Future<void> _loadSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user');
    final savedPage = prefs.getString('page') ?? 'dashboard';
    if (userJson != null) {
      _user = jsonDecode(userJson);
      _isLoggedIn = true;
      _page = savedPage;
      notifyListeners();
    }
  }

  Future<void> setPage(String newPage) async {
    _page = newPage;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('page', newPage);
    notifyListeners();
  }

  void setAuthPage(String p) {
    _authPage = p;
    notifyListeners();
  }

  Future<void> setUser(Map<String, dynamic> userData) async {
    _user = userData;
    _isLoggedIn = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode(userData));
    notifyListeners();
  }

  Future<void> handleLogout() async {
    _isLoggedIn = false;
    _user = null;
    _page = 'dashboard';
    _authPage = 'login';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user');
    await prefs.remove('page');
    notifyListeners();
  }

  void setCollapsed(bool val) {
    _collapsed = val;
    notifyListeners();
  }

  void setMobileSidebar(bool val) {
    _mobileSidebar = val;
    notifyListeners();
  }

  void showLoading([String message = 'Loading...']) {
    _loadingMessage = message;
    _isLoading = true;
    notifyListeners();
  }

  void hideLoading() {
    _isLoading = false;
    notifyListeners();
  }
}