import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';

class AddGroupModal extends StatefulWidget {
  final String action; // 'add' or 'edit'
  final Map<String, dynamic>? group;
  final void Function(Map<String, dynamic> data) onSave;
  final VoidCallback onCancel;

  const AddGroupModal({
    super.key,
    required this.action,
    this.group,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<AddGroupModal> createState() => _AddGroupModalState();
}

class _AddGroupModalState extends State<AddGroupModal> {
  bool _saving = false;
  bool _accepted = false;

  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  bool _email = false;
  bool _sms = false;
  bool _whatsapp = false;
  bool _social = false;

  @override
  void initState() {
    super.initState();
    if (widget.action == 'edit' && widget.group != null) {
      final g = widget.group!;
      _nameController.text = g['name'] ?? '';
      _descController.text = g['description'] ?? '';
      _email = g['email'] == true;
      _sms = g['sms'] == true;
      _whatsapp = g['whatsapp'] == true;
      _social = g['social'] == true;
      _accepted = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      _showSnack('Group name is required');
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
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'email': _email,
        'sms': _sms,
        'whatsapp': _whatsapp,
        'social': _social,
      };

      late Map<String, dynamic> result;
      if (widget.action == 'add') {
        final res =
            await api.dio.post('/api/v1/contacts/group/a/', data: payload);
        result = res.data;
      } else {
        final id = widget.group!['id'];
        final res =
            await api.dio.put('/api/v1/contacts/group/$id/u/', data: payload);
        result = res.data;
      }
      widget.onSave(result);
    } catch (_) {
      _showSnack('Could not save group. Try again.');
    }
    setState(() => _saving = false);
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B4748),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.action == 'edit' ? 'Edit Group' : 'Add Group',
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
          // Name
          _fieldLabel('Name'),
          const SizedBox(height: 6),
          _textField(_nameController, hint: 'Group name'),
          const SizedBox(height: 16),

          // Description
          _fieldLabel('Description'),
          const SizedBox(height: 6),
          _textField(_descController, hint: 'Description', maxLines: 3),
          const SizedBox(height: 20),

          // Methods
          _sectionHeader('Methods of Sending'),
          const SizedBox(height: 10),
          _checkRow('Email', _email, (v) => setState(() => _email = v)),
          _checkRow('SMS', _sms, (v) => setState(() => _sms = v)),
          _checkRow(
              'WhatsApp', _whatsapp, (v) => setState(() => _whatsapp = v)),
          _checkRow(
              'Social Posts', _social, (v) => setState(() => _social = v)),
          const SizedBox(height: 20),

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
                      : const Text('Save Group',
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
  }) =>
      TextField(
        controller: controller,
        maxLines: maxLines,
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

  Widget _checkRow(
    String label,
    bool value,
    void Function(bool) onChanged,
  ) =>
      Row(
        children: [
          Checkbox(
            value: value,
            activeColor: const Color(0xFF1B4748),
            onChanged: (v) => onChanged(v ?? false),
          ),
          Text(label,
              style: const TextStyle(fontSize: 13, color: Colors.black87)),
        ],
      );
}
