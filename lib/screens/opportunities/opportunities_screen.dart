import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../opportunities/opportunity_screen.dart';
import '../opportunities/add_opportunity.dart';

class OpportunitiesScreen extends StatefulWidget {
  const OpportunitiesScreen({super.key});

  @override
  State<OpportunitiesScreen> createState() => _OpportunitiesScreenState();
}

class _OpportunitiesScreenState extends State<OpportunitiesScreen> {
  // Account info
  int? _accountId;
  bool _hasMembership = false;
  Set<int> _appliedOppIds = {};
  bool _loadingAccount = true;

  // Tab
  int _tab = 2; // default until account loads

  // Tab 1 - My Opportunities
  List<dynamic> _myOpps = [];
  bool _loadingMine = false;

  // Tab 2 - My Applications
  List<dynamic> _myApps = [];
  bool _loadingApps = false;

  // Tab 3 - All Opportunities
  List<dynamic> _allOpps = [];
  bool _loadingAll = false;
  int _currentPage = 1;
  int _totalCount = 0;
  bool _hasNext = false;
  bool _hasPrev = false;
  int _selectedPageSize = 20;
  String _selectedOrdering = 'date-last';

  // Filter state (applied)
  List<dynamic> _categories = [];
  List<dynamic> _provinces = [];
  List<dynamic> _cities = [];
  int? _filterType;
  int? _filterSubCat;
  int? _filterProvince;
  int? _filterCity;

  // Temp filter state (in-sheet)
  int? _tempType;
  int? _tempSubCat;
  int? _tempProvince;
  int? _tempCity;

  bool get _hasActiveFilters =>
      _filterType != null ||
      _filterSubCat != null ||
      _filterProvince != null ||
      _filterCity != null;

  List<dynamic> get _currentOpps => _myOpps.where((o) => !_isPast(o)).toList();
  List<dynamic> get _pastOpps => _myOpps.where((o) => _isPast(o)).toList();

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  Future<void> _loadAccount() async {
    try {
      final api = context.read<ApiService>();
      final response = await api.dio.get('/api/v1/users/current/');
      final data = response.data;
      final membership = data['membership'];
      final hasMembership = membership != null && membership != false;
      final apps = data['applications'] as List? ?? [];
      final appliedIds = apps.map<int>((a) {
        final opp = a['opportunity'];
        return opp is int ? opp : int.tryParse(opp.toString()) ?? 0;
      }).toSet();

      setState(() {
        _accountId = data['id'];
        _hasMembership = hasMembership;
        _appliedOppIds = appliedIds;
        _tab = hasMembership ? 1 : 2;
        _loadingAccount = false;
      });

      if (hasMembership) {
        _loadMyOpps();
      } else {
        _loadMyApps();
      }
    } catch (_) {
      setState(() {
        _loadingAccount = false;
        _tab = 2;
      });
      _loadMyApps();
    }
  }

  Future<void> _loadMyOpps() async {
    setState(() => _loadingMine = true);
    try {
      final api = context.read<ApiService>();
      final response = await api.dio.get('/api/v1/opportunities/user/current/');
      setState(() => _myOpps = response.data is List ? response.data : []);
    } catch (_) {
      _showSnack('Could not load your opportunities. Try again.');
    }
    setState(() => _loadingMine = false);
  }

  Future<void> _loadMyApps() async {
    setState(() => _loadingApps = true);
    try {
      final api = context.read<ApiService>();
      final response =
          await api.dio.get('/api/v1/opportunities/applications/current/');
      setState(() => _myApps = response.data is List ? response.data : []);
    } catch (_) {
      _showSnack('Could not load your applications. Try again.');
    }
    setState(() => _loadingApps = false);
  }

  Future<void> _fetchAllOpps({int page = 1}) async {
    if (_loadingAll) return;
    setState(() => _loadingAll = true);
    try {
      final api = context.read<ApiService>();
      final params = <String, dynamic>{
        'page_size': _selectedPageSize,
        'ordering': _selectedOrdering,
      };
      if (page > 1) params['page'] = page;
      if (_filterType != null) params['category'] = _filterType;
      if (_filterSubCat != null) params['subcategory'] = _filterSubCat;
      if (_filterProvince != null) params['province'] = _filterProvince;
      if (_filterCity != null) params['city'] = _filterCity;

      final response =
          await api.dio.get('/api/v1/opportunities/', queryParameters: params);
      setState(() {
        _allOpps = response.data['results'] as List? ?? [];
        _totalCount = response.data['count'] ?? 0;
        _hasNext = response.data['next'] != null;
        _hasPrev = response.data['previous'] != null;
        _currentPage = page;
      });
    } catch (_) {
      _showSnack('Could not load opportunities. Try again.');
    }
    setState(() => _loadingAll = false);
  }

  Future<void> _loadProvinces() async {
    if (_provinces.isNotEmpty) return;
    try {
      final api = context.read<ApiService>();
      final response = await api.dio.get('/api/v1/locations/provinces/');
      setState(
          () => _provinces = response.data['results'] ?? response.data ?? []);
    } catch (_) {}
  }

  Future<void> _loadCities(int provinceId) async {
    try {
      final api = context.read<ApiService>();
      final response = await api.dio.get('/api/v1/locations/cities/',
          queryParameters: {'province': provinceId});
      setState(() => _cities = response.data['results'] ?? response.data ?? []);
    } catch (_) {}
  }

  Future<void> _loadCategories() async {
    if (_categories.isNotEmpty) return;
    try {
      final api = context.read<ApiService>();
      final response = await api.dio.get('/api/v1/opportunities/categories/');
      final data = response.data;
      setState(
          () => _categories = data is List ? data : (data['results'] ?? []));
    } catch (_) {}
  }

  Future<void> _deleteOpp(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Opportunity'),
        content: const Text(
            'Are you sure you want to delete this opportunity? This cannot be undone.'),
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
      await api.dio.delete('/api/v1/opportunities/opportunity/$id/d/');
      setState(() {
        _myOpps.removeWhere((o) => o['id'] == id);
        _allOpps.removeWhere((o) => o['id'] == id);
      });
      _showSnack('Opportunity deleted');
    } catch (_) {
      _showSnack('Could not delete opportunity. Try again.');
    }
  }

  Future<void> _deleteApplication(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Application'),
        content: const Text(
            'Are you sure you want to delete this application? This cannot be undone.'),
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
      await api.dio.delete('/api/v1/opportunities/application/$id/d/');
      setState(() => _myApps.removeWhere((a) => a['id'] == id));
      _showSnack('Application deleted');
    } catch (_) {
      _showSnack('Could not delete application. Try again.');
    }
  }

  bool _isPast(Map<String, dynamic> opp) {
    final validUntil = opp['valid_until'];
    if (validUntil == null) return false;
    final validDate = DateTime.tryParse(validUntil.toString());
    if (validDate == null) return false;
    final today = DateTime.now();
    return validDate.isBefore(DateTime(today.year, today.month, today.day));
  }

  bool _hasApplied(int oppId) => _appliedOppIds.contains(oppId);

  String _formatDate(String? dateStr) {
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
    return '${date.day} ${months[date.month]} ${date.year}';
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _openFilterSheet() async {
    await _loadProvinces();
    await _loadCategories();
    _tempType = _filterType;
    _tempSubCat = _filterSubCat;
    _tempProvince = _filterProvince;
    _tempCity = _filterCity;

    if (_tempProvince != null) await _loadCities(_tempProvince!);

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
        final tempFilteredCats = _tempType == null
            ? <dynamic>[]
            : _categories.where((c) => c['parent'] == _tempType).toList();

        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.4,
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
                      const Text('Filter Opportunities',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            _tempType = null;
                            _tempSubCat = null;
                            _tempProvince = null;
                            _tempCity = null;
                            _cities = [];
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
                      _filterLabel('Type'),
                      _filterDropdown<int>(
                        value: _tempType,
                        hint: 'All Types',
                        items: const [
                          DropdownMenuItem(value: 2, child: Text('Online')),
                          DropdownMenuItem(value: 1, child: Text('Offline')),
                        ],
                        onChanged: (v) {
                          setSheetState(() {
                            _tempType = v;
                            _tempSubCat = null;
                            _tempProvince = null;
                            _tempCity = null;
                            _cities = [];
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      if (tempFilteredCats.isNotEmpty) ...[
                        _filterLabel('Sub Category'),
                        _filterDropdown<int>(
                          value: _tempSubCat,
                          hint: 'All Sub Categories',
                          items: tempFilteredCats
                              .map((c) => DropdownMenuItem<int>(
                                    value: c['id'],
                                    child: Text(c['name'] ?? ''),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setSheetState(() => _tempSubCat = v),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_tempType == 1) ...[
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
                              _cities = [];
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
                            onChanged: (v) =>
                                setSheetState(() => _tempCity = v),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],
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
                          _filterType = _tempType;
                          _filterSubCat = _tempSubCat;
                          _filterProvince = _tempProvince;
                          _filterCity = _tempCity;
                        });
                        Navigator.pop(context);
                        _fetchAllOpps(page: 1);
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
                  child: Text(hint,
                      style: const TextStyle(color: Colors.black45))),
              ...items,
            ],
            onChanged: onChanged,
          ),
        ),
      );

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loadingAccount) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF094a25)));
    }
    return Column(
      children: [
        Container(
          color: const Color(0xFF094a25),
          child: Row(
            children: [
              if (_hasMembership) _tabBtn(1, 'You Added'),
              _tabBtn(2, 'You Applied To'),
              _tabBtn(3, 'All Opportunities'),
            ],
          ),
        ),
        Expanded(
          child: _tab == 1
              ? _myOppsTab()
              : _tab == 2
                  ? _myAppsTab()
                  : _allOppsTab(),
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
          if (index == 2 && _myApps.isEmpty) _loadMyApps();
          if (index == 3 && _allOpps.isEmpty) {
            _loadCategories();
            _fetchAllOpps(page: 1);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          color: active ? Colors.white : const Color(0xFF094a25),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: active ? const Color(0xFF094a25) : Colors.white60,
                fontSize: 12,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              )),
        ),
      ),
    );
  }

  // ─── Tab 1 — My Opportunities ────────────────────────────────────────────

  Widget _myOppsTab() {
    if (_loadingMine) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF094a25)));
    }
    if (_myOpps.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('You have not posted any opportunities.',
                style: TextStyle(color: Color(0xFF094a25))),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddOpportunityModal(
                    action: 'add',
                    onSave: (data) {
                      Navigator.pop(context);
                      setState(() => _myOpps.insert(0, data));
                    },
                    onCancel: () => Navigator.pop(context),
                  ),
                ),
              ),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF094a25)),
              child:
                  const Text('Post One', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadMyOpps,
      color: const Color(0xFF094a25),
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddOpportunityModal(
                    action: 'add',
                    onSave: (data) {
                      Navigator.pop(context);
                      setState(() => _myOpps.insert(0, data));
                    },
                    onCancel: () => Navigator.pop(context),
                  ),
                ),
              ),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF094a25),
                  minimumSize: const Size(double.infinity, 44)),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Post Opportunity',
                  style: TextStyle(color: Colors.white)),
            ),
          ),
          if (_currentOpps.isNotEmpty) ...[
            _listHeader('Current Opportunities'),
            ..._currentOpps
                .map((o) => _myOppCard(o as Map<String, dynamic>, past: false)),
          ],
          if (_pastOpps.isNotEmpty) ...[
            _listHeader('Past Opportunities'),
            ..._pastOpps
                .map((o) => _myOppCard(o as Map<String, dynamic>, past: true)),
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

  Widget _myOppCard(Map<String, dynamic> opp, {required bool past}) {
    final title = opp['title'] ?? '';
    final description = opp['description'] ?? '';
    final imageUrl = opp['image'];
    final category = opp['category'] as Map<String, dynamic>?;
    final validUntil = opp['valid_until'];
    final oppValue = opp['opp_value'];
    final isOnline = category != null && category['parent'] == 2;
    final isPublished = opp['published'] == true;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OpportunityDetailScreen(opportunityId: opp['id']),
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
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            width: 80,
                            height: 80,
                            fit: BoxFit.contain,
                            errorWidget: (_, __, ___) => _imagePlaceholder())
                        : _imagePlaceholder(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: past
                                    ? Colors.black54
                                    : const Color(0xFF094a25))),
                        const SizedBox(height: 4),
                        Text(
                            description.length > 60
                                ? '${description.substring(0, 60)}...'
                                : description,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black54)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _metaTag(
                              isOnline ? 'Online' : 'Offline',
                              isOnline
                                  ? const Color(0xFF094a25)
                                  : const Color(0xFFbc2023),
                            ),
                            if (category != null) ...[
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(category['name'] ?? '',
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.black45),
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (validUntil != null)
                          Text(
                              'Valid until: ${_formatDate(validUntil.toString())}',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.black45)),
                        const SizedBox(height: 2),
                        oppValue != null
                            ? Text('Value: R$oppValue',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF094a25)))
                            : const Text('Value: Quote',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.black45)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (!past && isPublished) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddOpportunityModal(
                              action: 'edit',
                              opportunity: opp,
                              onSave: (data) {
                                Navigator.pop(context);
                                final i = _myOpps
                                    .indexWhere((o) => o['id'] == data['id']);
                                if (i != -1) setState(() => _myOpps[i] = data);
                              },
                              onCancel: () => Navigator.pop(context),
                            ),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF094a25),
                            padding: const EdgeInsets.symmetric(vertical: 4)),
                        child:
                            const Text('Edit', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {}, // TODO: feature
                        style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFf8b324),
                            side: const BorderSide(color: Color(0xFFf8b324)),
                            padding: const EdgeInsets.symmetric(vertical: 4)),
                        child: const Text('Feature',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _deleteOpp(opp['id']),
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
      ),
    );
  }

  // ─── Tab 2 — My Applications ─────────────────────────────────────────────

  Widget _myAppsTab() {
    if (_loadingApps) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF094a25)));
    }
    if (_myApps.isEmpty) {
      return const Center(
        child: Text('You have not applied to any opportunities.',
            style: TextStyle(color: Color(0xFF094a25))),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadMyApps,
      color: const Color(0xFF094a25),
      child: ListView.builder(
        itemCount: _myApps.length,
        itemBuilder: (context, index) =>
            _applicationCard(_myApps[index] as Map<String, dynamic>),
      ),
    );
  }

  Widget _applicationCard(Map<String, dynamic> app) {
    final opp = app['opportunity'] as Map<String, dynamic>? ?? {};
    final oppTitle = opp['title'] ?? '';
    final pitch = app['pitch'] ?? '';
    final createdAt = app['created_at'];

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
            Text(
                oppTitle.length > 55
                    ? '${oppTitle.substring(0, 55)}...'
                    : oppTitle,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF094a25))),
            const SizedBox(height: 6),
            if (createdAt != null)
              Text('Date Applied: ${_formatDate(createdAt.toString())}',
                  style: const TextStyle(fontSize: 12, color: Colors.black45)),
            const SizedBox(height: 6),
            Text(pitch.length > 80 ? '${pitch.substring(0, 80)}...' : pitch,
                style: const TextStyle(fontSize: 12, color: Colors.black87)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {}, // TODO: edit application
                    style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF094a25),
                        padding: const EdgeInsets.symmetric(vertical: 4)),
                    child: const Text('Edit', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _deleteApplication(app['id']),
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

  // ─── Tab 3 — All Opportunities ───────────────────────────────────────────

  Widget _allOppsTab() {
    return Column(
      children: [
        // Controls bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              // Filter button
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
              const Spacer(),
              // Ordering dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedOrdering,
                    isDense: true,
                    style:
                        const TextStyle(fontSize: 12, color: Color(0xFF094a25)),
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
                          value: 'price-low', child: Text('Value Low–High')),
                      DropdownMenuItem(
                          value: 'price-high', child: Text('Value High–Low')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _selectedOrdering = v);
                      _fetchAllOpps(page: 1);
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
                if (_filterType != null)
                  _activeChip(
                    _filterType == 2 ? 'Online' : 'Offline',
                    () {
                      setState(() {
                        _filterType = null;
                        _filterSubCat = null;
                        _filterProvince = null;
                        _filterCity = null;
                      });
                      _fetchAllOpps(page: 1);
                    },
                  ),
                if (_filterSubCat != null)
                  _activeChip(
                    _categories.firstWhere((c) => c['id'] == _filterSubCat,
                            orElse: () => {'name': 'Sub Cat'})['name'] ??
                        '',
                    () {
                      setState(() => _filterSubCat = null);
                      _fetchAllOpps(page: 1);
                    },
                  ),
                if (_filterProvince != null)
                  _activeChip(
                    _provinces.firstWhere((p) => p['id'] == _filterProvince,
                            orElse: () => {'name': 'Province'})['name'] ??
                        '',
                    () {
                      setState(() {
                        _filterProvince = null;
                        _filterCity = null;
                      });
                      _fetchAllOpps(page: 1);
                    },
                  ),
                if (_filterCity != null)
                  _activeChip(
                    _cities.firstWhere((c) => c['id'] == _filterCity,
                            orElse: () => {'name': 'City'})['name'] ??
                        '',
                    () {
                      setState(() => _filterCity = null);
                      _fetchAllOpps(page: 1);
                    },
                  ),
              ],
            ),
          ),

        // Count + page size selector
        if (_totalCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            color: Colors.grey.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$_totalCount opportunities found',
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
                            fontSize: 12, color: Color(0xFF094a25)),
                        items: [20, 50, 100]
                            .map((s) =>
                                DropdownMenuItem(value: s, child: Text('$s')))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _selectedPageSize = v);
                          _fetchAllOpps(page: 1);
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
          child: _loadingAll
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF094a25)))
              : _allOpps.isEmpty
                  ? const Center(
                      child: Text('There are no opportunities at the moment.',
                          style: TextStyle(color: Color(0xFF094a25))))
                  : RefreshIndicator(
                      onRefresh: () => _fetchAllOpps(page: 1),
                      color: const Color(0xFF094a25),
                      child: ListView.builder(
                        itemCount: _allOpps.length + 1, // +1 for pagination
                        itemBuilder: (context, index) {
                          if (index == _allOpps.length) {
                            return _paginationBar();
                          }
                          return _allOppCard(
                              _allOpps[index] as Map<String, dynamic>);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

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
            _pageBtn('First', () => _fetchAllOpps(page: 1)),
            _pageBtn('‹ Prev', () => _fetchAllOpps(page: _currentPage - 1)),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF094a25).withOpacity(0.08),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('Page $_currentPage of $totalPages',
                style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF094a25),
                    fontWeight: FontWeight.bold)),
          ),
          if (_hasNext) ...[
            _pageBtn('Next ›', () => _fetchAllOpps(page: _currentPage + 1)),
            _pageBtn('Last', () => _fetchAllOpps(page: totalPages)),
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
            border: Border.all(color: const Color(0xFF094a25)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF094a25))),
        ),
      );

  Widget _allOppCard(Map<String, dynamic> opp) {
    final title = opp['title'] ?? '';
    final description = opp['description'] ?? '';
    final imageUrl = opp['image'];
    final category = opp['category'] as Map<String, dynamic>?;
    final validUntil = opp['valid_until'];
    final oppValue = opp['opp_value'];
    final applications = opp['applications'] as List? ?? [];
    final isOnline = category != null && category['parent'] == 2;
    final isOwner = _accountId != null &&
        opp['user'] is Map &&
        (opp['user'] as Map)['id'] == _accountId;
    final applied = _hasApplied(opp['id']);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OpportunityDetailScreen(opportunityId: opp['id']),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            width: 80,
                            height: 80,
                            fit: BoxFit.contain,
                            errorWidget: (_, __, ___) => _imagePlaceholder())
                        : _imagePlaceholder(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(title,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF094a25))),
                            ),
                            const SizedBox(width: 6),
                            _metaTag(
                              isOnline ? 'Online' : 'Offline',
                              isOnline
                                  ? const Color(0xFF094a25)
                                  : const Color(0xFFbc2023),
                            ),
                          ],
                        ),
                        if (category != null) ...[
                          const SizedBox(height: 3),
                          Text(category['name'] ?? '',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.black45)),
                        ],
                        const SizedBox(height: 5),
                        Text(
                            description.length > 100
                                ? '${description.substring(0, 100)}...'
                                : description,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black87)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            oppValue != null
                                ? 'Value: R$oppValue'
                                : 'Value: Quote',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: oppValue != null
                                    ? const Color(0xFF094a25)
                                    : Colors.black45)),
                        if (validUntil != null) ...[
                          const SizedBox(height: 2),
                          Text(
                              'Valid until: ${_formatDate(validUntil.toString())}',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.black45)),
                        ],
                        if (applications.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.people_outline,
                                  size: 13, color: Color(0xFFf8b324)),
                              const SizedBox(width: 3),
                              Text(
                                  '${applications.length} application${applications.length == 1 ? '' : 's'}',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFf8b324))),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isOwner) ...[
                    OutlinedButton(
                      onPressed: () {}, // TODO: edit
                      style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF094a25),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4)),
                      child: const Text('Edit', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton(
                      onPressed: () => _deleteOpp(opp['id']),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFbc2023),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4)),
                      child: const Text('Delete',
                          style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ] else
                    ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddOpportunityModal(
                            action: 'edit',
                            opportunity: opp,
                            onSave: (data) {
                              Navigator.pop(context);
                              final i = _allOpps
                                  .indexWhere((o) => o['id'] == data['id']);
                              if (i != -1) setState(() => _allOpps[i] = data);
                            },
                            onCancel: () => Navigator.pop(context),
                          ),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: applied
                              ? Colors.grey.shade400
                              : const Color(0xFF094a25),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8)),
                      child: Text(applied ? 'Applied' : 'Apply',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Shared helpers ──────────────────────────────────────────────────────

  Widget _metaTag(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10, color: color, fontWeight: FontWeight.bold)),
      );

  Widget _activeChip(String label, VoidCallback onRemove) => Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF094a25).withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF094a25).withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 11, color: Color(0xFF094a25))),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child:
                  const Icon(Icons.close, size: 12, color: Color(0xFF094a25)),
            ),
          ],
        ),
      );

  Widget _imagePlaceholder() => Container(
        width: 80,
        height: 80,
        color: const Color(0xFF094a25).withOpacity(0.1),
        child:
            const Icon(Icons.work_outline, color: Color(0xFF094a25), size: 30),
      );
}
