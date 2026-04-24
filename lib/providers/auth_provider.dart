import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api;

  AuthProvider(this._api);

  bool _isLoggedIn = false;
  bool _isLoading = false;
  Map<String, dynamic>? _account;

  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  Map<String, dynamic>? get account => _account;

  // Expose api so screens can call postMultipart / patchMultipart
  ApiService get apiService => _api;

  Future<void> checkAuth() async {
    _isLoggedIn = await _api.isLoggedIn();
    notifyListeners();
  }

  Future<String?> login(String email, String password,
      {bool rememberMe = false}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await _api.login(email, password);
      await _api.saveTokens(data['access'], data['refresh']);
      _isLoggedIn = true;
      _isLoading = false;
      notifyListeners();
      return null;
    } on DioException catch (e) {
      _isLoading = false;
      _isLoggedIn = false;
      notifyListeners();
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        return 'Cannot reach server. Check your network connection.';
      }
      if (e.response?.statusCode == 401 || e.response?.statusCode == 400) {
        return 'Invalid email or password.';
      }
      return 'Login failed (${e.response?.statusCode ?? 'no response'}). Try again.';
    } catch (e) {
      _isLoading = false;
      _isLoggedIn = false;
      notifyListeners();
      return 'Unexpected error: $e';
    }
  }

  Future<void> logout() async {
    await _api.clearTokens();
    _isLoggedIn = false;
    _account = null;
    notifyListeners();
  }
}
