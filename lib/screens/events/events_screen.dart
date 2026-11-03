import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../widgets/filter_chip_bar.dart';
import '../events/event_screen.dart';
import '../events/add_event.dart';
import '../feature_content.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  int _tab = 1;

  // Tab 1 - My Events
  List<dynamic> _myEvents = [];
  bool _loadingMine = false;

  // Tab 2 - All Events
  List<dynamic> _provinces = [];
  List<dynamic> _cities = [];
  List<dynamic> _eventTypes = [];
  List<dynamic> _events = [];
  bool _loadingAll = false;
  bool _hasMore = false;
  int _currentPage = 1;
  int _totalCount = 0;
  int? _selectedProvince;
  final ScrollController _scrollController = ScrollController();

  // Filter state
  int? _filterCity;
  int? _filterEventType;
  String? _filterDateFrom;
  String? _filterDateTo;

  // Temp filter state
  int? _tempCity;
  int? _tempEventType;
  final TextEditingController _dateFromController = TextEditingController();
  final TextEditingController _dateToController = TextEditingController();

  bool get _hasActiveFilters =>
      _filterCity != null ||
      _filterEventType != null ||
      _filterDateFrom != null ||
      _filterDateTo != null;

  @override
  void initState() {
    super.initState();
    _loadMyEvents();
    _loadProvinces();
    _loadEventTypes();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        if (!_loadingAll && _hasMore) _loadMoreEvents();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _dateFromController.dispose();
    _dateToController.dispose();
    super.dispose();
  }

  Future<void> _loadMyEvents() async {
    setState(() => _loadingMine = true);
    try {
      final api = context.read<ApiService>();
      final response = await api.dio.get('/api/v1/events/user/current/');
      setState(() => _myEvents = response.data ?? []);
    } catch (_) {}
    setState(() => _loadingMine = false);
  }

  Future<void> _loadProvinces() async {
    try {
      final api = context.read<ApiService>();
      final response = await api.dio.get('/api/v1/locations/provinces/');
      final data = response.data;
      setState(
          () => _provinces = data is List ? data : (data['results'] ?? []));
    } catch (_) {}
  }

  Future<void> _loadCities(int provinceId) async {
    try {
      final api = context.read<ApiService>();
      final response =
          await api.dio.get('/api/v1/locations/cities/$provinceId/');
      final data = response.data;
      setState(() => _cities = data is List ? data : (data['results'] ?? []));
    } catch (_) {}
  }

  Future<void> _loadEventTypes() async {
    try {
      final api = context.read<ApiService>();
      final response = await api.dio.get('/api/v1/events/types/');
      final data = response.data;
      setState(
          () => _eventTypes = data is List ? data : (data['results'] ?? []));
    } catch (_) {}
  }

  Future<void> _loadEvents({bool refresh = false}) async {
    if (_loadingAll || _selectedProvince == null) return;
    if (refresh) {
      setState(() {
        _events = [];
        _currentPage = 1;
        _hasMore = false;
        _totalCount = 0;
      });
    }
    setState(() => _loadingAll = true);
    try {
      final api = context.read<ApiService>();
      final params = <String, dynamic>{
        'page': _currentPage,
        'province': _selectedProvince,
      };
      if (_filterCity != null) params['city'] = _filterCity;
      if (_filterEventType != null) params['event_type'] = _filterEventType;
      if (_filterDateFrom != null) params['event_from'] = _filterDateFrom;
      if (_filterDateTo != null) params['event_to'] = _filterDateTo;

      final response =
          await api.dio.get('/api/v1/events', queryParameters: params);
      final results = response.data['results'] as List? ?? [];
      setState(() {
        _events.addAll(results);
        _currentPage++;
        _hasMore = response.data['next'] != null;
        _totalCount = response.data['count'] ?? 0;
      });
    } catch (_) {}
    setState(() => _loadingAll = false);
  }

  Future<void> _loadMoreEvents() async => await _loadEvents();

  Future<void> _deleteEvent(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: const Text(
            'Are you sure you want to delete this event? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final api = context.read<ApiService>();
      await api.dio.delete('/api/v1/events/event/$id/d/');
      setState(() => _myEvents.removeWhere((e) => e['id'] == id));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Event deleted')));
      }
    } catch (_) {}
  }

  void _openAddEvent() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEventModal(
          action: 'add',
          onSave: (data) {
            Navigator.pop(context);
            setState(() => _myEvents.insert(0, data));
          },
          onCancel: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _openEditEvent(Map<String, dynamic> event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEventModal(
          action: 'edit',
          event: event,
          onSave: (data) {
            Navigator.pop(context);
            final i = _myEvents.indexWhere((e) => e['id'] == data['id']);
            if (i != -1) setState(() => _myEvents[i] = data);
          },
          onCancel: () => Navigator.pop(context),
        ),
      ),
    );
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return '';
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${date.day} ${months[date.month]} ${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _openFilterSheet() async {
    _tempCity = _filterCity;
    _tempEventType = _filterEventType;
    _dateFromController.text = _filterDateFrom ?? '';
    _dateToController.text = _filterDateTo ?? '';

    if (_selectedProvince != null && _cities.isEmpty) {
      await _loadCities(_selectedProvince!);
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => _buildFilterSheet(),
    );
  }

  Widget _buildFilterSheet() {
    return StatefulBuilder(
      builder: (context, setSheetState) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          maxChildSize: 0.85,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1B4748),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      const Text('Filter Events',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _filterCity = null;
                            _filterEventType = null;
                            _filterDateFrom = null;
                            _filterDateTo = null;
                            _tempCity = null;
                            _tempEventType = null;
                            _dateFromController.clear();
                            _dateToController.clear();
                          });
                          Navigator.pop(context);
                          _loadEvents(refresh: true);
                        },
                        child: const Text('Reset',
                            style: TextStyle(color: Color(0xFFF8BB25))),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_cities.isNotEmpty) ...[
                        _filterLabel('City'),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black26),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          constraints: const BoxConstraints(maxHeight: 160),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _cities.length + 1,
                            itemBuilder: (context, i) {
                              if (i == 0) {
                                return ListTile(
                                  dense: true,
                                  title: const Text('All Cities',
                                      style: TextStyle(
                                          color: Colors.black45, fontSize: 13)),
                                  selected: _tempCity == null,
                                  selectedTileColor: const Color(0xFF1B4748)
                                      .withValues(alpha: 0.1),
                                  onTap: () =>
                                      setSheetState(() => _tempCity = null),
                                );
                              }
                              final city = _cities[i - 1];
                              return ListTile(
                                dense: true,
                                title: Text(city['name'] ?? '',
                                    style: const TextStyle(fontSize: 13)),
                                selected: _tempCity == city['id'],
                                selectedColor: const Color(0xFF1B4748),
                                selectedTileColor: const Color(0xFF1B4748)
                                    .withValues(alpha: 0.1),
                                onTap: () =>
                                    setSheetState(() => _tempCity = city['id']),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_eventTypes.isNotEmpty) ...[
                        _filterLabel('Event Type'),
                        _filterDropdown<int>(
                          value: _tempEventType,
                          hint: 'All Types',
                          items: _eventTypes
                              .map((t) => DropdownMenuItem<int>(
                                    value: t['id'],
                                    child: Text(t['name'] ?? ''),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setSheetState(() => _tempEventType = v),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _filterLabel('Date From'),
                      TextField(
                        controller: _dateFromController,
                        readOnly: true,
                        decoration: InputDecoration(
                          hintText: 'Select date',
                          suffixIcon:
                              const Icon(Icons.calendar_today, size: 18),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (date != null) {
                            setSheetState(() {
                              _dateFromController.text =
                                  date.toIso8601String().split('T')[0];
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      _filterLabel('Date To'),
                      TextField(
                        controller: _dateToController,
                        readOnly: true,
                        decoration: InputDecoration(
                          hintText: 'Select date',
                          suffixIcon:
                              const Icon(Icons.calendar_today, size: 18),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (date != null) {
                            setSheetState(() {
                              _dateToController.text =
                                  date.toIso8601String().split('T')[0];
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _filterCity = _tempCity;
                          _filterEventType = _tempEventType;
                          _filterDateFrom = _dateFromController.text.isNotEmpty
                              ? _dateFromController.text
                              : null;
                          _filterDateTo = _dateToController.text.isNotEmpty
                              ? _dateToController.text
                              : null;
                        });
                        Navigator.pop(context);
                        _loadEvents(refresh: true);
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B4748),
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('Apply Filters',
                          style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _filterLabel(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B4748),
                fontSize: 13)),
      );

  Widget _filterDropdown<T>({
    required T? value,
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
            hint: Text(hint, style: const TextStyle(color: Colors.black45)),
            isExpanded: true,
            items: [
              DropdownMenuItem<T>(
                value: null,
                child:
                    Text(hint, style: const TextStyle(color: Colors.black45)),
              ),
              ...items,
            ],
            onChanged: onChanged,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: const Color(0xFF1B4748),
          child: Row(
            children: [
              _tabBtn(1, 'My Events'),
              _tabBtn(2, 'All Events'),
            ],
          ),
        ),
        Expanded(
          child: _tab == 1 ? _myEventsTab() : _allEventsTab(),
        ),
      ],
    );
  }

  Widget _tabBtn(int index, String label) {
    final active = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          color: active ? Colors.white : const Color(0xFF1B4748),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: active ? const Color(0xFF1B4748) : Colors.white60,
                fontSize: 13,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              )),
        ),
      ),
    );
  }

  Widget _myEventsTab() {
    if (_loadingMine) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF1B4748)));
    }

    final currentEvents =
        _myEvents.where((e) => e['is_current'] == true).toList();
    final pastEvents = _myEvents.where((e) => e['is_current'] != true).toList();

    if (_myEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('You have not created any events.',
                style: TextStyle(color: Color(0xFF1B4748))),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _openAddEvent,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B4748)),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Create Event',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMyEvents,
      color: const Color(0xFF1B4748),
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: ElevatedButton.icon(
              onPressed: _openAddEvent,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B4748),
                  minimumSize: const Size(double.infinity, 44)),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Create New Event',
                  style: TextStyle(color: Colors.white)),
            ),
          ),
          if (currentEvents.isNotEmpty) ...[
            _listHeader('Current Events'),
            ...currentEvents.map((e) => _myEventCard(e)),
          ],
          if (pastEvents.isNotEmpty) ...[
            _listHeader('Past Events'),
            ...pastEvents.map((e) => _myEventCard(e, past: true)),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _listHeader(String title) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: const Color(0xFF1B4748),
        margin: const EdgeInsets.only(bottom: 4),
        child: Text(title,
            style: const TextStyle(
                color: Color(0xFFF8BB25), fontWeight: FontWeight.bold)),
      );

  Widget _myEventCard(Map<String, dynamic> event, {bool past = false}) {
    final name = event['name'] ?? '';
    final flyer = event['flyer'];
    final startDate = event['start_date'];
    final endDate = event['end_date'];
    final repeats = event['repeats'] ?? false;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EventDetailScreen(eventId: event['id']),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: past ? Colors.grey.shade100 : Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
              child: flyer != null && flyer.toString().isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: flyer,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                          height: 160, color: const Color(0xFF1B4748)))
                  : Container(height: 120, color: const Color(0xFF1B4748)),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B4748))),
                  const SizedBox(height: 6),
                  _eventDetail('Starts', _formatDateTime(startDate)),
                  _eventDetail('Ends', _formatDateTime(endDate)),
                  if (!past) _eventDetail('Repeats', repeats ? 'Yes' : 'No'),
                  if (!past) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _openEditEvent(event),
                            style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF1B4748),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4)),
                            child: const Text('Edit',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FeatureScreen(
                                    type: 'event',
                                    item: event,
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF8BB25),
                                foregroundColor: Colors.black87,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4)),
                            child: const Text('Feature',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _deleteEvent(event['id']),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF48900),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4)),
                            child: const Text('Delete',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _eventDetail(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text('$label: ',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B4748),
                  fontSize: 12)),
          Text(value,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _allEventsTab() {
    return Column(
      children: [
        // Province selector
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: _provinces.length,
                    itemBuilder: (context, index) {
                      final prov = _provinces[index];
                      final isSelected = _selectedProvince == prov['id'];
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedProvince = prov['id'];
                            _events = [];
                            _currentPage = 1;
                            _filterCity = null;
                            _cities = [];
                          });
                          _loadCities(prov['id']);
                          _loadEvents(refresh: true);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF1B4748)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: const Color(0xFF1B4748), width: 1),
                          ),
                          child: Text(prov['name'] ?? '',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF1B4748))),
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (_selectedProvince != null)
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.tune, color: Color(0xFF1B4748)),
                      onPressed: _openFilterSheet,
                    ),
                    if (_hasActiveFilters)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF48900),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
        // Active filter chips
        if (_hasActiveFilters)
          Container(
            height: 40,
            color: Colors.grey.shade50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              children: [
                if (_filterCity != null)
                  ActiveFilterChip(
                    label: _cities.firstWhere((c) => c['id'] == _filterCity,
                            orElse: () => {'name': 'City'})['name'] ??
                        '',
                    onRemove: () {
                      setState(() => _filterCity = null);
                      _loadEvents(refresh: true);
                    },
                  ),
                if (_filterEventType != null)
                  ActiveFilterChip(
                    label: _eventTypes.firstWhere(
                            (t) => t['id'] == _filterEventType,
                            orElse: () => {'name': 'Type'})['name'] ??
                        '',
                    onRemove: () {
                      setState(() => _filterEventType = null);
                      _loadEvents(refresh: true);
                    },
                  ),
                if (_filterDateFrom != null)
                  ActiveFilterChip(
                    label: 'From: $_filterDateFrom',
                    onRemove: () {
                      setState(() => _filterDateFrom = null);
                      _loadEvents(refresh: true);
                    },
                  ),
                if (_filterDateTo != null)
                  ActiveFilterChip(
                    label: 'To: $_filterDateTo',
                    onRemove: () {
                      setState(() => _filterDateTo = null);
                      _loadEvents(refresh: true);
                    },
                  ),
              ],
            ),
          ),
        if (_totalCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: Colors.grey.shade50,
            child: Text('$_totalCount events found',
                style: const TextStyle(fontSize: 12, color: Colors.black45)),
          ),
        Expanded(
          child: _selectedProvince == null
              ? const Center(
                  child: Text('Select a province above to start',
                      style: TextStyle(color: Color(0xFF1B4748))))
              : _loadingAll && _events.isEmpty
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF1B4748)))
                  : _events.isEmpty
                      ? const Center(
                          child: Text('No events found',
                              style: TextStyle(color: Color(0xFF1B4748))))
                      : RefreshIndicator(
                          onRefresh: () => _loadEvents(refresh: true),
                          color: const Color(0xFF1B4748),
                          child: ListView.builder(
                            controller: _scrollController,
                            itemCount: _events.length + (_hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _events.length) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(
                                        color: Color(0xFF1B4748)),
                                  ),
                                );
                              }
                              return _eventCard(_events[index]);
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _eventCard(Map<String, dynamic> event) {
    final name = event['name'] ?? '';
    final flyer = event['flyer'];
    final description = event['description'] ?? '';
    final startDate = event['start_date'];
    final endDate = event['end_date'];
    final venues = event['venues'] as List? ?? [];
    String location = '';
    if (venues.isNotEmpty) {
      final venue = venues[0];
      if (venue['area'] != null) {
        location =
            '${venue['area']['city']['name']} / ${venue['area']['name']}';
      } else if (venue['city'] != null) {
        location = venue['city']['name'] ?? '';
      }
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EventDetailScreen(eventId: event['id']),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: flyer != null && flyer.toString().isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: flyer,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _imagePlaceholder())
                    : _imagePlaceholder(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B4748))),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description.length > 100
                            ? '${description.substring(0, 100)}...'
                            : description,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54),
                      ),
                    ],
                    const SizedBox(height: 4),
                    _eventDetail('Starts', _formatDateTime(startDate)),
                    _eventDetail('Ends', _formatDateTime(endDate)),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 12, color: Colors.black45),
                          const SizedBox(width: 2),
                          Text(location,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.black45)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.black26),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imagePlaceholder() => Container(
        width: 80,
        height: 80,
        color: const Color(0xFF1B4748).withValues(alpha: 0.1),
        child: const Icon(Icons.event_outlined,
            color: Color(0xFF1B4748), size: 32),
      );
}
