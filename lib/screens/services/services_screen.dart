import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  int _tab = 1;

  // Tab 1 — All Services
  List<dynamic> _services = [];
  bool _loadingServices = false;
  int _currentPage = 1;
  int _totalCount = 0;
  bool _hasNext = false;
  bool _hasPrev = false;
  int _selectedPageSize = 20;
  String _ordering = 'date-last';

  // Tab 2 — Your Requests
  List<dynamic> _requests = [];
  bool _loadingRequests = false;

  // Service types for filter
  List<dynamic> _serviceTypes = [];

  // Applied filters
  int? _filterService;
  String _filterMinRate = '';
  String _filterMaxRate = '';
  String? _filterInterval;

  // Temp filter state (in-sheet)
  int? _tempService;
  String? _tempInterval;
  final _minRateController = TextEditingController();
  final _maxRateController = TextEditingController();

  bool get _hasActiveFilters =>
      _filterService != null ||
      _filterMinRate.isNotEmpty ||
      _filterMaxRate.isNotEmpty ||
      _filterInterval != null;

  static const _intervalOptions = [
    ('hour', 'Per Hour'),
    ('day', 'Per Day'),
    ('week', 'Per Week'),
    ('month', 'Per Month'),
    ('year', 'Per Year'),
    ('project', 'Per Project'),
  ];

  String _intervalLabel(String? val) {
    if (val == null) return '';
    return _intervalOptions
        .firstWhere((o) => o.$1 == val, orElse: () => ('', ''))
        .$2;
  }

  @override
  void initState() {
    super.initState();
    _loadServiceTypes();
    _fetchServices(page: 1);
  }

  @override
  void dispose() {
    _minRateController.dispose();
    _maxRateController.dispose();
    super.dispose();
  }

  Future<void> _loadServiceTypes() async {
    if (_serviceTypes.isNotEmpty) return;
    try {
      final api = context.read<ApiService>();
      final res = await api.dio.get('/api/v1/directory/business/services/');
      final data = res.data;
      setState(
          () => _serviceTypes = data is List ? data : (data['results'] ?? []));
    } catch (_) {}
  }

  Future<void> _fetchServices({int page = 1}) async {
    if (_loadingServices) return;
    setState(() => _loadingServices = true);
    try {
      final api = context.read<ApiService>();
      final params = <String, dynamic>{
        'ordering': _ordering,
        'page_size': _selectedPageSize,
      };
      if (page > 1) params['page'] = page;
      if (_filterService != null) params['category'] = _filterService;
      if (_filterMinRate.isNotEmpty) params['min_rate'] = _filterMinRate;
      if (_filterMaxRate.isNotEmpty) params['max_rate'] = _filterMaxRate;
      if (_filterInterval != null) params['interval'] = _filterInterval;

      final res = await api.dio
          .get('/api/v1/directory/services/', queryParameters: params);
      final data = res.data;
      setState(() {
        _services = data['results'] as List? ?? [];
        _totalCount = data['count'] ?? 0;
        _hasNext = data['next'] != null;
        _hasPrev = data['previous'] != null;
        _currentPage = page;
      });
    } catch (_) {
      _showSnack('Could not load services. Try again.');
    }
    setState(() => _loadingServices = false);
  }

  Future<void> _loadRequests() async {
    if (_requests.isNotEmpty) return;
    setState(() => _loadingRequests = true);
    try {
      final api = context.read<ApiService>();
      final res =
          await api.dio.get('/api/v1/directory/business/requests/current/');
      final data = res.data;
      final all = data is List ? data : (data['results'] ?? []);
      // Only service requests (have service field)
      setState(() => _requests =
          (all as List).where((r) => r['service'] != null).toList());
    } catch (_) {
      _showSnack('Could not load requests. Try again.');
    }
    setState(() => _loadingRequests = false);
  }

  Future<void> _deleteRequest(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Request'),
        content: const Text(
            'Are you sure you want to delete this request? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final api = context.read<ApiService>();
      await api.dio.delete('/api/v1/directory/business/lead/$id/d/');
      setState(() => _requests.removeWhere((r) => r['id'] == id));
      _showSnack('Request deleted');
    } catch (_) {
      _showSnack('Could not delete request. Try again.');
    }
  }

  void _openFilterSheet() async {
    await _loadServiceTypes();
    _tempService = _filterService;
    _tempInterval = _filterInterval;
    _minRateController.text = _filterMinRate;
    _maxRateController.text = _filterMaxRate;

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
          initialChildSize: 0.75,
          maxChildSize: 0.92,
          minChildSize: 0.4,
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
                      const Text('Filter Services',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setSheetState(() {
                          _tempService = null;
                          _tempInterval = null;
                          _minRateController.clear();
                          _maxRateController.clear();
                        }),
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
                      // Service type
                      _filterLabel('Service Type'),
                      _filterDropdown<int>(
                        value: _tempService,
                        hint: 'All Services',
                        items: _serviceTypes
                            .map((s) => DropdownMenuItem<int>(
                                  value: s['id'],
                                  child: Text(s['name'] ?? ''),
                                ))
                            .toList(),
                        onChanged: (v) => setSheetState(() => _tempService = v),
                      ),
                      const SizedBox(height: 16),

                      // Rate range
                      _filterLabel('Rate Range'),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _minRateController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: 'Min (R)',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text('—',
                                style: TextStyle(color: Color(0xFF1B4748))),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _maxRateController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: 'Max (R)',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Interval
                      _filterLabel('Rate Interval'),
                      _filterDropdown<String>(
                        value: _tempInterval,
                        hint: 'All Intervals',
                        items: _intervalOptions
                            .map((o) => DropdownMenuItem<String>(
                                  value: o.$1,
                                  child: Text(o.$2),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setSheetState(() => _tempInterval = v),
                      ),
                      const SizedBox(height: 8),
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
                          _filterService = _tempService;
                          _filterInterval = _tempInterval;
                          _filterMinRate = _minRateController.text.trim();
                          _filterMaxRate = _maxRateController.text.trim();
                        });
                        Navigator.pop(context);
                        _fetchServices(page: 1);
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
                  child: Text(hint,
                      style: const TextStyle(color: Colors.black45))),
              ...items,
            ],
            onChanged: onChanged,
          ),
        ),
      );

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: const Color(0xFF1B4748),
          child: Row(
            children: [
              _tabBtn(1, 'Browse Services'),
              _tabBtn(2, 'Your Requests'),
            ],
          ),
        ),
        Expanded(
          child: _tab == 1 ? _browseTab() : _requestsTab(),
        ),
      ],
    );
  }

  Widget _tabBtn(int index, String label) {
    final active = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _tab = index);
          if (index == 2) _loadRequests();
        },
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

  // ─── Tab 1 — Browse Services ─────────────────────────────────────────────

  Widget _browseTab() {
    return Column(
      children: [
        // Controls bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
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
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _ordering,
                    isDense: true,
                    style:
                        const TextStyle(fontSize: 12, color: Color(0xFF1B4748)),
                    items: const [
                      DropdownMenuItem(
                          value: 'date-last', child: Text('Newest First')),
                      DropdownMenuItem(
                          value: 'date-first', child: Text('Oldest First')),
                      DropdownMenuItem(
                          value: 'title-asc', child: Text('Title A-Z')),
                      DropdownMenuItem(
                          value: 'title-des', child: Text('Title Z-A')),
                      DropdownMenuItem(
                          value: 'price-low', child: Text('Rate Low–High')),
                      DropdownMenuItem(
                          value: 'price-high', child: Text('Rate High–Low')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _ordering = v);
                      _fetchServices(page: 1);
                    },
                  ),
                ),
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
                if (_filterService != null)
                  _activeChip(
                    _serviceTypes.firstWhere((s) => s['id'] == _filterService,
                            orElse: () => {'name': 'Service'})['name'] ??
                        '',
                    () {
                      setState(() => _filterService = null);
                      _fetchServices(page: 1);
                    },
                  ),
                if (_filterMinRate.isNotEmpty)
                  _activeChip('Min: R$_filterMinRate', () {
                    setState(() => _filterMinRate = '');
                    _fetchServices(page: 1);
                  }),
                if (_filterMaxRate.isNotEmpty)
                  _activeChip('Max: R$_filterMaxRate', () {
                    setState(() => _filterMaxRate = '');
                    _fetchServices(page: 1);
                  }),
                if (_filterInterval != null)
                  _activeChip(
                    _intervalLabel(_filterInterval),
                    () {
                      setState(() => _filterInterval = null);
                      _fetchServices(page: 1);
                    },
                  ),
              ],
            ),
          ),

        // Count + page size
        if (_totalCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            color: Colors.grey.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$_totalCount services found',
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black45)),
                Row(
                  children: [
                    const Text('Show: ',
                        style: TextStyle(fontSize: 12, color: Colors.black45)),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedPageSize,
                        isDense: true,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF1B4748)),
                        items: [20, 50, 100]
                            .map((s) =>
                                DropdownMenuItem(value: s, child: Text('$s')))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _selectedPageSize = v);
                          _fetchServices(page: 1);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

        // Content
        Expanded(
          child: _loadingServices
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF1B4748)))
              : _services.isEmpty
                  ? const Center(
                      child: Text('No services found',
                          style: TextStyle(color: Color(0xFF1B4748))))
                  : RefreshIndicator(
                      onRefresh: () => _fetchServices(page: 1),
                      color: const Color(0xFF1B4748),
                      child: ListView.builder(
                        itemCount: _services.length + 1,
                        itemBuilder: (context, index) {
                          if (index == _services.length) {
                            return _paginationBar();
                          }
                          return _serviceCard(
                              _services[index] as Map<String, dynamic>);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _serviceCard(Map<String, dynamic> service) {
    final serviceType = service['service'] as Map<String, dynamic>?;
    final pitch = service['pitch']?.toString() ?? '';
    final rate = service['rate'];
    final interval = service['interval']?.toString();
    final business = service['business'] as Map<String, dynamic>?;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Service type name
            if (serviceType != null)
              Text(serviceType['name']?.toString() ?? '',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B4748))),
            const SizedBox(height: 6),

            // Pitch
            if (pitch.isNotEmpty) ...[
              Text(pitch.length > 120 ? '${pitch.substring(0, 120)}...' : pitch,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.black54, height: 1.4)),
              const SizedBox(height: 8),
            ],

            // Rate
            if (rate != null)
              Row(
                children: [
                  Text('R$rate',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B4748))),
                  if (interval != null && interval.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(_intervalLabel(interval),
                          style: const TextStyle(
                              fontSize: 11, color: Colors.black54)),
                    ),
                  ],
                ],
              ),

            // Business name
            if (business != null &&
                (business['name']?.toString() ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.business, size: 13, color: Colors.black45),
                  const SizedBox(width: 4),
                  Text(business['name']?.toString() ?? '',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1B4748))),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Tab 2 — Your Requests ───────────────────────────────────────────────

  Widget _requestsTab() {
    return Column(
      children: [
        // Add request button
        Container(
          color: Colors.grey.shade50,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: () {}, // TODO: open add request modal
                icon: const Icon(Icons.add, size: 16),
                label:
                    const Text('Add Request', style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF8BB25),
                  foregroundColor: Colors.black87,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loadingRequests
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF1B4748)))
              : _requests.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                              'You have not submitted any service requests.',
                              style: TextStyle(color: Color(0xFF1B4748))),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1B4748)),
                            child: const Text('Submit One',
                                style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        _requests = [];
                        await _loadRequests();
                      },
                      color: const Color(0xFF1B4748),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _requests.length,
                        itemBuilder: (context, index) => _requestCard(
                            _requests[index] as Map<String, dynamic>),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _requestCard(Map<String, dynamic> request) {
    final service = request['service'] as Map<String, dynamic>?;
    final description = request['description'] ?? '';
    final city = request['city'] as Map<String, dynamic>?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (service != null)
              Text(service['name']?.toString() ?? '',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B4748))),
            const SizedBox(height: 6),
            Text(
                description.length > 100
                    ? '${description.substring(0, 100)}...'
                    : description,
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
            if (city != null) ...[
              const SizedBox(height: 6),
              _metaRow('Location', city['name'] ?? ''),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {}, // TODO: edit request
                    style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1B4748),
                        padding: const EdgeInsets.symmetric(vertical: 4)),
                    child: const Text('Edit', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _deleteRequest(request['id']),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF48900),
                        padding: const EdgeInsets.symmetric(vertical: 4)),
                    child: const Text('Delete',
                        style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Pagination ──────────────────────────────────────────────────────────

  Widget _paginationBar() {
    if (_totalCount == 0) return const SizedBox.shrink();
    final totalPages = (_totalCount / _selectedPageSize).ceil();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          if (_hasPrev) ...[
            _pageBtn('First', () => _fetchServices(page: 1)),
            _pageBtn('‹ Prev', () => _fetchServices(page: _currentPage - 1)),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1B4748).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('Page $_currentPage of $totalPages',
                style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF1B4748),
                    fontWeight: FontWeight.bold)),
          ),
          if (_hasNext) ...[
            _pageBtn('Next ›', () => _fetchServices(page: _currentPage + 1)),
            _pageBtn('Last', () => _fetchServices(page: totalPages)),
          ],
        ],
      ),
    );
  }

  Widget _pageBtn(String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF1B4748)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF1B4748))),
        ),
      );

  // ─── Shared helpers ──────────────────────────────────────────────────────

  Widget _metaRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                  text: '$label: ',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54)),
              TextSpan(
                  text: value,
                  style: const TextStyle(fontSize: 11, color: Colors.black87)),
            ],
          ),
        ),
      );

  Widget _activeChip(String label, VoidCallback onRemove) => Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1B4748).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: const Color(0xFF1B4748).withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 11, color: Color(0xFF1B4748))),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child:
                  const Icon(Icons.close, size: 12, color: Color(0xFF1B4748)),
            ),
          ],
        ),
      );
}
