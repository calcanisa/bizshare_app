import 'package:flutter/material.dart';
import '../services/api_service.dart';

class DashboardProvider extends ChangeNotifier {
  final ApiService _api;
  Map<String, dynamic> _counts = {};
  Map<String, dynamic>? _account;
  String _systemMessage = 'System alerts will appear here';
  bool _isLoading = false;

  Map<String, dynamic> get counts => _counts;
  Map<String, dynamic>? get account => _account;
  String get systemMessage => _systemMessage;
  bool get isLoading => _isLoading;

  DashboardProvider(this._api);

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        _api.dio.get('/api/v1/users/user/dashboard/'),
        _api.dio.get('/api/v1/users/current/'),
        _api.dio.get('/api/v1/alerts/system/'),
      ]);
      _counts = Map<String, dynamic>.from(results[0].data);
      _account = Map<String, dynamic>.from(results[1].data);
      final alerts = results[2].data as List;
      if (alerts.isNotEmpty) {
        final first = alerts.firstWhere((a) => a['dismissed'] == false, orElse: () => alerts[0]);
        _systemMessage = first['detail'] ?? 'System alerts will appear here';
      }
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  int count(String key) => (_counts[key] ?? 0) as int;

  String get membershipLabel {
    final mem = _account?['membership'];
    if (mem == null) return 'Bronze';
    final type = mem['mem_type'] as String? ?? '';
    if (type.startsWith('silver')) return 'Silver';
    if (type.startsWith('gold')) return 'Gold';
    return 'Bronze';
  }

  Color get membershipColor {
    switch (membershipLabel) {
      case 'Silver': return const Color(0xFF9E9E9E);
      case 'Gold': return const Color(0xFFF8BB25);
      default: return const Color(0xFF8D5524);
    }
  }
}
