import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import '../../providers/auth_provider.dart';

class JobApplicationScreen extends StatefulWidget {
  final Map<String, dynamic> job;

  const JobApplicationScreen({super.key, required this.job});

  @override
  State<JobApplicationScreen> createState() => _JobApplicationScreenState();
}

class _JobApplicationScreenState extends State<JobApplicationScreen> {
  static const _green = Color(0xFF1B4748);
  static const _red = Color(0xFFF48900);
  static const _yellow = Color(0xFFF8BB25);

  final _pitchCtrl = TextEditingController();
  bool _appAccepted = false;
  bool _submitting = false;

  // CV file
  File? _cvFile;
  String? _cvFileName;

  // Exam state
  bool _examCompleted = false;
  bool _showingExam = false;
  Map<int, dynamic> _examAnswers = {};
  bool _examAccepted = false;

  // Timer
  Timer? _timer;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _initTimer();
  }

  @override
  void dispose() {
    _pitchCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _initTimer() {
    final exams = widget.job['exams'] as List?;
    if (exams == null || exams.isEmpty) return;
    final exam = exams[0] as Map;
    final duration = (exam['duration'] as num?)?.toInt() ?? 0;
    final format = exam['time_format']?.toString() ?? 'minutes';
    _remainingSeconds = duration * (format == 'minutes' ? 60 : 3600);
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        t.cancel();
      }
    });
  }

  String get _formattedTime {
    final h = _remainingSeconds ~/ 3600;
    final m = (_remainingSeconds % 3600) ~/ 60;
    final s = _remainingSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  List get _exams => (widget.job['exams'] as List?) ?? [];
  bool get _hasExam => _exams.isNotEmpty;

  // ── CV upload ─────────────────────────────────────────────────────────────

  Future<void> _pickCV() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
      withData: false,
    );
    if (result != null && result.files.isNotEmpty) {
      final f = result.files.first;
      if (f.path != null) {
        setState(() {
          _cvFile = File(f.path!);
          _cvFileName = f.name;
        });
      }
    }
  }

  // ── Exam ──────────────────────────────────────────────────────────────────

  void _openExam() {
    setState(() {
      _showingExam = true;
      _examAnswers = {};
    });
    _startTimer();
  }

  void _submitExam() {
    setState(() {
      _showingExam = false;
      _examCompleted = true;
    });
    _timer?.cancel();
  }

  // ── Submit application ────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_hasExam && !_examCompleted) {
      _showError('You must complete the exam first.');
      return;
    }
    if (!_appAccepted) {
      _showError('You must accept the terms to continue.');
      return;
    }

    setState(() => _submitting = true);
    final auth = context.read<AuthProvider>();

    try {
      final fields = <String, String>{
        'pitch': _pitchCtrl.text.trim(),
        'job': widget.job['id'].toString(),
        'answers': _examAnswers.isNotEmpty ? _examAnswers.toString() : '{}',
      };
      final files = <String, File>{};
      if (_cvFile != null) files['cv'] = _cvFile!;

      await auth.apiService.postMultipart(
        '/api/v1/jobs/application/c/',
        fields: fields,
        files: files,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Application submitted successfully.'),
        backgroundColor: _green,
      ));
      Navigator.pop(context, true);
    } on DioException catch (e) {
      _showError(e.response?.data?['error'] ??
          'Could not submit application. Try again.');
    } catch (_) {
      _showError('Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: _red));

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        title: const Text('Job Application'),
        elevation: 0,
      ),
      body: _showingExam ? _examView() : _applicationView(),
    );
  }

  // ── Application view ──────────────────────────────────────────────────────

  Widget _applicationView() {
    final jobTitle = widget.job['title'] ?? '';
    final auth = context.read<AuthProvider>();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Job title
            const Text('You are applying to:',
                style: TextStyle(fontSize: 13, color: Colors.black54)),
            const SizedBox(height: 4),
            Text(jobTitle,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: _green)),
            const SizedBox(height: 16),

            // Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _yellow.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _yellow.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'All applications are valid for 30 days. If you do not get a reply within 30 days, it means your application was unsuccessful. You won\'t be able to apply again.',
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                  if (_hasExam) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'This job has an exam that must be completed at the same time as the application. Once you tap Start Exam the countdown begins.',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Pitch
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tell us why you are ideal',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87)),
                Text('${_pitchCtrl.text.length} / 1000',
                    style: TextStyle(
                        fontSize: 11,
                        color: _pitchCtrl.text.length >= 1000
                            ? _red
                            : Colors.grey[400])),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _pitchCtrl,
              maxLines: 6,
              maxLength: 1000,
              buildCounter: (_,
                      {required currentLength,
                      required isFocused,
                      maxLength}) =>
                  const SizedBox.shrink(),
              onChanged: (_) => setState(() {}),
              decoration: _inputDeco(
                  'Describe why you are the ideal candidate. Max 1000 characters.'),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),

            // CV upload
            const Text('Your CV',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _pickCV,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: _cvFile != null ? _green : Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                  color: _cvFile != null
                      ? _green.withValues(alpha: 0.05)
                      : Colors.grey[50],
                ),
                child: Row(
                  children: [
                    Icon(
                      _cvFile != null
                          ? Icons.check_circle_outline
                          : Icons.upload_file_outlined,
                      color: _cvFile != null ? _green : Colors.grey[400],
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _cvFileName ?? 'Upload CV (PDF, DOC, DOCX)',
                        style: TextStyle(
                            fontSize: 13,
                            color: _cvFile != null
                                ? Colors.black87
                                : Colors.grey[400]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_cvFile != null)
                      GestureDetector(
                        onTap: () => setState(() {
                          _cvFile = null;
                          _cvFileName = null;
                        }),
                        child: const Icon(Icons.close,
                            size: 16, color: Colors.black45),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Exam button
            if (_hasExam && !_examCompleted) ...[
              const Text('Complete Exam',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87)),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _openExam,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _yellow,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Start Exam',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 8),
              const Text('You must complete the exam before submitting.',
                  style: TextStyle(fontSize: 12, color: Colors.black45)),
              const SizedBox(height: 20),
            ],

            if (_hasExam && _examCompleted) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: _green, size: 20),
                    SizedBox(width: 8),
                    Text('Exam completed!',
                        style: TextStyle(
                            color: _green,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Terms
            if (!_hasExam || _examCompleted) ...[
              Row(
                children: [
                  Checkbox(
                    value: _appAccepted,
                    activeColor: _green,
                    onChanged: (v) => setState(() => _appAccepted = v ?? false),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _appAccepted = !_appAccepted),
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
              const SizedBox(height: 20),

              // Submit buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
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
                          : const Text('Submit',
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
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Exam view ─────────────────────────────────────────────────────────────

  Widget _examView() {
    final exam = _exams[0] as Map;
    final questions = exam['questions'] as List? ?? [];

    return SafeArea(
      child: Column(
        children: [
          // Exam header with timer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: _green.withValues(alpha: 0.08),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Complete Exam',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _green)),
                      Text(
                          'Duration: ${exam['duration']} ${exam['time_format']}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54)),
                      const Text(
                          'This exam cannot be stopped and started again.',
                          style:
                              TextStyle(fontSize: 11, color: Colors.black45)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _remainingSeconds < 60 ? _red : _green,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _formattedTime,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                ),
              ],
            ),
          ),

          // Questions
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Questions:',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _green)),
                  const SizedBox(height: 16),
                  ...questions.asMap().entries.map((e) {
                    final i = e.key;
                    final q = e.value as Map;
                    return _questionWidget(i, q);
                  }),
                  const SizedBox(height: 20),

                  // Exam terms
                  Row(
                    children: [
                      Checkbox(
                        value: _examAccepted,
                        activeColor: _green,
                        onChanged: (v) =>
                            setState(() => _examAccepted = v ?? false),
                      ),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _examAccepted = !_examAccepted),
                        child: RichText(
                          text: const TextSpan(
                            style:
                                TextStyle(fontSize: 13, color: Colors.black87),
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
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _examAccepted ? _submitExam : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Submit Exam',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            _timer?.cancel();
                            setState(() => _showingExam = false);
                          },
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
        ],
      ),
    );
  }

  Widget _questionWidget(int index, Map question) {
    final type = question['type'] ?? 'single';
    final text = question['question'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              children: [
                TextSpan(
                    text: '${index + 1}. ',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: _green)),
                TextSpan(text: '$text?'),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Multiline answer
          if (type == 'multiline')
            TextField(
              maxLines: 4,
              onChanged: (v) => _examAnswers[index] = v,
              decoration: _inputDeco('Your answer here'),
            ),

          // Single line answer
          if (type == 'single')
            TextField(
              onChanged: (v) => _examAnswers[index] = v,
              decoration: _inputDeco('Your answer here'),
            ),

          // Multiple choice
          if (type == 'multichoice') ...[
            ...(question['choices'] as List? ?? []).asMap().entries.map((e) {
              final choice = e.value.toString();
              final isSelected = _examAnswers[index] == choice;
              return GestureDetector(
                onTap: () => setState(() => _examAnswers[index] = choice),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _green.withValues(alpha: 0.1)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: isSelected ? _green : Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: isSelected ? _green : Colors.grey,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(choice,
                            style: TextStyle(
                                fontSize: 13,
                                color: isSelected ? _green : Colors.black87)),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[300]!)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[300]!)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _green, width: 1.5)),
      );
}
