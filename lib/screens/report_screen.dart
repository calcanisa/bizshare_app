import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../../providers/auth_provider.dart';

class ReportScreen extends StatefulWidget {
  final int contentId;
  final String type; // e.g. 'businesses', 'jobs', 'projects', 'events'

  const ReportScreen({
    super.key,
    required this.contentId,
    required this.type,
  });

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  static const _green = Color(0xFF1B4748);
  static const _red = Color(0xFFF48900);

  static const _reasons = [
    ('bullying', 'Bullying'),
    ('explicit', 'Explicit'),
    ('fake', 'Fake'),
    ('iptheft', 'IP Theft'),
    ('offensive', 'Offensive'),
    ('other', 'Other'),
    ('plagiarism', 'Plagiarism'),
    ('racism', 'Racism'),
    ('sexism', 'Sexism'),
    ('wrong', 'Wrong Category'),
  ];

  String? _reason;
  final _detailCtrl = TextEditingController();
  bool _accepted = false;
  bool _saving = false;
  int _detailLen = 0;

  @override
  void initState() {
    super.initState();
    _detailCtrl.addListener(
        () => setState(() => _detailLen = _detailCtrl.text.length));
  }

  @override
  void dispose() {
    _detailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reason == null) {
      _showError('Please choose a reason.');
      return;
    }
    if (!_accepted) {
      _showError('You must accept the terms to continue.');
      return;
    }

    setState(() => _saving = true);
    final auth = context.read<AuthProvider>();
    try {
      final res = await auth.apiService.dio.post(
        '/api/v1/${widget.type}/r/',
        data: {
          'id': widget.contentId,
          'reason': _reason,
          'description': _detailCtrl.text.trim(),
        },
      );
      if (!mounted) return;
      if (res.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Report submitted. Thank you.'),
          backgroundColor: _green,
        ));
        Navigator.pop(context, true);
      }
    } on DioException catch (e) {
      _showError(
          e.response?.data?['error'] ?? 'Could not submit report. Try again.');
    } catch (_) {
      _showError('Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
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
        title: Text(
          'Report this ${widget.type.replaceAll(RegExp(r's$'), '')}',
          style: const TextStyle(fontSize: 15),
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Reason dropdown
              const Text('Choose a Reason',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _green)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _reason,
                    isExpanded: true,
                    hint: Text('Select',
                        style:
                            TextStyle(color: Colors.grey[400], fontSize: 13)),
                    icon: const Icon(Icons.keyboard_arrow_down,
                        color: _green, size: 20),
                    items: _reasons
                        .map((r) => DropdownMenuItem(
                            value: r.$1,
                            child: Text(r.$2,
                                style: const TextStyle(
                                    fontSize: 13, color: Colors.black87))))
                        .toList(),
                    onChanged: (v) => setState(() => _reason = v),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Detail
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Give us detail please',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _green)),
                  Text('$_detailLen / 500',
                      style: TextStyle(
                          fontSize: 11,
                          color: _detailLen >= 500 ? _red : Colors.grey[400])),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _detailCtrl,
                maxLines: 5,
                maxLength: 500,
                buildCounter: (_,
                        {required currentLength,
                        required isFocused,
                        maxLength}) =>
                    const SizedBox.shrink(),
                decoration: InputDecoration(
                  hintText:
                      'Posting false reports counts against your reputation',
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
              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Report',
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
