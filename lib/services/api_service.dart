import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.10.215:8000';
  static const _storage = FlutterSecureStorage();
  late final Dio _dio;

  // Set this from outside to trigger logout
  void Function()? onUnauthorized;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        final status = error.response?.statusCode;

        // 401 — try token refresh first
        if (status == 401) {
          final refreshed = await _refreshToken();
          if (refreshed) {
            final token = await _storage.read(key: 'access_token');
            error.requestOptions.headers['Authorization'] = 'Bearer $token';
            final response = await _dio.fetch(error.requestOptions);
            return handler.resolve(response);
          } else {
            // Refresh failed — tokens are dead, log out
            onUnauthorized?.call();
            return handler.next(error);
          }
        }

        // 403 — permission denied, NOT a logout. Let the screen handle it.
        return handler.next(error);
      },
    ));
  }

  Future<bool> _refreshToken() async {
    try {
      final refresh = await _storage.read(key: 'refresh_token');
      if (refresh == null) return false;
      final response = await Dio().post(
        '$baseUrl/api/token/refresh/',
        data: {'refresh': refresh},
      );
      await _storage.write(key: 'access_token', value: response.data['access']);
      return true;
    } catch (_) {
      await _storage.deleteAll();
      return false;
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _dio.post('/api/token/', data: {
        'email': email,
        'password': password,
      });
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> saveTokens(String access, String refresh) async {
    await _storage.write(key: 'access_token', value: access);
    await _storage.write(key: 'refresh_token', value: refresh);
  }

  Future<void> clearTokens() async {
    await _storage.deleteAll();
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: 'access_token');
    return token != null;
  }

  Dio get dio => _dio;

  // ── Multipart POST ────────────────────────────────────────────────────────
  // Used for endpoints that receive files alongside text fields.
  // [fields] is a flat map of string values.
  // [files]  is a map of field-name → File (can be empty).
  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required Map<String, String> fields,
    Map<String, File> files = const {},
  }) async {
    final fileEntries = <String, MultipartFile>{};
    for (final entry in files.entries) {
      fileEntries[entry.key] = await MultipartFile.fromFile(entry.value.path);
    }
    final formData = FormData.fromMap({...fields, ...fileEntries});
    final response = await _dio.post(path, data: formData);
    return response.data as Map<String, dynamic>;
  }

  // ── Multipart PATCH ───────────────────────────────────────────────────────
  Future<Map<String, dynamic>> patchMultipart(
    String path, {
    required Map<String, String> fields,
    Map<String, File> files = const {},
  }) async {
    final fileEntries = <String, MultipartFile>{};
    for (final entry in files.entries) {
      fileEntries[entry.key] = await MultipartFile.fromFile(entry.value.path);
    }
    final formData = FormData.fromMap({...fields, ...fileEntries});
    final response = await _dio.patch(path, data: formData);
    return response.data as Map<String, dynamic>;
  }
}
