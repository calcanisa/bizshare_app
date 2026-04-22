import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';

class AddClassifiedModal extends StatefulWidget {
  final String action; // 'add' or 'edit'
  final Map<String, dynamic>? ad;
  final void Function(Map<String, dynamic> data) onSave;
  final VoidCallback onCancel;

  const AddClassifiedModal({
    super.key,
    required this.action,
    this.ad,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<AddClassifiedModal> createState() => _AddClassifiedModalState();
}

class _AddClassifiedModalState extends State<AddClassifiedModal> {
  bool _loading = true;
  bool _saving = false;
  bool _accepted = false;
  bool _published = true;

  // Ad type selection
  String _catName = '';
  int _catId = 0;

  // Categories
  List<dynamic> _topCategories = [];
  List<dynamic> _categories = [];
  List<dynamic> _subCategories = [];
  int? _selectedCategoryId;
  int? _selectedSubCategoryId;

  // Form controllers
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _phoneController = TextEditingController();
  final _priceController = TextEditingController();
  final _kilometersController = TextEditingController();
  final _modelYearController = TextEditingController();
  final _displacementController = TextEditingController();
  final _floorSizeController = TextEditingController();
  final _propSizeController = TextEditingController();

  // Dropdowns
  String _terms = '';
  String? _isNew;
  String _seller = '';
  String _propSeller = '';
  String _propertyType = '';
  String _parking = '';
  String? _bedrooms;
  String? _bathrooms;
  String _bodyType = '';
  String _transmission = '';
  String _driveType = '';
  String _carColor = '';
  String _fuelType = '';
  String? _availableFrom;
  String? _availableTill;

  // Location
  List<dynamic> _provinces = [];
  List<dynamic> _cities = [];
  List<dynamic> _areas = [];
  int? _province;
  int? _city;
  int? _area;

  // Vehicle
  List<dynamic> _makes = [];
  List<dynamic> _models = [];
  int? _selectedMake;
  int? _selectedModel;

  // Extras
  List<String> _carExtras = [];
  List<String> _propExtras = [];

  // Images
  List<File> _newImages = [];
  List<String> _existingImages = [];
  List<int> _imagesToRemove = [];
  int _defaultImageIndex = 0;

  List<String> _errors = [];

  static const _propertyExtras = [
    'Pool',
    'Tennis Courts',
    'Jacuzzi',
    'Electric Fence',
    'Flatlet',
    'Borehole',
    'Fibre'
  ];

  static const _vehicleExtras = [
    'Aircon',
    'Sound System',
    'Gearlock',
    'Parking Assist',
    'Cameras',
    'Alarm',
    'Electric Seats'
  ];

  static const _carColors = [
    ('black', 'Black'),
    ('white', 'White'),
    ('silver', 'Silver'),
    ('grey', 'Grey'),
    ('red', 'Red'),
    ('blue', 'Blue'),
    ('green', 'Green'),
    ('yellow', 'Yellow'),
    ('orange', 'Orange'),
    ('brown', 'Brown'),
    ('gold', 'Gold'),
    ('beige', 'Beige'),
    ('purple', 'Purple'),
    ('other', 'Other'),
  ];

  static const _adTypeIcons = {
    'For Sale': Icons.sell,
    'Property': Icons.home,
    'Services': Icons.build,
    'Society': Icons.people,
    'Vehicles': Icons.directions_car,
  };

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _phoneController.dispose();
    _priceController.dispose();
    _kilometersController.dispose();
    _modelYearController.dispose();
    _displacementController.dispose();
    _floorSizeController.dispose();
    _propSizeController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      final results = await Future.wait([
        api.dio.get('/api/v1/classifieds/categories/top/'),
        api.dio.get('/api/v1/locations/provinces/'),
        api.dio.get('/api/v1/classifieds/makes/'),
      ]);
      final cats = results[0].data;
      final provs = results[1].data;
      final mks = results[2].data;
      setState(() {
        _topCategories = cats is List ? cats : (cats['results'] ?? []);
        _provinces = provs is List ? provs : (provs['results'] ?? []);
        _makes = mks is List ? mks : (mks['results'] ?? []);
      });
    } catch (_) {}

    if (widget.action == 'edit' && widget.ad != null) {
      await _populateForm(widget.ad!);
    }

    setState(() => _loading = false);
  }

  Future<void> _populateForm(Map<String, dynamic> ad) async {
    _titleController.text = ad['title'] ?? '';
    _bodyController.text = ad['adbody'] ?? '';
    _phoneController.text = ad['phone'] ?? '';
    _priceController.text = ad['price']?.toString() ?? '';
    _kilometersController.text = ad['kilometers']?.toString() ?? '';
    _modelYearController.text = ad['model_year']?.toString() ?? '';
    _displacementController.text = ad['displacement'] ?? '';
    _floorSizeController.text = ad['floor_size']?.toString() ?? '';
    _propSizeController.text = ad['prop_size']?.toString() ?? '';
    _terms = ad['terms'] ?? '';
    _isNew = ad['is_new']?.toString();
    _seller = ad['seller'] ?? '';
    _propSeller = ad['prop_seller'] ?? '';
    _propertyType = ad['property_type'] ?? '';
    _parking = ad['parking'] ?? '';
    _bedrooms = ad['bedrooms']?.toString();
    _bathrooms = ad['bathrooms']?.toString();
    _bodyType = ad['body_type'] ?? '';
    _transmission = ad['transmission'] ?? '';
    _driveType = ad['drive_type'] ?? '';
    _carColor = ad['car_color'] ?? '';
    _fuelType = ad['fuel_type'] ?? '';
    _availableFrom = ad['available_from'];
    _availableTill = ad['available_till'];
    _published = ad['published'] ?? true;
    _carExtras = List<String>.from(ad['car_extras'] ?? []);
    _propExtras = List<String>.from(ad['prop_extras'] ?? []);

    // Category
    final cat = ad['category'];
    if (cat != null) {
      _catName = cat['parent']?['parent']?['name'] ?? '';
      _catId = cat['parent']?['parent']?['id'] ?? 0;
      _setCategories();
      _selectedCategoryId = cat['parent']?['id'];
      _loadSubCategories();
      _selectedSubCategoryId = cat['id'];
    }

    // Location
    if (ad['area'] != null) {
      _province = ad['area']['city']['province']['id'];
      await _loadCities(_province!);
      _city = ad['area']['city']['id'];
      await _loadAreas(_city!);
      _area = ad['area']['id'];
    } else if (ad['city'] != null) {
      _province = ad['city']['province']['id'];
      await _loadCities(_province!);
      _city = ad['city']['id'];
    }

    // Vehicle make/model
    final makeModel = ad['make_model'];
    if (makeModel != null) {
      _selectedMake = makeModel['parent']?['id'];
      if (_selectedMake != null) await _loadModels(_selectedMake!);
      _selectedModel = makeModel['id'];
    }

    // Existing images
    final images = ad['images'] as List? ?? [];
    _existingImages = images
        .map((img) => img['image']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();

    _accepted = true;
  }

  void _setType(String name, int id) {
    setState(() {
      _catName = name;
      _catId = id;
      _selectedCategoryId = null;
      _selectedSubCategoryId = null;
      _subCategories = [];
      _setCategories();
    });
  }

  void _setCategories() {
    final top =
        _topCategories.firstWhere((c) => c['id'] == _catId, orElse: () => null);
    _categories = top?['sub_categories'] ?? [];
  }

  void _loadSubCategories() {
    final parent = _categories.firstWhere((c) => c['id'] == _selectedCategoryId,
        orElse: () => null);
    setState(() => _subCategories = parent?['sub_categories'] ?? []);
  }

  Future<void> _loadCities(int provinceId) async {
    try {
      final api = context.read<ApiService>();
      final res = await api.dio.get('/api/v1/locations/cities/$provinceId/');
      setState(() {
        _cities = res.data is List ? res.data : (res.data['results'] ?? []);
        _city = null;
        _areas = [];
        _area = null;
      });
    } catch (_) {}
  }

  Future<void> _loadAreas(int cityId) async {
    try {
      final api = context.read<ApiService>();
      final res = await api.dio.get('/api/v1/locations/areas/$cityId/');
      setState(() {
        _areas = res.data is List ? res.data : (res.data['results'] ?? []);
        _area = null;
      });
    } catch (_) {}
  }

  Future<void> _loadModels(int makeId) async {
    try {
      final api = context.read<ApiService>();
      final res = await api.dio.get('/api/v1/classifieds/models/$makeId/');
      setState(() {
        _models = res.data is List ? res.data : (res.data['results'] ?? []);
        _selectedModel = null;
      });
    } catch (_) {}
  }

  Future<void> _pickImages() async {
    if (_newImages.length + _existingImages.length >= 8) {
      _showSnack('Maximum 8 images allowed');
      return;
    }
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;
    final remaining = 8 - _newImages.length - _existingImages.length;
    setState(() {
      _newImages.addAll(picked.take(remaining).map((f) => File(f.path)));
    });
  }

  List<String> _validate() {
    final errs = <String>[];
    if (_titleController.text.trim().isEmpty) errs.add('Title cannot be empty');
    if (_bodyController.text.trim().isEmpty) errs.add('Body cannot be empty');
    if (_selectedSubCategoryId == null) errs.add('Category is required');
    if (_terms != 'free' &&
        _terms != 'swop' &&
        _priceController.text.trim().isEmpty) errs.add('Price is required');
    if (_city == null && _area == null) errs.add('City or Area is required');
    if (_phoneController.text.trim().length != 10)
      errs.add('Phone must be 10 digits');
    if (_catName == 'Property') {
      if (_propertyType.isEmpty) errs.add('Property type is required');
      if (_bedrooms == null) errs.add('Bedrooms is required');
      if (_bathrooms == null) errs.add('Bathrooms is required');
    }
    if (_catName == 'Vehicles') {
      if (_selectedModel == null) errs.add('Model is required');
      if (_kilometersController.text.trim().isEmpty)
        errs.add('Kilometers is required');
    }
    if (widget.action == 'add' && !_accepted)
      errs.add('You must accept the terms');
    return errs;
  }

  Future<void> _save() async {
    final errs = _validate();
    if (errs.isNotEmpty) {
      setState(() => _errors = errs);
      return;
    }
    setState(() {
      _saving = true;
      _errors = [];
    });
    try {
      final api = context.read<ApiService>();
      final formData = FormData();
      formData.fields.addAll([
        MapEntry('title', _titleController.text.trim()),
        MapEntry('adbody', _bodyController.text.trim()),
        MapEntry('phone', _phoneController.text.trim()),
        MapEntry('terms', _terms),
        MapEntry('price', _priceController.text.trim()),
        MapEntry('seller', _seller),
        MapEntry('prop_seller', _propSeller),
        MapEntry('property_type', _propertyType),
        MapEntry('body_type', _bodyType),
        MapEntry('transmission', _transmission),
        MapEntry('drive_type', _driveType),
        MapEntry('car_color', _carColor),
        MapEntry('fuel_type', _fuelType),
        MapEntry('parking', _parking),
        MapEntry('bedrooms', _bedrooms ?? ''),
        MapEntry('bathrooms', _bathrooms ?? ''),
        MapEntry('displacement', _displacementController.text.trim()),
        MapEntry('kilometers', _kilometersController.text.trim()),
        MapEntry('model_year', _modelYearController.text.trim()),
        MapEntry('floor_size', _floorSizeController.text.trim()),
        MapEntry('prop_size', _propSizeController.text.trim()),
        MapEntry('available_from', _availableFrom ?? ''),
        MapEntry('available_till', _availableTill ?? ''),
        MapEntry('is_new', _isNew ?? ''),
        MapEntry('published', _published ? 'true' : 'false'),
        MapEntry('type', _catId.toString()),
        MapEntry('category', _selectedSubCategoryId.toString()),
        MapEntry('car_extras', '[${_carExtras.map((e) => '"$e"').join(',')}]'),
        MapEntry(
            'prop_extras', '[${_propExtras.map((e) => '"$e"').join(',')}]'),
        MapEntry('default_image', _defaultImageIndex.toString()),
        MapEntry('images_to_remove', '[${_imagesToRemove.join(',')}]'),
      ]);

      if (_selectedModel != null) {
        formData.fields.add(MapEntry('make_model', _selectedModel.toString()));
      }
      if (_area != null) {
        formData.fields.add(MapEntry('area', _area.toString()));
      }
      if (_city != null) {
        formData.fields.add(MapEntry('city', _city.toString()));
      }

      for (final file in _newImages) {
        formData.files.add(MapEntry(
            'adimages',
            await MultipartFile.fromFile(file.path,
                filename: file.path.split('/').last)));
      }

      late Map<String, dynamic> result;
      if (widget.action == 'edit') {
        final id = widget.ad!['id'];
        final res =
            await api.dio.put('/api/v1/classifieds/$id/u/', data: formData);
        result = res.data;
      } else {
        final res =
            await api.dio.post('/api/v1/classifieds/c/', data: formData);
        result = res.data;
      }
      widget.onSave(result);
    } catch (_) {
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
        backgroundColor: const Color(0xFF094a25),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.action == 'edit' ? 'Edit Classified' : 'Create Classified',
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
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF094a25)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Ad type picker
                if (widget.action != 'edit') ...[
                  _sectionHeader('Select Ad Type'),
                  const SizedBox(height: 12),
                  _adTypePicker(),
                  const SizedBox(height: 20),
                ],

                if (_catName.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF094a25).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'All classifieds ads are valid for 30 days only, but can be extended once they expire.',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black54, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  _field('Ad Title *', _titleController,
                      maxLength: 100,
                      hint:
                          'Make it exciting so people will notice it quickly'),

                  // Categories
                  _fieldLabel('Ad Category *'),
                  const SizedBox(height: 6),
                  _dropdownWidget<int>(
                    value: _selectedCategoryId,
                    hint: 'Select',
                    items: _categories
                        .map((c) => DropdownMenuItem<int>(
                              value: c['id'],
                              child: Text(c['name'] ?? '',
                                  style: const TextStyle(fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (v) {
                      setState(() => _selectedCategoryId = v);
                      _loadSubCategories();
                    },
                  ),
                  if (_subCategories.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _dropdownWidget<int>(
                      value: _selectedSubCategoryId,
                      hint: 'Choose Sub Category',
                      items: _subCategories
                          .map((c) => DropdownMenuItem<int>(
                                value: c['id'],
                                child: Text(c['name'] ?? '',
                                    style: const TextStyle(fontSize: 13)),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedSubCategoryId = v),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Body
                  _field('Ad Body *', _bodyController,
                      maxLines: 6, maxLength: 2500),

                  // Terms + Price
                  _fieldLabel('Purchase Terms / Price *'),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: _dropdownWidget<String>(
                          value: _terms.isEmpty ? null : _terms,
                          hint: 'Select',
                          items: const [
                            DropdownMenuItem(
                                value: 'fixed', child: Text('Fixed price')),
                            DropdownMenuItem(
                                value: 'negotiable', child: Text('Negotiable')),
                            DropdownMenuItem(
                                value: 'installments',
                                child: Text('Installments')),
                            DropdownMenuItem(
                                value: 'swop', child: Text('Swop')),
                            DropdownMenuItem(
                                value: 'free', child: Text('Free')),
                          ],
                          onChanged: (v) => setState(() => _terms = v ?? ''),
                        ),
                      ),
                      if (_terms != 'free' &&
                          _terms != 'swop' &&
                          _terms.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        const Text('R',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF094a25))),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _textField(_priceController,
                              hint: 'Price',
                              keyboardType: TextInputType.number),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // New or used
                  if (_catName == 'For Sale' || _catName == 'Vehicles') ...[
                    _fieldLabel('New or Used *'),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _radio('New', 'true', _isNew ?? '',
                            (v) => setState(() => _isNew = v)),
                        const SizedBox(width: 16),
                        _radio('Used', 'false', _isNew ?? '',
                            (v) => setState(() => _isNew = v)),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Seller
                  if (_catName != 'Society' && _catName != 'Property') ...[
                    _fieldLabel('Seller'),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _radio('Owner', 'owner', _seller,
                            (v) => setState(() => _seller = v ?? '')),
                        const SizedBox(width: 16),
                        _radio('Dealer', 'dealer', _seller,
                            (v) => setState(() => _seller = v ?? '')),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Property fields
                  if (_catName == 'Property') ...[
                    _dropdownField(
                        'Who\'s Selling?',
                        _propSeller,
                        const [
                          DropdownMenuItem(
                              value: 'owner', child: Text('Owner')),
                          DropdownMenuItem(
                              value: 'rep', child: Text('Representative')),
                          DropdownMenuItem(
                              value: 'agency', child: Text('Agency')),
                        ],
                        (v) => setState(() => _propSeller = v ?? '')),
                    _dropdownField(
                        'Property Type *',
                        _propertyType,
                        const [
                          DropdownMenuItem(
                              value: 'commercial', child: Text('Commercial')),
                          DropdownMenuItem(
                              value: 'empty', child: Text('Empty Land')),
                          DropdownMenuItem(value: 'farm', child: Text('Farm')),
                          DropdownMenuItem(value: 'flat', child: Text('Flat')),
                          DropdownMenuItem(
                              value: 'gardenflat', child: Text('Garden Flat')),
                          DropdownMenuItem(
                              value: 'house', child: Text('House')),
                          DropdownMenuItem(
                              value: 'holiday', child: Text('Holiday Home')),
                          DropdownMenuItem(
                              value: 'townhouse', child: Text('Townhouse')),
                          DropdownMenuItem(
                              value: 'other', child: Text('Other')),
                        ],
                        (v) => setState(() => _propertyType = v ?? '')),
                    if (_propertyType == 'holiday') ...[
                      _datePicker('Available From', _availableFrom, (v) {
                        setState(() => _availableFrom = v);
                      }),
                      _datePicker('Available Till', _availableTill, (v) {
                        setState(() => _availableTill = v);
                      }),
                    ],
                    _fieldLabel('Floor Size'),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _textField(_floorSizeController,
                              hint: 'Floor Size',
                              keyboardType: TextInputType.number),
                        ),
                        const SizedBox(width: 8),
                        const Text('m²', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _fieldLabel('Property Size'),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _textField(_propSizeController,
                              hint: 'Property Size',
                              keyboardType: TextInputType.number),
                        ),
                        const SizedBox(width: 8),
                        const Text('m²', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _dropdownField(
                        'Parking',
                        _parking,
                        const [
                          DropdownMenuItem(
                              value: 'garage', child: Text('Garage')),
                          DropdownMenuItem(
                              value: 'covered', child: Text('Covered')),
                          DropdownMenuItem(
                              value: 'open', child: Text('Complex')),
                          DropdownMenuItem(
                              value: 'street', child: Text('Street')),
                          DropdownMenuItem(
                              value: 'parkinglot', child: Text('Parking lot')),
                        ],
                        (v) => setState(() => _parking = v ?? '')),
                    _dropdownField<String>(
                        'Bedrooms *',
                        _bedrooms,
                        List.generate(
                            20,
                            (i) => DropdownMenuItem<String>(
                                value: '${i + 1}', child: Text('${i + 1}'))),
                        (v) => setState(() => _bedrooms = v)),
                    _dropdownField<String>(
                        'Bathrooms *',
                        _bathrooms,
                        List.generate(
                            12,
                            (i) => DropdownMenuItem<String>(
                                value: '${i + 1}', child: Text('${i + 1}'))),
                        (v) => setState(() => _bathrooms = v)),
                    _checkboxGroup('Property Extras', _propertyExtras,
                        _propExtras, (v) => setState(() => _propExtras = v)),
                  ],

                  // Vehicle fields
                  if (_catName == 'Vehicles') ...[
                    _fieldLabel('Make *'),
                    const SizedBox(height: 6),
                    _dropdownWidget<int>(
                      value: _selectedMake,
                      hint: 'Select Make',
                      items: _makes
                          .map((m) => DropdownMenuItem<int>(
                                value: m['id'],
                                child: Text(m['name'] ?? '',
                                    style: const TextStyle(fontSize: 13)),
                              ))
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          _selectedMake = v;
                          _selectedModel = null;
                          _models = [];
                        });
                        if (v != null) _loadModels(v);
                      },
                    ),
                    const SizedBox(height: 10),
                    _fieldLabel('Model *'),
                    const SizedBox(height: 6),
                    _dropdownWidget<int>(
                      value: _selectedModel,
                      hint: 'Select Model',
                      items: _models
                          .map((m) => DropdownMenuItem<int>(
                                value: m['id'],
                                child: Text(m['name'] ?? '',
                                    style: const TextStyle(fontSize: 13)),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedModel = v),
                    ),
                    const SizedBox(height: 16),
                    _field('Year', _modelYearController,
                        keyboardType: TextInputType.number),
                    _fieldLabel('Kilometers *'),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _textField(_kilometersController,
                              hint: 'Kilometers traveled',
                              keyboardType: TextInputType.number),
                        ),
                        const SizedBox(width: 8),
                        const Text('km', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _dropdownField(
                        'Body Type',
                        _bodyType,
                        const [
                          DropdownMenuItem(
                              value: 'sedan', child: Text('Sedan')),
                          DropdownMenuItem(
                              value: 'bakkie', child: Text('Bakkie')),
                          DropdownMenuItem(value: 'suv', child: Text('SUV')),
                          DropdownMenuItem(
                              value: 'sportscar', child: Text('Sportscar')),
                          DropdownMenuItem(
                              value: 'convertible', child: Text('Convertible')),
                          DropdownMenuItem(
                              value: 'coupe', child: Text('Coupe')),
                          DropdownMenuItem(
                              value: 'hatchback', child: Text('Hatchback')),
                          DropdownMenuItem(
                              value: 'stationwagon',
                              child: Text('Stationwagon')),
                          DropdownMenuItem(value: 'bus', child: Text('Bus')),
                          DropdownMenuItem(
                              value: 'panelvan', child: Text('Panelvan')),
                          DropdownMenuItem(
                              value: 'custom', child: Text('Custom')),
                        ],
                        (v) => setState(() => _bodyType = v ?? '')),
                    _dropdownField(
                        'Transmission',
                        _transmission,
                        const [
                          DropdownMenuItem(
                              value: 'manual', child: Text('Manual')),
                          DropdownMenuItem(
                              value: 'automatic', child: Text('Automatic')),
                        ],
                        (v) => setState(() => _transmission = v ?? '')),
                    _dropdownField(
                        'Drive Train',
                        _driveType,
                        const [
                          DropdownMenuItem(
                              value: 'rwd', child: Text('Rear wheel drive')),
                          DropdownMenuItem(
                              value: 'fwd', child: Text('Front wheel drive')),
                          DropdownMenuItem(
                              value: 'awd', child: Text('All wheel drive')),
                          DropdownMenuItem(value: '4x4', child: Text('4 x 4')),
                        ],
                        (v) => setState(() => _driveType = v ?? '')),
                    _dropdownField(
                        'Color',
                        _carColor,
                        _carColors
                            .map((c) => DropdownMenuItem<String>(
                                  value: c.$1,
                                  child: Text(c.$2),
                                ))
                            .toList(),
                        (v) => setState(() => _carColor = v ?? '')),
                    _dropdownField(
                        'Fuel Type',
                        _fuelType,
                        const [
                          DropdownMenuItem(
                              value: 'petrol', child: Text('Petrol')),
                          DropdownMenuItem(
                              value: 'diesel', child: Text('Diesel')),
                          DropdownMenuItem(
                              value: 'electric', child: Text('Electric')),
                          DropdownMenuItem(
                              value: 'hybrid', child: Text('Hybrid')),
                          DropdownMenuItem(
                              value: 'hydrogen', child: Text('Hydrogen')),
                        ],
                        (v) => setState(() => _fuelType = v ?? '')),
                    _checkboxGroup('Vehicle Extras', _vehicleExtras, _carExtras,
                        (v) => setState(() => _carExtras = v)),
                    _fieldLabel('Displacement *'),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _textField(_displacementController,
                              hint: 'Engine size', maxLength: 6),
                        ),
                        const SizedBox(width: 8),
                        const Text('cm³', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Location
                  _sectionHeader('Location *'),
                  const SizedBox(height: 12),
                  _dropdownWidget<int>(
                    value: _province,
                    hint: 'Province',
                    items: _provinces
                        .map((p) => DropdownMenuItem<int>(
                              value: p['id'],
                              child: Text(p['name'] ?? '',
                                  style: const TextStyle(fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (v) {
                      setState(() => _province = v);
                      if (v != null) _loadCities(v);
                    },
                  ),
                  if (_cities.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _dropdownWidget<int>(
                      value: _city,
                      hint: 'City',
                      items: _cities
                          .map((c) => DropdownMenuItem<int>(
                                value: c['id'],
                                child: Text(c['name'] ?? '',
                                    style: const TextStyle(fontSize: 13)),
                              ))
                          .toList(),
                      onChanged: (v) {
                        setState(() => _city = v);
                        if (v != null) _loadAreas(v);
                      },
                    ),
                  ],
                  if (_areas.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _dropdownWidget<int>(
                      value: _area,
                      hint: 'Area',
                      items: _areas
                          .map((a) => DropdownMenuItem<int>(
                                value: a['id'],
                                child: Text(a['name'] ?? '',
                                    style: const TextStyle(fontSize: 13)),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _area = v),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Phone
                  _field('Phone *', _phoneController,
                      hint: 'Phone number',
                      keyboardType: TextInputType.phone,
                      maxLength: 10),

                  // Images
                  _sectionHeader('Ad Images'),
                  const SizedBox(height: 8),
                  const Text(
                      'You can upload up to 8 images. Tap one to set as default.',
                      style: TextStyle(fontSize: 12, color: Colors.black45)),
                  const SizedBox(height: 10),
                  _imagesSection(),
                  const SizedBox(height: 16),

                  // Errors
                  if (_errors.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _errors
                            .map((e) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text('• $e',
                                      style: const TextStyle(
                                          color: Colors.red, fontSize: 13)),
                                ))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Published
                  Row(
                    children: [
                      Checkbox(
                        value: _published,
                        activeColor: const Color(0xFF094a25),
                        onChanged: (v) =>
                            setState(() => _published = v ?? true),
                      ),
                      const Text('Published', style: TextStyle(fontSize: 13)),
                    ],
                  ),

                  // Terms
                  if (widget.action == 'add') ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
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
                                  decoration: TextDecoration.underline)),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Save / Cancel
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF094a25),
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
                                  widget.action == 'edit' ? 'Save' : 'Create',
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
                            foregroundColor: const Color(0xFFbc2023),
                            side: const BorderSide(color: Color(0xFFbc2023)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Cancel',
                              style: TextStyle(fontSize: 15)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text('All classifieds are valid for 30 days.',
                        style: TextStyle(fontSize: 11, color: Colors.black45)),
                  ),
                  const SizedBox(height: 40),
                ],
              ],
            ),
    );
  }

  // ─── Ad type picker ───────────────────────────────────────────────────────

  Widget _adTypePicker() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _topCategories.map((cat) {
        final name = cat['name'] as String? ?? '';
        final id = cat['id'] as int;
        final selected = _catName == name;
        final icon = {
              'For Sale': Icons.sell,
              'Property': Icons.home,
              'Services': Icons.build,
              'Society': Icons.people,
              'Vehicles': Icons.directions_car,
            }[name] ??
            Icons.category;

        return GestureDetector(
          onTap: () => _setType(name, id),
          child: Container(
            width: 90,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF094a25) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: selected
                      ? const Color(0xFF094a25)
                      : Colors.grey.shade300),
            ),
            child: Column(
              children: [
                Icon(icon,
                    color: selected ? Colors.white : const Color(0xFF094a25),
                    size: 28),
                const SizedBox(height: 6),
                Text(name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color:
                            selected ? Colors.white : const Color(0xFF094a25))),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── Images section ───────────────────────────────────────────────────────

  Widget _imagesSection() {
    final allImages = <Widget>[];

    // Existing images
    for (int i = 0; i < _existingImages.length; i++) {
      allImages.add(_imageTile(
        child: Image.network(_existingImages[i], fit: BoxFit.cover),
        index: i,
        isDefault: _defaultImageIndex == i,
        onRemove: () {
          setState(() {
            _existingImages.removeAt(i);
            if (_defaultImageIndex >= _existingImages.length) {
              _defaultImageIndex = 0;
            }
          });
        },
        onSetDefault: () => setState(() => _defaultImageIndex = i),
      ));
    }

    // New images
    for (int i = 0; i < _newImages.length; i++) {
      final globalIndex = _existingImages.length + i;
      allImages.add(_imageTile(
        child: Image.file(_newImages[i], fit: BoxFit.cover),
        index: globalIndex,
        isDefault: _defaultImageIndex == globalIndex,
        onRemove: () {
          setState(() {
            _newImages.removeAt(i);
            if (_defaultImageIndex >= globalIndex) {
              _defaultImageIndex = 0;
            }
          });
        },
        onSetDefault: () => setState(() => _defaultImageIndex = globalIndex),
      ));
    }

    return Column(
      children: [
        if (allImages.isNotEmpty)
          Wrap(spacing: 8, runSpacing: 8, children: allImages),
        const SizedBox(height: 10),
        if (_existingImages.length + _newImages.length < 8)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _pickImages,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF094a25),
                side: const BorderSide(color: Color(0xFF094a25)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('Upload Images'),
            ),
          ),
      ],
    );
  }

  Widget _imageTile({
    required Widget child,
    required int index,
    required bool isDefault,
    required VoidCallback onRemove,
    required VoidCallback onSetDefault,
  }) =>
      GestureDetector(
        onTap: onSetDefault,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 90,
                height: 90,
                child: child,
              ),
            ),
            if (isDefault)
              Positioned(
                bottom: 4,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.black54,
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: const Text('Default',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 10)),
                ),
              ),
            Positioned(
              top: 2,
              right: 2,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 12),
                ),
              ),
            ),
          ],
        ),
      );

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Widget _sectionHeader(String title) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF094a25)));

  Widget _field(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    int? maxLength,
    String? hint,
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
              hint: hint,
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
            borderSide: const BorderSide(color: Color(0xFF094a25)),
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
          _dropdownWidget<T>(
              value: value, hint: 'Select', items: items, onChanged: onChanged),
          const SizedBox(height: 16),
        ],
      );

  Widget _dropdownWidget<T>({
    T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    // Treat empty string as null to avoid assertion errors
    final effectiveValue = (value is String && value.isEmpty) ? null : value;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black26),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: effectiveValue as T?,
          hint: Text(hint,
              style: const TextStyle(color: Colors.black45, fontSize: 13)),
          isExpanded: true,
          style: const TextStyle(fontSize: 13, color: Colors.black87),
          items: [
            DropdownMenuItem<T>(
                value: null,
                child: Text(hint,
                    style:
                        const TextStyle(color: Colors.black45, fontSize: 13))),
            ...items,
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

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
              style: const TextStyle(fontSize: 13, color: Colors.black87)),
        ],
      );

  Widget _checkboxGroup(
    String label,
    List<String> options,
    List<String> selected,
    void Function(List<String>) onChanged,
  ) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel(label),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: options.map((opt) {
              final isSelected = selected.contains(opt);
              return FilterChip(
                label: Text(opt, style: const TextStyle(fontSize: 12)),
                selected: isSelected,
                selectedColor: const Color(0xFF094a25).withOpacity(0.15),
                checkmarkColor: const Color(0xFF094a25),
                onSelected: (v) {
                  final updated = List<String>.from(selected);
                  if (v) {
                    updated.add(opt);
                  } else {
                    updated.remove(opt);
                  }
                  onChanged(updated);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
      );

  Widget _datePicker(
    String label,
    String? value,
    void Function(String) onChanged,
  ) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel(label),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate:
                    value != null ? DateTime.tryParse(value) ?? now : now,
                firstDate: now,
                lastDate: now.add(const Duration(days: 365 * 5)),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme:
                        const ColorScheme.light(primary: Color(0xFF094a25)),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) {
                onChanged(picked.toIso8601String().split('T')[0]);
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
                      value ?? 'Select date',
                      style: TextStyle(
                          fontSize: 13,
                          color:
                              value == null ? Colors.black45 : Colors.black87),
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
}
