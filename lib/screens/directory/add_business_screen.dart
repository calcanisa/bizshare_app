import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import '../locations/add_location.dart';

class AddBusinessModal extends StatefulWidget {
  final String action; // 'add' or 'edit'
  final Map<String, dynamic>? business;
  final void Function(Map<String, dynamic> data) onSave;
  final VoidCallback onCancel;

  const AddBusinessModal({
    super.key,
    required this.action,
    this.business,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<AddBusinessModal> createState() => _AddBusinessModalState();
}

class _AddBusinessModalState extends State<AddBusinessModal> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  bool _saving = false;
  bool _accepted = false;

  // Image files
  File? _heroFile;
  File? _logoFile;
  String? _existingHero;
  String? _existingLogo;

  // Text controllers
  final _nameController = TextEditingController();
  final _sloganController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _affiliateController = TextEditingController();

  // Dropdown values
  String _businessType = '';
  String _companySize = '0';
  String _founded = '';
  String _hasWeb = '';
  String _hasAffiliate = '';
  bool _openHolidays = false;
  String _holidaysOpen = '';
  String _holidaysClose = '';

  // Categories
  List<dynamic> _categories = [];
  List<dynamic> _subcategories = [];
  List<Map<String, dynamic>> _selectedCategories = [];
  int _mainCategory = 0;
  int _subCategory = 0;

  // Office hours
  final Map<String, String> _openHours = {};
  final Map<String, String> _closeHours = {};

  static const _days = [
    ('monday', 'Monday'),
    ('tuesday', 'Tuesday'),
    ('wednesday', 'Wednesday'),
    ('thursday', 'Thursday'),
    ('friday', 'Friday'),
    ('saturday', 'Saturday'),
    ('sunday', 'Sunday'),
  ];

  static const _hours = [
    ('closed', 'Closed'),
    ('06:00', '06:00'),
    ('06:30', '06:30'),
    ('07:00', '07:00'),
    ('07:30', '07:30'),
    ('08:00', '08:00'),
    ('08:30', '08:30'),
    ('09:00', '09:00'),
    ('09:30', '09:30'),
    ('10:00', '10:00'),
    ('10:30', '10:30'),
    ('11:00', '11:00'),
    ('11:30', '11:30'),
    ('12:00', '12:00'),
    ('12:30', '12:30'),
    ('13:00', '13:00'),
    ('13:30', '13:30'),
    ('14:00', '14:00'),
    ('14:30', '14:30'),
    ('15:00', '15:00'),
    ('15:30', '15:30'),
    ('16:00', '16:00'),
    ('16:30', '16:30'),
    ('17:00', '17:00'),
    ('17:30', '17:30'),
    ('18:00', '18:00'),
    ('18:30', '18:30'),
    ('19:00', '19:00'),
    ('19:30', '19:30'),
    ('20:00', '20:00'),
    ('20:30', '20:30'),
    ('21:00', '21:00'),
    ('22:00', '22:00'),
  ];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    if (widget.action == 'edit' && widget.business != null) {
      _populateForm(widget.business!);
    }
    for (final d in _days) {
      _openHours[d.$1] = '';
      _closeHours[d.$1] = '';
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameController.dispose();
    _sloganController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _affiliateController.dispose();
    super.dispose();
  }

  void _populateForm(Map<String, dynamic> b) {
    _nameController.text = b['name'] ?? '';
    _sloganController.text = b['slogan'] ?? '';
    _descriptionController.text = b['description'] ?? '';
    _phoneController.text = b['phone'] ?? '';
    _emailController.text = b['email'] ?? '';
    _websiteController.text = b['website'] ?? '';
    _affiliateController.text = b['affiliate_url'] ?? '';
    _businessType = b['business_type'] ?? '';
    _companySize = b['size']?.toString() ?? '0';
    _founded = b['founded'] ?? '';
    _existingHero = b['hero'];
    _existingLogo = b['logo'];
    _openHolidays = b['open_holidays'] == true || b['open_holidays'] == 'yes';
    _holidaysOpen = b['holidays_open'] ?? '';
    _holidaysClose = b['holidays_close'] ?? '';
    if (b['website'] != null && b['website'].toString().isNotEmpty) {
      _hasWeb = 'yes';
    }
    if (b['affiliate_url'] != null &&
        b['affiliate_url'].toString().isNotEmpty) {
      _hasAffiliate = 'yes';
    }
    for (final d in _days) {
      _openHours[d.$1] = b['${d.$1}_open'] ?? '';
      _closeHours[d.$1] = b['${d.$1}_close'] ?? '';
    }
    final cats = b['categories'] as List? ?? [];
    _selectedCategories =
        cats.map((c) => Map<String, dynamic>.from(c as Map)).toList();
  }

  Future<void> _loadCategories() async {
    try {
      final api = context.read<ApiService>();
      final res =
          await api.dio.get('/api/v1/directory/business/categories/top/');
      final data = res.data;
      setState(
          () => _categories = data is List ? data : (data['results'] ?? []));
    } catch (_) {}
  }

  void _onMainCategoryChanged(int? id) {
    if (id == null) return;
    final cat =
        _categories.firstWhere((c) => c['id'] == id, orElse: () => null);
    setState(() {
      _mainCategory = id;
      _subcategories = cat?['sub_categories'] ?? [];
      _subCategory = 0;
    });
  }

  void _addCategory() {
    if (_subCategory == 0) {
      _showSnack('Please select a subcategory');
      return;
    }
    final sub = _subcategories.firstWhere((s) => s['id'] == _subCategory,
        orElse: () => null);
    if (sub == null) return;
    if (_selectedCategories.any((c) => c['id'] == sub['id'])) {
      _showSnack('Category already added');
      return;
    }
    if (_selectedCategories.length >= 5) {
      _showSnack('Maximum 5 categories allowed');
      return;
    }
    setState(() {
      _selectedCategories.add(Map<String, dynamic>.from(sub));
    });
  }

  Future<void> _pickImage(bool isHero) async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() {
      if (isHero) {
        _heroFile = File(picked.path);
      } else {
        _logoFile = File(picked.path);
      }
    });
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      _showSnack('Business name is required');
      return;
    }
    if (_selectedCategories.isEmpty) {
      _showSnack('At least one category is required');
      return;
    }
    if (_descriptionController.text.trim().isEmpty) {
      _showSnack('Business description is required');
      return;
    }
    if (_founded.isEmpty) {
      _showSnack('Date founded is required');
      return;
    }
    if (!_accepted) {
      _showSnack('Please accept the terms');
      return;
    }

    setState(() => _saving = true);

    try {
      final api = context.read<ApiService>();

      final formData = FormData();
      formData.fields.addAll([
        MapEntry('name', _nameController.text.trim()),
        MapEntry('slogan', _sloganController.text.trim()),
        MapEntry('description', _descriptionController.text.trim()),
        MapEntry('phone', _phoneController.text.trim()),
        MapEntry('email', _emailController.text.trim()),
        MapEntry('website', _websiteController.text.trim()),
        MapEntry('business_type', _businessType),
        MapEntry('size', _companySize),
        MapEntry('founded', _founded),
        MapEntry('open_holidays', _openHolidays ? 'yes' : 'no'),
        MapEntry('holidays_open', _holidaysOpen),
        MapEntry('holidays_close', _holidaysClose),
        MapEntry('affiliate_url', _affiliateController.text.trim()),
        MapEntry('categories',
            '[${_selectedCategories.map((c) => c['id'].toString()).join(',')}]'),
        const MapEntry('social_profiles', '{}'),
      ]);

      // Office hours
      for (final d in _days) {
        formData.fields.add(MapEntry('${d.$1}_open', _openHours[d.$1] ?? ''));
        formData.fields.add(MapEntry('${d.$1}_close', _closeHours[d.$1] ?? ''));
      }

      // Images
      if (_heroFile != null) {
        formData.files.add(MapEntry(
            'hero',
            await MultipartFile.fromFile(_heroFile!.path,
                filename: 'hero.jpg')));
      }
      if (_logoFile != null) {
        formData.files.add(MapEntry(
            'logo',
            await MultipartFile.fromFile(_logoFile!.path,
                filename: 'logo.jpg')));
      }

      late Response res;
      if (widget.action == 'add') {
        res =
            await api.dio.post('/api/v1/directory/business/c/', data: formData);
      } else {
        final id = widget.business!['id'];
        res = await api.dio
            .put('/api/v1/directory/business/$id/u/', data: formData);
      }

      widget.onSave(res.data);
    } catch (e) {
      _showSnack('Could not save business. Try again.');
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
          widget.action == 'edit' ? 'Edit Business' : 'Create Business',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: widget.onCancel,
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            _infoBox(),
            const SizedBox(height: 16),
            _heroSection(),
            const SizedBox(height: 16),
            _logoSection(),
            const SizedBox(height: 20),
            _sectionHeader('Basic Info'),
            const SizedBox(height: 12),
            _field('Business Name *', _nameController, maxLength: 100),
            _field('Slogan', _sloganController, maxLength: 100),
            _businessTypeDropdown(),
            _categoriesSection(),
            _field('Description *', _descriptionController,
                maxLines: 5, maxLength: 3000),
            _foundedField(),
            _companySizeDropdown(),
            _field('Phone *', _phoneController,
                keyboardType: TextInputType.phone, maxLength: 10),
            _field('Email *', _emailController,
                keyboardType: TextInputType.emailAddress),
            _websiteSection(),
            _affiliateSection(),
            const SizedBox(height: 20),
            _sectionHeader('Office Hours'),
            const SizedBox(height: 12),
            _officeHoursSection(),
            _holidaysSection(),
            const SizedBox(height: 24),
            _termsAndSave(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ─── Info box ──────────────────────────────────────────────────────────────

  Widget _infoBox() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1B4748).withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF1B4748).withOpacity(0.2)),
        ),
        child: const Text(
          'It is important for business profiles to be complete, as a partially completed profile can harm your brand.',
          style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.5),
        ),
      );

  // ─── Hero image ────────────────────────────────────────────────────────────

  Widget _heroSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Header Image',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B4748))),
          const Text('Ideal size: 1920 x 600px',
              style: TextStyle(fontSize: 11, color: Colors.black45)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _pickImage(true),
            child: Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: _heroFile != null
                  ? Stack(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(_heroFile!,
                            width: double.infinity,
                            height: 140,
                            fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: GestureDetector(
                          onTap: () => setState(() => _heroFile = null),
                          child: _removeBtn(),
                        ),
                      ),
                    ])
                  : _existingHero != null
                      ? Stack(children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(_existingHero!,
                                width: double.infinity,
                                height: 140,
                                fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: GestureDetector(
                              onTap: () => setState(() => _existingHero = null),
                              child: _removeBtn(),
                            ),
                          ),
                        ])
                      : const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate,
                                  color: Colors.black26, size: 36),
                              SizedBox(height: 6),
                              Text('Tap to upload hero image',
                                  style: TextStyle(
                                      color: Colors.black38, fontSize: 12)),
                            ],
                          ),
                        ),
            ),
          ),
        ],
      );

  // ─── Logo image ────────────────────────────────────────────────────────────

  Widget _logoSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Logo',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B4748))),
          const Text('Ideal size: 300 x 300px',
              style: TextStyle(fontSize: 11, color: Colors.black45)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _pickImage(false),
            child: Container(
              height: 140,
              width: 140,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: _logoFile != null
                  ? Stack(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(_logoFile!,
                            width: 140, height: 140, fit: BoxFit.contain),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => setState(() => _logoFile = null),
                          child: _removeBtn(),
                        ),
                      ),
                    ])
                  : _existingLogo != null
                      ? Stack(children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(_existingLogo!,
                                width: 140, height: 140, fit: BoxFit.contain),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => setState(() => _existingLogo = null),
                              child: _removeBtn(),
                            ),
                          ),
                        ])
                      : const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.business,
                                  color: Colors.black26, size: 32),
                              SizedBox(height: 4),
                              Text('Upload logo',
                                  style: TextStyle(
                                      color: Colors.black38, fontSize: 11)),
                            ],
                          ),
                        ),
            ),
          ),
        ],
      );

  // ─── Business type ────────────────────────────────────────────────────────

  Widget _businessTypeDropdown() => _dropdownField(
        'Business Type',
        _businessType,
        const [
          DropdownMenuItem(value: '', child: Text('Select type')),
          DropdownMenuItem(value: 'sole', child: Text('Sole Proprietor')),
          DropdownMenuItem(value: 'partnership', child: Text('Partnership')),
          DropdownMenuItem(value: 'closed', child: Text('Closed Corporation')),
          DropdownMenuItem(value: 'public', child: Text('Public Company')),
          DropdownMenuItem(
              value: 'personal', child: Text('Personal Liability')),
          DropdownMenuItem(value: 'nonprofit', child: Text('Non Profit')),
          DropdownMenuItem(value: 'state', child: Text('State Owned')),
        ],
        (v) => setState(() => _businessType = v ?? ''),
      );

  // ─── Categories ────────────────────────────────────────────────────────────

  Widget _categoriesSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('Categories *'),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _dropdown<int>(
                  value: _mainCategory == 0 ? null : _mainCategory,
                  hint: 'Category',
                  items: _categories
                      .map((c) => DropdownMenuItem<int>(
                            value: c['id'],
                            child: Text(c['name'] ?? '',
                                style: const TextStyle(fontSize: 13)),
                          ))
                      .toList(),
                  onChanged: _onMainCategoryChanged,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _dropdown<int>(
                  value: _subCategory == 0 ? null : _subCategory,
                  hint: 'Sub Category',
                  items: _subcategories
                      .map((c) => DropdownMenuItem<int>(
                            value: c['id'],
                            child: Text(c['name'] ?? '',
                                style: const TextStyle(fontSize: 13)),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _subCategory = v ?? 0),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _addCategory,
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B4748),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10)),
                child: const Text('Add',
                    style: TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('You may choose up to 5 categories',
              style: TextStyle(fontSize: 11, color: Colors.black45)),
          if (_selectedCategories.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _selectedCategories
                  .map((cat) => Chip(
                        label: Text(cat['name'] ?? '',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12)),
                        backgroundColor: const Color(0xFFF48900),
                        deleteIcon: const Icon(Icons.close,
                            size: 14, color: Colors.white),
                        onDeleted: () => setState(() => _selectedCategories
                            .removeWhere((c) => c['id'] == cat['id'])),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 16),
        ],
      );

  // ─── Founded ───────────────────────────────────────────────────────────────

  Widget _foundedField() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('Founded *'),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: _founded.isNotEmpty
                    ? DateTime.tryParse(_founded) ?? now
                    : now,
                firstDate: DateTime(1800),
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
                setState(
                    () => _founded = picked.toIso8601String().split('T')[0]);
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
                      _founded.isEmpty ? 'Select date' : _founded,
                      style: TextStyle(
                          fontSize: 13,
                          color: _founded.isEmpty
                              ? Colors.black45
                              : Colors.black87),
                    ),
                  ),
                  const Icon(Icons.calendar_today,
                      size: 16, color: Colors.black45),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      );

  // ─── Company size ──────────────────────────────────────────────────────────

  Widget _companySizeDropdown() => _dropdownField(
        'Company Size *',
        _companySize == '0' ? '' : _companySize,
        const [
          DropdownMenuItem(value: '', child: Text('Please select')),
          DropdownMenuItem(value: '10', child: Text('1 to 10 employees')),
          DropdownMenuItem(value: '11', child: Text('11 to 100')),
          DropdownMenuItem(value: '101', child: Text('101 to 1000')),
          DropdownMenuItem(value: '1001', child: Text('1001 to 10,000')),
          DropdownMenuItem(value: '10001', child: Text('More than 10,000')),
        ],
        (v) => setState(() => _companySize = v ?? '0'),
      );

  // ─── Website ───────────────────────────────────────────────────────────────

  Widget _websiteSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('Website'),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _radioOption('Has Website', 'yes', _hasWeb,
                  (v) => setState(() => _hasWeb = v!)),
              _radioOption('No Website', 'no', _hasWeb,
                  (v) => setState(() => _hasWeb = v!)),
              _radioOption('Need Website', 'need', _hasWeb,
                  (v) => setState(() => _hasWeb = v!)),
            ],
          ),
          if (_hasWeb == 'yes') ...[
            const SizedBox(height: 8),
            _textField(_websiteController,
                hint: 'Website address', keyboardType: TextInputType.url),
          ],
          if (_hasWeb == 'need') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Please send an email with your requirements to websites@bizshare.co.za and someone will contact you promptly.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      );

  // ─── Affiliate ─────────────────────────────────────────────────────────────

  Widget _affiliateSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('Affiliate Program'),
          const Text('Does your company have an affiliate program?',
              style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 6),
          Row(
            children: [
              _radioOption('Yes', 'yes', _hasAffiliate,
                  (v) => setState(() => _hasAffiliate = v!)),
              const SizedBox(width: 16),
              _radioOption('No', 'no', _hasAffiliate,
                  (v) => setState(() => _hasAffiliate = v!)),
            ],
          ),
          if (_hasAffiliate == 'yes') ...[
            const SizedBox(height: 8),
            _textField(_affiliateController,
                hint: 'Program URL', keyboardType: TextInputType.url),
          ],
          const SizedBox(height: 16),
        ],
      );

  // ─── Office hours ──────────────────────────────────────────────────────────

  Widget _officeHoursSection() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: _days.map((d) => _dayHoursRow(d)).toList(),
        ),
      );

  Widget _dayHoursRow((String, String) day) {
    final isOpen =
        _openHours[day.$1] != 'closed' && _openHours[day.$1]!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(day.$2,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B4748))),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Open',
                        style: TextStyle(fontSize: 11, color: Colors.black45)),
                    const SizedBox(height: 2),
                    _hoursDropdown(
                      value: _openHours[day.$1],
                      onChanged: (v) =>
                          setState(() => _openHours[day.$1] = v ?? ''),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Close',
                        style: TextStyle(fontSize: 11, color: Colors.black45)),
                    const SizedBox(height: 2),
                    _hoursDropdown(
                      value: _closeHours[day.$1],
                      enabled: isOpen,
                      onChanged: (v) =>
                          setState(() => _closeHours[day.$1] = v ?? ''),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hoursDropdown(
          {String? value,
          bool enabled = true,
          void Function(String?)? onChanged}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          border: Border.all(color: enabled ? Colors.black26 : Colors.black12),
          borderRadius: BorderRadius.circular(6),
          color: enabled ? Colors.white : Colors.grey.shade100,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value?.isEmpty ?? true ? null : value,
            hint: const Text('Select',
                style: TextStyle(fontSize: 12, color: Colors.black38)),
            isExpanded: true,
            isDense: true,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
            onChanged: enabled ? onChanged : null,
            items: _hours
                .map((h) => DropdownMenuItem(
                    value: h.$1,
                    child: Text(h.$2, style: const TextStyle(fontSize: 12))))
                .toList(),
          ),
        ),
      );

  // ─── Holidays ──────────────────────────────────────────────────────────────

  Widget _holidaysSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Row(
            children: [
              Checkbox(
                value: _openHolidays,
                activeColor: const Color(0xFF1B4748),
                onChanged: (v) => setState(() => _openHolidays = v ?? false),
              ),
              const Text('Open on public holidays',
                  style: TextStyle(fontSize: 13, color: Colors.black87)),
            ],
          ),
          if (_openHolidays) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Open',
                          style:
                              TextStyle(fontSize: 11, color: Colors.black45)),
                      const SizedBox(height: 2),
                      _hoursDropdown(
                        value: _holidaysOpen,
                        onChanged: (v) =>
                            setState(() => _holidaysOpen = v ?? ''),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Close',
                          style:
                              TextStyle(fontSize: 11, color: Colors.black45)),
                      const SizedBox(height: 2),
                      _hoursDropdown(
                        value: _holidaysClose,
                        enabled: _holidaysOpen != 'closed' &&
                            _holidaysOpen.isNotEmpty,
                        onChanged: (v) =>
                            setState(() => _holidaysClose = v ?? ''),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
        ],
      );

  // ─── Terms and save ────────────────────────────────────────────────────────

  Widget _termsAndSave() => Column(
        children: [
          if (widget.action == 'add')
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
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
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: (widget.action == 'edit' || _accepted) && !_saving
                      ? _save
                      : null,
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
                      : Text(widget.action == 'edit' ? 'Save' : 'Create',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
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
                  child: const Text('Cancel', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ],
      );

  // ─── Shared helpers ────────────────────────────────────────────────────────

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

  Widget _field(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    int? maxLength,
    TextInputType keyboardType = TextInputType.text,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel(label),
          const SizedBox(height: 6),
          _textField(controller,
              maxLines: maxLines,
              maxLength: maxLength,
              keyboardType: keyboardType),
          const SizedBox(height: 16),
        ],
      );

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

  Widget _dropdownField<T>(
    String label,
    T? value,
    List<DropdownMenuItem<T>> items,
    void Function(T?) onChanged,
  ) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel(label),
          const SizedBox(height: 6),
          _dropdown<T>(
              value: value, hint: 'Select', items: items, onChanged: onChanged),
          const SizedBox(height: 16),
        ],
      );

  Widget _dropdown<T>({
    T? value,
    String hint = 'Select',
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
            items: items,
            onChanged: onChanged,
          ),
        ),
      );

  Widget _radioOption(
    String label,
    String value,
    String groupValue,
    void Function(String?) onChanged,
  ) =>
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<String>(
            value: value,
            groupValue: groupValue,
            activeColor: const Color(0xFF1B4748),
            onChanged: onChanged,
          ),
          Text(label,
              style: const TextStyle(fontSize: 13, color: Colors.black87)),
        ],
      );

  Widget _removeBtn() => Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.close, color: Colors.white, size: 14),
      );
}
