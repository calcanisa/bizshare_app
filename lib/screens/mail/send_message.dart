import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../../providers/auth_provider.dart';

class SendMessageSheet extends StatefulWidget {
  final String origin; // 'business' | 'event' | 'leads' | 'profile' | 'mail'
  final String title;
  final int? recipientId; // pre-set recipient (business/event/profile/leads)
  final String? recipientName; // display name for pre-set recipient

  const SendMessageSheet({
    super.key,
    required this.origin,
    required this.title,
    this.recipientId,
    this.recipientName,
  });

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required String origin,
    required String title,
    int? recipientId,
    String? recipientName,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SendMessageSheet(
        origin: origin,
        title: title,
        recipientId: recipientId,
        recipientName: recipientName,
      ),
    );
  }

  @override
  State<SendMessageSheet> createState() => _SendMessageSheetState();
}

class _SendMessageSheetState extends State<SendMessageSheet> {
  static const _green = Color(0xFF1B4748);
  static const _red = Color(0xFFF48900);
  static const _msgLimit = 1000;

  final _messageCtrl = TextEditingController();
  bool _submitting = false;
  bool _loadingConnections = false;

  // For mail origin — pick from connections
  List<dynamic> _connections = [];
  int? _selectedRecipientId;
  String? _selectedRecipientName;

  @override
  void initState() {
    super.initState();
    _selectedRecipientId = widget.recipientId;
    _selectedRecipientName = widget.recipientName;
    _messageCtrl.addListener(() => setState(() {}));
    if (widget.origin == 'mail') _loadConnections();
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadConnections() async {
    setState(() => _loadingConnections = true);
    final auth = context.read<AuthProvider>();
    try {
      final res = await auth.apiService.dio.get('/api/v1/connections/current/');
      setState(() {
        _connections =
            res.data is List ? res.data : (res.data['results'] ?? []);
      });
    } catch (_) {
      _showError('Could not load connections. Try again.');
    }
    setState(() => _loadingConnections = false);
  }

  Future<void> _send() async {
    if (_selectedRecipientId == null) {
      _showError('You must choose a recipient.');
      return;
    }
    if (_messageCtrl.text.trim().isEmpty) {
      _showError('Message cannot be empty.');
      return;
    }

    setState(() => _submitting = true);
    final auth = context.read<AuthProvider>();
    try {
      final res = await auth.apiService.dio.post(
        '/api/v1/mailbox/message/c/',
        data: {
          'receiver': _selectedRecipientId,
          'message': _messageCtrl.text.trim(),
          'origin': widget.origin,
          'name': _selectedRecipientName ?? '',
        },
      );
      if (!mounted) return;
      if (res.statusCode == 201) {
        Navigator.pop(context, res.data);
      }
    } on DioException catch (e) {
      _showError(
          e.response?.data?['error'] ?? 'Could not send message. Try again.');
    } catch (_) {
      _showError('Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: _red));

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(widget.title,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold, color: _green)),
          const SizedBox(height: 16),

          // Recipient
          const Text('Recipient',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87)),
          const SizedBox(height: 6),

          // Mail origin — dropdown of connections
          if (widget.origin == 'mail') ...[
            _loadingConnections
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(
                          color: _green, strokeWidth: 2),
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedRecipientId,
                        isExpanded: true,
                        hint: Text('Choose a connection',
                            style: TextStyle(
                                color: Colors.grey[400], fontSize: 13)),
                        icon: const Icon(Icons.keyboard_arrow_down,
                            color: _green, size: 20),
                        items: _connections.map((c) {
                          final profile = c['profile'] as Map?;
                          final name = profile != null
                              ? '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}'
                                  .trim()
                              : 'No profile';
                          return DropdownMenuItem<int>(
                            value: c['id'] as int,
                            child: Text(name,
                                style: const TextStyle(
                                    fontSize: 13, color: Colors.black87)),
                          );
                        }).toList(),
                        onChanged: (v) {
                          setState(() {
                            _selectedRecipientId = v;
                            final conn = _connections.firstWhere(
                                (c) => c['id'] == v,
                                orElse: () => null);
                            if (conn != null) {
                              final profile = conn['profile'] as Map?;
                              _selectedRecipientName = profile != null
                                  ? '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}'
                                      .trim()
                                  : '';
                            }
                          });
                        },
                      ),
                    ),
                  ),
          ] else ...[
            // Pre-set recipient — just show the name
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: _green.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _green.withValues(alpha: 0.2)),
              ),
              child: Text(
                _selectedRecipientName ?? '—',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600, color: _green),
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Message
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Message',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87)),
              Text('${_messageCtrl.text.length} / $_msgLimit',
                  style: TextStyle(
                      fontSize: 11,
                      color: _messageCtrl.text.length >= _msgLimit
                          ? _red
                          : Colors.grey[400])),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _messageCtrl,
            maxLines: 5,
            maxLength: _msgLimit,
            buildCounter: (_,
                    {required currentLength, required isFocused, maxLength}) =>
                const SizedBox.shrink(),
            decoration: InputDecoration(
              hintText: '1000 character limit',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _green, width: 1.5)),
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 20),

          // Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _submitting ? null : _send,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Send',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _red,
                    side: const BorderSide(color: _red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Cancel',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
