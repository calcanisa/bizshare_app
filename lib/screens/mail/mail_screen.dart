import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';

class MailScreen extends StatefulWidget {
  const MailScreen({super.key});

  @override
  State<MailScreen> createState() => _MailScreenState();
}

class _MailScreenState extends State<MailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _inbox = [];
  List<dynamic> _sent = [];
  bool _loadingInbox = false;
  bool _loadingSent = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInbox();
    _tabController.addListener(() {
      if (_tabController.index == 1 && _sent.isEmpty) _loadSent();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInbox() async {
    setState(() => _loadingInbox = true);
    try {
      final api = context.read<ApiService>();
      final response = await api.dio.get('/api/v1/mail/inbox/');
      setState(() => _inbox = response.data['results'] ?? response.data ?? []);
    } catch (_) {}
    setState(() => _loadingInbox = false);
  }

  Future<void> _loadSent() async {
    setState(() => _loadingSent = true);
    try {
      final api = context.read<ApiService>();
      final response = await api.dio.get('/api/v1/mail/sent/');
      setState(() => _sent = response.data['results'] ?? response.data ?? []);
    } catch (_) {}
    setState(() => _loadingSent = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: const Color(0xFF094a25),
          child: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFFf8b324),
            labelColor: const Color(0xFFf8b324),
            unselectedLabelColor: Colors.white60,
            tabs: const [
              Tab(text: 'Inbox'),
              Tab(text: 'Sent'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _mailList(_inbox, _loadingInbox, _loadInbox),
              _mailList(_sent, _loadingSent, _loadSent),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mailList(
      List<dynamic> messages, bool loading, VoidCallback onRefresh) {
    if (loading)
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF094a25)));
    if (messages.isEmpty) return const Center(child: Text('No messages'));
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: const Color(0xFF094a25),
      child: ListView.builder(
        itemCount: messages.length,
        itemBuilder: (context, index) => _messageCard(messages[index]),
      ),
    );
  }

  Widget _messageCard(Map<String, dynamic> message) {
    final subject = message['subject'] ?? 'No subject';
    final body = message['body'] ?? message['message'] ?? '';
    final sender = message['sender']?['profile']?['first_name'] ??
        message['sender']?['email'] ??
        'Unknown';
    final date = message['created_at'] ?? '';
    final isRead = message['is_read'] ?? true;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color:
            isRead ? Colors.white : const Color(0xFF094a25).withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)
        ],
        border: isRead
            ? null
            : Border.all(color: const Color(0xFF094a25).withOpacity(0.2)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF094a25),
          child: Text(
            sender.isNotEmpty ? sender[0].toUpperCase() : '?',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          subject,
          style: TextStyle(
              fontWeight: isRead ? FontWeight.normal : FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sender,
                style: const TextStyle(fontSize: 12, color: Color(0xFF094a25))),
            Text(
              body.length > 60 ? '${body.substring(0, 60)}...' : body,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        trailing: Text(
          _formatDate(date),
          style: const TextStyle(fontSize: 11, color: Colors.black45),
        ),
        isThreeLine: true,
        onTap: () {},
      ),
    );
  }

  String _formatDate(String date) {
    if (date.isEmpty) return '';
    try {
      final d = DateTime.parse(date);
      final now = DateTime.now();
      if (d.day == now.day && d.month == now.month && d.year == now.year) {
        return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
      }
      return '${d.day}/${d.month}';
    } catch (_) {
      return '';
    }
  }
}
