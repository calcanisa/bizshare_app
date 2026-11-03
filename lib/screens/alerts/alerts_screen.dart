import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  int _tab = 2; // default to System Alerts

  List<dynamic> _userAlerts = [];
  List<dynamic> _systemAlerts = [];
  bool _loadingUser = false;
  bool _loadingSystem = false;

  List<dynamic> get _currentUserAlerts =>
      _userAlerts.where((a) => a['dismissed'] != true).toList();
  List<dynamic> get _dismissedUserAlerts =>
      _userAlerts.where((a) => a['dismissed'] == true).toList();
  List<dynamic> get _currentSystemAlerts =>
      _systemAlerts.where((a) => a['dismissed'] != true).toList();
  List<dynamic> get _dismissedSystemAlerts =>
      _systemAlerts.where((a) => a['dismissed'] == true).toList();

  @override
  void initState() {
    super.initState();
    _loadUserAlerts();
    _loadSystemAlerts();
  }

  Future<void> _loadUserAlerts() async {
    if (_userAlerts.isNotEmpty) return;
    setState(() => _loadingUser = true);
    try {
      final api = context.read<ApiService>();
      final response = await api.dio.get('/api/v1/alerts/user/current/');
      setState(() => _userAlerts = response.data is List ? response.data : []);
    } catch (_) {
      _showSnack('Could not load user alerts. Try again.');
    }
    setState(() => _loadingUser = false);
  }

  Future<void> _loadSystemAlerts() async {
    if (_systemAlerts.isNotEmpty) return;
    setState(() => _loadingSystem = true);
    try {
      final api = context.read<ApiService>();
      final response = await api.dio.get('/api/v1/alerts/system/');
      setState(
          () => _systemAlerts = response.data is List ? response.data : []);
    } catch (_) {
      _showSnack('Could not load system alerts. Try again.');
    }
    setState(() => _loadingSystem = false);
  }

  Future<void> _dismissAlert(int id, {bool isSystem = false}) async {
    try {
      final api = context.read<ApiService>();
      final url = isSystem
          ? '/api/v1/alerts/system/$id/dismiss/'
          : '/api/v1/alerts/$id/dismiss/';
      await api.dio.post(url);
      setState(() {
        final list = isSystem ? _systemAlerts : _userAlerts;
        final alert = list.firstWhere((a) => a['id'] == id, orElse: () => null);
        if (alert != null) {
          alert['dismissed'] = true;
          alert['dismissed_at'] = DateTime.now().toIso8601String();
        }
      });
    } catch (_) {
      _showSnack('Failed to dismiss alert. Try again.');
    }
  }

  String _formatDateTime(String? dtStr) {
    if (dtStr == null) return '';
    final dt = DateTime.tryParse(dtStr);
    if (dt == null) return '';
    final local = dt.toLocal();
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sept',
      'Oct',
      'Nov',
      'Dec'
    ];
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${months[local.month]} ${local.year} $h:$m';
  }

  Color _alertColor(String? type) {
    switch (type?.toLowerCase()) {
      case 'info':
        return const Color(0xFF1B4748);
      case 'warning':
        return const Color(0xFFF8BB25);
      case 'error':
      case 'danger':
        return const Color(0xFFF48900);
      case 'success':
        return Colors.teal;
      default:
        return Colors.blueGrey;
    }
  }

  Color _alertTextColor(String? type) {
    switch (type?.toLowerCase()) {
      case 'warning':
        return Colors.black87;
      default:
        return Colors.white;
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final loading = _loadingUser && _loadingSystem;

    if (loading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF1B4748)));
    }

    return Column(
      children: [
        Container(
          color: const Color(0xFF1B4748),
          child: Row(
            children: [
              _tabBtn(1, 'User Alerts'),
              _tabBtn(2, 'System Alerts'),
            ],
          ),
        ),
        Expanded(
          child: _tab == 1 ? _userAlertsTab() : _systemAlertsTab(),
        ),
      ],
    );
  }

  Widget _tabBtn(int index, String label) {
    final active = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          color: active ? Colors.white : const Color(0xFF1B4748),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: active ? const Color(0xFF1B4748) : Colors.white60,
                fontSize: 13,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              )),
        ),
      ),
    );
  }

  // ─── Tab 1 — User Alerts ─────────────────────────────────────────────────

  Widget _userAlertsTab() {
    if (_loadingUser) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF1B4748)));
    }
    return RefreshIndicator(
      onRefresh: () async {
        _userAlerts = [];
        await _loadUserAlerts();
      },
      color: const Color(0xFF1B4748),
      child: ListView(
        children: [
          _sectionHeader('Current User Alerts'),
          if (_currentUserAlerts.isEmpty)
            _emptyState('No user alerts at the moment')
          else
            ..._currentUserAlerts.map((a) => _alertCard(
                  a as Map<String, dynamic>,
                  isSystem: false,
                  dismissed: false,
                )),
          _sectionHeader('Dismissed User Alerts'),
          if (_dismissedUserAlerts.isEmpty)
            _emptyState('No dismissed user alerts')
          else
            ..._dismissedUserAlerts.map((a) => _alertCard(
                  a as Map<String, dynamic>,
                  isSystem: false,
                  dismissed: true,
                )),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ─── Tab 2 — System Alerts ───────────────────────────────────────────────

  Widget _systemAlertsTab() {
    if (_loadingSystem) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF1B4748)));
    }
    return RefreshIndicator(
      onRefresh: () async {
        _systemAlerts = [];
        await _loadSystemAlerts();
      },
      color: const Color(0xFF1B4748),
      child: ListView(
        children: [
          _sectionHeader('Current System Alerts'),
          if (_currentSystemAlerts.isEmpty)
            _emptyState('No system alerts at the moment')
          else
            ..._currentSystemAlerts.map((a) => _alertCard(
                  a as Map<String, dynamic>,
                  isSystem: true,
                  dismissed: false,
                )),
          _sectionHeader('Dismissed System Alerts'),
          if (_dismissedSystemAlerts.isEmpty)
            _emptyState('No dismissed system alerts')
          else
            ..._dismissedSystemAlerts.map((a) => _alertCard(
                  a as Map<String, dynamic>,
                  isSystem: true,
                  dismissed: true,
                )),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ─── Shared widgets ──────────────────────────────────────────────────────

  Widget _sectionHeader(String title) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: const Color(0xFF1B4748),
        margin: const EdgeInsets.only(top: 4, bottom: 2),
        child: Text(title,
            style: const TextStyle(
                color: Color(0xFFF8BB25),
                fontWeight: FontWeight.bold,
                fontSize: 13)),
      );

  Widget _emptyState(String msg) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        color: Colors.white,
        child: Text(msg,
            style: const TextStyle(fontSize: 13, color: Color(0xFF1B4748))),
      );

  Widget _alertCard(
    Map<String, dynamic> alert, {
    required bool isSystem,
    required bool dismissed,
  }) {
    final alertType = alert['alert_type']?.toString();
    final detail = alert['detail']?.toString() ?? '';
    final createdAt = alert['created_at']?.toString();
    final dismissedAt = alert['dismissed_at']?.toString();
    final typeColor = _alertColor(alertType);
    final typeTextColor = _alertTextColor(alertType);
    final typeLabel = alertType != null && alertType.isNotEmpty
        ? alertType[0].toUpperCase() + alertType.substring(1)
        : '—';
    final truncatedDetail =
        detail.length > 120 ? '${detail.substring(0, 120)}...' : detail;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: dismissed ? Colors.grey.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: dismissed
                ? Colors.grey.shade200
                : typeColor.withValues(alpha: 0.3)),
        boxShadow: dismissed
            ? []
            : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: dismissed ? Colors.grey.shade300 : typeColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(typeLabel,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: dismissed ? Colors.black54 : typeTextColor)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(truncatedDetail,
                      style: TextStyle(
                          fontSize: 13,
                          color: dismissed ? Colors.black45 : Colors.black87)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _metaRow('Received', _formatDateTime(createdAt)),
                      if (dismissed && dismissedAt != null)
                        _metaRow('Dismissed', _formatDateTime(dismissedAt)),
                    ],
                  ),
                ),
                if (!dismissed)
                  ElevatedButton(
                    onPressed: () =>
                        _dismissAlert(alert['id'], isSystem: isSystem),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF48900),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                    ),
                    child: const Text('Dismiss',
                        style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                  text: '$label: ',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54)),
              TextSpan(
                  text: value,
                  style: const TextStyle(fontSize: 11, color: Colors.black87)),
            ],
          ),
        ),
      );
}
