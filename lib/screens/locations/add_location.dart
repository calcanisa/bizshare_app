import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';

class AddLocationModal extends StatefulWidget {
  final String action; // 'add', 'edit', 'nosave', 'editno'
  final String type; // 'business', 'event', 'profile', 'opportunity'
  final String labelName; // 'branch', 'venue', etc.
  final String title;
  final Map<String, dynamic>? location;
  final int? profileId;
  final int? eventId;
  final void Function(Map<String, dynamic> data) onSave;
  final VoidCallback onCancel;

  const AddLocationModal({
    super.key,
    required this.action,
    required this.type,
    this.labelName = 'Location',
    this.title = 'Add Location',
    this.location,
    this.profileId,
    this.eventId,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<AddLocationModal> createState() => _AddLocationModalState();
}

class _AddLocationModalState extends State<AddLocationModal> {
  bool _saving = false;
  bool _accepted = false;
  String _sameWhatsapp = '';

  final _nameController = TextEditingController();
  final _complexController = TextEditingController();
  final _streetController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _faxController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();

  bool _isVenue = false;
  int? _businessId;

  List<dynamic> _provinces = [];
  List<dynamic> _cities = [];
  List<dynamic> _areas = [];
  List<dynamic> _businesses = [];

  int? _selectedProvince;
  int? _selectedCity;
  int? _selectedArea;
  String _cityName = '';
  String _areaName = '';

  // Venue search
  List<dynamic> _venues = [];
  List<dynamic> _filteredVenues = [];
  bool _showSuggestions = false;

  String _error = '';
  int? _locationId;

  @override
  void initState() {
    super.initState();
    _loadProvinces();
    if (widget.type == 'business') _loadBusinesses();
    if (widget.type == 'event' || widget.type == 'business') _loadVenues();
    if (widget.action == 'edit' || widget.action == 'editno') {
      _populateForm(widget.location!);
    }
    if (widget.action == 'add') {
      _isVenue = widget.type == 'event';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _complexController.dispose();
    _streetController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _faxController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    super.dispose();
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

  Future<void> _loadCities(int provinceId, {bool reset = true}) async {
    try {
      final api = context.read<ApiService>();
      final res =
          await api.dio.get('/api/v1/locations/cities/$provinceId/');
      final data = res.data;
      setState(() {
        _cities = data is List ? data : (data['results'] ?? []);
        if (reset) {
          _selectedCity = null;
          _areas = [];
          _selectedArea = null;
        }
      });
    } catch (_) {}
  }

  Future<void> _loadAreas(int cityId) async {
    try {
      final api = context.read<ApiService>();
      final res = await api.dio.get('/api/v1/locations/areas/$cityId/');
      final data = res.data;
      setState(() {
        _areas = data is List ? data : (data['results'] ?? []);
      });
      final city = _cities.firstWhere((c) => c['id'] == cityId,
          orElse: () => null);
      _cityName = city?['name'] ?? '';
    } catch (_) {}
  }

  Future<void> _loadBusinesses() async {
    try {
      final api = context.read<ApiService>();
      final res =
          await api.dio.get('/api/v1/directory/businesses/current/');
      setState(() => _businesses = res.data ?? []);
    } catch (_) {}
  }

  Future<void> _loadVenues() async {
    try {
      final api = context.read<ApiService>();
      final res = await api.dio
          .get('/api/v1/locations/venues/', queryParameters: {'page_size': 100});
      final data = res.data;
      setState(() =>
          _venues = data is List ? data : (data['results'] ?? []));
    } catch (_) {}
  }

  void _onNameChanged(String val) {
    if (val.length < 2) {
      setState(() {
        _filteredVenues = [];
        _showSuggestions = false;
      });
      return;
    }
    final keyword = val.toLowerCase();
    setState(() {
      _filteredVenues = _venues
          .where((v) =>
              (v['name']?.toString().toLowerCase() ?? '').startsWith(keyword))
          .toList();
      _showSuggestions = _filteredVenues.isNotEmpty;
    });
  }

  void _selectVenue(Map<String, dynamic> venue) {
    setState(() {
      _nameController.text = venue['name'] ?? '';
      _streetController.text = venue['street'] ?? '';
      _phoneController.text = venue['phone'] ?? '';
      _whatsappController.text = venue['whatsapp'] ?? '';
      _emailController.text = venue['email'] ?? '';
      _faxController.text = venue['fax'] ?? '';
      _showSuggestions = false;
    });
  }

  Future<void> _populateForm(Map<String, dynamic> loc) async {
    _locationId = loc['id'];
    _nameController.text = loc['name'] ?? '';
    _complexController.text = loc['complex'] ?? '';
    _streetController.text = loc['street'] ?? '';
    _phoneController.text = loc['phone'] ?? '';
    _whatsappController.text = loc['whatsapp'] ?? '';
    _faxController.text = loc['fax'] ?? '';
    _emailController.text = loc['email'] ?? '';
    _websiteController.text = loc['website'] ?? '';
    _isVenue = loc['is_venue'] ?? false;
    _businessId = loc['business'] is Map
        ? (loc['business'] as Map)['id']
        : loc['business'];

    if (loc['phone'] == loc['whatsapp']) {
      _sameWhatsapp = 'yes';
    }

    final area = loc['area'] as Map?;
    final city = loc['city'] as Map?;

    if (area != null) {
      final province = area['city']?['province'];
      if (province != null) {
        _selectedProvince = province['id'];
        await _loadCities(province['id'], reset: false);
        _selectedCity = area['city']['id'];
        await _loadAreas(_selectedCity!);
        _selectedArea = area['id'];
        final a =
            _areas.firstWhere((a) => a['id'] == _selectedArea, orElse: () => null);
        _areaName = a?['name'] ?? '';
      }
    } else if (city != null) {
      final province = city['province'];
      if (province != null) {
        _selectedProvince = province['id'];
        await _loadCities(province['id'], reset: false);
        _selectedCity = city['id'];
        await _loadAreas(_selectedCity!);
      }
    }

    setState(() {});
  }

  bool _validate() {
    if ((widget.type == 'event' || widget.type == 'business') &&
        _nameController.text.trim().isEmpty) {
      setState(() =>
          _error = '${widget.labelName} name is required');
      return false;
    }
    if (widget.type != 'opportunity' &&
        _streetController.text.trim().isEmpty) {
      setState(() => _error = 'Street is required');
      return false;
    }
    if (_selectedProvince == null) {
      setState(() => _error = 'Province is required');
      return false;
    }
    if (_selectedCity == null) {
      setState(() => _error = 'City is required');
      return false;
    }
    if (_phoneController.text.trim().length != 10) {
      setState(() => _error = 'Phone number is empty or incorrect');
      return false;
    }
    setState(() => _error = '');
    return true;
  }

  Future<void> _save() async {
    if (!_validate()) return;

    // nosave / editno — return data to parent without API call
    if (widget.action == 'nosave' || widget.action == 'editno') {
      widget.onSave({
        'name': _nameController.text.trim(),
        'complex': _complexController.text.trim(),
        'street': _streetController.text.trim(),
        'province': _selectedProvince,
        'city': {'id': _selectedCity, 'name': _cityName},
        'area': {'id': _selectedArea, 'name': _areaName},
        'phone': _phoneController.text.trim(),
        'whatsapp': _whatsappController.text.trim(),
        'fax': _faxController.text.trim(),
        'email': _emailController.text.trim(),
        'website': _websiteController.text.trim(),
      });
      return;
    }

    if (widget.action == 'add' && !_accepted) {
      setState(() => _error = 'You must accept the terms');
      return;
    }

    setState(() => _saving = true);
    try {
      final api = context.read<ApiService>();

      if (widget.action == 'add') {
        final data = <String, dynamic>{
          'name': _nameController.text.trim(),
          'complex': _complexController.text.trim(),
          'street': _streetController.text.trim(),
          'city_id': _selectedCity,
          'area_id': _selectedArea,
          'phone': _phoneController.text.trim(),
          'whatsapp': _whatsappController.text.trim(),
          'fax': _faxController.text.trim(),
          'email': _emailController.text.trim(),
          'website': _websiteController.text.trim(),
        };
        if (widget.type == 'business') {
          data['business_id'] = _businessId;
          data['is_venue'] = _isVenue;
        } else if (widget.type == 'event') {
          data['event'] = widget.eventId;
          data['is_venue'] = _isVenue;
        } else if (widget.type == 'profile') {
          data['profile'] = widget.profileId;
        }
        final res =
            await api.dio.post('/api/v1/locations/c/', data: data);
        widget.onSave(res.data);
      } else {
        // edit
        final data = <String, dynamic>{
          'name': _nameController.text.trim(),
          'street': _streetController.text.trim(),
          'area_id': _selectedArea,
          'city_id': _selectedCity,
          'phone': _phoneController.text.trim(),
          'whatsapp': _whatsappController.text.trim(),
          'fax': _faxController.text.trim(),
          'email': _emailController.text.trim(),
          'website': _websiteController.text.trim(),
        };
        if (widget.type == 'profile') {
          data['complex'] = _complexController.text.trim();
        }
        final res = await api.dio
            .put('/api/v1/locations/$_locationId/u/', data: data);
        widget.onSave(res.data);
      }
    } catch (_) {
      setState(() => _error = 'Could not save location. Try again.');
    }
    setState(() => _saving = false);
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF094a25),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(widget.title,
            style: const TextStyle(
                color: Colors.white, fontSize: 15)),
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
          const Text(
              'Fields marked with * are required',
              style: TextStyle(
                  fontSize: 12, color: Colors.black45)),
          const SizedBox(height: 16),

          // Name (event / business only)
          if (widget.type == 'event' ||
              widget.type == 'business') ...[
            _fieldLabel(
                '${widget.labelName[0].toUpperCase()}${widget.labelName.substring(1)} Name *'),
            const SizedBox(height: 6),
            Stack(
              children: [
                _textField(_nameController,
                    hint: 'Location, Branch or Venue',
                    onChanged: _onNameChanged),
                if (_showSuggestions)
                  Positioned(
                    top: 44,
                    left: 0,
                    right: 0,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(8),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _filteredVenues.length,
                        itemBuilder: (ctx, i) {
                          final v = _filteredVenues[i]
                              as Map<String, dynamic>;
                          return ListTile(
                            dense: true,
                            title: Text(v['name'] ?? '',
                                style: const TextStyle(
                                    fontSize: 13)),
                            onTap: () => _selectVenue(v),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Complex (profile only)
          if (widget.type == 'profile') ...[
            _field('Complex / Estate', _complexController,
                hint: 'Complex or Estate'),
          ],

          // Street
          if (widget.type != 'opportunity') ...[
            _field('Number and Street *', _streetController,
                hint: 'Number and Street'),
          ],

          // Province
          _fieldLabel('Province *'),
          const SizedBox(height: 6),
          _dropdownWidget<int>(
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
          const SizedBox(height: 16),

          // City
          _fieldLabel('City *'),
          const SizedBox(height: 6),
          _dropdownWidget<int>(
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
          const SizedBox(height: 16),

          // Area
          _fieldLabel('Area / Suburb / Zone'),
          const SizedBox(height: 6),
          _dropdownWidget<int>(
            value: _selectedArea,
            hint: 'Select',
            items: _areas
                .map((a) => DropdownMenuItem<int>(
                      value: a['id'],
                      child: Text(a['name'] ?? '',
                          style: const TextStyle(fontSize: 13)),
                    ))
                .toList(),
            onChanged: (v) {
              setState(() => _selectedArea = v);
              final area = _areas.firstWhere(
                  (a) => a['id'] == v,
                  orElse: () => null);
              _areaName = area?['name'] ?? '';
            },
          ),
          const SizedBox(height: 16),

          // Phone
          _field('Phone *', _phoneController,
              hint: 'Phone (numbers only)',
              keyboardType: TextInputType.phone,
              maxLength: 10),

          // WhatsApp
          _fieldLabel('Use same number for WhatsApp?'),
          const SizedBox(height: 6),
          Row(
            children: [
              _radio('Yes', 'yes', _sameWhatsapp, (v) {
                setState(() {
                  _sameWhatsapp = v!;
                  if (v == 'yes') {
                    _whatsappController.text =
                        _phoneController.text;
                  }
                });
              }),
              const SizedBox(width: 20),
              _radio('No', 'no', _sameWhatsapp,
                  (v) => setState(() => _sameWhatsapp = v!)),
            ],
          ),
          if (_sameWhatsapp == 'no') ...[
            const SizedBox(height: 8),
            _textField(_whatsappController,
                hint: 'WhatsApp number (numbers only)',
                keyboardType: TextInputType.phone),
          ],
          const SizedBox(height: 16),

          // Is venue (business only)
          if (widget.type == 'business') ...[
            Row(
              children: [
                Checkbox(
                  value: _isVenue,
                  activeColor: const Color(0xFF094a25),
                  onChanged: (v) =>
                      setState(() => _isVenue = v ?? false),
                ),
                const Text('This is a venue',
                    style: TextStyle(
                        fontSize: 13, color: Color(0xFF094a25))),
              ],
            ),
            const SizedBox(height: 8),
          ],

          // Business selector (business type only)
          if (widget.type == 'business' &&
              _businesses.isNotEmpty) ...[
            _fieldLabel('Related Business (optional)'),
            const SizedBox(height: 6),
            _dropdownWidget<int>(
              value: _businessId,
              hint: 'Select a Business',
              items: _businesses
                  .map((b) => DropdownMenuItem<int>(
                        value: b['id'],
                        child: Text(b['name'] ?? '',
                            style:
                                const TextStyle(fontSize: 13)),
                      ))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _businessId = v),
            ),
            const SizedBox(height: 16),
          ],

          // Fax
          _field('Fax', _faxController,
              hint: 'Fax (numbers only)',
              keyboardType: TextInputType.phone,
              maxLength: 10),

          // Email
          _field('Email', _emailController,
              hint: 'Email',
              keyboardType: TextInputType.emailAddress),

          // Website (non-business)
          if (widget.type != 'business') ...[
            _field('Website', _websiteController,
                hint: 'Website', keyboardType: TextInputType.url),
          ],

          // Terms (add only)
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
            const SizedBox(height: 12),
          ],

          // Error
          if (_error.isNotEmpty) ...[
            Text(_error,
                style: const TextStyle(
                    color: Color(0xFFbc2023), fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
          ],

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

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Widget _field(
    String label,
    TextEditingController controller, {
    String? hint,
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
              hint: hint,
              maxLines: maxLines,
              maxLength: maxLength,
              keyboardType: keyboardType),
          const SizedBox(height: 16),
        ],
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
    void Function(String)? onChanged,
  }) =>
      TextField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        keyboardType: keyboardType,
        onChanged: onChanged,
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
            activeColor: const Color(0xFF094a25),
            onChanged: onChanged,
          ),
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: Colors.black87)),
        ],
      );
}