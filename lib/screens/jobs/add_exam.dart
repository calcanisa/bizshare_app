import 'package:flutter/material.dart';

class AddExamModal extends StatefulWidget {
  final String action; // 'add' or 'edit'
  final Map<String, dynamic>? exam;
  final void Function(Map<String, dynamic> data) onSave;
  final VoidCallback onCancel;

  const AddExamModal({
    super.key,
    required this.action,
    this.exam,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<AddExamModal> createState() => _AddExamModalState();
}

class _AddExamModalState extends State<AddExamModal> {
  bool _accepted = false;

  final _durationController = TextEditingController();
  String _timeFormat = '';

  List<Map<String, dynamic>> _questions = [];

  // Adding question state
  bool _addingQuestion = false;
  bool _addingChoice = false;
  String _questionType = '';
  final _questionTextController = TextEditingController();
  final _questionBodyController = TextEditingController();
  final _choiceController = TextEditingController();
  List<String> _choices = [];

  @override
  void initState() {
    super.initState();
    if (widget.action == 'edit' && widget.exam != null) {
      _durationController.text = widget.exam!['duration']?.toString() ?? '';
      _timeFormat = widget.exam!['time_format'] ?? '';
      _questions = (widget.exam!['questions'] as List? ?? [])
          .map((q) => Map<String, dynamic>.from(q as Map))
          .toList();
      _accepted = true;
    }
  }

  @override
  void dispose() {
    _durationController.dispose();
    _questionTextController.dispose();
    _questionBodyController.dispose();
    _choiceController.dispose();
    super.dispose();
  }

  void _pushQuestion() {
    if (_questionTextController.text.trim().isEmpty) {
      _showSnack('A question must be asked');
      return;
    }
    setState(() {
      _questions.add({
        'question': _questionTextController.text.trim(),
        'body': _questionBodyController.text.trim(),
        'type': _questionType,
        'choices': List<String>.from(_choices),
      });
      _resetQuestionForm();
    });
  }

  void _resetQuestionForm() {
    _addingQuestion = false;
    _addingChoice = false;
    _questionType = '';
    _questionTextController.clear();
    _questionBodyController.clear();
    _choiceController.clear();
    _choices = [];
  }

  void _addOption() {
    final val = _choiceController.text.trim();
    if (val.isEmpty) return;
    if (_choices.length >= 4) {
      _showSnack('You are limited to 4 choices');
      return;
    }
    if (_choices.contains(val)) {
      _showSnack('You have already added that choice');
      return;
    }
    setState(() {
      _choices.add(val);
      _choiceController.clear();
    });
  }

  void _save() {
    if (widget.action == 'add' && !_accepted) {
      _showSnack('You must accept the terms');
      return;
    }
    widget.onSave({
      'duration': int.tryParse(_durationController.text.trim()) ?? 0,
      'time_format': _timeFormat,
      'questions': _questions,
    });
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final title = widget.action == 'edit' ? 'Edit An Exam' : 'Add An Exam';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B4748),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(title,
            style: const TextStyle(color: Colors.white, fontSize: 15)),
        actions: [
          TextButton(
            onPressed: widget.onCancel,
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info
          const Text(
            'To make the selection process faster, you can add an exam to a job application. Set a time limit and every applicant will have to complete it. Once added, questions cannot be edited — delete and recreate if needed.',
            style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.5),
          ),
          const SizedBox(height: 20),

          // Duration + format
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('How long is this exam?'),
                    const SizedBox(height: 6),
                    _textField(_durationController,
                        hint: 'Enter a number',
                        keyboardType: TextInputType.number),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Time Format'),
                    const SizedBox(height: 6),
                    _dropdownWidget<String>(
                      value: _timeFormat.isEmpty ? null : _timeFormat,
                      hint: 'Choose',
                      items: const [
                        DropdownMenuItem(
                            value: 'minutes', child: Text('Minutes')),
                        DropdownMenuItem(value: 'hours', child: Text('Hours')),
                      ],
                      onChanged: (v) => setState(() => _timeFormat = v ?? ''),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Questions section
          _sectionHeader('Questions'),
          const SizedBox(height: 12),

          // Added questions
          if (_questions.isNotEmpty) ...[
            ..._questions
                .asMap()
                .entries
                .map((e) => _questionCard(e.key, e.value)),
            const SizedBox(height: 12),
          ],

          // Add question button
          if (!_addingQuestion)
            OutlinedButton.icon(
              onPressed: () => setState(() => _addingQuestion = true),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1B4748),
                side: const BorderSide(color: Color(0xFF1B4748)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add A Question'),
            ),

          // Question form
          if (_addingQuestion) ...[
            const SizedBox(height: 12),
            _questionForm(),
          ],

          const SizedBox(height: 24),

          // Terms
          if (widget.action == 'add') ...[
            Row(
              children: [
                Checkbox(
                  value: _accepted,
                  activeColor: const Color(0xFF1B4748),
                  onChanged: (v) => setState(() => _accepted = v ?? false),
                ),
                const Text('I accept the '),
                GestureDetector(
                  onTap: () {},
                  child: const Text('terms',
                      style: TextStyle(
                          color: Color(0xFF1B4748),
                          decoration: TextDecoration.underline)),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B4748),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Save',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFF48900),
                    side: const BorderSide(color: Color(0xFFF48900)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontSize: 15)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ─── Question card ────────────────────────────────────────────────────────

  Widget _questionCard(int index, Map<String, dynamic> q) {
    final question = q['question'] ?? '';
    final body = q['body'] ?? '';
    final choices = q['choices'] as List? ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(question,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B4748))),
              ),
              GestureDetector(
                onTap: () => setState(() => _questions.removeAt(index)),
                child:
                    const Icon(Icons.close, size: 18, color: Color(0xFFF48900)),
              ),
            ],
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(body,
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
          if (choices.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Choices:',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54)),
            const SizedBox(height: 4),
            ...choices.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, size: 6, color: Colors.black45),
                      const SizedBox(width: 6),
                      Text(c.toString(),
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black87)),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  // ─── Question form ────────────────────────────────────────────────────────

  Widget _questionForm() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: const Color(0xFF1B4748).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('Question Type'),
          const SizedBox(height: 6),
          _dropdownWidget<String>(
            value: _questionType.isEmpty ? null : _questionType,
            hint: 'Select',
            items: const [
              DropdownMenuItem(
                  value: 'single', child: Text('Single line Question')),
              DropdownMenuItem(
                  value: 'multiline', child: Text('Multi line Question')),
              DropdownMenuItem(
                  value: 'multichoice',
                  child: Text('Multiple Choice Question')),
            ],
            onChanged: (v) => setState(() => _questionType = v ?? ''),
          ),
          const SizedBox(height: 12),

          // Single / multiline / multichoice question text
          if (_questionType == 'single' ||
              _questionType == 'multiline' ||
              _questionType == 'multichoice') ...[
            _fieldLabel('Question'),
            const SizedBox(height: 6),
            _textField(_questionTextController,
                hint: 'Ask the question here', maxLength: 100),
            const SizedBox(height: 12),
          ],

          // Multiline body
          if (_questionType == 'multiline') ...[
            _fieldLabel('Detail'),
            const SizedBox(height: 6),
            _textField(_questionBodyController,
                hint: 'Enter question detail here',
                maxLines: 4,
                maxLength: 1000),
            const SizedBox(height: 12),
          ],

          // Multiple choice options
          if (_questionType == 'multichoice') ...[
            if (_choices.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _choices.asMap().entries.map((e) {
                  return Chip(
                    label: Text(
                      e.value.length > 30
                          ? '${e.value.substring(0, 30)}...'
                          : e.value,
                      style: const TextStyle(fontSize: 12),
                    ),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () => setState(() => _choices.removeAt(e.key)),
                    backgroundColor: Colors.grey.shade200,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                if (!_addingChoice)
                  TextButton.icon(
                    onPressed: () => setState(() => _addingChoice = true),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Choice',
                        style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF1B4748)),
                  ),
                if (_addingChoice)
                  TextButton(
                    onPressed: () => setState(() {
                      _addingChoice = false;
                      _choiceController.clear();
                    }),
                    child: const Text('Done',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFF1B4748))),
                  ),
              ],
            ),
            if (_addingChoice) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _textField(_choiceController,
                        hint: 'Add choice', maxLength: 50),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _addOption,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B4748),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10)),
                    child: const Text('Add',
                        style: TextStyle(color: Colors.white, fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ],

          // Add / Cancel question
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _pushQuestion,
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B4748),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 8)),
                child: const Text('Add',
                    style: TextStyle(color: Colors.white, fontSize: 13)),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () => setState(() => _resetQuestionForm()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFF48900),
                  side: const BorderSide(color: Color(0xFFF48900)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                ),
                child: const Text('Cancel', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Widget _sectionHeader(String title) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1B4748),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold)),
      );

  Widget _fieldLabel(String label) => Text(label,
      style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1B4748)));

  Widget _textField(
    TextEditingController controller, {
    String? hint,
    int maxLines = 1,
    int? maxLength,
    TextInputType keyboardType = TextInputType.text,
  }) =>
      TextField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF1B4748)),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
        ),
      );

  Widget _dropdownWidget<T>({
    T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black26),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            hint: Text(hint,
                style: const TextStyle(color: Colors.black45, fontSize: 13)),
            isExpanded: true,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
            items: [
              DropdownMenuItem<T>(
                  value: null,
                  child: Text(hint,
                      style: const TextStyle(
                          color: Colors.black45, fontSize: 13))),
              ...items,
            ],
            onChanged: onChanged,
          ),
        ),
      );
}
