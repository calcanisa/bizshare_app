import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';

class AddLeadModal extends StatefulWidget {
  final String action; // 'add' or 'edit'
  final Map<String, dynamic>? request;
  final void Function(Map<String, dynamic> data) onSave;
  final VoidCallback onCancel;

  const AddLeadModal({
    super.key,
    required this.action,
    this.request,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<AddLeadModal> createState() => _AddLeadModalState();
}

class _AddLeadModalState extends State<AddLeadModal> {
  bool _saving = false;
  bool _accepted = false;

  String _type = 'services'; // 'services' or 'products'

  final _titleController = TextEditingController();
  final _productNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();

  List<dynamic> _services = [];
  List<dynamic> _categories = [];
  List<dynamic> _provinces = [];
  List<dynamic> _cities = [];
  List<dynamic> _areas = [];

  int? _selectedService;
  int? _selectedCategory;
  int? _selectedProvince;
  int? _selectedCity;
  int? _selectedArea;

  bool _hasProfileLocation = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    if (widget.action == 'edit' && widget.request != null) {
      _populateForm(widget.request!);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _productNameController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final api = context.read<ApiService>();
      final results = await Future.wait([
        api.dio.get('/api/v1/directory/services/'),
        api.dio.get('/api/v1/directory/categories/'),
        api.dio.get('/api/v1/locations/provinces/'),
        api.dio.get('/api/v1/users/current/'),
      ]);

      final servicesData = results[0].data;
      final categoriesData = results[1].data;
      final provincesData = results[2].data;
      final userData = results[3].data;

      final locations = userData['profile']?['locations'] as List? ?? [];

      setState(() {
        _services = servicesData is List
            ? servicesData
            : (servicesData['results'] ?? []);
        _categories = categoriesData is List
            ? categoriesData
            : (categoriesData['results'] ?? []);
        _provinces = provincesData is List
            ? provincesData
            : (provincesData['results'] ?? []);
        _hasProfileLocation = locations.isNotEmpty;
      });
    } catch (_) {}
  }

  Future<void> _loadCities(int provinceId) async {
    try {
      final api = context.read<ApiService>();
      final res = await api.dio.get('/api/v1/locations/cities/$provinceId/');
      setState(() {
        _cities = res.data is List ? res.data : (res.data['results'] ?? []);
        _selectedCity = null;
        _areas = [];
        _selectedArea = null;
      });
    } catch (_) {}
  }

  Future<void> _loadAreas(int cityId) async {
    try {
      final api = context.read<ApiService>();
      final res = await api.dio.get('/api/v1/locations/areas/$cityId/');
      setState(() {
        _areas = res.data is List ? res.data : (res.data['results'] ?? []);
        _selectedArea = null;
      });
    } catch (_) {}
  }

  void _populateForm(Map<String, dynamic> r) {
    _titleController.text = r['title'] ?? '';
    _productNameController.text = r['product_name'] ?? '';
    _descriptionController.text = r['description'] ?? '';
    _amountController.text = r['amount']?.toString() ?? '';
    _selectedService = (r['service'] as Map?)?['id'];
    _selectedCategory = (r['category'] as Map?)?['id'];
    _type = r['product_name'] != null && r['product_name'].toString().isNotEmpty
        ? 'products'
        : 'services';
  }

  bool get _canSave {
    if (widget.action == 'add' && !_accepted) return false;
    if (_descriptionController.text.trim().isEmpty) return false;
    if (_type == 'services' &&
        (_selectedService == null || _selectedService == 0)) {
      return false;
    }
    if (_type == 'products' && _productNameController.text.trim().isEmpty) {
      return false;
    }
    return true;
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    try {
      final api = context.read<ApiService>();
      final data = {
        'title': _titleController.text.trim(),
        'service_id': _type == 'services' ? _selectedService : null,
        'description': _descriptionController.text.trim(),
        'product_name':
            _type == 'products' ? _productNameController.text.trim() : null,
        'category_id': _selectedCategory,
        'amount': _amountController.text.trim().isNotEmpty
            ? int.tryParse(_amountController.text.trim())
            : null,
        'area_id': _selectedArea,
        'city_id': _selectedCity,
      };

      late Map<String, dynamic> result;
      if (widget.action == 'add') {
        final res = await api.dio
            .post('/api/v1/directory/business/lead/c/', data: data);
        result = res.data;
      } else {
        final id = widget.request!['id'];
        final res = await api.dio
            .put('/api/v1/directory/business/lead/$id/u/', data: data);
        result = res.data;
      }
      widget.onSave(result);
    } catch (e) {
      _showSnack('Something went wrong. Please try again.');
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
          widget.action == 'edit'
              ? 'Edit Request'
              : 'What Are You Looking For?',
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
          const Text(
            'This request is associated with your profile location. If you have no location set, please add one below.',
            style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Type selector — only for add
          if (widget.action == 'add') ...[
            _fieldLabel('Looking for products or services?'),
            const SizedBox(height: 8),
            Row(
              children: [
                _radio('Services', 'services', _type,
                    (v) => setState(() => _type = v!)),
                const SizedBox(width: 24),
                _radio('Products', 'products', _type,
                    (v) => setState(() => _type = v!)),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Title
          _fieldLabel('Request Title *'),
          const SizedBox(height: 6),
          _textField(_titleController,
              hint: 'Give this request a title', maxLength: 50),
          const SizedBox(height: 16),

          // Services
          if (_type == 'services') ...[
            _fieldLabel('Choose a Service *'),
            const SizedBox(height: 6),
            _dropdownField<int>(
              value: _selectedService,
              hint: _services.isEmpty ? 'Loading...' : 'Select',
              items: _services
                  .map((s) => DropdownMenuItem<int>(
                        value: s['id'],
                        child: Text(s['name'] ?? '',
                            style: const TextStyle(fontSize: 13)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedService = v),
            ),
            const SizedBox(height: 16),
          ],

          // Products
          if (_type == 'products') ...[
            _fieldLabel('Product Name *'),
            const SizedBox(height: 6),
            _textField(_productNameController,
                hint: 'What product are you looking for?', maxLength: 50),
            const SizedBox(height: 16),
            _fieldLabel('Category'),
            const SizedBox(height: 6),
            _dropdownField<int>(
              value: _selectedCategory,
              hint: _categories.isEmpty ? 'Loading...' : 'Select',
              items: _categories
                  .map((c) => DropdownMenuItem<int>(
                        value: c['id'],
                        child: Text(c['name'] ?? '',
                            style: const TextStyle(fontSize: 13)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedCategory = v),
            ),
            const SizedBox(height: 16),
            _fieldLabel('Amount'),
            const SizedBox(height: 6),
            _textField(_amountController,
                hint: 'How many products are you looking for?',
                keyboardType: TextInputType.number),
            const SizedBox(height: 16),
          ],

          // Location — only if no profile location
          if (!_hasProfileLocation) ...[
            _fieldLabel('Location'),
            const SizedBox(height: 6),
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
                  _fieldLabel('Province'),
                  const SizedBox(height: 4),
                  _dropdownField<int>(
                    value: _selectedProvince,
                    hint: 'Select',
                    items: _provinces
                        .map((p) => DropdownMenuItem<int>(
                              value: p['id'],
                              child: Text(p['name'] ?? '',
                                  style: const TextStyle(fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (v) {
                      setState(() => _selectedProvince = v);
                      if (v != null) _loadCities(v);
                    },
                  ),
                  const SizedBox(height: 10),
                  _fieldLabel('City'),
                  const SizedBox(height: 4),
                  _dropdownField<int>(
                    value: _selectedCity,
                    hint: 'Select',
                    items: _cities
                        .map((c) => DropdownMenuItem<int>(
                              value: c['id'],
                              child: Text(c['name'] ?? '',
                                  style: const TextStyle(fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (v) {
                      setState(() => _selectedCity = v);
                      if (v != null) _loadAreas(v);
                    },
                  ),
                  const SizedBox(height: 10),
                  _fieldLabel('Area'),
                  const SizedBox(height: 4),
                  _dropdownField<int>(
                    value: _selectedArea,
                    hint: 'Select',
                    items: _areas
                        .map((a) => DropdownMenuItem<int>(
                              value: a['id'],
                              child: Text(a['name'] ?? '',
                                  style: const TextStyle(fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedArea = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Description
          _fieldLabel('Description *'),
          const SizedBox(height: 6),
          TextField(
            controller: _descriptionController,
            maxLines: 5,
            maxLength: 1000,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'In 1000 characters or less, describe what you need.',
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

          // Terms — only for add
          if (widget.action == 'add') ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
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
                  onPressed: _canSave && !_saving ? _save : null,
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
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Widget _fieldLabel(String label) => Text(label,
      style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1B4748)));

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

  Widget _dropdownField<T>({
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
                style: const TextStyle(color: Colors.black45, fontSize: 13)),
            isExpanded: true,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
            items: [
              DropdownMenuItem<T>(
                  value: null,
                  child: Text(hint,
                      style: const TextStyle(
                          color: Colors.black45, fontSize: 13))),
              ...items,
            ],
            onChanged: onChanged,
          ),
        ),
      );

  Widget _radio(
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
}
