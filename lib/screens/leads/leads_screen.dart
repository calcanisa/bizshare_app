import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../widgets/filter_chip_bar.dart';
import '../leads/lead_screen.dart';
import '../leads/add_lead_modal.dart';

class LeadsScreen extends StatefulWidget {
  const LeadsScreen({super.key});

  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen> {
  int _tab = 1;

  List<dynamic> _leads = [];
  bool _loadingLeads = false;

  List<dynamic> _providers = [];
  bool _loadingProviders = false;
  bool _hasMoreProviders = false;
  int _currentPageProviders = 1;
  int _totalCountProviders = 0;
  final ScrollController _scrollController = ScrollController();

  List<dynamic> _requests = [];
  bool _loadingRequests = false;

  List<dynamic> _provinces = [];
  List<dynamic> _cities = [];
  List<dynamic> _areas = [];
  int? _filterProvince;
  int? _filterCity;
  int? _filterArea;
  String? _filterBusinessType;
  String? _filterBusinessSize;

  int? _tempProvince;
  int? _tempCity;
  int? _tempArea;
  String? _tempBusinessType;
  String? _tempBusinessSize;

  final Map<String, String> _typeLabels = {
    'sole': 'Sole Proprietor',
    'partnership': 'Partnership',
    'closed': 'Closed Corporation',
    'public': 'Public Company',
    'personal': 'Personal Liability',
    'nonprofit': 'Non Profit',
    'state': 'State Owned',
  };

  final Map<String, String> _sizeLabels = {
    '10': '1-10 People',
    '50': '11-50 People',
    '100': '51-100 People',
    '101': '100+ People',
    '1001': '1000+ People',
  };

  bool get _hasActiveFilters =>
      _filterProvince != null ||
      _filterBusinessType != null ||
      _filterBusinessSize != null;

  List<Map<String, dynamic>> get _groupedLeads {
    final groups = <int, Map<String, dynamic>>{};
    for (final lead in _leads) {
      final biz = lead['matching_business'];
      final bizId = biz?['id'] ?? 0;
      final bizName = biz?['name'] ?? 'Other';
      if (!groups.containsKey(bizId)) {
        groups[bizId] = {'id': bizId, 'name': bizName, 'leads': []};
      }
      (groups[bizId]!['leads'] as List).add(lead);
    }
    return groups.values.toList();
  }

  @override
  void initState() {
    super.initState();
    _loadLeads();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        if (!_loadingProviders && _hasMoreProviders) _loadMoreProviders();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLeads() async {
    setState(() => _loadingLeads = true);
    try {
      final api = context.read<ApiService>();
      final response =
          await api.dio.get('/api/v1/directory/business/leads/user/current/');
      setState(() => _leads = response.data ?? []);
    } catch (_) {}
    setState(() => _loadingLeads = false);
  }

  Future<void> _loadRequests() async {
    setState(() => _loadingRequests = true);
    try {
      final api = context.read<ApiService>();
      final response =
          await api.dio.get('/api/v1/directory/business/requests/current/');
      setState(() => _requests = response.data ?? []);
    } catch (_) {}
    setState(() => _loadingRequests = false);
  }

  Future<void> _loadProvinces() async {
    if (_provinces.isNotEmpty) return;
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

  Future<void> _loadAreas(int cityId) async {
    try {
      final api = context.read<ApiService>();
      final response = await api.dio.get('/api/v1/locations/areas/$cityId/');
      final data = response.data;
      setState(() => _areas = data is List ? data : (data['results'] ?? []));
    } catch (_) {}
  }

  Future<void> _loadProviders({bool refresh = false}) async {
    if (_loadingProviders) return;
    if (refresh) {
      setState(() {
        _providers = [];
        _currentPageProviders = 1;
        _hasMoreProviders = false;
        _totalCountProviders = 0;
      });
    }
    setState(() => _loadingProviders = true);
    try {
      final api = context.read<ApiService>();
      final params = <String, dynamic>{
        'page': _currentPageProviders,
      };
      if (_filterProvince != null) params['province'] = _filterProvince;
      if (_filterCity != null) params['city'] = _filterCity;
      if (_filterArea != null) params['area'] = _filterArea;
      if (_filterBusinessType != null)
        params['business_type'] = _filterBusinessType;
      if (_filterBusinessSize != null) params['size'] = _filterBusinessSize;

      final response = await api.dio.get(
        '/api/v1/directory/business/services/current/providers/',
        queryParameters: params,
      );
      final results = response.data['results'] as List? ?? [];
      setState(() {
        _providers.addAll(results);
        _currentPageProviders++;
        _hasMoreProviders = response.data['next'] != null;
        _totalCountProviders = response.data['count'] ?? 0;
      });
    } catch (_) {}
    setState(() => _loadingProviders = false);
  }

  Future<void> _loadMoreProviders() async => await _loadProviders();

  Future<void> _deleteRequest(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Request'),
        content: const Text(
            'Are you sure you want to delete this request? This cannot be undone.'),
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
      await api.dio.delete('/api/v1/directory/business/lead/$id/d/');
      setState(() => _requests.removeWhere((r) => r['id'] == id));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Request deleted')));
      }
    } catch (_) {}
  }

  void _openAddRequest() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddLeadModal(
          action: 'add',
          onSave: (data) {
            Navigator.pop(context);
            setState(() => _requests.insert(0, data));
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Request created')));
          },
          onCancel: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _openEditRequest(Map<String, dynamic> request) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddLeadModal(
          action: 'edit',
          request: request,
          onSave: (data) {
            Navigator.pop(context);
            setState(() {
              final index = _requests.indexWhere((r) => r['id'] == data['id']);
              if (index != -1) _requests[index] = data;
            });
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Request updated')));
          },
          onCancel: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _openFilterSheet() async {
    await _loadProvinces();
    _tempProvince = _filterProvince;
    _tempCity = _filterCity;
    _tempArea = _filterArea;
    _tempBusinessType = _filterBusinessType;
    _tempBusinessSize = _filterBusinessSize;

    if (_tempProvince != null) await _loadCities(_tempProvince!);
    if (_tempCity != null) await _loadAreas(_tempCity!);

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
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFF094a25),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      const Text('Filter Providers',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            _tempProvince = null;
                            _tempCity = null;
                            _tempArea = null;
                            _tempBusinessType = null;
                            _tempBusinessSize = null;
                            _cities = [];
                            _areas = [];
                          });
                        },
                        child: const Text('Reset',
                            style: TextStyle(color: Color(0xFFf8b324))),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      _filterLabel('Province'),
                      _filterDropdown<int>(
                        value: _tempProvince,
                        hint: 'All Provinces',
                        items: _provinces
                            .map((p) => DropdownMenuItem<int>(
                                  value: p['id'],
                                  child: Text(p['name'] ?? ''),
                                ))
                            .toList(),
                        onChanged: (v) async {
                          setSheetState(() {
                            _tempProvince = v;
                            _tempCity = null;
                            _tempArea = null;
                            _cities = [];
                            _areas = [];
                          });
                          if (v != null) {
                            await _loadCities(v);
                            setSheetState(() {});
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      if (_cities.isNotEmpty) ...[
                        _filterLabel('City'),
                        _filterDropdown<int>(
                          value: _tempCity,
                          hint: 'All Cities',
                          items: _cities
                              .map((c) => DropdownMenuItem<int>(
                                    value: c['id'],
                                    child: Text(c['name'] ?? ''),
                                  ))
                              .toList(),
                          onChanged: (v) async {
                            setSheetState(() {
                              _tempCity = v;
                              _tempArea = null;
                              _areas = [];
                            });
                            if (v != null) {
                              await _loadAreas(v);
                              setSheetState(() {});
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_areas.isNotEmpty) ...[
                        _filterLabel('Area'),
                        _filterDropdown<int>(
                          value: _tempArea,
                          hint: 'All Areas',
                          items: _areas
                              .map((a) => DropdownMenuItem<int>(
                                    value: a['id'],
                                    child: Text(a['name'] ?? ''),
                                  ))
                              .toList(),
                          onChanged: (v) => setSheetState(() => _tempArea = v),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _filterLabel('Business Type'),
                      _filterDropdown<String>(
                        value: _tempBusinessType,
                        hint: 'All Types',
                        items: _typeLabels.entries
                            .map((e) => DropdownMenuItem<String>(
                                  value: e.key,
                                  child: Text(e.value),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setSheetState(() => _tempBusinessType = v),
                      ),
                      const SizedBox(height: 16),
                      _filterLabel('Business Size'),
                      _filterDropdown<String>(
                        value: _tempBusinessSize,
                        hint: 'All Sizes',
                        items: _sizeLabels.entries
                            .map((e) => DropdownMenuItem<String>(
                                  value: e.key,
                                  child: Text(e.value),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setSheetState(() => _tempBusinessSize = v),
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
                          _filterProvince = _tempProvince;
                          _filterCity = _tempCity;
                          _filterArea = _tempArea;
                          _filterBusinessType = _tempBusinessType;
                          _filterBusinessSize = _tempBusinessSize;
                        });
                        Navigator.pop(context);
                        _loadProviders(refresh: true);
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF094a25),
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
                color: Color(0xFF094a25),
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
          color: const Color(0xFF094a25),
          child: Row(
            children: [
              _tabBtn(1, 'Leads'),
              _tabBtn(2, 'Providers'),
              _tabBtn(3, 'Requests'),
            ],
          ),
        ),
        Expanded(
          child: _tab == 1
              ? _leadsTab()
              : _tab == 2
                  ? _providersTab()
                  : _requestsTab(),
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
          if (index == 2 && _providers.isEmpty) _loadProviders(refresh: true);
          if (index == 3 && _requests.isEmpty) _loadRequests();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          color: active ? Colors.white : const Color(0xFF094a25),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: active ? const Color(0xFF094a25) : Colors.white60,
                fontSize: 13,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              )),
        ),
      ),
    );
  }

  // ─── Tab 1 — Leads ───────────────────────────────────────────────────────

  Widget _leadsTab() {
    if (_loadingLeads) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF094a25)));
    }
    if (_leads.isEmpty) {
      return const Center(
        child: Text('You do not have any leads at the moment. Check back soon!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF094a25))),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadLeads,
      color: const Color(0xFF094a25),
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('You have ${_leads.length} leads',
                style: const TextStyle(
                    color: Color(0xFF094a25), fontWeight: FontWeight.bold)),
          ),
          ..._groupedLeads.map((group) {
            final groupLeads = group['leads'] as List;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: const Color(0xFF094a25),
                  child: Text(group['name'] as String,
                      style: const TextStyle(
                          color: Color(0xFFf8b324),
                          fontWeight: FontWeight.bold)),
                ),
                ...groupLeads.map((lead) => _leadCard(lead)),
              ],
            );
          }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _leadCard(Map<String, dynamic> lead) {
    final user = lead['user'];
    final service = lead['service'];
    final isLocked = lead['is_locked'] ?? false;
    final hasPurchased = lead['has_purchased'] ?? false;
    final pricePerLead = lead['price_per_lead'];

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LeadDetailScreen(leadId: lead['id']),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                user != null
                    ? '${user['first_name']} is looking for ${service?['name'] ?? 'a service'}'
                    : 'Someone is looking for ${service?['name'] ?? 'a service'}',
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ),
            const SizedBox(width: 8),
            if (!isLocked || hasPurchased)
              ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LeadDetailScreen(leadId: lead['id']),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF094a25),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6)),
                child: const Text('View',
                    style: TextStyle(color: Colors.white, fontSize: 12)),
              )
            else
              ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LeadDetailScreen(leadId: lead['id']),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFf8b324),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6)),
                child: Text(
                    pricePerLead != null ? 'Buy - R$pricePerLead' : 'Buy Lead',
                    style:
                        const TextStyle(color: Colors.black87, fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Tab 2 — Providers ───────────────────────────────────────────────────

  Widget _providersTab() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _totalCountProviders > 0
                    ? '$_totalCountProviders providers found'
                    : 'Providers matching your services',
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.tune, color: Color(0xFF094a25)),
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
                          color: Color(0xFFbc2023),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (_hasActiveFilters)
          Container(
            height: 40,
            color: Colors.grey.shade50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              children: [
                if (_filterProvince != null)
                  ActiveFilterChip(
                    label: _provinces.firstWhere(
                            (p) => p['id'] == _filterProvince,
                            orElse: () => {'name': 'Province'})['name'] ??
                        '',
                    onRemove: () {
                      setState(() {
                        _filterProvince = null;
                        _filterCity = null;
                        _filterArea = null;
                      });
                      _loadProviders(refresh: true);
                    },
                  ),
                if (_filterBusinessType != null)
                  ActiveFilterChip(
                    label: _typeLabels[_filterBusinessType] ??
                        _filterBusinessType!,
                    onRemove: () {
                      setState(() => _filterBusinessType = null);
                      _loadProviders(refresh: true);
                    },
                  ),
                if (_filterBusinessSize != null)
                  ActiveFilterChip(
                    label: _sizeLabels[_filterBusinessSize] ??
                        _filterBusinessSize!,
                    onRemove: () {
                      setState(() => _filterBusinessSize = null);
                      _loadProviders(refresh: true);
                    },
                  ),
              ],
            ),
          ),
        Expanded(
          child: _loadingProviders && _providers.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF094a25)))
              : _providers.isEmpty
                  ? const Center(
                      child: Text('No providers found for your services',
                          style: TextStyle(color: Color(0xFF094a25))))
                  : RefreshIndicator(
                      onRefresh: () => _loadProviders(refresh: true),
                      color: const Color(0xFF094a25),
                      child: ListView.builder(
                        controller: _scrollController,
                        itemCount:
                            _providers.length + (_hasMoreProviders ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _providers.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(
                                    color: Color(0xFF094a25)),
                              ),
                            );
                          }
                          return _providerCard(_providers[index]);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _providerCard(Map<String, dynamic> business) {
    final logo = business['logo'];
    final name = business['name'] ?? '';
    final description = business['description'] ?? '';
    final categories = business['categories'] as List? ?? [];
    final branches = business['branches'] as List? ?? [];

    String location = '';
    if (branches.isNotEmpty) {
      final branch = branches[0];
      if (branch['area'] != null) {
        location =
            '${branch['area']['city']['name']} / ${branch['area']['name']}';
      } else if (branch['city'] != null) {
        location =
            '${branch['city']['province']['name']} / ${branch['city']['name']}';
      }
    }

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
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: logo != null && logo.toString().isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: logo,
                      width: 70,
                      height: 70,
                      fit: BoxFit.contain,
                      errorWidget: (_, __, ___) => _logoPlaceholder())
                  : _logoPlaceholder(),
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
                          color: Color(0xFF094a25))),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description.length > 100
                          ? '${description.substring(0, 100)}...'
                          : description,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
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
                  if (categories.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: categories.take(3).map((cat) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF094a25),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(cat['name'] ?? '',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 10)),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black26),
          ],
        ),
      ),
    );
  }

  // ─── Tab 3 — Requests ────────────────────────────────────────────────────

  Widget _requestsTab() {
    if (_loadingRequests) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF094a25)));
    }

    final serviceRequests =
        _requests.where((r) => r['service'] != null).toList();
    final productRequests =
        _requests.where((r) => r['product_name'] != null).toList();

    return RefreshIndicator(
      onRefresh: _loadRequests,
      color: const Color(0xFF094a25),
      child: ListView(
        children: [
          // Create new request button
          Padding(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton.icon(
              onPressed: _openAddRequest,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF094a25),
                  padding: const EdgeInsets.symmetric(vertical: 12)),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Create New Request',
                  style: TextStyle(color: Colors.white)),
            ),
          ),
          if (_requests.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text('You have not submitted any requests.',
                    style: TextStyle(color: Color(0xFF094a25))),
              ),
            )
          else ...[
            if (serviceRequests.isNotEmpty) ...[
              _listHeader('Service Requests'),
              ...serviceRequests.map((r) => _requestCard(r)),
            ],
            if (productRequests.isNotEmpty) ...[
              _listHeader('Product Requests'),
              ...productRequests.map((r) => _requestCard(r)),
            ],
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _listHeader(String title) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: const Color(0xFF094a25),
        margin: const EdgeInsets.only(bottom: 4),
        child: Text(title,
            style: const TextStyle(
                color: Color(0xFFf8b324), fontWeight: FontWeight.bold)),
      );

  Widget _requestCard(Map<String, dynamic> request) {
    final service = request['service'];
    final productName = request['product_name'];
    final title = service?['name'] ?? productName ?? 'Request';
    final description = request['description'] ?? '';
    final city = request['city'];

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
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF094a25))),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                description.length > 100
                    ? '${description.substring(0, 100)}...'
                    : description,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
            if (city != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 12, color: Colors.black45),
                  const SizedBox(width: 2),
                  Text(city['name'] ?? '',
                      style:
                          const TextStyle(fontSize: 11, color: Colors.black45)),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _openEditRequest(request),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF094a25),
                        padding: const EdgeInsets.symmetric(vertical: 4)),
                    child: const Text('Edit', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _deleteRequest(request['id']),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFbc2023),
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

  Widget _logoPlaceholder() => Container(
        width: 70,
        height: 70,
        color: const Color(0xFF094a25).withOpacity(0.1),
        child: const Icon(Icons.people_outline,
            color: Color(0xFF094a25), size: 32),
      );
}
