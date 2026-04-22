import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../contacts/add_contact.dart';
import '../contacts/add_group.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  int _tab = 1;

  // ── Tab 1: Contacts ──────────────────────────────────────────────────────
  List<dynamic> _contacts = [];
  bool _loadingContacts = false;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalContacts = 0;
  String _contactSort = '';
  final Set<int> _selectedContacts = {};
  final _searchController = TextEditingController();

  // ── Tab 2: Groups ────────────────────────────────────────────────────────
  List<dynamic> _groups = [];
  List<dynamic> _filteredGroups = [];
  bool _loadingGroups = false;
  String _groupSort = '';
  final Set<int> _selectedGroups = {};
  final _groupSearchController = TextEditingController();
  bool _filterEmail = false;
  bool _filterSms = false;
  bool _filterWhatsapp = false;
  bool _filterSocial = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _loadGroups();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _groupSearchController.dispose();
    super.dispose();
  }

  // ── API calls ─────────────────────────────────────────────────────────────

  Future<void> _loadContacts({int page = 1}) async {
    setState(() => _loadingContacts = true);
    try {
      final api = context.read<ApiService>();
      final params = <String, dynamic>{'page': page};
      if (_searchController.text.trim().isNotEmpty)
        params['search'] = _searchController.text.trim();
      if (_contactSort.isNotEmpty) params['ordering'] = _contactSort;

      final res = await api.dio
          .get('/api/v1/contacts/current/', queryParameters: params);
      final data = res.data;
      setState(() {
        _contacts = data['results'] as List? ?? [];
        _totalContacts = data['count'] ?? 0;
        _totalPages = data['total_pages'] ?? ((_totalContacts / 20).ceil());
        _currentPage = page;
        _selectedContacts.clear();
      });
    } catch (_) {
      _showSnack('Could not load contacts. Try again.');
    }
    setState(() => _loadingContacts = false);
  }

  Future<void> _loadGroups() async {
    setState(() => _loadingGroups = true);
    try {
      final api = context.read<ApiService>();
      final res = await api.dio.get('/api/v1/contacts/groups/current/');
      final data = res.data;
      setState(() {
        _groups = data is List ? data : (data['results'] ?? []);
        _selectedGroups.clear();
      });
      _applyGroupFilters();
    } catch (_) {
      _showSnack('Could not load groups. Try again.');
    }
    setState(() => _loadingGroups = false);
  }

  Future<void> _bulkDeleteContacts() async {
    if (_selectedContacts.isEmpty) return;
    final confirm = await _confirm(
        'Delete ${_selectedContacts.length} selected contact(s)?');
    if (!confirm) return;
    try {
      final api = context.read<ApiService>();
      await api.dio.post('/api/v1/contacts/bulk-delete/',
          data: {'ids': _selectedContacts.toList()});
      setState(() {
        _contacts.removeWhere((c) => _selectedContacts.contains(c['id']));
        _totalContacts -= _selectedContacts.length;
        _selectedContacts.clear();
      });
      _showSnack('Contacts deleted');
    } catch (_) {
      _showSnack('Failed to delete contacts. Try again.');
    }
  }

  Future<void> _bulkDeleteGroups() async {
    if (_selectedGroups.isEmpty) return;
    final confirm =
        await _confirm('Delete ${_selectedGroups.length} selected group(s)?');
    if (!confirm) return;
    try {
      final api = context.read<ApiService>();
      await api.dio.post('/api/v1/contacts/groups/bulk-delete/',
          data: {'ids': _selectedGroups.toList()});
      setState(() {
        _groups.removeWhere((g) => _selectedGroups.contains(g['id']));
        _selectedGroups.clear();
      });
      _applyGroupFilters();
      _showSnack('Groups deleted');
    } catch (_) {
      _showSnack('Failed to delete groups. Try again.');
    }
  }

  // ── Filtering / sorting ───────────────────────────────────────────────────

  void _applyGroupFilters() {
    var result = List<dynamic>.from(_groups);
    final q = _groupSearchController.text.toLowerCase().trim();
    if (q.isNotEmpty) {
      result = result
          .where((g) => (g['name']?.toString().toLowerCase() ?? '').contains(q))
          .toList();
    }
    if (_filterEmail) result = result.where((g) => g['email'] == true).toList();
    if (_filterSms) result = result.where((g) => g['sms'] == true).toList();
    if (_filterWhatsapp)
      result = result.where((g) => g['whatsapp'] == true).toList();
    if (_filterSocial)
      result = result.where((g) => g['social'] == true).toList();

    if (_groupSort.isNotEmpty) {
      final desc = _groupSort.startsWith('-');
      final key = _groupSort.replaceAll('-', '');
      result.sort((a, b) {
        final aVal = a[key] ?? '';
        final bVal = b[key] ?? '';
        final cmp = aVal
            .toString()
            .toLowerCase()
            .compareTo(bVal.toString().toLowerCase());
        return desc ? -cmp : cmp;
      });
    }

    setState(() => _filteredGroups = result);
  }

  void _sortContactsBy(String field) {
    setState(() {
      _contactSort = _contactSort == field ? '-$field' : field;
    });
    _loadContacts(page: 1);
  }

  void _sortGroupsBy(String field) {
    setState(() {
      _groupSort = _groupSort == field ? '-$field' : field;
    });
    _applyGroupFilters();
  }

  String _sortIcon(String field, String currentSort) {
    if (currentSort == field) return ' ▲';
    if (currentSort == '-$field') return ' ▼';
    return '';
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _formatDate(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
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
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  }

  Future<bool> _confirm(String msg) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(msg),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Confirm')),
          ],
        ),
      ) ==
      true;

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: const Color(0xFF094a25),
          child: Row(
            children: [
              _tabBtn(1, 'Contacts'),
              _tabBtn(2, 'Groups'),
            ],
          ),
        ),
        Expanded(
          child: _tab == 1 ? _contactsTab() : _groupsTab(),
        ),
      ],
    );
  }

  Widget _tabBtn(int index, String label) {
    final active = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
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

  // ── Tab 1: Contacts ───────────────────────────────────────────────────────

  Widget _contactsTab() {
    return Column(
      children: [
        // Search + Add bar
        Container(
          color: Colors.grey.shade50,
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name or email',
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF094a25)),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    prefixIcon: const Icon(Icons.search,
                        size: 18, color: Colors.black45),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              _loadContacts(page: 1);
                            })
                        : null,
                  ),
                  onSubmitted: (_) => _loadContacts(page: 1),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddContactModal(
                      action: 'add',
                      onSave: (data) {
                        Navigator.pop(context);
                        setState(() {
                          _contacts.insert(0, data);
                          _totalContacts++;
                        });
                      },
                      onCancel: () => Navigator.pop(context),
                    ),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFf8b324),
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10)),
                child: const Text('Add', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),

        // Count + bulk actions
        if (_totalContacts > 0 || _selectedContacts.isNotEmpty)
          Container(
            color: Colors.grey.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Text('$_totalContacts contacts',
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black45)),
                const Spacer(),
                if (_selectedContacts.isNotEmpty) ...[
                  Text('${_selectedContacts.length} selected',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF094a25),
                          fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  _actionBtn('Delete', _bulkDeleteContacts,
                      isDestructive: true),
                  const SizedBox(width: 6),
                  _actionBtn('Clear', () {
                    setState(() => _selectedContacts.clear());
                  }),
                ],
              ],
            ),
          ),

        // Sort header
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                child: Checkbox(
                  value: _contacts.isNotEmpty &&
                      _contacts
                          .every((c) => _selectedContacts.contains(c['id'])),
                  tristate: true,
                  activeColor: const Color(0xFF094a25),
                  onChanged: (_) {
                    setState(() {
                      if (_contacts
                          .every((c) => _selectedContacts.contains(c['id']))) {
                        _selectedContacts.clear();
                      } else {
                        for (final c in _contacts) {
                          _selectedContacts.add(c['id']);
                        }
                      }
                    });
                  },
                ),
              ),
              _sortHeader('First Name', 'first_name', flex: 2),
              _sortHeader('Last Name', 'last_name', flex: 2),
              const Expanded(
                  flex: 2,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text('Email',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54)),
                  )),
              const Expanded(
                  flex: 1,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text('Phone',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54)),
                  )),
              _sortHeader('Added', 'created_at', flex: 1),
              const SizedBox(width: 36),
            ],
          ),
        ),

        // List
        Expanded(
          child: _loadingContacts
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF094a25)))
              : _contacts.isEmpty
                  ? const Center(
                      child: Text('No contacts found',
                          style: TextStyle(color: Color(0xFF094a25))))
                  : RefreshIndicator(
                      onRefresh: () => _loadContacts(page: 1),
                      color: const Color(0xFF094a25),
                      child: ListView.builder(
                        itemCount: _contacts.length + 1,
                        itemBuilder: (context, index) {
                          if (index == _contacts.length) {
                            return _contactPagination();
                          }
                          return _contactRow(
                              _contacts[index] as Map<String, dynamic>);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _sortHeader(String label, String field, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: () => _sortContactsBy(field),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Text(
            label + _sortIcon(field, _contactSort),
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.black54),
          ),
        ),
      ),
    );
  }

  Widget _contactRow(Map<String, dynamic> contact) {
    final id = contact['id'] as int;
    final isSelected = _selectedContacts.contains(id);
    final emails = contact['email_addresses'] as List? ?? [];
    final phones = contact['phone_numbers'] as List? ?? [];
    final email =
        emails.isNotEmpty ? emails[0]['email']?.toString() ?? 'N/A' : 'N/A';
    final phone =
        phones.isNotEmpty ? phones[0]['number']?.toString() ?? 'N/A' : 'N/A';

    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF094a25).withOpacity(0.06)
            : Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Checkbox(
              value: isSelected,
              activeColor: const Color(0xFF094a25),
              onChanged: (_) => setState(() {
                if (isSelected)
                  _selectedContacts.remove(id);
                else
                  _selectedContacts.add(id);
              }),
            ),
          ),
          Expanded(
              flex: 2,
              child: _cellText(contact['first_name']?.toString() ?? '')),
          Expanded(
              flex: 2,
              child: _cellText(contact['last_name']?.toString() ?? '')),
          Expanded(flex: 2, child: _cellText(email)),
          Expanded(flex: 1, child: _cellText(phone)),
          Expanded(
              flex: 1,
              child: _cellText(_formatDate(contact['created_at']?.toString()))),
          SizedBox(
            width: 36,
            child: IconButton(
              icon: const Icon(Icons.edit_outlined,
                  size: 16, color: Color(0xFF094a25)),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddContactModal(
                    action: 'edit',
                    contact: contact,
                    onSave: (data) {
                      Navigator.pop(context);
                      final i =
                          _contacts.indexWhere((c) => c['id'] == data['id']);
                      if (i != -1) setState(() => _contacts[i] = data);
                    },
                    onCancel: () => Navigator.pop(context),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cellText(String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Text(text,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
            overflow: TextOverflow.ellipsis,
            maxLines: 1),
      );

  Widget _contactPagination() {
    if (_totalPages <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          if (_currentPage > 1) ...[
            _pageBtn('First', () => _loadContacts(page: 1)),
            _pageBtn('‹ Prev', () => _loadContacts(page: _currentPage - 1)),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF094a25).withOpacity(0.08),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('Page $_currentPage of $_totalPages',
                style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF094a25),
                    fontWeight: FontWeight.bold)),
          ),
          if (_currentPage < _totalPages) ...[
            _pageBtn('Next ›', () => _loadContacts(page: _currentPage + 1)),
            _pageBtn('Last', () => _loadContacts(page: _totalPages)),
          ],
        ],
      ),
    );
  }

  // ── Tab 2: Groups ─────────────────────────────────────────────────────────

  Widget _groupsTab() {
    return Column(
      children: [
        Container(
          color: Colors.grey.shade50,
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _groupSearchController,
                      decoration: InputDecoration(
                        hintText: 'Search by group name',
                        isDense: true,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFF094a25)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        prefixIcon: const Icon(Icons.search,
                            size: 18, color: Colors.black45),
                      ),
                      onChanged: (_) {
                        setState(() {});
                        _applyGroupFilters();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddGroupModal(
                          action: 'add',
                          onSave: (data) {
                            Navigator.pop(context);
                            setState(() => _groups.insert(0, data));
                            _applyGroupFilters();
                          },
                          onCancel: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFf8b324),
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10)),
                    child: const Text('Create', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _filterChipToggle('Email', _filterEmail, (v) {
                    setState(() => _filterEmail = v);
                    _applyGroupFilters();
                  }),
                  _filterChipToggle('SMS', _filterSms, (v) {
                    setState(() => _filterSms = v);
                    _applyGroupFilters();
                  }),
                  _filterChipToggle('WhatsApp', _filterWhatsapp, (v) {
                    setState(() => _filterWhatsapp = v);
                    _applyGroupFilters();
                  }),
                  _filterChipToggle('Social', _filterSocial, (v) {
                    setState(() => _filterSocial = v);
                    _applyGroupFilters();
                  }),
                  if (_filterEmail ||
                      _filterSms ||
                      _filterWhatsapp ||
                      _filterSocial ||
                      _groupSearchController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _filterEmail = false;
                          _filterSms = false;
                          _filterWhatsapp = false;
                          _filterSocial = false;
                          _groupSearchController.clear();
                        });
                        _applyGroupFilters();
                      },
                      child: Chip(
                        label: const Text('Reset',
                            style:
                                TextStyle(fontSize: 11, color: Colors.white)),
                        backgroundColor: const Color(0xFFbc2023),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (_filteredGroups.isNotEmpty || _selectedGroups.isNotEmpty)
          Container(
            color: Colors.grey.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Text('${_filteredGroups.length} groups',
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black45)),
                const Spacer(),
                if (_selectedGroups.isNotEmpty) ...[
                  Text('${_selectedGroups.length} selected',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF094a25),
                          fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  _actionBtn('Delete', _bulkDeleteGroups, isDestructive: true),
                  const SizedBox(width: 6),
                  _actionBtn('Clear', () {
                    setState(() => _selectedGroups.clear());
                  }),
                ],
              ],
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                child: Checkbox(
                  value: _filteredGroups
                          .where((g) => g['is_default'] != true)
                          .isNotEmpty &&
                      _filteredGroups
                          .where((g) => g['is_default'] != true)
                          .every((g) => _selectedGroups.contains(g['id'])),
                  tristate: true,
                  activeColor: const Color(0xFF094a25),
                  onChanged: (_) {
                    setState(() {
                      final editable = _filteredGroups
                          .where((g) => g['is_default'] != true)
                          .toList();
                      if (editable
                          .every((g) => _selectedGroups.contains(g['id']))) {
                        _selectedGroups.clear();
                      } else {
                        for (final g in editable) {
                          _selectedGroups.add(g['id']);
                        }
                      }
                    });
                  },
                ),
              ),
              _groupSortHeader('Name', 'name', flex: 3),
              SizedBox(
                width: 38,
                child: GestureDetector(
                  onTap: () => _sortGroupsBy('size'),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
                    child: Text(
                      'Size${_sortIcon('size', _groupSort)}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              _groupTypeHeader('Email'),
              _groupTypeHeader('SMS'),
              _groupTypeHeader('WA'),
              _groupTypeHeader('Social'),
              const SizedBox(width: 36),
            ],
          ),
        ),
        Expanded(
          child: _loadingGroups
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF094a25)))
              : _filteredGroups.isEmpty
                  ? const Center(
                      child: Text('No groups found',
                          style: TextStyle(color: Color(0xFF094a25))))
                  : RefreshIndicator(
                      onRefresh: _loadGroups,
                      color: const Color(0xFF094a25),
                      child: ListView.builder(
                        itemCount: _filteredGroups.length,
                        itemBuilder: (context, index) => _groupRow(
                            _filteredGroups[index] as Map<String, dynamic>),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _groupSortHeader(String label, String field, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: () => _sortGroupsBy(field),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Text(
            label + _sortIcon(field, _groupSort),
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.black54),
          ),
        ),
      ),
    );
  }

  Widget _groupTypeHeader(String label) => SizedBox(
        width: 38,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54),
              textAlign: TextAlign.center),
        ),
      );

  Widget _groupRow(Map<String, dynamic> group) {
    final id = group['id'] as int;
    final isDefault = group['is_default'] == true;
    final isSelected = _selectedGroups.contains(id);

    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF094a25).withOpacity(0.06)
            : Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: isDefault
                ? const SizedBox()
                : Checkbox(
                    value: isSelected,
                    activeColor: const Color(0xFF094a25),
                    onChanged: (_) => setState(() {
                      if (isSelected)
                        _selectedGroups.remove(id);
                      else
                        _selectedGroups.add(id);
                    }),
                  ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(group['name']?.toString() ?? '',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black87),
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (isDefault)
                    Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF094a25).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Default',
                          style:
                              TextStyle(fontSize: 9, color: Color(0xFF094a25))),
                    ),
                ],
              ),
            ),
          ),
          Expanded(flex: 1, child: _cellText('${group['size'] ?? 0}')),
          _boolCell(group['email'] == true),
          _boolCell(group['sms'] == true),
          _boolCell(group['whatsapp'] == true),
          _boolCell(group['social'] == true),
          SizedBox(
            width: 36,
            child: isDefault
                ? const SizedBox()
                : IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        size: 16, color: Color(0xFF094a25)),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddGroupModal(
                          action: 'edit',
                          group: group,
                          onSave: (data) {
                            Navigator.pop(context);
                            final i = _groups
                                .indexWhere((g) => g['id'] == data['id']);
                            if (i != -1) setState(() => _groups[i] = data);
                            _applyGroupFilters();
                          },
                          onCancel: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _boolCell(bool value) => SizedBox(
        width: 38,
        child: Center(
          child: Text(
            value ? '✓' : '–',
            style: TextStyle(
                fontSize: 13,
                color: value ? const Color(0xFF094a25) : Colors.black26,
                fontWeight: value ? FontWeight.bold : FontWeight.normal),
          ),
        ),
      );

  // ── Shared helpers ────────────────────────────────────────────────────────

  Widget _filterChipToggle(
      String label, bool active, void Function(bool) onTap) {
    return GestureDetector(
      onTap: () => onTap(!active),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF094a25) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                color: active ? Colors.white : Colors.black54,
                fontWeight: active ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  Widget _actionBtn(String label, VoidCallback onTap,
          {bool isDestructive = false}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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

  Widget _pageBtn(String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF094a25)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF094a25))),
        ),
      );
}
