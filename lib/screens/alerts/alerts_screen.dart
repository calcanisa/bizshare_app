import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  List<dynamic> _alerts = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      final response = await api.dio.get('/api/v1/alerts/');
      setState(() => _alerts = response.data['results'] ?? response.data ?? []);
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _dismissAlert(int id) async {
    try {
      final api = context.read<ApiService>();
      await api.dio.post('/api/v1/alerts/$id/dismiss/');
      setState(() {
        _alerts = _alerts.map((a) {
          if (a['id'] == id) return {...a, 'dismissed': true};
          return a;
        }).toList();
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF094a25)));
    if (_alerts.isEmpty) return const Center(child: Text('No alerts'));
    return RefreshIndicator(
      onRefresh: _loadAlerts,
      color: const Color(0xFF094a25),
      child: ListView.builder(
        itemCount: _alerts.length,
        itemBuilder: (context, index) => _alertCard(_alerts[index]),
      ),
    );
  }

  Widget _alertCard(Map<String, dynamic> alert) {
    final title = alert['title'] ?? '';
    final detail = alert['detail'] ?? '';
    final dismissed = alert['dismissed'] ?? false;
    final id = alert['id'];
    final type = alert['alert_type'] ?? 'info';

    Color alertColor;
    IconData alertIcon;
    switch (type) {
      case 'warning':
        alertColor = Colors.orange;
        alertIcon = Icons.warning_outlined;
        break;
      case 'error':
        alertColor = Colors.red;
        alertIcon = Icons.error_outline;
        break;
      case 'success':
        alertColor = Colors.green;
        alertIcon = Icons.check_circle_outline;
        break;
      default:
        alertColor = const Color(0xFF094a25);
        alertIcon = Icons.info_outline;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: dismissed ? Colors.grey.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)
        ],
        border: Border(
            left: BorderSide(
                color: dismissed ? Colors.grey : alertColor, width: 4)),
      ),
      child: ListTile(
        leading: Icon(alertIcon, color: dismissed ? Colors.grey : alertColor),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: dismissed ? Colors.grey : Colors.black87,
          ),
        ),
        subtitle: Text(detail,
            style: TextStyle(color: dismissed ? Colors.grey : Colors.black54)),
        trailing: dismissed
            ? const Icon(Icons.check, color: Colors.grey, size: 18)
            : TextButton(
                onPressed: () => _dismissAlert(id),
                child: const Text('Dismiss',
                    style: TextStyle(color: Color(0xFF094a25), fontSize: 12)),
              ),
      ),
    );
  }
}
