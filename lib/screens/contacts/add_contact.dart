import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';

class AddContactModal extends StatefulWidget {
  final String action; // 'add' or 'edit'
  final Map<String, dynamic>? contact;
  final void Function(Map<String, dynamic> data) onSave;
  final VoidCallback onCancel;

  const AddContactModal({
    super.key,
    required this.action,
    this.contact,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<AddContactModal> createState() => _AddContactModalState();
}

class _AddContactModalState extends State<AddContactModal> {
  bool _saving = false;
  bool _accepted = false;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  String _birthdate = '';

  // Emails: [{id, etype, email, primary}]
  List<Map<String, dynamic>> _emails = [
    {'id': null, 'etype': '', 'email': '', 'primary': false}
  ];

  // Numbers: [{id, ntype, number, primary}]
  List<Map<String, dynamic>> _numbers = [
    {'id': null, 'ntype': '', 'number': '', 'primary': false}
  ];

  // Groups
  List<dynamic> _allGroups = [];
  List<int> _selectedGroups = [];
  bool _addingGroup = false;
  final _groupNameController = TextEditingController();
  final _groupDescController = TextEditingController();

  static const _contactTypes = ['work', 'personal', 'extra'];

  @override
  void initState() {
    super.initState();
    _loadGroups();
    if (widget.action == 'edit' && widget.contact != null) {
      _populateForm(widget.contact!);
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _groupNameController.dispose();
    _groupDescController.dispose();
    super.dispose();
  }

  void _populateForm(Map<String, dynamic> c) {
    _firstNameController.text = c['first_name'] ?? '';
    _lastNameController.text = c['last_name'] ?? '';
    _birthdate = c['birthdate'] ?? '';

    final emails = c['email_addresses'] as List? ?? [];
    if (emails.isNotEmpty) {
      _emails = emails
          .map((e) => {
                'id': e['id'],
                'etype': e['emailtype'] ?? '',
                'email': e['email'] ?? '',
                'primary': e['primary'] ?? false,
              })
          .toList();
    }

    final numbers = c['phone_numbers'] as List? ?? [];
    if (numbers.isNotEmpty) {
      _numbers = numbers
          .map((n) => {
                'id': n['id'],
                'ntype': n['numtype'] ?? '',
                'number': n['number'] ?? '',
                'primary': n['primary'] ?? false,
              })
          .toList();
    }

    final groups = c['groups'] as List? ?? [];
    _selectedGroups =
        groups.map((g) => g is Map ? g['id'] as int : g as int).toList();

    _accepted = true;
  }

  Future<void> _loadGroups() async {
    try {
      final api = context.read<ApiService>();
      final res = await api.dio.get('/api/v1/contacts/groups/current/');
      setState(() {
        _allGroups = (res.data is List ? res.data : (res.data['results'] ?? []));
      });
    } catch (_) {}
  }

  Future<void> _saveGroup() async {
    if (_groupNameController.text.trim().isEmpty) {
      _showSnack('Group name is required');
      return;
    }
    try {
      final api = context.read<ApiService>();
      final res = await api.dio.post('/api/v1/contacts/group/a/', data: {
        'name': _groupNameController.text.trim(),
        'description': _groupDescController.text.trim(),
      });
      setState(() {
        _allGroups.add(res.data);
        _selectedGroups.add(res.data['id']);
        _groupNameController.clear();
        _groupDescController.clear();
        _addingGroup = false;
      });
      _showSnack('Group added successfully');
    } catch (_) {
      _showSnack('Could not save group. Try again.');
    }
  }

  // ─── Email helpers ────────────────────────────────────────────────────────

  void _addEmail(int afterIndex) {
    final current = _emails[afterIndex];
    if (current['etype'].isEmpty || current['email'].isEmpty) {
      _showSnack('Both type and email must be filled out.');
      return;
    }
    if (_emails.length >= 3) {
      _showSnack('You can only add up to 3 email addresses.');
      return;
    }
    final emailExists = _emails.asMap().entries.any((e) =>
        e.key != afterIndex &&
        e.value['email'].toString().toLowerCase() ==
            current['email'].toString().toLowerCase());
    if (emailExists) {
      _showSnack('This email address is already added.');
      return;
    }
    final hasPrimary = _emails.any((e) => e['primary'] == true);
    setState(() {
      _emails.insert(afterIndex + 1, {
        'id': null,
        'etype': '',
        'email': '',
        'primary': !hasPrimary,
      });
    });
  }

  void _removeEmail(int index) {
    if (_emails.length <= 1) {
      _showSnack('At least one email is required.');
      return;
    }
    final wasPrimary = _emails[index]['primary'] == true;
    setState(() {
      _emails.removeAt(index);
      if (wasPrimary && !_emails.any((e) => e['primary'] == true)) {
        _emails[0]['primary'] = true;
      }
    });
  }

  void _setPrimaryEmail(int index) {
    setState(() {
      for (int i = 0; i < _emails.length; i++) {
        _emails[i]['primary'] = i == index;
      }
    });
  }

  // ─── Number helpers ───────────────────────────────────────────────────────

  void _addNumber(int afterIndex) {
    final current = _numbers[afterIndex];
    if (current['ntype'].isEmpty || current['number'].isEmpty) {
      _showSnack('Both type and number must be filled out.');
      return;
    }
    if (current['number'].toString().length > 10) {
      _showSnack('Number is incorrect');
      return;
    }
    if (_numbers.length >= 3) {
      _showSnack('You can only add up to 3 phone numbers.');
      return;
    }
    final numExists = _numbers.asMap().entries.any(
        (e) => e.key != afterIndex && e.value['number'] == current['number']);
    if (numExists) {
      _showSnack('This phone number is already added.');
      return;
    }
    final hasPrimary = _numbers.any((n) => n['primary'] == true);
    setState(() {
      _numbers.insert(afterIndex + 1, {
        'id': null,
        'ntype': '',
        'number': '',
        'primary': !hasPrimary,
      });
    });
  }

  void _removeNumber(int index) {
    if (_numbers.length <= 1) {
      _showSnack('At least one phone number is required.');
      return;
    }
    final wasPrimary = _numbers[index]['primary'] == true;
    setState(() {
      _numbers.removeAt(index);
      if (wasPrimary && !_numbers.any((n) => n['primary'] == true)) {
        _numbers[0]['primary'] = true;
      }
    });
  }

  void _setPrimaryNumber(int index) {
    setState(() {
      for (int i = 0; i < _numbers.length; i++) {
        _numbers[i]['primary'] = i == index;
      }
    });
  }

  // ─── Save ─────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_firstNameController.text.trim().isEmpty ||
        _lastNameController.text.trim().isEmpty) {
      _showSnack('First name and last name are required');
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
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'birthdate': _birthdate.isNotEmpty ? _birthdate : null,
        'groups': _selectedGroups,
        'emails': _emails,
        'numbers': _numbers,
      };

      late Map<String, dynamic> result;
      if (widget.action == 'add') {
        final res = await api.dio.post('/api/v1/contacts/a/', data: payload);
        result = res.data;
      } else {
        final id = widget.contact!['id'];
        final res = await api.dio.put('/api/v1/contacts/$id/u/', data: payload);
        result = res.data;
      }
      widget.onSave(result);
    } catch (_) {
      _showSnack('Could not save contact. Try again.');
    }
    setState(() => _saving = false);
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B4748),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.action == 'edit' ? 'Edit Contact' : 'Add Contact',
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
          // First name
          _fieldLabel('First Name'),
          const SizedBox(height: 6),
          _textField(_firstNameController, hint: 'First name'),
          const SizedBox(height: 16),

          // Last name
          _fieldLabel('Last Name'),
          const SizedBox(height: 6),
          _textField(_lastNameController, hint: 'Last name'),
          const SizedBox(height: 16),

          // Birthday
          _fieldLabel('Birthday'),
          const SizedBox(height: 6),
          _datePicker(),
          const SizedBox(height: 20),

          // Emails
          _sectionHeader('Emails'),
          const SizedBox(height: 10),
          ..._emails.asMap().entries.map((e) => _emailRow(e.key)),
          const SizedBox(height: 20),

          // Numbers
          _sectionHeader('Phone Numbers'),
          const SizedBox(height: 10),
          ..._numbers.asMap().entries.map((e) => _numberRow(e.key)),
          const SizedBox(height: 20),

          // Groups
          _sectionHeader('Groups'),
          const SizedBox(height: 10),
          _groupsSection(),
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
                      : Text(
                          widget.action == 'edit'
                              ? 'Save Contact'
                              : 'Save Contact',
                          style: const TextStyle(
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

  // ─── Email row ────────────────────────────────────────────────────────────

  Widget _emailRow(int index) {
    final email = _emails[index];
    final isPrimary = email['primary'] == true;
    final isLast = index == _emails.length - 1;
    final canRemove = widget.action == 'edit' &&
        (_emails.length == 2 && index == 0 || _emails.length == 3);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              // Type dropdown
              SizedBox(
                width: 110,
                child: _typeDropdown(
                  value: email['etype'].isEmpty ? null : email['etype'],
                  hint: 'Type',
                  options: _contactTypes,
                  disabledValues: _emails
                      .asMap()
                      .entries
                      .where((e) => e.key != index)
                      .map((e) => e.value['etype'].toString())
                      .where((t) => t.isNotEmpty)
                      .toList(),
                  onChanged: (v) => setState(() => email['etype'] = v ?? ''),
                ),
              ),
              const SizedBox(width: 8),
              // Email input
              Expanded(
                child: TextField(
                  onChanged: (v) => email['email'] = v,
                  controller: TextEditingController(text: email['email'])
                    ..selection = TextSelection.collapsed(
                        offset: email['email'].toString().length),
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Email',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Primary radio
              GestureDetector(
                onTap: () => _setPrimaryEmail(index),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Radio<bool>(
                      value: true,
                      groupValue: isPrimary,
                      activeColor: const Color(0xFF1B4748),
                      onChanged: (_) => _setPrimaryEmail(index),
                    ),
                    const Text('Primary',
                        style: TextStyle(fontSize: 12, color: Colors.black54)),
                  ],
                ),
              ),
              const Spacer(),
              // Add button
              if (isLast && _emails.length < 3)
                TextButton.icon(
                  onPressed: () => _addEmail(index),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF1B4748)),
                ),
              // Remove button
              if (canRemove)
                TextButton.icon(
                  onPressed: () => _removeEmail(index),
                  icon: const Icon(Icons.remove, size: 16),
                  label: const Text('Remove', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFF48900)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Number row ───────────────────────────────────────────────────────────

  Widget _numberRow(int index) {
    final number = _numbers[index];
    final isPrimary = number['primary'] == true;
    final isLast = index == _numbers.length - 1;
    final canRemove = widget.action == 'edit' &&
        (_numbers.length == 2 && index == 0 || _numbers.length == 3);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              SizedBox(
                width: 110,
                child: _typeDropdown(
                  value: number['ntype'].isEmpty ? null : number['ntype'],
                  hint: 'Type',
                  options: _contactTypes,
                  disabledValues: _numbers
                      .asMap()
                      .entries
                      .where((e) => e.key != index)
                      .map((e) => e.value['ntype'].toString())
                      .where((t) => t.isNotEmpty)
                      .toList(),
                  onChanged: (v) => setState(() => number['ntype'] = v ?? ''),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  onChanged: (v) {
                    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
                    number['number'] =
                        digits.length > 10 ? digits.substring(0, 10) : digits;
                  },
                  controller: TextEditingController(text: number['number'])
                    ..selection = TextSelection.collapsed(
                        offset: number['number'].toString().length),
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Phone number',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              GestureDetector(
                onTap: () => _setPrimaryNumber(index),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Radio<bool>(
                      value: true,
                      groupValue: isPrimary,
                      activeColor: const Color(0xFF1B4748),
                      onChanged: (_) => _setPrimaryNumber(index),
                    ),
                    const Text('Primary',
                        style: TextStyle(fontSize: 12, color: Colors.black54)),
                  ],
                ),
              ),
              const Spacer(),
              if (isLast && _numbers.length < 3)
                TextButton.icon(
                  onPressed: () => _addNumber(index),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF1B4748)),
                ),
              if (canRemove)
                TextButton.icon(
                  onPressed: () => _removeNumber(index),
                  icon: const Icon(Icons.remove, size: 16),
                  label: const Text('Remove', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFF48900)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Groups section ───────────────────────────────────────────────────────

  Widget _groupsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group chips
        if (_allGroups.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _allGroups.map((g) {
              final id = g['id'] as int;
              final name = g['name'] ?? '';
              final selected = _selectedGroups.contains(id);
              return FilterChip(
                label: Text(name, style: const TextStyle(fontSize: 12)),
                selected: selected,
                selectedColor: const Color(0xFF1B4748).withOpacity(0.15),
                checkmarkColor: const Color(0xFF1B4748),
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      _selectedGroups.add(id);
                    } else {
                      _selectedGroups.remove(id);
                    }
                  });
                },
              );
            }).toList(),
          ),
        const SizedBox(height: 10),

        // Add group toggle
        if (!_addingGroup)
          OutlinedButton.icon(
            onPressed: () => setState(() => _addingGroup = true),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1B4748),
              side: const BorderSide(color: Color(0xFF1B4748)),
            ),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Group', style: TextStyle(fontSize: 13)),
          )
        else
          Container(
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
                      child:
                          _textField(_groupNameController, hint: 'Group name'),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _addingGroup = false),
                      child: const Icon(Icons.close, color: Colors.black45),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _groupDescController,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Description',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.all(10),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _saveGroup,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B4748),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8)),
                  child: const Text('Save Group',
                      style: TextStyle(color: Colors.white, fontSize: 13)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ─── Date picker ──────────────────────────────────────────────────────────

  Widget _datePicker() => GestureDetector(
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: _birthdate.isNotEmpty
                ? DateTime.tryParse(_birthdate) ?? DateTime(1990)
                : DateTime(1990),
            firstDate: DateTime(1900),
            lastDate: now,
            builder: (ctx, child) => Theme(
              data: Theme.of(ctx).copyWith(
                colorScheme:
                    const ColorScheme.light(primary: Color(0xFF1B4748)),
              ),
              child: child!,
            ),
          );
          if (picked != null) {
            setState(() => _birthdate = picked.toIso8601String().split('T')[0]);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black26),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _birthdate.isEmpty ? 'Select birthday' : _birthdate,
                  style: TextStyle(
                      fontSize: 13,
                      color:
                          _birthdate.isEmpty ? Colors.black45 : Colors.black87),
                ),
              ),
              const Icon(Icons.calendar_today, size: 16, color: Colors.black45),
            ],
          ),
        ),
      );

  // ─── Shared helpers ───────────────────────────────────────────────────────

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
    TextInputType keyboardType = TextInputType.text,
  }) =>
      TextField(
        controller: controller,
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

  Widget _typeDropdown({
    String? value,
    required String hint,
    required List<String> options,
    required List<String> disabledValues,
    required void Function(String?) onChanged,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black26),
          borderRadius: BorderRadius.circular(6),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            hint: Text(hint,
                style: const TextStyle(color: Colors.black45, fontSize: 12)),
            isDense: true,
            isExpanded: true,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
            items: [
              DropdownMenuItem<String>(
                  value: null,
                  child: Text(hint,
                      style: const TextStyle(
                          color: Colors.black45, fontSize: 12))),
              ...options.map((opt) => DropdownMenuItem<String>(
                    value: opt,
                    enabled: !disabledValues.contains(opt),
                    child: Text(
                      opt[0].toUpperCase() + opt.substring(1),
                      style: TextStyle(
                          fontSize: 12,
                          color: disabledValues.contains(opt)
                              ? Colors.black26
                              : Colors.black87),
                    ),
                  )),
            ],
            onChanged: onChanged,
          ),
        ),
      );
}
