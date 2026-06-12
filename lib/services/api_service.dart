import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static const String baseUrl = 'https://sesha.co.za';
  static const _storage = FlutterSecureStorage();
  late final Dio _dio;
  DateTime? _tokenExpiry;

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
          if (_tokenExpiry == null ||
              _tokenExpiry!.difference(DateTime.now()).inMinutes < 5) {
            await refreshIfNeeded();
          }
          final freshToken = await _storage.read(key: 'access_token');
          options.headers['Authorization'] = 'Bearer $freshToken';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        final status = error.response?.statusCode;

        if (status == 401) {
          final refreshed = await _refreshToken();
          if (refreshed) {
            final token = await _storage.read(key: 'access_token');
            error.requestOptions.headers['Authorization'] = 'Bearer $token';
            final response = await _dio.fetch(error.requestOptions);
            return handler.resolve(response);
          } else {
            onUnauthorized?.call();
            return handler.next(error);
          }
        }

        // 403 — permission denied, not a logout
        return handler.next(error);
      },
    ));
  }

  // ── Proactive refresh ─────────────────────────────────────────────────────
  Future<void> refreshIfNeeded() async {
    try {
      final token = await _storage.read(key: 'access_token');
      if (token == null) return;

      final parts = token.split('.');
      if (parts.length != 3) return;

      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final map = jsonDecode(decoded) as Map<String, dynamic>;
      final exp = map['exp'] as int?;
      if (exp == null) return;

      _tokenExpiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      if (_tokenExpiry!.difference(DateTime.now()).inMinutes < 5) {
        await _refreshToken();
      }
    } catch (_) {
      // Decode failed — leave token as-is
    }
  }

  bool _refreshing = false;

  Future<bool> _refreshToken() async {
    if (_refreshing) {
      // Wait for the in-progress refresh to complete
      await Future.delayed(const Duration(milliseconds: 500));
      return await _storage.read(key: 'access_token') != null;
    }
    _refreshing = true;
    try {
      final refresh = await _storage.read(key: 'refresh_token');
      if (refresh == null) {
        _refreshing = false;
        return false;
      }
      final response = await Dio().post(
        '$baseUrl/api/v1/token/refresh/',
        data: {'refresh': refresh},
      );
      final newAccess = response.data['access'] as String;
      await _storage.write(key: 'access_token', value: newAccess);

      final parts = newAccess.split('.');
      if (parts.length == 3) {
        final payload =
            utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
        final map = jsonDecode(payload) as Map<String, dynamic>;
        final exp = map['exp'] as int?;
        if (exp != null) {
          _tokenExpiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
        }
      }

      if (response.data['refresh'] != null) {
        await _storage.write(
            key: 'refresh_token', value: response.data['refresh']);
      }
      _refreshing = false;
      return true;
    } catch (e) {
      debugPrint('_refreshToken error: $e');
      _refreshing = false;
      await _storage.deleteAll();
      return false;
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _dio.post('/api/v1/', data: {
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
