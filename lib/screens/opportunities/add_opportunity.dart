import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';

class AddOpportunityModal extends StatefulWidget {
  final String action; // 'add' or 'edit'
  final Map<String, dynamic>? opportunity;
  final void Function(Map<String, dynamic> data) onSave;
  final VoidCallback onCancel;

  const AddOpportunityModal({
    super.key,
    required this.action,
    this.opportunity,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<AddOpportunityModal> createState() => _AddOpportunityModalState();
}

class _AddOpportunityModalState extends State<AddOpportunityModal> {
  bool _saving = false;
  bool _accepted = false;
  bool _published = true;
  bool _quoteMe = false;

  File? _imageFile;
  String? _existingImage;

  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _valueController = TextEditingController();
  String _validUntil = '';

  // Category: parent = 1 (Offline), 2 (Online)
  int? _categoryParent;
  int? _categoryId;
  List<dynamic> _categories = [];

  // Location (offline only)
  List<dynamic> _provinces = [];
  List<dynamic> _cities = [];
  List<dynamic> _areas = [];
  int? _selectedProvince;
  int? _selectedCity;
  int? _selectedArea;

  List<dynamic> get _filteredCategories {
    if (_categoryParent == null) return [];
    return _categories
        .where((c) => c['parent'] == _categoryParent)
        .toList();
  }

  String get _maxDate {
    final date = DateTime.now().add(const Duration(days: 31));
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadProvinces();
    if (widget.action == 'edit' && widget.opportunity != null) {
      _populate(widget.opportunity!);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final api = context.read<ApiService>();
      final res = await api.dio.get('/api/v1/opportunities/categories/');
      final data = res.data;
      setState(() =>
          _categories = data is List ? data : (data['results'] ?? []));
    } catch (_) {}
  }

  Future<void> _loadProvinces() async {
    try {
      final api = context.read<ApiService>();
      final res = await api.dio.get('/api/v1/locations/provinces/');
      final data = res.data;
      setState(() =>
          _provinces = data is List ? data : (data['results'] ?? []));
    } catch (_) {}
  }

  Future<void> _loadCities(int provinceId) async {
    try {
      final api = context.read<ApiService>();
      final res =
          await api.dio.get('/api/v1/locations/cities/$provinceId/');
      final data = res.data;
      setState(() {
        _cities = data is List ? data : (data['results'] ?? []);
        _selectedCity = null;
        _areas = [];
        _selectedArea = null;
      });
    } catch (_) {}
  }

  Future<void> _loadAreas(int cityId) async {
    try {
      final api = context.read<ApiService>();
      final res =
          await api.dio.get('/api/v1/locations/areas/$cityId/');
      final data = res.data;
      setState(() {
        _areas = data is List ? data : (data['results'] ?? []);
        _selectedArea = null;
      });
    } catch (_) {}
  }

  void _populate(Map<String, dynamic> opp) {
    _titleController.text = opp['title'] ?? '';
    _descController.text = opp['description'] ?? '';
    _valueController.text = opp['opp_value']?.toString() ?? '';
    _validUntil = opp['valid_until'] ?? '';
    _existingImage = opp['image'];
    _published = opp['published'] ?? true;
    _quoteMe = opp['quote_me'] ?? false;
    _categoryParent = (opp['category'] as Map?)?['parent'];
    _categoryId = (opp['category'] as Map?)?['id'];
    _accepted = true;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      _showSnack('Title is required');
      return;
    }
    if (!_quoteMe && _valueController.text.trim().isEmpty) {
      _showSnack('You have to enter a value for this opportunity');
      return;
    }
    if (widget.action == 'add' && !_accepted) {
      _showSnack('You must accept the terms');
      return;
    }

    setState(() => _saving = true);
    try {
      final api = context.read<ApiService>();
      final formData = FormData();
      formData.fields.addAll([
        MapEntry('title', _titleController.text.trim()),
        MapEntry('description', _descController.text.trim()),
        MapEntry('category', _categoryId?.toString() ?? ''),
        MapEntry('opp_value',
            _quoteMe ? '' : _valueController.text.trim()),
        MapEntry('quote_me', _quoteMe.toString()),
        MapEntry('valid_until', _validUntil),
        MapEntry('published', _published.toString()),
        if (_selectedCity != null)
          MapEntry('city', _selectedCity.toString()),
        if (_selectedArea != null)
          MapEntry('area', _selectedArea.toString()),
      ]);

      if (_imageFile != null) {
        formData.files.add(MapEntry('image',
            await MultipartFile.fromFile(_imageFile!.path,
                filename: 'opp.jpg')));
      }

      late Map<String, dynamic> result;
      if (widget.action == 'add') {
        final res = await api.dio.post(
            '/api/v1/opportunities/opportunity/c/',
            data: formData);
        result = res.data;
      } else {
        final id = widget.opportunity!['id'];
        final res = await api.dio.patch(
            '/api/v1/opportunities/opportunity/$id/u/',
            data: formData);
        result = res.data;
      }
      widget.onSave(result);
    } catch (_) {
      _showSnack('Failed to save opportunity. Please try again.');
    }
    setState(() => _saving = false);
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF094a25),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.action == 'edit'
              ? 'Edit Opportunity'
              : 'Add Opportunity',
          style: const TextStyle(
              color: Colors.white, fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: widget.onCancel,
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Warning
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFbc2023).withOpacity(0.07),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'DO NOT post permanent positions using opportunities. It will be deleted without explanation. Opportunities are valid for one month but can be extended.',
              style: TextStyle(
                  fontSize: 12, color: Colors.black54, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),

          // Image
          _imageSection(),
          const SizedBox(height: 16),

          // Title
          _fieldLabel('Title'),
          const SizedBox(height: 6),
          _textField(_titleController,
              hint: 'Give this opportunity a title',
              maxLength: 100),
          const SizedBox(height: 16),

          // Description
          _fieldLabel('Description'),
          const SizedBox(height: 6),
          _textField(_descController,
              hint: 'Describe what this opportunity entails',
              maxLines: 5,
              maxLength: 1000),
          const SizedBox(height: 16),

          // Type (parent category)
          _fieldLabel('Type'),
          const SizedBox(height: 6),
          _dropdownWidget<int>(
            value: _categoryParent,
            hint: 'Select',
            items: const [
              DropdownMenuItem(value: 1, child: Text('Offline')),
              DropdownMenuItem(value: 2, child: Text('Online')),
            ],
            onChanged: (v) => setState(() {
              _categoryParent = v;
              _categoryId = null;
            }),
          ),
          const SizedBox(height: 16),

          // Sub category
          if (_categoryParent != null &&
              _filteredCategories.isNotEmpty) ...[
            _fieldLabel('Category'),
            const SizedBox(height: 6),
            _dropdownWidget<int>(
              value: _categoryId,
              hint: 'Select',
              items: _filteredCategories
                  .map((c) => DropdownMenuItem<int>(
                        value: c['id'],
                        child: Text(c['name'] ?? '',
                            style:
                                const TextStyle(fontSize: 13)),
                      ))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _categoryId = v),
            ),
            const SizedBox(height: 16),
          ],

          // Location (offline only)
          if (_categoryParent == 1) ...[
            _sectionHeader('Location'),
            const SizedBox(height: 12),
            _dropdownWidget<int>(
              value: _selectedProvince,
              hint: 'Province',
              items: _provinces
                  .map((p) => DropdownMenuItem<int>(
                        value: p['id'],
                        child: Text(p['name'] ?? '',
                            style:
                                const TextStyle(fontSize: 13)),
                      ))
                  .toList(),
              onChanged: (v) {
                setState(() => _selectedProvince = v);
                if (v != null) _loadCities(v);
              },
            ),
            if (_cities.isNotEmpty) ...[
              const SizedBox(height: 8),
              _dropdownWidget<int>(
                value: _selectedCity,
                hint: 'City',
                items: _cities
                    .map((c) => DropdownMenuItem<int>(
                          value: c['id'],
                          child: Text(c['name'] ?? '',
                              style: const TextStyle(
                                  fontSize: 13)),
                        ))
                    .toList(),
                onChanged: (v) {
                  setState(() => _selectedCity = v);
                  if (v != null) _loadAreas(v);
                },
              ),
            ],
            if (_areas.isNotEmpty) ...[
              const SizedBox(height: 8),
              _dropdownWidget<int>(
                value: _selectedArea,
                hint: 'Area / Suburb',
                items: _areas
                    .map((a) => DropdownMenuItem<int>(
                          value: a['id'],
                          child: Text(a['name'] ?? '',
                              style: const TextStyle(
                                  fontSize: 13)),
                        ))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _selectedArea = v),
              ),
            ],
            const SizedBox(height: 16),
          ],

          // Value
          _fieldLabel('Value'),
          const SizedBox(height: 6),
          Row(
            children: [
              Checkbox(
                value: _quoteMe,
                activeColor: const Color(0xFF094a25),
                onChanged: (v) =>
                    setState(() => _quoteMe = v ?? false),
              ),
              const Text('Quote me',
                  style: TextStyle(fontSize: 13)),
            ],
          ),
          if (!_quoteMe) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Text('R ',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF094a25))),
                Expanded(
                  child: _textField(_valueController,
                      hint: 'What is this opportunity worth?',
                      keyboardType: TextInputType.number),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),

          // Valid until
          _fieldLabel('Valid Until'),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () async {
              final now = DateTime.now();
              final max =
                  now.add(const Duration(days: 31));
              final picked = await showDatePicker(
                context: context,
                initialDate: _validUntil.isNotEmpty
                    ? DateTime.tryParse(_validUntil) ?? now
                    : now,
                firstDate: now,
                lastDate: max,
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: const ColorScheme.light(
                        primary: Color(0xFF094a25)),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) {
                setState(() => _validUntil =
                    picked.toIso8601String().split('T')[0]);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _validUntil.isEmpty
                          ? 'Select date'
                          : _validUntil,
                      style: TextStyle(
                          fontSize: 13,
                          color: _validUntil.isEmpty
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

          // Published
          Row(
            children: [
              Checkbox(
                value: _published,
                activeColor: const Color(0xFF094a25),
                onChanged: (v) =>
                    setState(() => _published = v ?? true),
              ),
              const Text('Published',
                  style: TextStyle(fontSize: 13)),
            ],
          ),

          // Terms
          if (widget.action == 'add') ...[
            Row(
              children: [
                Checkbox(
                  value: _accepted,
                  activeColor: const Color(0xFF094a25),
                  onChanged: (v) =>
                      setState(() => _accepted = v ?? false),
                ),
                const Text('I accept the '),
                GestureDetector(
                  onTap: () {},
                  child: const Text('terms',
                      style: TextStyle(
                          color: Color(0xFF094a25),
                          decoration:
                              TextDecoration.underline)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),

          // Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF094a25),
                    disabledBackgroundColor:
                        Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(8)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2))
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
                    foregroundColor: const Color(0xFFbc2023),
                    side: const BorderSide(
                        color: Color(0xFFbc2023)),
                    padding: const EdgeInsets.symmetric(
                        vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(8)),
                  ),
                  child: const Text('Cancel',
                      style: TextStyle(fontSize: 15)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _imageSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('Image (optional)'),
          const Text('Ideal size: 500 x 400px',
              style: TextStyle(
                  fontSize: 11, color: Colors.black45)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _imageFile == null && _existingImage == null
                ? _pickImage
                : null,
            child: Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: _imageFile != null
                  ? Stack(children: [
                      ClipRRect(
                          borderRadius:
                              BorderRadius.circular(8),
                          child: Image.file(_imageFile!,
                              width: double.infinity,
                              height: 160,
                              fit: BoxFit.cover)),
                      Positioned(
                          top: 6,
                          right: 6,
                          child: GestureDetector(
                              onTap: () => setState(
                                  () => _imageFile = null),
                              child: _closeBtn())),
                    ])
                  : _existingImage != null
                      ? Stack(children: [
                          ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(8),
                              child: Image.network(
                                  _existingImage!,
                                  width: double.infinity,
                                  height: 160,
                                  fit: BoxFit.cover)),
                          Positioned(
                              top: 6,
                              right: 6,
                              child: GestureDetector(
                                  onTap: () => setState(() =>
                                      _existingImage = null),
                                  child: _closeBtn())),
                        ])
                      : Center(
                          child: Column(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              const Icon(
                                  Icons.add_photo_alternate,
                                  color: Colors.black26,
                                  size: 32),
                              TextButton(
                                  onPressed: _pickImage,
                                  child: const Text(
                                      'Upload Image',
                                      style: TextStyle(
                                          color: Color(
                                              0xFF094a25)))),
                            ],
                          ),
                        ),
            ),
          ),
        ],
      );

  Widget _sectionHeader(String title) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF094a25),
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
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Color(0xFF094a25)));

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
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                const BorderSide(color: Color(0xFF094a25)),
          ),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 10),
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
                style: const TextStyle(
                    color: Colors.black45, fontSize: 13)),
            isExpanded: true,
            style: const TextStyle(
                fontSize: 13, color: Colors.black87),
            items: [
              DropdownMenuItem<T>(
                  value: null,
                  child: Text(hint,
                      style: const TextStyle(
                          color: Colors.black45,
                          fontSize: 13))),
              ...items,
            ],
            onChanged: onChanged,
          ),
        ),
      );

  Widget _closeBtn() => Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
            color: Colors.black54, shape: BoxShape.circle),
        child: const Icon(Icons.close,
            color: Colors.white, size: 14),
      );
}