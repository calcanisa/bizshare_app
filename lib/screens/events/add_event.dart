import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';

class AddEventModal extends StatefulWidget {
  final String action; // 'add' or 'edit'
  final Map<String, dynamic>? event;
  final void Function(Map<String, dynamic> data) onSave;
  final VoidCallback onCancel;

  const AddEventModal({
    super.key,
    required this.action,
    this.event,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<AddEventModal> createState() => _AddEventModalState();
}

class _AddEventModalState extends State<AddEventModal> {
  bool _saving = false;
  bool _accepted = false;
  bool _published = true;

  // Flyer
  File? _flyerFile;
  String? _existingFlyer;

  // Controllers
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _pricesFromController = TextEditingController();
  final _pricesToController = TextEditingController();
  final _organizerController = TextEditingController();
  final _organizerPhoneController = TextEditingController();
  final _organizerEmailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _venueSearchController = TextEditingController();

  // Event type
  List<dynamic> _eventTypes = [];
  int? _selectedEventTypeId;

  // Dates
  String _startDate = '';
  String _endDate = '';
  String _startTime = '';
  String _endTime = '';

  // Repeat
  bool _repeats = false;
  bool _repeatMonday = false;
  bool _repeatTuesday = false;
  bool _repeatWednesday = false;
  bool _repeatThursday = false;
  bool _repeatFriday = false;
  bool _repeatSaturday = false;
  bool _repeatSunday = false;

  // Online
  bool _online = false;

  // Venues
  List<dynamic> _venues = [];
  List<Map<String, dynamic>> _selectedVenues = [];

  static const _hours = [
    ('06:00', '06:00'), ('06:30', '06:30'), ('07:00', '07:00'),
    ('07:30', '07:30'), ('08:00', '08:00'), ('08:30', '08:30'),
    ('09:00', '09:00'), ('09:30', '09:30'), ('10:00', '10:00'),
    ('10:30', '10:30'), ('11:00', '11:00'), ('11:30', '11:30'),
    ('12:00', '12:00'), ('12:30', '12:30'), ('13:00', '13:00'),
    ('13:30', '13:30'), ('14:00', '14:00'), ('14:30', '14:30'),
    ('15:00', '15:00'), ('15:30', '15:30'), ('16:00', '16:00'),
    ('16:30', '16:30'), ('17:00', '17:00'), ('17:30', '17:30'),
    ('18:00', '18:00'), ('18:30', '18:30'), ('19:00', '19:00'),
    ('19:30', '19:30'), ('20:00', '20:00'), ('20:30', '20:30'),
    ('21:00', '21:00'), ('22:00', '22:00'), ('23:00', '23:00'),
  ];

  @override
  void initState() {
    super.initState();
    _loadEventTypes();
    _loadVenues();
    if (widget.action == 'edit' && widget.event != null) {
      _populateForm(widget.event!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _pricesFromController.dispose();
    _pricesToController.dispose();
    _organizerController.dispose();
    _organizerPhoneController.dispose();
    _organizerEmailController.dispose();
    _websiteController.dispose();
    _venueSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadEventTypes() async {
    try {
      final api = context.read<ApiService>();
      final res = await api.dio.get('/api/v1/events/types/');
      final data = res.data;
      setState(() =>
          _eventTypes = data is List ? data : (data['results'] ?? []));
    } catch (_) {}
  }

  Future<void> _loadVenues({String search = ''}) async {
    try {
      final api = context.read<ApiService>();
      final params = <String, dynamic>{'page_size': 50};
      if (search.isNotEmpty) params['search'] = search;
      final res = await api.dio
          .get('/api/v1/locations/venues/', queryParameters: params);
      final data = res.data;
      setState(() =>
          _venues = data is List ? data : (data['results'] ?? []));
    } catch (_) {}
  }

  void _populateForm(Map<String, dynamic> e) {
    _nameController.text = e['name'] ?? '';
    _descController.text = e['description'] ?? '';
    _pricesFromController.text = e['prices_from']?.toString() ?? '';
    _pricesToController.text = e['prices_to']?.toString() ?? '';
    _organizerController.text = e['organizer'] ?? '';
    _organizerPhoneController.text = e['organizer_phone']?.toString() ?? '';
    _organizerEmailController.text = e['organizer_email'] ?? '';
    _websiteController.text = e['event_website'] ?? '';
    _existingFlyer = e['flyer'];
    _published = e['published'] ?? true;
    _online = e['online'] ?? false;
    _repeats = e['repeats'] ?? false;
    _repeatMonday = e['repeat_monday'] ?? false;
    _repeatTuesday = e['repeat_tuesday'] ?? false;
    _repeatWednesday = e['repeat_wednesday'] ?? false;
    _repeatThursday = e['repeat_thursday'] ?? false;
    _repeatFriday = e['repeat_friday'] ?? false;
    _repeatSaturday = e['repeat_saturday'] ?? false;
    _repeatSunday = e['repeat_sunday'] ?? false;
    _selectedEventTypeId = (e['event_type'] as Map?)?['id'];

    // Parse dates
    final start = e['start_date']?.toString() ?? '';
    final end = e['end_date']?.toString() ?? '';
    if (start.isNotEmpty) {
      final dt = DateTime.tryParse(start);
      if (dt != null) {
        _startDate = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
        _startTime = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    }
    if (end.isNotEmpty) {
      final dt = DateTime.tryParse(end);
      if (dt != null) {
        _endDate = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
        _endTime = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    }

    _selectedVenues = (e['venues'] as List? ?? [])
        .map((v) => Map<String, dynamic>.from(v as Map))
        .toList();
    _accepted = true;
  }

  Future<void> _pickFlyer() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _flyerFile = File(picked.path));
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      _showSnack('Event name is required');
      return;
    }
    if (_descController.text.trim().isEmpty) {
      _showSnack('Description is required');
      return;
    }
    if (_selectedEventTypeId == null) {
      _showSnack('Event type is required');
      return;
    }
    if (_startDate.isEmpty || _startTime.isEmpty) {
      _showSnack('Start date and time are required');
      return;
    }
    if (_endDate.isEmpty || _endTime.isEmpty) {
      _showSnack('End date and time are required');
      return;
    }
    if (!_online && _selectedVenues.isEmpty) {
      _showSnack('Venue is required for non-online events');
      return;
    }
    if (widget.action == 'add' && !_accepted) {
      _showSnack('You must accept the terms');
      return;
    }

    final startDateTime = '${_startDate}T$_startTime';
    final endDateTime = '${_endDate}T$_endTime';
    final start = DateTime.tryParse(startDateTime);
    final end = DateTime.tryParse(endDateTime);
    if (start != null && end != null && !start.isBefore(end)) {
      _showSnack('Start date must be before end date');
      return;
    }

    setState(() => _saving = true);
    try {
      final api = context.read<ApiService>();
      final formData = FormData();

      formData.fields.addAll([
        MapEntry('name', _nameController.text.trim()),
        MapEntry('description', _descController.text.trim()),
        MapEntry('event_type', _selectedEventTypeId.toString()),
        MapEntry('start_date', startDateTime),
        MapEntry('end_date', endDateTime),
        MapEntry('online', _online.toString()),
        MapEntry('repeats', _repeats.toString()),
        MapEntry('repeat_monday', _repeatMonday.toString()),
        MapEntry('repeat_tuesday', _repeatTuesday.toString()),
        MapEntry('repeat_wednesday', _repeatWednesday.toString()),
        MapEntry('repeat_thursday', _repeatThursday.toString()),
        MapEntry('repeat_friday', _repeatFriday.toString()),
        MapEntry('repeat_saturday', _repeatSaturday.toString()),
        MapEntry('repeat_sunday', _repeatSunday.toString()),
        MapEntry('prices_from', _pricesFromController.text.trim()),
        MapEntry('prices_to', _pricesToController.text.trim()),
        MapEntry('organizer', _organizerController.text.trim()),
        MapEntry('organizer_phone', _organizerPhoneController.text.trim()),
        MapEntry('organizer_email', _organizerEmailController.text.trim()),
        MapEntry('event_website', _websiteController.text.trim()),
        MapEntry('published', _published.toString()),
      ]);

      // Venues
      for (int i = 0; i < _selectedVenues.length; i++) {
        final v = _selectedVenues[i];
        if (v['id'] != null) {
          formData.fields
              .add(MapEntry('venues[$i][id]', v['id'].toString()));
        }
      }

      // Flyer
      if (_flyerFile != null) {
        formData.files.add(MapEntry('flyer',
            await MultipartFile.fromFile(_flyerFile!.path,
                filename: 'flyer.jpg')));
      }

      late Map<String, dynamic> result;
      if (widget.action == 'add') {
        final res = await api.dio
            .post('/api/v1/events/event/c/', data: formData);
        result = res.data;
      } else {
        final id = widget.event!['id'];
        final res = await api.dio
            .put('/api/v1/events/event/$id/u/', data: formData);
        result = res.data;
      }
      widget.onSave(result);
    } catch (_) {
      _showSnack('Failed to save event. Please try again.');
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
          widget.action == 'edit' ? 'Edit Event' : 'Add Event',
          style: const TextStyle(color: Colors.white, fontSize: 15),
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
          // Note
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF094a25).withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'If you do not add a ticket price, the event is presumed free of charge.',
              style: TextStyle(
                  fontSize: 12, color: Colors.black54, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),

          // Flyer
          _flyerSection(),
          const SizedBox(height: 20),

          // Name
          _fieldLabel('Event Name *'),
          const SizedBox(height: 6),
          _textField(_nameController,
              hint: 'Event name (max 100 characters)',
              maxLength: 100),
          const SizedBox(height: 16),

          // Event type
          _fieldLabel('Event Type *'),
          const SizedBox(height: 6),
          _dropdownWidget<int>(
            value: _selectedEventTypeId,
            hint: 'Choose Category',
            items: _eventTypes
                .map((t) => DropdownMenuItem<int>(
                      value: t['id'],
                      child: Text(t['name'] ?? '',
                          style: const TextStyle(fontSize: 13)),
                    ))
                .toList(),
            onChanged: (v) =>
                setState(() => _selectedEventTypeId = v),
          ),
          const SizedBox(height: 16),

          // Online
          Row(
            children: [
              Checkbox(
                value: _online,
                activeColor: const Color(0xFF094a25),
                onChanged: (v) =>
                    setState(() => _online = v ?? false),
              ),
              const Text('Online Event',
                  style: TextStyle(fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),

          // Description
          _fieldLabel('Event Description *'),
          const SizedBox(height: 6),
          _textField(_descController,
              hint: 'Max 3000 characters',
              maxLines: 5,
              maxLength: 3000),
          const SizedBox(height: 16),

          // Dates
          _sectionHeader('Event Dates *'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _dateField('Start Date', _startDate,
                      (v) => setState(() => _startDate = v))),
              const SizedBox(width: 8),
              Expanded(
                  child: _dateField('End Date', _endDate,
                      (v) => setState(() => _endDate = v))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _timeField('Start Time', _startTime,
                      (v) => setState(() => _startTime = v))),
              const SizedBox(width: 8),
              Expanded(
                  child: _timeField('End Time', _endTime,
                      (v) => setState(() => _endTime = v))),
            ],
          ),
          const SizedBox(height: 16),

          // Repeats
          Row(
            children: [
              Checkbox(
                value: _repeats,
                activeColor: const Color(0xFF094a25),
                onChanged: (v) =>
                    setState(() => _repeats = v ?? false),
              ),
              const Text('Does this event repeat?',
                  style: TextStyle(fontSize: 13)),
            ],
          ),
          if (_repeats) ...[
            const SizedBox(height: 8),
            _sectionHeader('Repeat Days'),
            const SizedBox(height: 8),
            _repeatDays(),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),

          // Ticket prices
          _sectionHeader('Ticket Prices'),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('From: R',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Expanded(
                  child: _textField(_pricesFromController,
                      hint: 'Price',
                      keyboardType: TextInputType.number)),
              const SizedBox(width: 16),
              const Text('To: R',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Expanded(
                  child: _textField(_pricesToController,
                      hint: 'Price',
                      keyboardType: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 16),

          // Organizer
          _sectionHeader('Event Organizer *'),
          const SizedBox(height: 12),
          _fieldLabel('Name'),
          const SizedBox(height: 6),
          _textField(_organizerController,
              hint: 'Company or person'),
          const SizedBox(height: 10),
          _fieldLabel('Phone'),
          const SizedBox(height: 6),
          _textField(_organizerPhoneController,
              hint: 'Phone',
              keyboardType: TextInputType.phone,
              maxLength: 10),
          const SizedBox(height: 10),
          _fieldLabel('Email'),
          const SizedBox(height: 6),
          _textField(_organizerEmailController,
              hint: 'Email',
              keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 16),

          // Website
          _fieldLabel('Event Website'),
          const SizedBox(height: 6),
          _textField(_websiteController,
              hint: 'Website URL',
              keyboardType: TextInputType.url),
          const SizedBox(height: 16),

          // Venues
          if (!_online) ...[
            _sectionHeader('Venues'),
            const SizedBox(height: 10),
            _venuesSection(),
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
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF094a25),
                    disabledBackgroundColor:
                        Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2))
                      : Text(
                          widget.action == 'edit'
                              ? 'Save'
                              : 'Add Event',
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
                    side: const BorderSide(
                        color: Color(0xFFbc2023)),
                    padding: const EdgeInsets.symmetric(
                        vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
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

  // ─── Flyer section ────────────────────────────────────────────────────────

  Widget _flyerSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('Event Flyer'),
          const Text('Ideal size: 480 x 640px',
              style:
                  TextStyle(fontSize: 11, color: Colors.black45)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _flyerFile == null && _existingFlyer == null
                ? _pickFlyer
                : null,
            child: Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: Colors.grey.shade300),
              ),
              child: _flyerFile != null
                  ? Stack(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(_flyerFile!,
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _flyerFile = null),
                          child: _closeBtn(),
                        ),
                      ),
                    ])
                  : _existingFlyer != null
                      ? Stack(children: [
                          ClipRRect(
                            borderRadius:
                                BorderRadius.circular(8),
                            child: Image.network(_existingFlyer!,
                                width: double.infinity,
                                height: 200,
                                fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: GestureDetector(
                              onTap: () => setState(
                                  () => _existingFlyer = null),
                              child: _closeBtn(),
                            ),
                          ),
                        ])
                      : Center(
                          child: Column(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_photo_alternate,
                                  color: Colors.black26, size: 36),
                              const SizedBox(height: 6),
                              const Text('Upload Flyer',
                                  style: TextStyle(
                                      color: Colors.black38,
                                      fontSize: 12)),
                              TextButton(
                                onPressed: _pickFlyer,
                                child: const Text('Choose Image',
                                    style: TextStyle(
                                        color: Color(0xFF094a25))),
                              ),
                            ],
                          ),
                        ),
            ),
          ),
        ],
      );

  // ─── Repeat days ──────────────────────────────────────────────────────────

  Widget _repeatDays() {
    final days = [
      ('Monday', _repeatMonday,
          (v) => setState(() => _repeatMonday = v)),
      ('Tuesday', _repeatTuesday,
          (v) => setState(() => _repeatTuesday = v)),
      ('Wednesday', _repeatWednesday,
          (v) => setState(() => _repeatWednesday = v)),
      ('Thursday', _repeatThursday,
          (v) => setState(() => _repeatThursday = v)),
      ('Friday', _repeatFriday,
          (v) => setState(() => _repeatFriday = v)),
      ('Saturday', _repeatSaturday,
          (v) => setState(() => _repeatSaturday = v)),
      ('Sunday', _repeatSunday,
          (v) => setState(() => _repeatSunday = v)),
    ];
    return Column(
      children: days.map((d) {
        return Row(
          children: [
            Checkbox(
              value: d.$2,
              activeColor: const Color(0xFF094a25),
              onChanged: (v) => d.$3(v ?? false),
            ),
            Text(d.$1,
                style: const TextStyle(fontSize: 13)),
          ],
        );
      }).toList(),
    );
  }

  // ─── Venues section ───────────────────────────────────────────────────────

  Widget _venuesSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search
          TextField(
            controller: _venueSearchController,
            onChanged: (v) => _loadVenues(search: v),
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search venues',
              prefixIcon: const Icon(Icons.search,
                  size: 18, color: Colors.black45),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),

          // Venue list
          if (_venues.isNotEmpty)
            Container(
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                itemCount: _venues.length,
                itemBuilder: (ctx, i) {
                  final v = _venues[i] as Map<String, dynamic>;
                  final isSelected = _selectedVenues
                      .any((s) => s['id'] == v['id']);
                  final city = v['city'] as Map?;
                  final area = v['area'] as Map?;
                  final location = area?['city']?['name'] ??
                      city?['name'] ??
                      '';
                  return ListTile(
                    dense: true,
                    title: Text(v['name'] ?? '',
                        style: TextStyle(
                            fontSize: 13,
                            color: isSelected
                                ? const Color(0xFF094a25)
                                : Colors.black87,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal)),
                    subtitle: location.isNotEmpty
                        ? Text('in $location',
                            style: const TextStyle(
                                fontSize: 11))
                        : null,
                    trailing: isSelected
                        ? const Icon(Icons.check,
                            color: Color(0xFF094a25), size: 18)
                        : null,
                    onTap: () {
                      if (!isSelected) {
                        setState(() => _selectedVenues
                            .add(Map<String, dynamic>.from(v)));
                      }
                    },
                  );
                },
              ),
            ),

          // Selected venues
          if (_selectedVenues.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('Selected Venues:',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF094a25))),
            const SizedBox(height: 6),
            ..._selectedVenues.asMap().entries.map((e) {
              final v = e.value;
              final city = v['city'] as Map?;
              final area = v['area'] as Map?;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(v['name'] ?? '',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight:
                                      FontWeight.bold,
                                  color:
                                      Color(0xFF094a25))),
                          if (v['street'] != null)
                            Text(v['street'],
                                style: const TextStyle(
                                    fontSize: 11,
                                    color:
                                        Colors.black54)),
                          if (city != null)
                            Text(city['name'] ?? '',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color:
                                        Colors.black54)),
                          if (area != null)
                            Text(area['name'] ?? '',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color:
                                        Colors.black54)),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() =>
                          _selectedVenues.removeAt(e.key)),
                      child: const Text('Remove',
                          style: TextStyle(
                              color: Color(0xFFbc2023),
                              fontSize: 12)),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      );

  // ─── Helpers ──────────────────────────────────────────────────────────────

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

  Widget _dateField(
    String label,
    String value,
    void Function(String) onChanged,
  ) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: Colors.black54)),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: value.isNotEmpty
                    ? DateTime.tryParse(value) ?? now
                    : now,
                firstDate: now,
                lastDate:
                    now.add(const Duration(days: 365 * 5)),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: const ColorScheme.light(
                        primary: Color(0xFF094a25)),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) {
                onChanged(picked.toIso8601String().split('T')[0]);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value.isEmpty ? 'Select date' : value,
                      style: TextStyle(
                          fontSize: 13,
                          color: value.isEmpty
                              ? Colors.black45
                              : Colors.black87),
                    ),
                  ),
                  const Icon(Icons.calendar_today,
                      size: 14, color: Colors.black45),
                ],
              ),
            ),
          ),
        ],
      );

  Widget _timeField(
    String label,
    String value,
    void Function(String) onChanged,
  ) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: Colors.black54)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black26),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value.isEmpty ? null : value,
                hint: const Text('Choose',
                    style: TextStyle(
                        color: Colors.black45, fontSize: 12)),
                isExpanded: true,
                isDense: true,
                style: const TextStyle(
                    fontSize: 12, color: Colors.black87),
                items: _hours
                    .map((h) => DropdownMenuItem(
                        value: h.$1,
                        child: Text(h.$2,
                            style: const TextStyle(
                                fontSize: 12))))
                    .toList(),
                onChanged: (v) {
                  if (v != null) onChanged(v);
                },
              ),
            ),
          ),
        ],
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