import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../../providers/auth_provider.dart';

class SendMessageSheet extends StatefulWidget {
  final String origin;
  final String title;
  final int targetId;
  final String? recipientName;

  const SendMessageSheet({
    super.key,
    required this.origin,
    required this.title,
    required this.targetId,
    this.recipientName,
  });

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required String origin,
    required String title,
    required int targetId,
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
        targetId: targetId,
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

  @override
  void initState() {
    super.initState();
    _messageCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty) {
      _showError('Message cannot be empty.');
      return;
    }

    setState(() => _submitting = true);
    final auth = context.read<AuthProvider>();
    try {
      final res = await auth.apiService.dio.post(
        '/api/v1/mailbox/message/c/',
        data: {
          'origin': widget.origin,
          'target_id': widget.targetId,
          'message': text,
        },
      );
      if (!mounted) return;
      if (res.statusCode == 201) {
        Navigator.pop(context, Map<String, dynamic>.from(res.data as Map));
      }
    } on DioException catch (e) {
      final body = e.response?.data;
      _showError(body is Map && body['error'] != null
          ? body['error'].toString()
          : 'Could not send message. Try again.');
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
          Text(widget.title,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold, color: _green)),
          const SizedBox(height: 16),
          const Text('Recipient',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _green.withValues(alpha: 0.2)),
            ),
            child: Text(
              widget.recipientName ?? '',
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: _green),
            ),
          ),
          const SizedBox(height: 16),
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
