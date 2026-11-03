import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class SeshaPassiveScreen extends StatefulWidget {
  final Map<String, dynamic>? profile;

  const SeshaPassiveScreen({super.key, this.profile});

  @override
  State<SeshaPassiveScreen> createState() => _SeshaPassiveScreenState();
}

class _SeshaPassiveScreenState extends State<SeshaPassiveScreen> {
  static const _green = Color(0xFF1B4748);
  static const _red = Color(0xFFF48900);

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _additionalCtrl = TextEditingController();

  File? _photo;
  bool _accepted = false;
  bool _saving = false;
  bool _loadingData = true;

  List<Map<String, dynamic>> _provinces = [];
  List<Map<String, dynamic>> _cities = [];
  int? _selectedProvinceId;
  int? _selectedCityId;

  @override
  void initState() {
    super.initState();
    if (widget.profile != null) {
      _firstNameCtrl.text = widget.profile!['first_name'] ?? '';
      _lastNameCtrl.text = widget.profile!['last_name'] ?? '';
    }
    _loadProvinces();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _idCtrl.dispose();
    _streetCtrl.dispose();
    _additionalCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProvinces() async {
    setState(() => _loadingData = true);
    try {
      final api = context.read<ApiService>();
      final res = await api.dio.get('/api/v1/locations/provinces/');
      final data = res.data;
      setState(() {
        _provinces = List<Map<String, dynamic>>.from(
            data is List ? data : (data['results'] ?? []));
      });
    } catch (_) {
      _showError('Could not load provinces. Try again.');
    }
    setState(() => _loadingData = false);
  }

  Future<void> _loadCities(int provinceId) async {
    setState(() {
      _cities = [];
      _selectedCityId = null;
    });
    try {
      final api = context.read<ApiService>();
      final res = await api.dio.get('/api/v1/locations/cities/$provinceId/');
      final data = res.data;
      setState(() {
        _cities = List<Map<String, dynamic>>.from(
            data is List ? data : (data['results'] ?? []));
      });
    } catch (_) {
      _showError('Could not load cities. Try again.');
    }
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked != null) setState(() => _photo = File(picked.path));
  }

  bool _validate() {
    if (_photo == null) {
      _showError('A photo is required.');
      return false;
    }
    if (_firstNameCtrl.text.trim().isEmpty) {
      _showError('First name is required.');
      return false;
    }
    if (_lastNameCtrl.text.trim().isEmpty) {
      _showError('Last name is required.');
      return false;
    }
    if (_idCtrl.text.trim().length != 13) {
      _showError('SA ID number must be 13 digits.');
      return false;
    }
    if (_streetCtrl.text.trim().isEmpty) {
      _showError('Street address is required.');
      return false;
    }
    if (_selectedProvinceId == null) {
      _showError('Please select a province.');
      return false;
    }
    if (_selectedCityId == null) {
      _showError('Please select a city.');
      return false;
    }
    if (!_accepted) {
      _showError('You must accept the terms to continue.');
      return false;
    }
    return true;
  }

  Future<void> _apply() async {
    if (!_validate()) return;
    setState(() => _saving = true);
    final auth = context.read<AuthProvider>();
    try {
      final fields = <String, String>{
        'first_name': _firstNameCtrl.text.trim(),
        'last_name': _lastNameCtrl.text.trim(),
        'sa_id': _idCtrl.text.trim(),
        'street': _streetCtrl.text.trim(),
        'additional': _additionalCtrl.text.trim(),
        'province': _selectedProvinceId.toString(),
        'location': _selectedCityId.toString(),
      };
      final files = <String, File>{'photo': _photo!};

      await auth.apiService.postMultipart(
        '/api/v1/users/sesha/',
        fields: fields,
        files: files,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Application submitted. We will respond within 30 days.'),
        backgroundColor: _green,
      ));
      Navigator.pop(context, true);
    } on DioException catch (e) {
      _showError(e.response?.data?['error'] ??
          'Could not submit application. Try again.');
    } catch (_) {
      _showError('Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: _red));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        title: const Text('BizShare Passive Application'),
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
                    // Terms notice
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _green.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: _green.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: const TextSpan(
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black87,
                                  height: 1.6),
                              children: [
                                TextSpan(text: 'Please read our '),
                                TextSpan(
                                  text: 'terms',
                                  style: TextStyle(
                                    color: _green,
                                    decoration: TextDecoration.underline,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                TextSpan(
                                    text:
                                        ' before applying. Supplying false information or impersonating another person will result in the immediate denial and deletion of the application. '
                                        'No further applications for the same person will be allowed. '
                                        'We verify every ID number to ensure it is legitimate. '
                                        'Once completed, it can take up to 30 days for us to respond. '
                                        'If we do not respond within 30 days, the application was unsuccessful.'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Photo
                    _label('Photo', required: true),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _pickPhoto,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: _photo != null
                                      ? _green
                                      : Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey[50],
                            ),
                            child: _photo != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(7),
                                    child:
                                        Image.file(_photo!, fit: BoxFit.cover),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_a_photo_outlined,
                                          color: Colors.grey[400], size: 28),
                                      const SizedBox(height: 4),
                                      Text('Browse',
                                          style: TextStyle(
                                              color: Colors.grey[400],
                                              fontSize: 11)),
                                    ],
                                  ),
                          ),
                        ),
                        if (_photo != null) ...[
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: _pickPhoto,
                                child: const Text('Change photo',
                                    style: TextStyle(
                                        color: _green,
                                        fontSize: 12,
                                        decoration: TextDecoration.underline)),
                              ),
                              const SizedBox(height: 6),
                              GestureDetector(
                                onTap: () => setState(() => _photo = null),
                                child: const Text('Remove',
                                    style: TextStyle(
                                        color: _red,
                                        fontSize: 12,
                                        decoration: TextDecoration.underline)),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),

                    // First name
                    _label('First Name', required: true),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _firstNameCtrl,
                      maxLength: 50,
                      buildCounter: _noCounter,
                      decoration: _inputDeco('First name'),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),

                    // Last name
                    _label('Last Name', required: true),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _lastNameCtrl,
                      maxLength: 50,
                      buildCounter: _noCounter,
                      decoration: _inputDeco('Last name'),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),

                    // SA ID
                    _label('SA ID Number', required: true),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _idCtrl,
                      maxLength: 13,
                      buildCounter: (_,
                              {required currentLength,
                              required isFocused,
                              maxLength}) =>
                          Text('$currentLength / 13',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: currentLength == 13
                                      ? _green
                                      : Colors.grey[400])),
                      keyboardType: TextInputType.number,
                      decoration: _inputDeco('13-digit SA ID number'),
                    ),
                    const SizedBox(height: 16),

                    // Street
                    _label('Street', required: true),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _streetCtrl,
                      maxLength: 100,
                      buildCounter: _noCounter,
                      decoration: _inputDeco(
                          'Name and number of street, flat, complex'),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),

                    // Additional
                    _label('Additional'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _additionalCtrl,
                      maxLength: 100,
                      buildCounter: _noCounter,
                      decoration: _inputDeco('Suburb, area or zone'),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),

                    // Province
                    _label('Province', required: true),
                    const SizedBox(height: 6),
                    _buildDropdown<int>(
                      value: _selectedProvinceId,
                      hint: 'Select province',
                      items: _provinces
                          .map((p) => DropdownMenuItem<int>(
                              value: p['id'] as int,
                              child: Text(p['name']?.toString() ?? '',
                                  style: const TextStyle(
                                      fontSize: 13, color: Colors.black87))))
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          _selectedProvinceId = v;
                          _selectedCityId = null;
                          _cities = [];
                        });
                        if (v != null) _loadCities(v);
                      },
                    ),
                    const SizedBox(height: 16),

                    // City
                    _label('City', required: true),
                    const SizedBox(height: 6),
                    _buildDropdown<int>(
                      value: _selectedCityId,
                      hint: _selectedProvinceId == null
                          ? 'Select a province first'
                          : 'Select city',
                      items: _cities
                          .map((c) => DropdownMenuItem<int>(
                              value: c['id'] as int,
                              child: Text(c['name']?.toString() ?? '',
                                  style: const TextStyle(
                                      fontSize: 13, color: Colors.black87))))
                          .toList(),
                      onChanged: _selectedProvinceId == null
                          ? null
                          : (v) => setState(() => _selectedCityId = v),
                    ),
                    const SizedBox(height: 20),

                    // Terms
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
                    const SizedBox(height: 24),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _saving ? null : _apply,
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
                                        strokeWidth: 2, color: Colors.white))
                                : const Text('Apply',
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

  Widget _buildDropdown<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
  }) =>
      Container(
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
            icon:
                const Icon(Icons.keyboard_arrow_down, color: _green, size: 20),
            items: items,
            onChanged: onChanged,
          ),
        ),
      );

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

  Widget? Function(BuildContext,
      {required int currentLength,
      required bool isFocused,
      required int? maxLength}) get _noCounter => (_,
          {required currentLength, required isFocused, maxLength}) =>
      const SizedBox.shrink();
}
