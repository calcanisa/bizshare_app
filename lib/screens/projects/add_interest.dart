import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';

class AddInterestModal extends StatefulWidget {
  final String action; // 'add' or 'edit'
  final Map<String, dynamic> project;
  final Map<String, dynamic>? interest;
  final void Function(Map<String, dynamic> data) onSave;
  final VoidCallback onCancel;

  const AddInterestModal({
    super.key,
    required this.action,
    required this.project,
    this.interest,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<AddInterestModal> createState() => _AddInterestModalState();
}

class _AddInterestModalState extends State<AddInterestModal> {
  bool _saving = false;
  bool _accepted = false;

  String _motive = '';
  final _messageController = TextEditingController();

  static const _motives = [
    ('invest', 'I want to invest in your company'),
    ('partnership', 'I want to partner with you'),
    ('acquisition', 'I want to acquire your company'),
    ('work', 'I want to work for you'),
    ('services', 'I want to provide services to you'),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.action == 'edit' && widget.interest != null) {
      _motive = widget.interest!['motive'] ?? '';
      _messageController.text = widget.interest!['message'] ?? '';
      _accepted = true;
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_motive.isEmpty) {
      _showSnack('Please select a motive');
      return;
    }
    if (widget.action == 'add' && !_accepted) {
      _showSnack('You must accept the terms');
      return;
    }

    setState(() => _saving = true);
    try {
      final api = context.read<ApiService>();
      final payload = {
        'project_id': widget.project['id'],
        'motive': _motive,
        'message': _messageController.text.trim(),
      };

      late Map<String, dynamic> result;
      if (widget.action == 'add') {
        final res =
            await api.dio.post('/api/v1/projects/interest/c/', data: payload);
        result = res.data;
      } else {
        final id = widget.interest!['id'];
        final res = await api.dio
            .put('/api/v1/projects/interest/$id/u/', data: payload);
        result = res.data;
      }
      widget.onSave(result);
    } catch (_) {
      _showSnack('Could not save interest. Try again.');
    }
    setState(() => _saving = false);
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final projectTitle = widget.project['title'] ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B4748),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.action == 'edit' ? 'Edit Interest' : 'Show Interest',
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
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
          // Project name
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1B4748).withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Text('Project: ',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B4748))),
                Expanded(
                  child: Text(projectTitle,
                      style:
                          const TextStyle(fontSize: 13, color: Colors.black87)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Motive
          const Text('Motive',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B4748))),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black26),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _motive.isEmpty ? null : _motive,
                hint: const Text('Select',
                    style: TextStyle(color: Colors.black45, fontSize: 13)),
                isExpanded: true,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                items: [
                  const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Select',
                          style:
                              TextStyle(color: Colors.black45, fontSize: 13))),
                  ..._motives.map((m) => DropdownMenuItem<String>(
                        value: m.$1,
                        child: Text(m.$2, style: const TextStyle(fontSize: 13)),
                      )),
                ],
                onChanged: (v) => setState(() => _motive = v ?? ''),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Message
          const Text('Message',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B4748))),
          const SizedBox(height: 4),
          const Text('For your own safety do not include contact information',
              style: TextStyle(fontSize: 11, color: Colors.black45)),
          const SizedBox(height: 6),
          TextField(
            controller: _messageController,
            maxLines: 5,
            maxLength: 500,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF1B4748)),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 16),

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
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B4748),
                    disabledBackgroundColor: Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Save',
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
}
