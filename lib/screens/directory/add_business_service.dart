import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class AddServiceScreen extends StatefulWidget {
  final String action; // 'add' | 'edit'
  final int businessId;
  final Map<String, dynamic>? service; // required for edit

  const AddServiceScreen({
    super.key,
    required this.action,
    required this.businessId,
    this.service,
  });

  @override
  State<AddServiceScreen> createState() => _AddServiceScreenState();
}

class _AddServiceScreenState extends State<AddServiceScreen> {
  static const _green = Color(0xFF1B4748);
  static const _red = Color(0xFFF48900);

  static const _intervalOptions = [
    ('hour', 'Per Hour'),
    ('day', 'Per Day'),
    ('week', 'Per Week'),
    ('month', 'Per Month'),
    ('year', 'Per Year'),
    ('job', 'Per Project'),
  ];

  final _pitchCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();

  int? _selectedCategoryId;
  int? _selectedServiceId;
  String? _selectedInterval;
  bool _accepted = false;
  bool _saving = false;
  bool _loadingData = true;
  bool _loadingServices = false;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _services = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _pitchCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _loadingData = true);
    try {
      final api = context.read<ApiService>();
      final res = await api.dio.get('/api/v1/directory/categories/');
      final data = res.data;
      setState(() {
        _categories = List<Map<String, dynamic>>.from(
            data is List ? data : (data['results'] ?? []));
      });
    } catch (_) {
      _showError('Could not load categories. Try again.');
    }

    if (widget.action == 'edit' && widget.service != null) {
      await _prefill();
    }

    setState(() => _loadingData = false);
  }

  Future<void> _loadServices(int categoryId) async {
    setState(() {
      _loadingServices = true;
      _services = [];
      _selectedServiceId = null;
    });
    try {
      final api = context.read<ApiService>();
      final res =
          await api.dio.get('/api/v1/directory/business/services/$categoryId/');
      setState(() {
        _services = List<Map<String, dynamic>>.from(
            res.data is List ? res.data : (res.data['results'] ?? []));
      });
    } catch (_) {
      _showError('Could not load services. Try again.');
    } finally {
      if (mounted) setState(() => _loadingServices = false);
    }
  }

  Future<void> _prefill() async {
    final s = widget.service!;
    _pitchCtrl.text = s['pitch'] ?? '';
    _rateCtrl.text = (s['rate'] ?? '').toString();
    _selectedInterval = s['interval'];
    _accepted = true;

    final svc = s['service'] as Map?;
    if (svc != null) {
      _selectedServiceId = svc['id'] as int?;
      // Load the category from the service's categories list
      final cats = svc['categories'] as List?;
      final catId = cats != null && cats.isNotEmpty ? cats[0] as int? : null;
      if (catId != null) {
        _selectedCategoryId = catId;
        await _loadServices(catId);
        // Re-set after services load so the dropdown value is valid
        setState(() => _selectedServiceId = svc['id'] as int?);
      }
    }
  }

  Future<void> _save() async {
    if (_selectedServiceId == null) {
      _showError('Please select a service.');
      return;
    }
    if (_pitchCtrl.text.trim().isEmpty) {
      _showError('Please describe what makes you better.');
      return;
    }
    if (widget.action == 'add' && !_accepted) {
      _showError('You must accept the terms to continue.');
      return;
    }

    setState(() => _saving = true);
    final auth = context.read<AuthProvider>();

    try {
      if (widget.action == 'add') {
        final res = await auth.apiService.dio.post(
          '/api/v1/directory/business/${widget.businessId}/service/c/',
          data: {
            'service': _selectedServiceId,
            'pitch': _pitchCtrl.text.trim(),
            'rate': _rateCtrl.text.trim(),
            'interval': _selectedInterval ?? '',
            'business': widget.businessId,
          },
        );
        if (!mounted) return;
        if (res.statusCode == 201) {
          _showSuccess('Service added successfully.');
          Navigator.pop(context, res.data);
        }
      } else {
        final serviceId = widget.service!['id'];
        final res = await auth.apiService.dio.put(
          '/api/v1/directory/business/service/$serviceId/u/',
          data: {
            'service_id': _selectedServiceId,
            'pitch': _pitchCtrl.text.trim(),
            'rate': _rateCtrl.text.trim(),
            'interval': _selectedInterval ?? '',
          },
        );
        if (!mounted) return;
        if (res.statusCode == 200) {
          _showSuccess('Service updated successfully.');
          Navigator.pop(context, res.data);
        }
      }
    } on DioException catch (e) {
      _showError(
          e.response?.data?['error'] ?? 'Could not save service. Try again.');
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
        title: Text(isEdit ? 'Edit Service' : 'Add Service'),
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
                    if (!isEdit) ...[
                      Text(
                        'Use the form below to add a service to your business.',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Category
                    _label('Category', required: true),
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
                      onChanged: (v) {
                        setState(() {
                          _selectedCategoryId = v;
                          _selectedServiceId = null;
                          _services = [];
                        });
                        if (v != null) _loadServices(v);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Service
                    _label('Service', required: true),
                    const SizedBox(height: 6),
                    _loadingServices
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                                child: CircularProgressIndicator(
                                    color: _green, strokeWidth: 2)),
                          )
                        : _buildDropdown<int>(
                            value: _selectedServiceId,
                            hint: _selectedCategoryId == null
                                ? 'Select a category first'
                                : 'Select service',
                            items: _services
                                .map((s) => DropdownMenuItem<int>(
                                    value: s['id'] as int,
                                    child: Text(s['name']?.toString() ?? '',
                                        style: _dropStyle)))
                                .toList(),
                            onChanged: _selectedCategoryId == null
                                ? null
                                : (v) => setState(() => _selectedServiceId = v),
                          ),
                    const SizedBox(height: 16),

                    // Pitch
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _label('What makes you better?', required: true),
                        Text(
                          '${_pitchCtrl.text.length} / 250',
                          style: TextStyle(
                              fontSize: 11,
                              color: _pitchCtrl.text.length >= 250
                                  ? _red
                                  : Colors.grey[400]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _pitchCtrl,
                      maxLines: 4,
                      maxLength: 250,
                      buildCounter: (_,
                              {required currentLength,
                              required isFocused,
                              maxLength}) =>
                          const SizedBox.shrink(),
                      onChanged: (_) => setState(() {}),
                      decoration: _inputDeco(
                          'Describe what makes you better than the competition'),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 16),

                    // Rate + interval
                    _label('Rate (optional)'),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // R prefix + number
                        SizedBox(
                          width: 120,
                          child: TextField(
                            controller: _rateCtrl,
                            decoration:
                                _inputDeco('0').copyWith(prefixText: 'R '),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Interval
                        Expanded(
                          child: _buildDropdown<String>(
                            value: _selectedInterval,
                            hint: 'Interval',
                            items: _intervalOptions
                                .map((o) => DropdownMenuItem(
                                    value: o.$1,
                                    child: Text(o.$2, style: _dropStyle)))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedInterval = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Terms (add mode only)
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

  Widget _buildDropdown<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
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
