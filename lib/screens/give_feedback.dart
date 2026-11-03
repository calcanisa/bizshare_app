import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../../providers/auth_provider.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  static const _green = Color(0xFF1B4748);
  static const _red = Color(0xFFF48900);

  String? _subject;
  final _messageCtrl = TextEditingController();
  bool _accepted = false;
  bool _sending = false;

  static const _subjects = [
    ('suggestion', 'Suggestion'),
    ('problem', 'Problem'),
    ('feature', 'Feature Request'),
  ];

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_subject == null) {
      _showError('Please select a subject.');
      return;
    }
    if (_messageCtrl.text.trim().isEmpty) {
      _showError('Please provide some detail.');
      return;
    }
    if (!_accepted) {
      _showError('You must accept the terms to continue.');
      return;
    }

    setState(() => _sending = true);
    final auth = context.read<AuthProvider>();
    try {
      final res = await auth.apiService.dio.post(
        '/api/v1/users/feedback/',
        data: {
          'subject': _subject,
          'message': _messageCtrl.text.trim(),
        },
      );
      if (!mounted) return;
      if (res.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Thank you for your feedback!'),
          backgroundColor: _green,
        ));
        Navigator.pop(context);
      }
    } on DioException catch (e) {
      _showError(
          e.response?.data?['error'] ?? 'Could not send feedback. Try again.');
    } catch (_) {
      _showError('Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: _red));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        title: const Text('Give us Feedback'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Subject
              const Text('Subject',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _subject,
                    isExpanded: true,
                    hint: Text('Select',
                        style:
                            TextStyle(color: Colors.grey[400], fontSize: 13)),
                    icon: const Icon(Icons.keyboard_arrow_down,
                        color: _green, size: 20),
                    items: _subjects
                        .map((s) => DropdownMenuItem(
                            value: s.$1,
                            child: Text(s.$2,
                                style: const TextStyle(
                                    fontSize: 13, color: Colors.black87))))
                        .toList(),
                    onChanged: (v) => setState(() => _subject = v),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Message
              const Text('Detail',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87)),
              const SizedBox(height: 6),
              TextField(
                controller: _messageCtrl,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText:
                      'If it\'s an issue please provide as much detail as possible',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
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
              const SizedBox(height: 16),

              // Terms
              Row(
                children: [
                  Checkbox(
                    value: _accepted,
                    activeColor: _green,
                    onChanged: (v) => setState(() => _accepted = v ?? false),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _accepted = !_accepted),
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(fontSize: 13, color: Colors.black87),
                        children: [
                          TextSpan(text: 'I accept the '),
                          TextSpan(
                            text: 'terms',
                            style: TextStyle(
                              color: _green,
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(text: '.'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _sending ? null : _send,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _sending
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
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
