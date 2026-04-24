import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class AddWebsiteScreen extends StatefulWidget {
  final String action; // 'add' | 'edit'
  final Map<String, dynamic>? listing;
  final int count;
  final int limit;

  const AddWebsiteScreen({
    super.key,
    required this.action,
    this.listing,
    this.count = 0,
    this.limit = 5,
  });

  @override
  State<AddWebsiteScreen> createState() => _AddWebsiteScreenState();
}

class _AddWebsiteScreenState extends State<AddWebsiteScreen> {
  static const _green = Color(0xFF094a25);
  static const _red = Color(0xFFbc2023);

  final _nameCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  int? _selectedTypeId;
  int? _selectedCategoryId;
  bool _accepted = false;
  bool _saving = false;
  bool _loadingData = true;
  bool _showInfo = false;

  File? _pickedImage;
  String? _existingImageUrl;

  List<Map<String, dynamic>> _types = [];
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loadingData = true);
    final api = context.read<ApiService>();
    try {
      final results = await Future.wait([
        api.dio.get('/api/v1/websites/types/'),
        api.dio.get('/api/v1/websites/categories/'),
      ]);
      final t = results[0].data;
      final c = results[1].data;
      setState(() {
        _types = List<Map<String, dynamic>>.from(
            t is List ? t : (t['results'] ?? []));
        _categories = List<Map<String, dynamic>>.from(
            c is List ? c : (c['results'] ?? []));
      });
    } catch (_) {
      _showError('Could not load form data. Try again.');
    }

    if (widget.action == 'edit' && widget.listing != null) {
      _prefill(widget.listing!);
    }

    setState(() => _loadingData = false);
  }

  void _prefill(Map<String, dynamic> l) {
    _nameCtrl.text = l['name'] ?? '';
    _urlCtrl.text = l['url'] ?? '';
    _descCtrl.text = l['description'] ?? '';
    _accepted = true;
    _existingImageUrl = l['image'] as String?;

    final type = l['type'];
    _selectedTypeId = type is Map ? type['id'] as int? : type as int?;

    final cat = l['category'];
    _selectedCategoryId = cat is Map ? cat['id'] as int? : cat as int?;
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

  String _normalizeUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;
    if (!trimmed.toLowerCase().startsWith('http://') &&
        !trimmed.toLowerCase().startsWith('https://')) {
      return 'https://$trimmed';
    }
    return trimmed;
  }

  bool _validate() {
    if (widget.action == 'add' && widget.count >= widget.limit) {
      _showError('You have reached your limit for website listings.');
      return false;
    }
    if (_nameCtrl.text.trim().isEmpty) {
      _showError('Title is required.');
      return false;
    }
    if (_urlCtrl.text.trim().isEmpty) {
      _showError('URL is required.');
      return false;
    }
    if (_selectedTypeId == null) {
      _showError('Please select a website type.');
      return false;
    }
    if (_selectedCategoryId == null) {
      _showError('Please select a website category.');
      return false;
    }
    if (widget.action == 'add' && !_accepted) {
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
      'name': _nameCtrl.text.trim(),
      'url': _normalizeUrl(_urlCtrl.text),
      'description': _descCtrl.text.trim(),
      'type': _selectedTypeId.toString(),
      'category': _selectedCategoryId.toString(),
    };
    final files = <String, File>{};
    if (_pickedImage != null) files['image'] = _pickedImage!;

    try {
      if (widget.action == 'add') {
        final result = await auth.apiService.postMultipart(
          '/api/v1/websites/listing/c/',
          fields: fields,
          files: files,
        );
        if (!mounted) return;
        _showSuccess('Website listing created successfully.');
        Navigator.pop(context, result);
      } else {
        final result = await auth.apiService.patchMultipart(
          '/api/v1/websites/listing/${widget.listing!['id']}/u/',
          fields: fields,
          files: files,
        );
        if (!mounted) return;
        _showSuccess('Website listing updated successfully.');
        Navigator.pop(context, result);
      }
    } on DioException catch (e) {
      _showError(
          e.response?.data?['error'] ?? 'Could not save listing. Try again.');
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
        title: Text(isEdit ? 'Edit Website' : 'Add Website'),
        elevation: 0,
      ),
      body: _loadingData
          ? const Center(child: CircularProgressIndicator(color: _green))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image picker
                    _buildImagePicker(),
                    const SizedBox(height: 20),

                    // Title
                    _label('Title', required: true),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameCtrl,
                      decoration: _inputDeco(
                          'Give this listing a name (e.g. business name)'),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),

                    // Website Type
                    _label('Website Type', required: true),
                    const SizedBox(height: 6),
                    _buildDropdown<int>(
                      value: _selectedTypeId,
                      hint: 'Select type',
                      items: _types
                          .map((t) => DropdownMenuItem<int>(
                              value: t['id'] as int,
                              child: Text(t['name']?.toString() ?? '',
                                  style: _dropStyle)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedTypeId = v),
                    ),
                    const SizedBox(height: 16),

                    // Website Category
                    _label('Website Category', required: true),
                    const SizedBox(height: 6),
                    _buildDropdown<int>(
                      value: _selectedCategoryId,
                      hint: 'Select category',
                      items: _categories
                          .map((c) => DropdownMenuItem<int>(
                              value: c['id'] as int,
                              child: Text(c['name']?.toString() ?? '',
                                  style: _dropStyle)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedCategoryId = v),
                    ),
                    const SizedBox(height: 16),

                    // URL
                    Row(
                      children: [
                        _label('Website URL', required: true),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setState(() => _showInfo = !_showInfo),
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: _green,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Text('?',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_showInfo) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: const Text(
                          'Only single domain websites are allowed. No subdomains or specific pages. '
                          'For example, website.somenetwork.com or network.com/website are not allowed. '
                          'Single domains like mywebsite.co.za or mywebsite.com are allowed.',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    TextField(
                      controller: _urlCtrl,
                      maxLength: 255,
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
                      decoration: _inputDeco('Only single domain entries'),
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                    ),
                    const SizedBox(height: 16),

                    // Description
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _label('Description'),
                        Text('${_descCtrl.text.length} / 500',
                            style: TextStyle(
                                fontSize: 11,
                                color: _descCtrl.text.length >= 500
                                    ? _red
                                    : Colors.grey[400])),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _descCtrl,
                      maxLines: 4,
                      maxLength: 500,
                      buildCounter: (_,
                              {required currentLength,
                              required isFocused,
                              maxLength}) =>
                          const SizedBox.shrink(),
                      onChanged: (_) => setState(() {}),
                      decoration: _inputDeco(
                          'Short description of what your website is about'),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 16),

                    // Terms
                    if (!isEdit) ...[
                      Row(
                        children: [
                          Checkbox(
                            value: _accepted,
                            activeColor: _green,
                            onChanged: (v) =>
                                setState(() => _accepted = v ?? false),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _accepted = !_accepted),
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
                      const SizedBox(height: 20),
                    ],

                    // Buttons
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
        _label('Image (Optional)'),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: hasImage ? null : _pickImage,
          child: Container(
            width: 120,
            height: 120,
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
                    child: Image.file(_pickedImage!, fit: BoxFit.contain),
                  )
                else if (_existingImageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Image.network(_existingImageUrl!,
                        fit: BoxFit.contain,
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
                      child: const Text('Upload',
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

  static const _dropStyle = TextStyle(fontSize: 13, color: Colors.black87);

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
