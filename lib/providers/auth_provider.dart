import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  bool _isLoggedIn = false;
  bool _isLoading = false;
  Map<String, dynamic>? _account;

  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  Map<String, dynamic>? get account => _account;

  Future<void> checkAuth() async {
    _isLoggedIn = await _api.isLoggedIn();
    notifyListeners();
  }

  Future<String?> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await _api.login(email, password);
      await _api.saveTokens(data['access'], data['refresh']);
      _isLoggedIn = true;
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _isLoading = false;
      _isLoggedIn = false;
      notifyListeners();
      return 'Invalid email or password';
    }
  }

  Future<void> logout() async {
    await _api.clearTokens();
    _isLoggedIn = false;
    _account = null;
    notifyListeners();
  }
}
