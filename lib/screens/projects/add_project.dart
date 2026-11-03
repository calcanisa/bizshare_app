import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class AddProjectScreen extends StatefulWidget {
  final String action; // 'add' | 'edit'
  final Map<String, dynamic>? project;

  const AddProjectScreen({
    super.key,
    required this.action,
    this.project,
  });

  @override
  State<AddProjectScreen> createState() => _AddProjectScreenState();
}

class _AddProjectScreenState extends State<AddProjectScreen> {
  static const _green = Color(0xFF1B4748);
  static const _red = Color(0xFFF48900);

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _investmentSizeCtrl = TextEditingController();

  String? _stage;
  String? _teamSize;
  String? _lookingFor;
  int? _selectedCategoryId;
  int? _selectedProvinceId;
  int? _selectedCityId;
  int? _selectedAreaId;

  bool _businessPlan = false;
  bool _acceptedTerms = false;
  bool _saving = false;

  File? _pickedImage;
  String? _existingImageUrl;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _provinces = [];
  List<Map<String, dynamic>> _cities = [];
  List<Map<String, dynamic>> _areas = [];
  bool _loadingData = true;
  bool _hasError = false;

  static const _stageOptions = [
    ('idea', 'Idea'),
    ('startup', 'Startup'),
    ('growth', 'Growth'),
    ('expansion', 'Expansion'),
    ('mature', 'Mature'),
  ];

  static const _teamOptions = [
    ('1', '1 to 10 people'),
    ('11', '11 to 50 people'),
    ('51', '51 to 100 people'),
    ('101', 'More than 100 people'),
  ];

  static const _lookingForOptions = [
    ('investor', 'Investor'),
    ('partner', 'Partner'),
    ('provider', 'Provider'),
    ('coach', 'Mentor'),
  ];

  @override
  void initState() {
    super.initState();
    _titleCtrl.addListener(() => setState(() {}));
    _descCtrl.addListener(() => setState(() {}));
    _loadInitialData();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _investmentSizeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _loadingData = true;
      _hasError = false;
    });
    try {
      final api = context.read<ApiService>();
      final results = await Future.wait([
        api.dio.get('/api/v1/directory/business/categories/top/'),
        api.dio.get('/api/v1/locations/provinces/'),
      ]);
      if (!mounted) return;
      final cats = results[0].data;
      final provs = results[1].data;
      setState(() {
        _categories = List<Map<String, dynamic>>.from(
            cats is List ? cats : (cats['results'] ?? []));
        _provinces = List<Map<String, dynamic>>.from(
            provs is List ? provs : (provs['results'] ?? []));
      });
      // Prefill AFTER categories/provinces are loaded so dropdowns have their items
      if (widget.action == 'edit' && widget.project != null) {
        _prefill(widget.project!);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _hasError = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showError('Could not load form data. Please try again.');
      });
    } finally {
      if (mounted) setState(() => _loadingData = false);
    }
  }

  Future<void> _loadCities(int provinceId) async {
    setState(() {
      _cities = [];
      _areas = [];
      _selectedCityId = null;
      _selectedAreaId = null;
    });
    try {
      final api = context.read<ApiService>();
      final res = await api.dio.get('/api/v1/locations/cities/$provinceId/');
      setState(() {
        _cities = List<Map<String, dynamic>>.from(
            res.data is List ? res.data : (res.data['results'] ?? []));
      });
    } catch (_) {}
  }

  Future<void> _loadAreas(int cityId) async {
    setState(() {
      _areas = [];
      _selectedAreaId = null;
    });
    try {
      final api = context.read<ApiService>();
      final res = await api.dio.get('/api/v1/locations/areas/$cityId/');
      setState(() {
        _areas = List<Map<String, dynamic>>.from(
            res.data is List ? res.data : (res.data['results'] ?? []));
      });
    } catch (_) {}
  }

  void _prefill(Map<String, dynamic> p) {
    _titleCtrl.text = p['title'] ?? '';
    _descCtrl.text = p['description'] ?? '';
    _investmentSizeCtrl.text = p['project_size'] ?? '';
    _stage = p['stage'];
    _teamSize = p['team_size']?.toString();
    _lookingFor = p['looking_for'];
    _businessPlan = p['business_plan'] ?? false;
    _existingImageUrl = p['image'] as String?;

    final cat = p['category'];
    if (cat is Map) _selectedCategoryId = cat['id'] as int?;

    final area = p['area'];
    if (area is Map) {
      final city = area['city'] as Map?;
      if (city != null) {
        final province = city['province'] as Map?;
        if (province != null) {
          _selectedProvinceId = province['id'] as int?;
          _loadCities(province['id'] as int).then((_) {
            setState(() => _selectedCityId = city['id'] as int?);
            _loadAreas(city['id'] as int).then((_) {
              setState(() => _selectedAreaId = area['id'] as int?);
            });
          });
        }
      }
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      setState(() {
        _pickedImage = File(picked.path);
        _existingImageUrl = null;
      });
    }
  }

  void _removeImage() => setState(() {
        _pickedImage = null;
        _existingImageUrl = null;
      });

  bool _validate() {
    if (_titleCtrl.text.trim().isEmpty) {
      _showError('Title is required.');
      return false;
    }
    if (_stage == null) {
      _showError('Please select a project stage.');
      return false;
    }
    if (_teamSize == null) {
      _showError('Please select a team size.');
      return false;
    }
    if (_selectedCategoryId == null) {
      _showError('Please select an industry.');
      return false;
    }
    if (_lookingFor == null) {
      _showError('Please select what you are looking for.');
      return false;
    }
    if (_descCtrl.text.trim().isEmpty) {
      _showError('Description is required.');
      return false;
    }
    if (widget.action == 'add' && !_acceptedTerms) {
      _showError('You must accept the terms to continue.');
      return false;
    }
    return true;
  }

  Future<void> _save() async {
    if (!_validate()) return;
    setState(() => _saving = true);
    final auth = context.read<AuthProvider>();

    final fields = <String, String>{
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'stage': _stage!,
      'team_size': _teamSize!,
      'looking_for': _lookingFor!,
      'category_id': _selectedCategoryId.toString(),
      'business_plan': _businessPlan ? 'true' : 'false',
      if (_investmentSizeCtrl.text.trim().isNotEmpty)
        'project_size': _investmentSizeCtrl.text.trim(),
      if (_selectedAreaId != null) 'area': _selectedAreaId.toString(),
    };

    final files = <String, File>{};
    if (_pickedImage != null) files['image'] = _pickedImage!;

    try {
      if (widget.action == 'add') {
        final result = await auth.apiService.postMultipart(
          '/api/v1/projects/project/c/',
          fields: fields,
          files: files,
        );
        if (!mounted) return;
        _showSuccess('Project created successfully.');
        Navigator.pop(context, result);
      } else {
        final result = await auth.apiService.patchMultipart(
          '/api/v1/projects/project/${widget.project!['id']}/u/',
          fields: fields,
          files: files,
        );
        if (!mounted) return;
        _showSuccess('Project updated successfully.');
        Navigator.pop(context, result);
      }
    } on DioException catch (e) {
      _showError(
          e.response?.data?['error'] ?? 'Could not save project. Try again.');
    } catch (_) {
      _showError('Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: _red));

  void _showSuccess(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: _green));

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.action == 'edit';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        title: Text(isEdit ? 'Edit Project' : 'Add Project'),
        elevation: 0,
      ),
      body: _loadingData
          ? const Center(child: CircularProgressIndicator(color: _green))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isEdit) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFF8BB25).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFFF8BB25)
                                  .withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.lightbulb_outline,
                                color: Color(0xFFF8BB25), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Do not share secretive information about your project. '
                                'Add enough to attract interest, but protect your idea. '
                                'Consider patenting any new inventions.',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[700]),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    _buildImagePicker(),
                    const SizedBox(height: 20),
                    _label('Title', required: true),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _titleCtrl,
                      maxLength: 100,
                      buildCounter: (_,
                              {required currentLength,
                              required isFocused,
                              maxLength}) =>
                          Text('$currentLength / $maxLength',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: currentLength == maxLength
                                      ? _red
                                      : Colors.grey[400])),
                      decoration: _inputDeco('Max 100 characters'),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 16),
                    _label('Project Stage', required: true),
                    const SizedBox(height: 6),
                    _buildDropdown<String>(
                      value: _stage,
                      hint: 'Select stage',
                      items: _stageOptions
                          .map((o) => DropdownMenuItem(
                              value: o.$1,
                              child: Text(o.$2, style: _dropdownTextStyle)))
                          .toList(),
                      onChanged: (v) => setState(() => _stage = v),
                    ),
                    const SizedBox(height: 16),
                    _label('Team Size', required: true),
                    const SizedBox(height: 6),
                    _buildDropdown<String>(
                      value: _teamSize,
                      hint: 'Select team size',
                      items: _teamOptions
                          .map((o) => DropdownMenuItem(
                              value: o.$1,
                              child: Text(o.$2, style: _dropdownTextStyle)))
                          .toList(),
                      onChanged: (v) => setState(() => _teamSize = v),
                    ),
                    const SizedBox(height: 16),
                    _label('Industry', required: true),
                    const SizedBox(height: 6),
                    _buildDropdown<int>(
                      value: _selectedCategoryId,
                      hint: 'Select industry',
                      items: _categories
                          .map((c) => DropdownMenuItem<int>(
                              value: c['id'] as int,
                              child: Text(c['name']?.toString() ?? '',
                                  style: _dropdownTextStyle)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedCategoryId = v),
                    ),
                    const SizedBox(height: 16),
                    _label('Looking For', required: true),
                    const SizedBox(height: 6),
                    _buildDropdown<String>(
                      value: _lookingFor,
                      hint: 'Select',
                      items: _lookingForOptions
                          .map((o) => DropdownMenuItem(
                              value: o.$1,
                              child: Text(o.$2, style: _dropdownTextStyle)))
                          .toList(),
                      onChanged: (v) => setState(() => _lookingFor = v),
                    ),
                    const SizedBox(height: 16),
                    if (_lookingFor == 'investor') ...[
                      _label('Investment Size'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _investmentSizeCtrl,
                        decoration: _inputDeco('e.g. R500000'),
                        keyboardType: TextInputType.text,
                      ),
                      const SizedBox(height: 16),
                    ],
                    _label('Location (optional)'),
                    const SizedBox(height: 6),
                    _buildLocationRow(),
                    const SizedBox(height: 16),
                    _label('Project Description', required: true),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _descCtrl,
                      maxLines: 7,
                      maxLength: 5000,
                      buildCounter: (_,
                              {required currentLength,
                              required isFocused,
                              maxLength}) =>
                          Text('$currentLength / $maxLength',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: currentLength == maxLength
                                      ? _red
                                      : Colors.grey[400])),
                      decoration: _inputDeco('Max 5000 characters'),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Checkbox(
                          value: _businessPlan,
                          activeColor: _green,
                          onChanged: (v) =>
                              setState(() => _businessPlan = v ?? false),
                        ),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _businessPlan = !_businessPlan),
                          child: const Text('I have a business plan',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: _green,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                    if (!isEdit) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Checkbox(
                            value: _acceptedTerms,
                            activeColor: _green,
                            onChanged: (v) =>
                                setState(() => _acceptedTerms = v ?? false),
                          ),
                          GestureDetector(
                            onTap: () => setState(
                                () => _acceptedTerms = !_acceptedTerms),
                            child: RichText(
                              text: const TextSpan(
                                style: TextStyle(
                                    fontSize: 13, color: Colors.black87),
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
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _saving ? null : _save,
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
                                : const Text('Save',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15)),
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

  Widget _buildImagePicker() {
    final hasImage = _pickedImage != null || _existingImageUrl != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Project Image'),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: hasImage ? null : _pickImage,
          child: Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[50],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_pickedImage != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Image.file(_pickedImage!, fit: BoxFit.cover),
                  )
                else if (_existingImageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Image.network(_existingImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const _NoImagePlaceholder()),
                  )
                else
                  const _NoImagePlaceholder(),
                if (hasImage)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: _removeImage,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4)),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 12),
                      ),
                    ),
                  )
                else
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: _green.withValues(alpha: 0.85),
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(7)),
                      ),
                      child: const Text('Add Image',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (hasImage) ...[
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _pickImage,
            child: const Text('Change image',
                style: TextStyle(
                    color: _green,
                    fontSize: 12,
                    decoration: TextDecoration.underline)),
          ),
        ],
        const SizedBox(height: 4),
        Text('300 × 300 px recommended',
            style: TextStyle(color: Colors.grey[400], fontSize: 11)),
      ],
    );
  }

  Widget _buildLocationRow() {
    return Column(
      children: [
        _buildDropdown<int>(
          value: _selectedProvinceId,
          hint: 'Province',
          items: _provinces
              .map((p) => DropdownMenuItem<int>(
                  value: p['id'] as int,
                  child: Text(p['name']?.toString() ?? '',
                      style: _dropdownTextStyle)))
              .toList(),
          onChanged: (v) {
            setState(() {
              _selectedProvinceId = v;
              _selectedCityId = null;
              _selectedAreaId = null;
              _cities = [];
              _areas = [];
            });
            if (v != null) _loadCities(v);
          },
        ),
        if (_selectedProvinceId != null) ...[
          const SizedBox(height: 8),
          _buildDropdown<int>(
            value: _selectedCityId,
            hint: 'City',
            items: _cities
                .map((c) => DropdownMenuItem<int>(
                    value: c['id'] as int,
                    child: Text(c['name']?.toString() ?? '',
                        style: _dropdownTextStyle)))
                .toList(),
            onChanged: (v) {
              setState(() {
                _selectedCityId = v;
                _selectedAreaId = null;
                _areas = [];
              });
              if (v != null) _loadAreas(v);
            },
          ),
        ],
        if (_selectedCityId != null) ...[
          const SizedBox(height: 8),
          _buildDropdown<int>(
            value: _selectedAreaId,
            hint: 'Area',
            items: _areas
                .map((a) => DropdownMenuItem<int>(
                    value: a['id'] as int,
                    child: Text(a['name']?.toString() ?? '',
                        style: _dropdownTextStyle)))
                .toList(),
            onChanged: (v) => setState(() => _selectedAreaId = v),
          ),
        ],
      ],
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          hint: Text(hint,
              style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          icon: const Icon(Icons.keyboard_arrow_down, color: _green, size: 20),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  static const _dropdownTextStyle =
      TextStyle(fontSize: 13, color: Colors.black87);

  Widget _label(String text, {bool required = false}) => RichText(
        text: TextSpan(
          style: const TextStyle(
              color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 13),
          children: [
            TextSpan(text: text),
            if (required)
              const TextSpan(text: ' *', style: TextStyle(color: _red)),
          ],
        ),
      );

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

class _NoImagePlaceholder extends StatelessWidget {
  const _NoImagePlaceholder();
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.image_outlined, color: Colors.grey[400], size: 32),
        const SizedBox(height: 4),
        Text('No image',
            style: TextStyle(color: Colors.grey[400], fontSize: 11)),
      ],
    );
  }
}
