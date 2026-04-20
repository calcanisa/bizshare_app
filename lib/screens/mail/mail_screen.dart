import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';

class MailScreen extends StatefulWidget {
  const MailScreen({super.key});

  @override
  State<MailScreen> createState() => _MailScreenState();
}

class _MailScreenState extends State<MailScreen> {
  int _tab = 1;
  int? _accountId;

  // Data
  List<dynamic> _inbox = [];
  List<dynamic> _filteredInbox = [];
  List<dynamic> _sent = [];
  List<dynamic> _filteredSent = [];
  List<dynamic> _trash = [];

  // Loading
  bool _loadingInbox = false;
  bool _loadingSent = false;
  bool _loadingTrash = false;

  // Bulk selection
  final Set<int> _selectedReceived = {};
  final Set<int> _selectedSent = {};
  final Set<int> _selectedTrash = {};

  // Filters
  String? _originFilter;
  DateTime? _dateFromReceived;
  DateTime? _dateFromSent;

  static const _originOptions = [
    'business',
    'classifieds',
    'events',
    'jobs',
    'leads',
    'system'
  ];

  @override
  void initState() {
    super.initState();
    _loadAccount();
    _loadInbox();
  }

  Future<void> _loadAccount() async {
    try {
      final api = context.read<ApiService>();
      final res = await api.dio.get('/api/v1/users/current/');
      setState(() => _accountId = res.data['id']);
    } catch (_) {}
  }

  Future<void> _loadInbox() async {
    if (_loadingInbox) return;
    setState(() => _loadingInbox = true);
    try {
      final api = context.read<ApiService>();
      final res = await api.dio.get('/api/v1/mailbox/inbox/');
      final data = res.data is List ? res.data : (res.data['results'] ?? []);
      setState(() {
        _inbox = data;
        _filteredInbox = data;
      });
    } catch (_) {
      _showSnack('Could not load messages. Try again.');
    }
    setState(() => _loadingInbox = false);
  }

  Future<void> _loadSent() async {
    if (_loadingSent || _sent.isNotEmpty) return;
    setState(() => _loadingSent = true);
    try {
      final api = context.read<ApiService>();
      final res = await api.dio.get('/api/v1/mailbox/sent/');
      final raw = res.data;
      final data =
          raw is List ? raw : (raw['messages'] ?? raw['results'] ?? []);
      setState(() {
        _sent = data;
        _filteredSent = data;
      });
    } catch (_) {
      _showSnack('Could not load sent messages. Try again.');
    }
    setState(() => _loadingSent = false);
  }

  Future<void> _loadTrash() async {
    if (_loadingTrash || _trash.isNotEmpty) return;
    setState(() => _loadingTrash = true);
    try {
      final api = context.read<ApiService>();
      final res = await api.dio.get('/api/v1/mailbox/trash/');
      final data = res.data is List ? res.data : (res.data['results'] ?? []);
      setState(() => _trash = data);
    } catch (_) {
      _showSnack('Could not load trash. Try again.');
    }
    setState(() => _loadingTrash = false);
  }

  Future<void> _markReadStatus(int id, bool read) async {
    try {
      final api = context.read<ApiService>();
      await api.dio
          .post('/api/v1/mailbox/message/$id/mark/', data: {'read': read});
      setState(() {
        final msg = _inbox.firstWhere((m) => m['id'] == id, orElse: () => null);
        if (msg != null) msg['read'] = read;
        final fMsg =
            _filteredInbox.firstWhere((m) => m['id'] == id, orElse: () => null);
        if (fMsg != null) fMsg['read'] = read;
      });
    } catch (_) {
      _showSnack('Could not update read status.');
    }
  }

  Future<void> _trashMessage(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Move this message to trash?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final api = context.read<ApiService>();
      await api.dio.post('/api/v1/mailbox/message/$id/d/');
      setState(() {
        _inbox.removeWhere((m) => m['id'] == id);
        _filteredInbox.removeWhere((m) => m['id'] == id);
      });
      if (mounted) Navigator.of(context).pop(); // close read sheet
    } catch (_) {
      _showSnack('Could not delete message. Try again.');
    }
  }

  Future<void> _sendReply(int msgId, int receiverId, String replyText) async {
    if (replyText.trim().isEmpty) {
      _showSnack('Reply message cannot be empty');
      return;
    }
    try {
      final api = context.read<ApiService>();
      final res = await api.dio.post(
        '/api/v1/mailbox/message/$msgId/reply/c/',
        data: {
          'reply_text': replyText,
          'sender': _accountId,
          'receiver': receiverId,
          'message': msgId,
        },
      );
      if (res.statusCode == 201) {
        setState(() {
          final msg =
              _inbox.firstWhere((m) => m['id'] == msgId, orElse: () => null);
          if (msg != null) {
            (msg['replies'] as List?)?.add(res.data);
          }
        });
        _showSnack('Reply sent');
      }
    } catch (_) {
      _showSnack('Could not send reply. Try again.');
    }
  }

  Future<void> _performBulkAction(String action, String mailType) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Action'),
        content: Text('Perform "$action" on selected messages?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes')),
        ],
      ),
    );
    if (confirm != true) return;

    final selected = mailType == 'received'
        ? List<int>.from(_selectedReceived)
        : mailType == 'sent'
            ? List<int>.from(_selectedSent)
            : List<int>.from(_selectedTrash);

    for (final id in selected) {
      try {
        final api = context.read<ApiService>();
        if (action == 'markread') {
          await _markReadStatus(id, true);
        } else if (action == 'markunread') {
          await _markReadStatus(id, false);
        } else if (action == 'delete') {
          await api.dio.post('/api/v1/mailbox/message/$id/d/');
          setState(() {
            _inbox.removeWhere((m) => m['id'] == id);
            _filteredInbox.removeWhere((m) => m['id'] == id);
            _sent.removeWhere((m) => m['id'] == id);
            _filteredSent.removeWhere((m) => m['id'] == id);
            _trash.removeWhere((m) => m['id'] == id);
          });
        } else if (action == 'restore') {
          await api.dio.post('/api/v1/mailbox/message/$id/restore/');
          setState(() => _trash.removeWhere((m) => m['id'] == id));
        }
      } catch (_) {}
    }

    setState(() {
      _selectedReceived.clear();
      _selectedSent.clear();
      _selectedTrash.clear();
    });
    _showSnack('Done');
  }

  Future<void> _emptyTrash() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Empty Trash'),
        content: const Text('Permanently delete all messages in trash?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Empty', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final api = context.read<ApiService>();
      await api.dio.delete('/api/v1/mailbox/empty/');
      setState(() => _trash.clear());
      _showSnack('Trash emptied');
    } catch (_) {
      _showSnack('Could not empty trash. Try again.');
    }
  }

  void _applyInboxFilters() {
    setState(() {
      _filteredInbox = _inbox.where((m) {
        final matchOrigin =
            _originFilter == null || m['origin'] == _originFilter;
        final matchDate = _dateFromReceived == null ||
            DateTime.tryParse(m['created_at'] ?? '')
                    ?.isAfter(_dateFromReceived!) ==
                true;
        return matchOrigin && matchDate;
      }).toList();
    });
  }

  void _applySentFilters() {
    setState(() {
      _filteredSent = _sent.where((m) {
        return _dateFromSent == null ||
            DateTime.tryParse(m['created_at'] ?? '')?.isAfter(_dateFromSent!) ==
                true;
      }).toList();
    });
  }

  void _resetFilters() {
    setState(() {
      _originFilter = null;
      _dateFromReceived = null;
      _dateFromSent = null;
      _filteredInbox = _inbox;
      _filteredSent = _sent;
    });
  }

  void _openMessage(Map<String, dynamic> msg, {bool isSent = false}) async {
    if (!isSent && msg['read'] != true) {
      await _markReadStatus(msg['id'], true);
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => _ReadMessageSheet(
        message: msg,
        isSent: isSent,
        onTrash: isSent ? null : () => _trashMessage(msg['id']),
        onReply: isSent
            ? null
            : (replyText) => _sendReply(
                  msg['id'],
                  msg['sender']?['id'],
                  replyText,
                ),
      ),
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return '';
    final local = dt.toLocal();
    final now = DateTime.now();
    if (local.day == now.day &&
        local.month == now.month &&
        local.year == now.year) {
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }
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
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${local.day} ${months[local.month]}';
  }

  String _senderName(Map<String, dynamic>? sender) {
    if (sender == null) return 'Unknown';
    final profile = sender['profile'] as Map<String, dynamic>?;
    final first = profile?['first_name'] ?? sender['first_name'] ?? '';
    final last = profile?['last_name'] ?? sender['last_name'] ?? '';
    if (first.isNotEmpty || last.isNotEmpty) return '$first $last'.trim();
    return sender['email']?.toString() ?? 'User ${sender['id']}';
  }

  String _receiverName(Map<String, dynamic>? receiver) {
    if (receiver == null) return 'Unknown';
    final profile = receiver['profile'] as Map<String, dynamic>?;
    final first = profile?['first_name'] ?? '';
    final last = profile?['last_name'] ?? '';
    if (first.isNotEmpty || last.isNotEmpty) return '$first $last'.trim();
    return 'User ${receiver['id']}';
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: const Color(0xFF094a25),
          child: Row(
            children: [
              _tabBtn(1, 'Received'),
              _tabBtn(2, 'Sent'),
              _tabBtn(3, 'Trash'),
            ],
          ),
        ),
        Expanded(
          child: _tab == 1
              ? _receivedTab()
              : _tab == 2
                  ? _sentTab()
                  : _trashTab(),
        ),
      ],
    );
  }

  Widget _tabBtn(int index, String label) {
    final active = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _tab = index);
          if (index == 2) _loadSent();
          if (index == 3) _loadTrash();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          color: active ? Colors.white : const Color(0xFF094a25),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: active ? const Color(0xFF094a25) : Colors.white60,
                fontSize: 13,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              )),
        ),
      ),
    );
  }

  // ─── Tab 1 — Received ────────────────────────────────────────────────────

  Widget _receivedTab() {
    return Column(
      children: [
        _receivedFilterBar(),
        if (_selectedReceived.isNotEmpty) _bulkActionBar('received'),
        Expanded(
          child: _loadingInbox
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF094a25)))
              : _filteredInbox.isEmpty
                  ? const Center(
                      child: Text('No messages',
                          style: TextStyle(color: Color(0xFF094a25))))
                  : RefreshIndicator(
                      onRefresh: () async {
                        _inbox = [];
                        _filteredInbox = [];
                        await _loadInbox();
                      },
                      color: const Color(0xFF094a25),
                      child: ListView.builder(
                        itemCount: _filteredInbox.length,
                        itemBuilder: (ctx, i) => _inboxCard(
                            _filteredInbox[i] as Map<String, dynamic>),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _receivedFilterBar() {
    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          // Origin filter
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _originFilter,
                  hint: const Text('Origin', style: TextStyle(fontSize: 12)),
                  isDense: true,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF094a25)),
                  items: [
                    const DropdownMenuItem(
                        value: null,
                        child: Text('All Origins',
                            style: TextStyle(color: Colors.black45))),
                    ..._originOptions.map((o) => DropdownMenuItem(
                          value: o,
                          child: Text(o[0].toUpperCase() + o.substring(1)),
                        )),
                  ],
                  onChanged: (v) {
                    setState(() => _originFilter = v);
                    _applyInboxFilters();
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Date from
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _dateFromReceived ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme:
                        const ColorScheme.light(primary: Color(0xFF094a25)),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) {
                setState(() => _dateFromReceived = picked);
                _applyInboxFilters();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                border: Border.all(
                    color: _dateFromReceived != null
                        ? const Color(0xFF094a25)
                        : Colors.black12),
                borderRadius: BorderRadius.circular(6),
                color: _dateFromReceived != null
                    ? const Color(0xFF094a25).withOpacity(0.08)
                    : null,
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 13,
                      color: _dateFromReceived != null
                          ? const Color(0xFF094a25)
                          : Colors.black45),
                  const SizedBox(width: 4),
                  Text(
                    _dateFromReceived != null
                        ? '${_dateFromReceived!.day}/${_dateFromReceived!.month}/${_dateFromReceived!.year}'
                        : 'From',
                    style: TextStyle(
                        fontSize: 12,
                        color: _dateFromReceived != null
                            ? const Color(0xFF094a25)
                            : Colors.black45),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Reset
          if (_originFilter != null || _dateFromReceived != null)
            GestureDetector(
              onTap: _resetFilters,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF094a25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Reset',
                    style: TextStyle(fontSize: 12, color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _inboxCard(Map<String, dynamic> msg) {
    final id = msg['id'] as int;
    final isRead = msg['read'] == true;
    final isSelected = _selectedReceived.contains(id);
    final body = msg['message']?.toString() ?? '';
    final sender = _senderName(msg['sender'] as Map<String, dynamic>?);
    final origin = msg['origin']?.toString() ?? '';
    final hasReplies = (msg['replies'] as List?)?.isNotEmpty == true;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF094a25).withOpacity(0.08)
            : isRead
                ? Colors.white
                : const Color(0xFF094a25).withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: isSelected
                ? const Color(0xFF094a25).withOpacity(0.4)
                : isRead
                    ? Colors.grey.shade200
                    : const Color(0xFF094a25).withOpacity(0.2)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _openMessage(msg),
        onLongPress: () => setState(() {
          if (isSelected)
            _selectedReceived.remove(id);
          else
            _selectedReceived.add(id);
        }),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              // Checkbox (visible when any selected)
              if (_selectedReceived.isNotEmpty)
                Checkbox(
                  value: isSelected,
                  activeColor: const Color(0xFF094a25),
                  onChanged: (v) => setState(() {
                    if (v == true)
                      _selectedReceived.add(id);
                    else
                      _selectedReceived.remove(id);
                  }),
                )
              else
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF094a25),
                  child: Text(
                    sender.isNotEmpty ? sender[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(sender,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isRead
                                      ? FontWeight.normal
                                      : FontWeight.bold,
                                  color: const Color(0xFF094a25))),
                        ),
                        Text(_formatDate(msg['created_at']?.toString()),
                            style: const TextStyle(
                                fontSize: 11, color: Colors.black45)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body.length > 60 ? '${body.substring(0, 60)}...' : body,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                          fontWeight:
                              isRead ? FontWeight.normal : FontWeight.w500),
                    ),
                    if (origin.isNotEmpty || hasReplies)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Row(
                          children: [
                            if (origin.isNotEmpty)
                              _pill(
                                  origin[0].toUpperCase() + origin.substring(1),
                                  Colors.blueGrey),
                            if (hasReplies) ...[
                              const SizedBox(width: 4),
                              _pill('Replied', const Color(0xFF094a25)),
                            ],
                            if (!isRead) ...[
                              const SizedBox(width: 4),
                              _pill('Unread', const Color(0xFFbc2023)),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Tab 2 — Sent ────────────────────────────────────────────────────────

  Widget _sentTab() {
    return Column(
      children: [
        _sentFilterBar(),
        if (_selectedSent.isNotEmpty) _bulkActionBar('sent'),
        Expanded(
          child: _loadingSent
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF094a25)))
              : _filteredSent.isEmpty
                  ? const Center(
                      child: Text('No sent messages',
                          style: TextStyle(color: Color(0xFF094a25))))
                  : RefreshIndicator(
                      onRefresh: () async {
                        _sent = [];
                        _filteredSent = [];
                        await _loadSent();
                      },
                      color: const Color(0xFF094a25),
                      child: ListView.builder(
                        itemCount: _filteredSent.length,
                        itemBuilder: (ctx, i) =>
                            _sentCard(_filteredSent[i] as Map<String, dynamic>),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _sentFilterBar() {
    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _dateFromSent ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme:
                        const ColorScheme.light(primary: Color(0xFF094a25)),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) {
                setState(() => _dateFromSent = picked);
                _applySentFilters();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                border: Border.all(
                    color: _dateFromSent != null
                        ? const Color(0xFF094a25)
                        : Colors.black12),
                borderRadius: BorderRadius.circular(6),
                color: _dateFromSent != null
                    ? const Color(0xFF094a25).withOpacity(0.08)
                    : null,
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 13,
                      color: _dateFromSent != null
                          ? const Color(0xFF094a25)
                          : Colors.black45),
                  const SizedBox(width: 4),
                  Text(
                    _dateFromSent != null
                        ? '${_dateFromSent!.day}/${_dateFromSent!.month}/${_dateFromSent!.year}'
                        : 'From date',
                    style: TextStyle(
                        fontSize: 12,
                        color: _dateFromSent != null
                            ? const Color(0xFF094a25)
                            : Colors.black45),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (_dateFromSent != null)
            GestureDetector(
              onTap: () {
                setState(() => _dateFromSent = null);
                _applySentFilters();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF094a25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Reset',
                    style: TextStyle(fontSize: 12, color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sentCard(Map<String, dynamic> msg) {
    final id = msg['id'] as int;
    final isRead = msg['read'] == true;
    final isSelected = _selectedSent.contains(id);
    final body = msg['message']?.toString() ?? '';
    final receiver = _receiverName(msg['receiver'] as Map<String, dynamic>?);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF094a25).withOpacity(0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: isSelected
                ? const Color(0xFF094a25).withOpacity(0.4)
                : Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _openMessage(msg, isSent: true),
        onLongPress: () => setState(() {
          if (isSelected)
            _selectedSent.remove(id);
          else
            _selectedSent.add(id);
        }),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              if (_selectedSent.isNotEmpty)
                Checkbox(
                  value: isSelected,
                  activeColor: const Color(0xFF094a25),
                  onChanged: (v) => setState(() {
                    if (v == true)
                      _selectedSent.add(id);
                    else
                      _selectedSent.remove(id);
                  }),
                )
              else
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.blueGrey,
                  child: Icon(Icons.send, size: 14, color: Colors.white),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('To: $receiver',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF094a25))),
                        ),
                        Text(_formatDate(msg['created_at']?.toString()),
                            style: const TextStyle(
                                fontSize: 11, color: Colors.black45)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body.length > 60 ? '${body.substring(0, 60)}...' : body,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    if (isRead)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: _pill('Read', Colors.teal),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Tab 3 — Trash ───────────────────────────────────────────────────────

  Widget _trashTab() {
    return Column(
      children: [
        _trashActionBar(),
        if (_selectedTrash.isNotEmpty) _bulkActionBar('trash'),
        Expanded(
          child: _loadingTrash
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF094a25)))
              : _trash.isEmpty
                  ? const Center(
                      child: Text('Trash is empty',
                          style: TextStyle(color: Color(0xFF094a25))))
                  : RefreshIndicator(
                      onRefresh: () async {
                        _trash = [];
                        await _loadTrash();
                      },
                      color: const Color(0xFF094a25),
                      child: ListView.builder(
                        itemCount: _trash.length,
                        itemBuilder: (ctx, i) =>
                            _trashCard(_trash[i] as Map<String, dynamic>),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _trashActionBar() {
    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Text(
              '${_trash.length} message${_trash.length == 1 ? '' : 's'} in trash',
              style: const TextStyle(fontSize: 12, color: Colors.black45)),
          const Spacer(),
          if (_trash.isNotEmpty)
            ElevatedButton.icon(
              onPressed: _emptyTrash,
              icon: const Icon(Icons.delete_forever, size: 15),
              label: const Text('Empty Trash', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFbc2023),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
            ),
        ],
      ),
    );
  }

  Widget _trashCard(Map<String, dynamic> msg) {
    final id = msg['id'] as int;
    final isSelected = _selectedTrash.contains(id);
    final body = msg['message']?.toString() ?? '';
    final sender = _senderName(msg['sender'] as Map<String, dynamic>?);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF094a25).withOpacity(0.08)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: isSelected
                ? const Color(0xFF094a25).withOpacity(0.4)
                : Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onLongPress: () => setState(() {
          if (isSelected)
            _selectedTrash.remove(id);
          else
            _selectedTrash.add(id);
        }),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              if (_selectedTrash.isNotEmpty)
                Checkbox(
                  value: isSelected,
                  activeColor: const Color(0xFF094a25),
                  onChanged: (v) => setState(() {
                    if (v == true)
                      _selectedTrash.add(id);
                    else
                      _selectedTrash.remove(id);
                  }),
                )
              else
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey,
                  child:
                      Icon(Icons.delete_outline, size: 14, color: Colors.white),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(sender,
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.black54)),
                        ),
                        Text(_formatDate(msg['created_at']?.toString()),
                            style: const TextStyle(
                                fontSize: 11, color: Colors.black45)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body.length > 60 ? '${body.substring(0, 60)}...' : body,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black45),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                          'Deleted: ${_formatDate(msg['updated_at']?.toString())}',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.black38)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Bulk action bar ─────────────────────────────────────────────────────

  Widget _bulkActionBar(String mailType) {
    final count = mailType == 'received'
        ? _selectedReceived.length
        : mailType == 'sent'
            ? _selectedSent.length
            : _selectedTrash.length;

    final isTrash = mailType == 'trash';

    return Container(
      color: const Color(0xFF094a25).withOpacity(0.08),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Text('$count selected',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF094a25))),
          const Spacer(),
          if (!isTrash) ...[
            _actionBtn(
                'Mark Read', () => _performBulkAction('markread', mailType)),
            const SizedBox(width: 6),
            _actionBtn(
                'Unread', () => _performBulkAction('markunread', mailType)),
            const SizedBox(width: 6),
          ],
          if (isTrash) ...[
            _actionBtn(
                'Restore', () => _performBulkAction('restore', mailType)),
            const SizedBox(width: 6),
          ],
          _actionBtn(
            isTrash ? 'Delete Permanently' : 'Delete',
            () => _performBulkAction('delete', mailType),
            isDestructive: true,
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => setState(() {
              _selectedReceived.clear();
              _selectedSent.clear();
              _selectedTrash.clear();
            }),
            child: const Icon(Icons.close, size: 18, color: Colors.black45),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(String label, VoidCallback onTap,
          {bool isDestructive = false}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: isDestructive
                ? const Color(0xFFbc2023)
                : const Color(0xFF094a25),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.white)),
        ),
      );

  Widget _pill(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10, color: color, fontWeight: FontWeight.bold)),
      );
}

// ─── Read Message Bottom Sheet ───────────────────────────────────────────────

class _ReadMessageSheet extends StatefulWidget {
  final Map<String, dynamic> message;
  final bool isSent;
  final VoidCallback? onTrash;
  final Future<void> Function(String)? onReply;

  const _ReadMessageSheet({
    required this.message,
    required this.isSent,
    this.onTrash,
    this.onReply,
  });

  @override
  State<_ReadMessageSheet> createState() => _ReadMessageSheetState();
}

class _ReadMessageSheetState extends State<_ReadMessageSheet> {
  bool _replying = false;
  bool _sending = false;
  final _replyController = TextEditingController();

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  String _personName(Map<String, dynamic>? person) {
    if (person == null) return 'Unknown';
    final profile = person['profile'] as Map<String, dynamic>?;
    final first = profile?['first_name'] ?? person['first_name'] ?? '';
    final last = profile?['last_name'] ?? person['last_name'] ?? '';
    if (first.isNotEmpty || last.isNotEmpty) return '$first $last'.trim();
    return person['email']?.toString() ?? 'User ${person['id']}';
  }

  @override
  Widget build(BuildContext context) {
    final msg = widget.message;
    final body = msg['message']?.toString() ?? '';
    final replies = msg['replies'] as List? ?? [];
    final person = widget.isSent
        ? msg['receiver'] as Map<String, dynamic>?
        : msg['sender'] as Map<String, dynamic>?;
    final personName = _personName(person);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF094a25),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.isSent ? 'To: $personName' : 'From: $personName',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (!widget.isSent) ...[
                    if (!_replying)
                      TextButton(
                        onPressed: () => setState(() => _replying = true),
                        child: const Text('Reply',
                            style: TextStyle(color: Color(0xFFf8b324))),
                      ),
                    if (widget.onTrash != null)
                      TextButton(
                        onPressed: widget.onTrash,
                        child: const Text('Trash',
                            style: TextStyle(color: Color(0xFFbc2023))),
                      ),
                  ],
                ],
              ),
            ),
            // Body
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  // Message body
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(body,
                        style: const TextStyle(
                            fontSize: 14, color: Colors.black87, height: 1.5)),
                  ),
                  // Reply box
                  if (_replying) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _replyController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Enter your reply...',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFF094a25)),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _sending
                                ? null
                                : () async {
                                    setState(() => _sending = true);
                                    await widget.onReply
                                        ?.call(_replyController.text);
                                    setState(() {
                                      _sending = false;
                                      _replying = false;
                                      _replyController.clear();
                                    });
                                  },
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF094a25)),
                            child: _sending
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : const Text('Send',
                                    style: TextStyle(color: Colors.white)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() {
                              _replying = false;
                              _replyController.clear();
                            }),
                            style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF094a25)),
                            child: const Text('Cancel'),
                          ),
                        ),
                      ],
                    ),
                  ],
                  // Existing replies
                  if (replies.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('Replies',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF094a25))),
                    const SizedBox(height: 8),
                    ...replies.map((r) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF094a25).withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color:
                                    const Color(0xFF094a25).withOpacity(0.15)),
                          ),
                          child: Text(r['reply_text']?.toString() ?? '',
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.black87)),
                        )),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
