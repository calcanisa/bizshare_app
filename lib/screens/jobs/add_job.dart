import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import '../jobs/add_exam.dart';

class AddJobModal extends StatefulWidget {
  final String action; // 'add' or 'edit'
  final Map<String, dynamic>? job;
  final void Function(Map<String, dynamic> data) onSave;
  final VoidCallback onCancel;

  const AddJobModal({
    super.key,
    required this.action,
    this.job,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<AddJobModal> createState() => _AddJobModalState();
}

class _AddJobModalState extends State<AddJobModal> {
  bool _saving = false;
  bool _accepted = false;
  bool _published = true;
  bool _marketRelated = false;

  // Image
  File? _imageFile;
  String? _existingImage;

  // Controllers
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _dutyTitleController = TextEditingController();
  final _dutyDescController = TextEditingController();
  final _questionTitleController = TextEditingController();
  final _questionDescController = TextEditingController();

  // Dropdowns
  int? _selectedIndustryId;
  int? _selectedFunctionId;
  String _rateInterval = '';
  String _minRemuneration = '';
  String _maxRemuneration = '';
  String _equality = '';
  String _contractType = '';
  String _workEnvironment = '';
  String _workSchedule = '';
  String _experienceRequired = '';
  String _educationRequired = '';
  int? _companyPosting;

  // Location
  List<dynamic> _provinces = [];
  List<dynamic> _cities = [];
  List<dynamic> _areas = [];
  int? _selectedProvince;
  int? _selectedCity;
  int? _selectedArea;

  // Reference data
  List<dynamic> _industries = [];
  List<dynamic> _functions = [];
  List<dynamic> _businesses = [];
  List<dynamic> _allSkills = [];

  // Skills
  List<Map<String, dynamic>> _selectedSkills = [];
  bool _addingSkills = false;
  int? _skillCategory;
  int? _skillSubcategory;
  Map<String, dynamic>? _skillToAdd;

  // Duties
  List<Map<String, dynamic>> _duties = [];
  bool _addingDuty = false;

  // Questions
  List<Map<String, dynamic>> _questions = [];
  bool _addingQuestion = false;

  // Exams
  List<Map<String, dynamic>> _exams = [];

  // Rate options
  static const _hourlyRates = [
    ('25', 'R25'),
    ('50', 'R50'),
    ('75', 'R75'),
    ('100', 'R100'),
    ('125', 'R125'),
    ('150', 'R150'),
    ('175', 'R175'),
    ('200', 'R200'),
    ('250', 'R250'),
    ('300', 'R300'),
    ('350', 'R350'),
    ('400', 'R400'),
    ('500', 'R500'),
    ('600', 'R600'),
    ('750', 'R750'),
    ('1000', 'R1000+'),
  ];
  static const _dailyRates = [
    ('200', 'R200'),
    ('300', 'R300'),
    ('400', 'R400'),
    ('500', 'R500'),
    ('600', 'R600'),
    ('700', 'R700'),
    ('800', 'R800'),
    ('1000', 'R1000'),
    ('1200', 'R1200'),
    ('1500', 'R1500'),
    ('2000', 'R2000'),
    ('2500', 'R2500+'),
  ];
  static const _weeklyRates = [
    ('500', 'R500'),
    ('750', 'R750'),
    ('1000', 'R1000'),
    ('1500', 'R1500'),
    ('2000', 'R2000'),
    ('2500', 'R2500'),
    ('3000', 'R3000'),
    ('4000', 'R4000'),
    ('5000', 'R5000'),
    ('6000', 'R6000'),
    ('7500', 'R7500'),
    ('10000', 'R10000+'),
  ];
  static const _monthlyRates = [
    ('3000', 'R3000'),
    ('4000', 'R4000'),
    ('5000', 'R5000'),
    ('6000', 'R6000'),
    ('7000', 'R7000'),
    ('8000', 'R8000'),
    ('10000', 'R10000'),
    ('12000', 'R12000'),
    ('15000', 'R15000'),
    ('18000', 'R18000'),
    ('20000', 'R20000'),
    ('25000', 'R25000'),
    ('30000', 'R30000'),
    ('40000', 'R40000'),
    ('50000', 'R50000+'),
  ];
  static const _yearlyRates = [
    ('50000', 'R50000'),
    ('75000', 'R75000'),
    ('100000', 'R100000'),
    ('120000', 'R120000'),
    ('150000', 'R150000'),
    ('180000', 'R180000'),
    ('200000', 'R200000'),
    ('250000', 'R250000'),
    ('300000', 'R300000'),
    ('400000', 'R400000'),
    ('500000', 'R500000'),
    ('600000', 'R600000+'),
  ];

  List<(String, String)> get _currentRates {
    switch (_rateInterval) {
      case 'hour':
        return _hourlyRates;
      case 'day':
        return _dailyRates;
      case 'week':
        return _weeklyRates;
      case 'month':
        return _monthlyRates;
      case 'year':
        return _yearlyRates;
      default:
        return [];
    }
  }

  String get _rateLabel {
    switch (_rateInterval) {
      case 'hour':
        return 'p/h';
      case 'day':
        return 'p/d';
      case 'week':
        return 'p/w';
      case 'month':
        return 'p/m';
      case 'year':
        return 'p/y';
      default:
        return '';
    }
  }

  List<dynamic> get _skillCategories =>
      _allSkills.where((s) => s['parent'] == null).toList();

  List<dynamic> get _skillSubcategories =>
      _allSkills.where((s) => s['parent'] == _skillCategory).toList();

  List<dynamic> get _skillOptions =>
      _allSkills.where((s) => s['parent'] == _skillSubcategory).toList();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _dutyTitleController.dispose();
    _dutyDescController.dispose();
    _questionTitleController.dispose();
    _questionDescController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    debugPrint('_loadInitialData called, action: ${widget.action}');
    try {
      final api = context.read<ApiService>();
      final results = await Future.wait([
        api.dio.get('/api/v1/directory/business/categories/'),
        api.dio.get('/api/v1/jobs/functions/'),
        api.dio.get('/api/v1/locations/provinces/'),
        api.dio.get('/api/v1/directory/businesses/current/'),
      ]);
      debugPrint('results loaded, industries: ${results[0].data}');
      setState(() {
        debugPrint('setState called in _loadInitialData');
        final ind = results[0].data;
        _industries = ind is List ? ind : ((ind['results'] ?? ind) as List);
        final fn = results[1].data;
        _functions = fn is List ? fn : (fn['results'] ?? []);
        final prov = results[2].data;
        _provinces = prov is List ? prov : (prov['results'] ?? []);
        _businesses = results[3].data ?? [];
      });
      // Populate form AFTER reference data is loaded
      if (widget.action == 'edit' && widget.job != null) {
        setState(() => _populateForm(widget.job!));
      }
    } catch (e) {
      debugPrint('_loadInitialData error: $e');
    }
  }

  Future<void> _loadSkills() async {
    if (_allSkills.isNotEmpty) return;
    try {
      final api = context.read<ApiService>();
      final res = await api.dio.get('/api/v1/jobs/skills/');
      final data = res.data;
      setState(
          () => _allSkills = data is List ? data : (data['results'] ?? []));
    } catch (e) {
      debugPrint('_loadInitialData error: $e');
    }
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

  void _populateForm(Map<String, dynamic> j) {
    debugPrint('JOB DATA: $j');
    _titleController.text = j['title'] ?? '';
    _descController.text = j['description'] ?? '';
    _existingImage = j['image'];
    _published = j['published'] ?? true;
    _marketRelated = j['market_related'] ?? false;
    _rateInterval = j['rate_interval'] ?? '';
    _rateInterval = j['rate_interval'] ?? '';
    final minVal = j['min_remuneration']?.toString() ?? '';
    final maxVal = j['max_remuneration']?.toString() ?? '';
    _minRemuneration = minVal;
    _maxRemuneration = maxVal;
    _equality = j['equality'] ?? '';
    _contractType = j['contract_type'] ?? '';
    _workEnvironment = j['work_environment'] ?? '';
    _workSchedule = j['work_schedule'] ?? '';
    _experienceRequired = j['experience_required'] ?? '';
    _educationRequired = j['education_required'] ?? '';
    final industryId = (j['industry'] as Map?)?['id'];
    final functionId = (j['function'] as Map?)?['id'];
    _selectedIndustryId = industryId is int
        ? industryId
        : int.tryParse(industryId?.toString() ?? '');
    _selectedFunctionId = functionId is int
        ? functionId
        : int.tryParse(functionId?.toString() ?? '');
    final cp = j['company_posting'] is Map
        ? (j['company_posting'] as Map)['id']
        : j['company_posting'];
    _companyPosting = cp is int ? cp : int.tryParse(cp?.toString() ?? '');

    final area = j['area'] as Map?;
    if (area != null) {
      _selectedArea = area['id'] is int
          ? area['id']
          : int.tryParse(area['id']?.toString() ?? '');
      final city = area['city'] as Map?;
      if (city != null) {
        _selectedCity = city['id'] is int
            ? city['id']
            : int.tryParse(city['id']?.toString() ?? '');
        final province = city['province'] as Map?;
        if (province != null) {
          _selectedProvince = province['id'] is int
              ? province['id']
              : int.tryParse(province['id']?.toString() ?? '');
          _loadCities(province['id']).then((_) {
            if (_selectedCity != null) _loadAreas(_selectedCity!);
          });
        }
      }
    }

    _selectedSkills = (j['skills'] as List? ?? [])
        .map((s) => Map<String, dynamic>.from(s as Map))
        .toList();
    _duties = (j['duties'] as List? ?? [])
        .map((d) => Map<String, dynamic>.from(d as Map))
        .toList();
    _questions = (j['questions'] as List? ?? [])
        .map((q) => Map<String, dynamic>.from(q as Map))
        .toList();
    _exams = (j['exams'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    _accepted = true;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  void _addDuty() {
    if (_dutyTitleController.text.trim().isEmpty) {
      _showSnack('Duty title cannot be empty');
      return;
    }
    if (_duties.length >= 10) {
      _showSnack('You are limited to 10 duties');
      return;
    }
    setState(() {
      _duties.add({
        'title': _dutyTitleController.text.trim(),
        'description': _dutyDescController.text.trim(),
      });
      _dutyTitleController.clear();
      _dutyDescController.clear();
    });
  }

  void _addQuestion() {
    if (_questionTitleController.text.trim().isEmpty) {
      _showSnack('Question title cannot be empty');
      return;
    }
    setState(() {
      _questions.add({
        'title': _questionTitleController.text.trim(),
        'description': _questionDescController.text.trim(),
      });
      _questionTitleController.clear();
      _questionDescController.clear();
    });
  }

  void _addSkill() {
    if (_skillToAdd == null) {
      _showSnack('Please select a skill');
      return;
    }
    if (_selectedSkills.length >= 10) {
      _showSnack('You are limited to 10 skills');
      return;
    }
    if (_selectedSkills.any((s) => s['id'] == _skillToAdd!['id'])) {
      _showSnack('Skill already added');
      return;
    }
    setState(() {
      _selectedSkills.add(Map<String, dynamic>.from(_skillToAdd!));
      _skillToAdd = null;
      _skillCategory = null;
      _skillSubcategory = null;
    });
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty ||
        _descController.text.trim().isEmpty) {
      _showSnack('Title and description are required');
      return;
    }
    if (_selectedIndustryId == null) {
      _showSnack('Industry is required');
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
        MapEntry('industry', _selectedIndustryId.toString()),
        MapEntry('function', _selectedFunctionId?.toString() ?? ''),
        MapEntry('market_related', _marketRelated.toString()),
        MapEntry('rate_interval', _rateInterval),
        MapEntry('min_remuneration', _minRemuneration),
        MapEntry('max_remuneration', _maxRemuneration),
        MapEntry('equality', _equality),
        MapEntry('contract_type', _contractType),
        MapEntry('work_environment', _workEnvironment),
        MapEntry('work_schedule', _workSchedule),
        MapEntry('experience_required', _experienceRequired),
        MapEntry('education_required', _educationRequired),
        MapEntry('area', _selectedArea?.toString() ?? ''),
        MapEntry('city', _selectedCity?.toString() ?? ''),
        MapEntry('company_posting', _companyPosting?.toString() ?? ''),
        MapEntry('published', _published.toString()),
        MapEntry('skill_ids',
            '[${_selectedSkills.map((s) => s['id'].toString()).join(',')}]'),
        MapEntry('duties',
            '[${_duties.map((d) => '{"title":"${d['title']}","description":"${d['description']}"}').join(',')}]'),
        MapEntry('questions',
            '[${_questions.map((q) => '{"title":"${q['title']}","description":"${q['description']}"}').join(',')}]'),
        MapEntry(
            'exams',
            _exams.isNotEmpty
                ? '[${_exams.map((e) => '{"duration":${e['duration']},"time_format":"${e['time_format']}","questions":${e['questions']}}').join(',')}]'
                : '[]'),
      ]);

      if (_imageFile != null) {
        formData.files.add(MapEntry(
            'image',
            await MultipartFile.fromFile(_imageFile!.path,
                filename: 'job.jpg')));
      }

      late Map<String, dynamic> result;
      if (widget.action == 'add') {
        final res = await api.dio.post('/api/v1/jobs/job/c/', data: formData);
        result = res.data;
      } else {
        final id = widget.job!['id'];
        final res =
            await api.dio.put('/api/v1/jobs/job/$id/u/', data: formData);
        result = res.data;
      }
      widget.onSave(result);
    } catch (_) {
      _showSnack('Failed to save job. Please try again.');
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
          widget.action == 'edit' ? 'Edit Job' : 'Add Job',
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
          // Note
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF094a25).withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'All jobs posted are published for one month only. A job can be extended but will count as a new job.',
              style:
                  TextStyle(fontSize: 12, color: Colors.black54, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),

          // Image
          _imageSection(),
          const SizedBox(height: 16),

          // Title
          _field('Position Title *', _titleController, maxLength: 100),

          // Industry
          _dropdownField(
              'Industry *',
              _selectedIndustryId,
              _industries
                  .map((i) => DropdownMenuItem<int>(
                      value: i['id'],
                      child: Text(i['name'] ?? '',
                          style: const TextStyle(fontSize: 13))))
                  .toList(),
              (v) => setState(() => _selectedIndustryId = v)),

          // Function
          _dropdownField(
              'Function *',
              _selectedFunctionId,
              _functions
                  .map((f) => DropdownMenuItem<int>(
                      value: f['id'],
                      child: Text(f['name'] ?? '',
                          style: const TextStyle(fontSize: 13))))
                  .toList(),
              (v) => setState(() => _selectedFunctionId = v)),

          // Pay package
          _sectionHeader('Pay Package'),
          const SizedBox(height: 12),
          Row(
            children: [
              Checkbox(
                value: _marketRelated,
                activeColor: const Color(0xFF094a25),
                onChanged: (v) => setState(() => _marketRelated = v ?? false),
              ),
              const Text('Market Related', style: TextStyle(fontSize: 13)),
            ],
          ),
          if (!_marketRelated) ...[
            _dropdownField(
                'Rate Interval',
                _rateInterval.isEmpty ? null : _rateInterval,
                const [
                  DropdownMenuItem(value: 'hour', child: Text('Per hour')),
                  DropdownMenuItem(value: 'day', child: Text('Per day')),
                  DropdownMenuItem(value: 'week', child: Text('Per week')),
                  DropdownMenuItem(value: 'month', child: Text('Per month')),
                  DropdownMenuItem(value: 'year', child: Text('Per year')),
                ],
                (v) => setState(() {
                      _rateInterval = v ?? '';
                      _minRemuneration = '';
                      _maxRemuneration = '';
                    })),
            if (_rateInterval.isNotEmpty && _currentRates.isNotEmpty) ...[
              _dropdownField(
                  'Min Remuneration $_rateLabel',
                  _minRemuneration.isEmpty ? null : _minRemuneration,
                  _currentRates
                      .map((r) => DropdownMenuItem<String>(
                          value: r.$1,
                          child: Text('R${r.$2}',
                              style: const TextStyle(fontSize: 13))))
                      .toList(),
                  (v) => setState(() => _minRemuneration = v ?? '')),
              _dropdownField(
                  'Max Remuneration $_rateLabel',
                  _maxRemuneration.isEmpty ? null : _maxRemuneration,
                  _currentRates
                      .map((r) => DropdownMenuItem<String>(
                          value: r.$1,
                          child: Text('R${r.$2}',
                              style: const TextStyle(fontSize: 13))))
                      .toList(),
                  (v) => setState(() => _maxRemuneration = v ?? '')),
            ],
          ],
          const SizedBox(height: 8),

          // Other dropdowns
          _dropdownField(
              'Empowerment',
              _equality.isEmpty ? null : _equality,
              const [
                DropdownMenuItem(value: 'eeaa', child: Text('EE/AA')),
                DropdownMenuItem(value: 'nonee', child: Text('Non EE/AA')),
              ],
              (v) => setState(() => _equality = v ?? '')),
          _dropdownField(
              'Contract Type',
              _contractType.isEmpty ? null : _contractType,
              const [
                DropdownMenuItem(value: 'fulltime', child: Text('Full Time')),
                DropdownMenuItem(value: 'parttime', child: Text('Part Time')),
                DropdownMenuItem(value: 'temporary', child: Text('Temporary')),
                DropdownMenuItem(value: 'contract', child: Text('Contract')),
                DropdownMenuItem(
                    value: 'internship', child: Text('Internship')),
                DropdownMenuItem(value: 'freelance', child: Text('Freelance')),
              ],
              (v) => setState(() => _contractType = v ?? '')),
          _dropdownField(
              'Work Environment',
              _workEnvironment.isEmpty ? null : _workEnvironment,
              const [
                DropdownMenuItem(value: 'office', child: Text('Office')),
                DropdownMenuItem(value: 'hybrid', child: Text('Hybrid')),
                DropdownMenuItem(value: 'remote', child: Text('Remote')),
              ],
              (v) => setState(() => _workEnvironment = v ?? '')),
          _dropdownField(
              'Work Schedule',
              _workSchedule.isEmpty ? null : _workSchedule,
              const [
                DropdownMenuItem(
                    value: '8hours', child: Text('8 hours per day')),
                DropdownMenuItem(
                    value: 'overtime', child: Text('8 hours + overtime')),
                DropdownMenuItem(
                    value: 'flexible', child: Text('Flexible hours')),
                DropdownMenuItem(value: 'project', child: Text('Per project')),
              ],
              (v) => setState(() => _workSchedule = v ?? '')),

          // Description
          _field('Description *', _descController,
              maxLines: 6, maxLength: 3000),

          // Location
          if (_workEnvironment != 'remote') ...[
            _sectionHeader('Position Location'),
            const SizedBox(height: 12),
            _dropdownWidget<int>(
              value: _selectedProvince,
              hint: 'Province',
              items: _provinces
                  .map((p) => DropdownMenuItem<int>(
                      value: p['id'],
                      child: Text(p['name'] ?? '',
                          style: const TextStyle(fontSize: 13))))
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
                            style: const TextStyle(fontSize: 13))))
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
                hint: 'Area',
                items: _areas
                    .map((a) => DropdownMenuItem<int>(
                        value: a['id'],
                        child: Text(a['name'] ?? '',
                            style: const TextStyle(fontSize: 13))))
                    .toList(),
                onChanged: (v) => setState(() => _selectedArea = v),
              ),
            ],
            const SizedBox(height: 16),
          ],

          // Requirements
          _sectionHeader('Position Requirements'),
          const SizedBox(height: 12),
          _dropdownField(
              'Experience Required',
              _experienceRequired.isEmpty ? null : _experienceRequired,
              [
                '1 year',
                '2 years',
                '3 years',
                '4 years',
                '5 years',
                '6 years',
                '7 years',
                '8 years',
                '9 years',
                '10 years'
              ]
                  .map(
                      (v) => DropdownMenuItem<String>(value: v, child: Text(v)))
                  .toList(),
              (v) => setState(() => _experienceRequired = v ?? '')),
          _dropdownField(
              'Education Required',
              _educationRequired.isEmpty ? null : _educationRequired,
              const [
                DropdownMenuItem(value: 'school', child: Text('High School')),
                DropdownMenuItem(
                    value: 'cert', child: Text('Grade12 + Certificates')),
                DropdownMenuItem(
                    value: 'diploma', child: Text('Grade12 + Diploma')),
                DropdownMenuItem(value: 'bsc', child: Text('Bsc Degree')),
                DropdownMenuItem(value: 'honors', child: Text('Honors Degree')),
                DropdownMenuItem(
                    value: 'masters', child: Text('Masters Degree')),
                DropdownMenuItem(value: 'phd', child: Text('PHD')),
              ],
              (v) => setState(() => _educationRequired = v ?? '')),

          // Skills
          _sectionHeader('Required Skills'),
          const SizedBox(height: 8),
          const Text('The skills required to do the job.',
              style: TextStyle(fontSize: 12, color: Colors.black45)),
          const SizedBox(height: 10),
          if (_selectedSkills.isNotEmpty) ...[
            ..._selectedSkills.asMap().entries.map((e) => Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text(e.value['name'] ?? '',
                              style: const TextStyle(fontSize: 13))),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _selectedSkills.removeAt(e.key)),
                        child: const Icon(Icons.close,
                            size: 16, color: Color(0xFFbc2023)),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 8),
          ],
          if (!_addingSkills)
            OutlinedButton.icon(
              onPressed: () async {
                await _loadSkills();
                setState(() => _addingSkills = true);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF094a25),
                side: const BorderSide(color: Color(0xFF094a25)),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add A Skill'),
            )
          else
            _skillsForm(),
          const SizedBox(height: 16),

          // Duties
          _sectionHeader('Duties'),
          const SizedBox(height: 8),
          const Text('The tasks the employee will perform.',
              style: TextStyle(fontSize: 12, color: Colors.black45)),
          const SizedBox(height: 10),
          if (_duties.isNotEmpty) ...[
            ..._duties.asMap().entries.map((e) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.value['title'] ?? '',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF094a25))),
                            if ((e.value['description'] ?? '').isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(e.value['description'] ?? '',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.black54)),
                            ],
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _duties.removeAt(e.key)),
                        child: const Icon(Icons.close,
                            size: 16, color: Color(0xFFbc2023)),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 8),
          ],
          if (!_addingDuty)
            OutlinedButton.icon(
              onPressed: () => setState(() => _addingDuty = true),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF094a25),
                side: const BorderSide(color: Color(0xFF094a25)),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add A Duty'),
            )
          else
            _dutyForm(),
          const SizedBox(height: 16),

          // Questions
          _sectionHeader('Application Questions'),
          const SizedBox(height: 8),
          const Text('Optional questions applicants must answer when applying.',
              style: TextStyle(fontSize: 12, color: Colors.black45)),
          const SizedBox(height: 10),
          if (_questions.isNotEmpty) ...[
            ..._questions.asMap().entries.map((e) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${e.value['title'] ?? ''}${(e.value['title'] ?? '').endsWith('?') ? '' : '?'}',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF094a25)),
                            ),
                            if ((e.value['description'] ?? '').isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(e.value['description'] ?? '',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.black54)),
                            ],
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _questions.removeAt(e.key)),
                        child: const Icon(Icons.close,
                            size: 16, color: Color(0xFFbc2023)),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 8),
          ],
          if (!_addingQuestion)
            OutlinedButton.icon(
              onPressed: () => setState(() => _addingQuestion = true),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF094a25),
                side: const BorderSide(color: Color(0xFF094a25)),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add A Question'),
            )
          else
            _questionForm(),
          const SizedBox(height: 16),

          // Exams
          _sectionHeader('Exam'),
          const SizedBox(height: 8),
          const Text('Optional exam applicants must complete when applying.',
              style: TextStyle(fontSize: 12, color: Colors.black45)),
          const SizedBox(height: 10),
          if (_exams.isNotEmpty) ...[
            ..._exams.asMap().entries.map((e) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'Duration: ${e.value['duration']} ${e.value['time_format']}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF094a25))),
                            Text(
                                '${(e.value['questions'] as List?)?.length ?? 0} questions',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black54)),
                          ],
                        ),
                      ),
                      if (widget.action == 'edit')
                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddExamModal(
                                action: 'edit',
                                exam: e.value,
                                onSave: (data) {
                                  Navigator.pop(context);
                                  setState(() => _exams[e.key] = data);
                                },
                                onCancel: () => Navigator.pop(context),
                              ),
                            ),
                          ),
                          child: const Text('Edit',
                              style: TextStyle(
                                  color: Color(0xFF094a25), fontSize: 12)),
                        ),
                      GestureDetector(
                        onTap: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              content: const Text('Remove this exam?'),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel')),
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Remove',
                                        style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            setState(() => _exams.removeAt(e.key));
                          }
                        },
                        child: const Icon(Icons.close,
                            size: 16, color: Color(0xFFbc2023)),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 8),
          ],
          if (_exams.isEmpty)
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddExamModal(
                    action: 'add',
                    onSave: (data) {
                      Navigator.pop(context);
                      setState(() => _exams = [data]);
                    },
                    onCancel: () => Navigator.pop(context),
                  ),
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF094a25),
                side: const BorderSide(color: Color(0xFF094a25)),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add An Exam'),
            ),
          const SizedBox(height: 16),

          // Company
          if (_businesses.isNotEmpty) ...[
            _dropdownField(
              'Related Business (optional)',
              _companyPosting,
              _businesses
                  .map((b) => DropdownMenuItem<int>(
                      value: b['id'],
                      child: Text(b['name'] ?? '',
                          style: const TextStyle(fontSize: 13))))
                  .toList(),
              (v) => setState(() => _companyPosting = v),
            ),
          ],

          // Published + Terms
          Row(
            children: [
              Checkbox(
                value: _published,
                activeColor: const Color(0xFF094a25),
                onChanged: (v) => setState(() => _published = v ?? true),
              ),
              const Text('Publish immediately', style: TextStyle(fontSize: 13)),
            ],
          ),
          if (widget.action == 'add') ...[
            Row(
              children: [
                Checkbox(
                  value: _accepted,
                  activeColor: const Color(0xFF094a25),
                  onChanged: (v) => setState(() => _accepted = v ?? false),
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
          const SizedBox(height: 16),

          // Buttons
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
                    side: const BorderSide(color: Color(0xFFbc2023)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontSize: 15)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ─── Image section ────────────────────────────────────────────────────────

  Widget _imageSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('Job Image (optional)'),
          const Text('Ideal size: 300 x 240px',
              style: TextStyle(fontSize: 11, color: Colors.black45)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _imageFile == null && _existingImage == null
                ? _pickImage
                : null,
            child: Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: _imageFile != null
                  ? Stack(children: [
                      ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(_imageFile!,
                              width: double.infinity,
                              height: 140,
                              fit: BoxFit.cover)),
                      Positioned(
                          top: 6,
                          right: 6,
                          child: GestureDetector(
                              onTap: () => setState(() => _imageFile = null),
                              child: _closeBtn())),
                    ])
                  : _existingImage != null
                      ? Stack(children: [
                          ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(_existingImage!,
                                  width: double.infinity,
                                  height: 140,
                                  fit: BoxFit.cover)),
                          Positioned(
                              top: 6,
                              right: 6,
                              child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _existingImage = null),
                                  child: _closeBtn())),
                        ])
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_photo_alternate,
                                  color: Colors.black26, size: 36),
                              const SizedBox(height: 6),
                              TextButton(
                                  onPressed: _pickImage,
                                  child: const Text('Upload Image',
                                      style:
                                          TextStyle(color: Color(0xFF094a25)))),
                            ],
                          ),
                        ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      );

  // ─── Skills form ──────────────────────────────────────────────────────────

  Widget _skillsForm() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: const Color(0xFF094a25).withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fieldLabel('Category'),
            const SizedBox(height: 6),
            _dropdownWidget<int>(
              value: _skillCategory,
              hint: 'Select Category',
              items: _skillCategories
                  .map((s) => DropdownMenuItem<int>(
                      value: s['id'],
                      child: Text(s['name'] ?? '',
                          style: const TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: (v) => setState(() {
                _skillCategory = v;
                _skillSubcategory = null;
                _skillToAdd = null;
              }),
            ),
            if (_skillSubcategories.isNotEmpty) ...[
              const SizedBox(height: 10),
              _fieldLabel('Subcategory'),
              const SizedBox(height: 6),
              _dropdownWidget<int>(
                value: _skillSubcategory,
                hint: 'Select Subcategory',
                items: _skillSubcategories
                    .map((s) => DropdownMenuItem<int>(
                        value: s['id'],
                        child: Text(s['name'] ?? '',
                            style: const TextStyle(fontSize: 13))))
                    .toList(),
                onChanged: (v) => setState(() {
                  _skillSubcategory = v;
                  _skillToAdd = null;
                }),
              ),
            ],
            if (_skillOptions.isNotEmpty) ...[
              const SizedBox(height: 10),
              _fieldLabel('Skill'),
              const SizedBox(height: 6),
              _dropdownWidget<Map<String, dynamic>>(
                value: _skillToAdd,
                hint: 'Select Skill',
                items: _skillOptions
                    .map((s) => DropdownMenuItem<Map<String, dynamic>>(
                        value: Map<String, dynamic>.from(s),
                        child: Text(s['name'] ?? '',
                            style: const TextStyle(fontSize: 13))))
                    .toList(),
                onChanged: (v) => setState(() => _skillToAdd = v),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _addSkill,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF094a25),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8)),
                  child: const Text('Add',
                      style: TextStyle(color: Colors.white, fontSize: 13)),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () => setState(() => _addingSkills = false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFbc2023),
                    side: const BorderSide(color: Color(0xFFbc2023)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  ),
                  child: const Text('Done', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ],
        ),
      );

  // ─── Duty form ────────────────────────────────────────────────────────────

  Widget _dutyForm() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: const Color(0xFF094a25).withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fieldLabel('Title'),
            const SizedBox(height: 6),
            _textField(_dutyTitleController, hint: 'Duty title'),
            const SizedBox(height: 10),
            _fieldLabel('Description'),
            const SizedBox(height: 6),
            _textField(_dutyDescController,
                hint: 'Duty description', maxLines: 2),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _addDuty,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF094a25),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8)),
                  child: const Text('Add',
                      style: TextStyle(color: Colors.white, fontSize: 13)),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () => setState(() => _addingDuty = false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFbc2023),
                    side: const BorderSide(color: Color(0xFFbc2023)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  ),
                  child: const Text('Done', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ],
        ),
      );

  // ─── Question form ────────────────────────────────────────────────────────

  Widget _questionForm() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: const Color(0xFF094a25).withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fieldLabel('Question'),
            const SizedBox(height: 6),
            _textField(_questionTitleController, hint: 'Ask the question'),
            const SizedBox(height: 10),
            _fieldLabel('Description'),
            const SizedBox(height: 6),
            _textField(_questionDescController,
                hint: 'Additional detail', maxLines: 2),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _addQuestion,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF094a25),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8)),
                  child: const Text('Add',
                      style: TextStyle(color: Colors.white, fontSize: 13)),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () => setState(() => _addingQuestion = false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFbc2023),
                    side: const BorderSide(color: Color(0xFFbc2023)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  ),
                  child: const Text('Done', style: TextStyle(fontSize: 13)),
                ),
              ],
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
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black26),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: items.any((i) => i.value == value) ? value : null,
            hint: Text(hint,
                style: const TextStyle(color: Colors.black45, fontSize: 13)),
            isExpanded: true,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
            items: [
              if (!items.any((i) => i.value == null))
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

  Widget _closeBtn() => Container(
        width: 24,
        height: 24,
        decoration:
            const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
        child: const Icon(Icons.close, color: Colors.white, size: 14),
      );
}
