import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../widgets/filter_chip_bar.dart';
import '../directory/business_screen.dart';
import '../directory/add_business_screen.dart';
import '../feature_content.dart';

class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({super.key});

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  int _tab = 1;

  List<dynamic> _myBusinesses = [];
  bool _loadingMine = false;

  List<dynamic> _following = [];
  bool _loadingFollowing = false;

  List<dynamic> _categories = [];
  List<dynamic> _businesses = [];
  bool _loadingAll = false;
  bool _hasMore = false;
  int _currentPage = 1;
  int _totalCount = 0;
  int? _selectedCategory;
  final ScrollController _scrollController = ScrollController();

  List<dynamic> _provinces = [];
  List<dynamic> _cities = [];
  List<dynamic> _areas = [];
  List<dynamic> _subcategories = [];
  int? _filterSubcategory;
  int? _filterProvince;
  int? _filterCity;
  int? _filterArea;
  String? _filterBusinessType;
  String? _filterBusinessSize;

  int? _tempSubcategory;
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
    '10001': '10,000+ People',
  };

  bool get _hasActiveFilters =>
      _filterSubcategory != null ||
      _filterProvince != null ||
      _filterCity != null ||
      _filterArea != null ||
      _filterBusinessType != null ||
      _filterBusinessSize != null;

  @override
  void initState() {
    super.initState();
    _loadMyBusinesses();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        if (!_loadingAll && _hasMore) _loadMoreBusinesses();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMyBusinesses() async {
    setState(() => _loadingMine = true);
    try {
      final api = context.read<ApiService>();
      final response =
          await api.dio.get('/api/v1/directory/businesses/current/');
      setState(() => _myBusinesses = response.data ?? []);
    } catch (_) {}
    setState(() => _loadingMine = false);
  }

  Future<void> _loadFollowing() async {
    setState(() => _loadingFollowing = true);
    try {
      final api = context.read<ApiService>();
      final response =
          await api.dio.get('/api/v1/directory/business/following/current/');
      setState(
          () => _following = (response.data is List ? response.data : (response.data['results'] ?? [])));
    } catch (_) {}
    setState(() => _loadingFollowing = false);
  }

  Future<void> _loadCategories() async {
    if (_categories.isNotEmpty) return;
    try {
      final api = context.read<ApiService>();
      final response =
          await api.dio.get('/api/v1/directory/business/categories/top/');
      final data = response.data;
      setState(
          () => _categories = data is List ? data : (data['results'] ?? []));
    } catch (_) {}
  }

  Future<void> _loadProvinces() async {
    if (_provinces.isNotEmpty) return;
    try {
      final api = context.read<ApiService>();
      final response = await api.dio.get('/api/v1/locations/provinces/');
      setState(
          () => _provinces = (response.data is List ? response.data : (response.data['results'] ?? [])));
    } catch (_) {}
  }

  Future<void> _loadCities(int provinceId) async {
    try {
      final api = context.read<ApiService>();
      final response =
          await api.dio.get('/api/v1/locations/cities/$provinceId/');
      setState(() => _cities = (response.data is List ? response.data : (response.data['results'] ?? [])));
    } catch (_) {}
  }

  Future<void> _loadAreas(int cityId) async {
    try {
      final api = context.read<ApiService>();
      final response = await api.dio.get('/api/v1/locations/areas/$cityId/');
      setState(() => _areas = (response.data is List ? response.data : (response.data['results'] ?? [])));
    } catch (_) {}
  }

  Future<void> _loadBusinesses({bool refresh = false}) async {
    if (_loadingAll || _selectedCategory == null) return;
    if (refresh) {
      setState(() {
        _businesses = [];
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
        'category': _selectedCategory,
      };
      if (_filterSubcategory != null) {
        params['subcategory'] = _filterSubcategory;
      }
      if (_filterProvince != null) params['province'] = _filterProvince;
      if (_filterCity != null) params['city'] = _filterCity;
      if (_filterArea != null) params['area'] = _filterArea;
      if (_filterBusinessType != null) {
        params['business_type'] = _filterBusinessType;
      }
      if (_filterBusinessSize != null) params['size'] = _filterBusinessSize;

      final response = await api.dio
          .get('/api/v1/directory/businesses/', queryParameters: params);
      final results = response.data['results'] as List? ?? [];
      setState(() {
        _businesses.addAll(results);
        _currentPage++;
        _hasMore = response.data['next'] != null;
        _totalCount = response.data['count'] ?? 0;
      });
    } catch (_) {}
    setState(() => _loadingAll = false);
  }

  Future<void> _loadMoreBusinesses() async {
    await _loadBusinesses();
  }

  Future<void> _unfollow(int id) async {
    try {
      final api = context.read<ApiService>();
      await api.dio.post('/api/v1/directory/business/$id/follow/');
      setState(() => _following.removeWhere((b) => b['id'] == id));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Business unfollowed')));
      }
    } catch (_) {}
  }

  Future<void> _deleteBusiness(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Business'),
        content: const Text(
            'Are you sure you want to delete this business? This cannot be undone.'),
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
      await api.dio.delete('/api/v1/directory/business/$id/d/');
      setState(() => _myBusinesses.removeWhere((b) => b['id'] == id));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Business deleted')));
      }
    } catch (_) {}
  }

  void _openAddBusiness() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddBusinessModal(
          action: 'add',
          onSave: (data) {
            Navigator.pop(context);
            setState(() => _myBusinesses.insert(0, data));
          },
          onCancel: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _openEditBusiness(Map<String, dynamic> business) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddBusinessModal(
          action: 'edit',
          business: business,
          onSave: (data) {
            Navigator.pop(context);
            setState(() {
              final index =
                  _myBusinesses.indexWhere((b) => b['id'] == data['id']);
              if (index != -1) _myBusinesses[index] = data;
            });
          },
          onCancel: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _openFilterSheet() async {
    await _loadProvinces();
    _tempSubcategory = _filterSubcategory;
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
                    color: Color(0xFF1B4748),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      const Text('Filter Businesses',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            _tempSubcategory = null;
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
                      if (_subcategories.isNotEmpty) ...[
                        _filterLabel('Sub Category'),
                        _filterDropdown<int>(
                          value: _tempSubcategory,
                          hint: 'All Sub Categories',
                          items: _subcategories
                              .map((s) => DropdownMenuItem<int>(
                                    value: s['id'],
                                    child: Text(s['name'] ?? ''),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setSheetState(() => _tempSubcategory = v),
                        ),
                        const SizedBox(height: 16),
                      ],
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
                          _filterSubcategory = _tempSubcategory;
                          _filterProvince = _tempProvince;
                          _filterCity = _tempCity;
                          _filterArea = _tempArea;
                          _filterBusinessType = _tempBusinessType;
                          _filterBusinessSize = _tempBusinessSize;
                        });
                        Navigator.pop(context);
                        _loadBusinesses(refresh: true);
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
              _tabBtn(1, 'My Businesses'),
              _tabBtn(2, 'Following'),
              _tabBtn(3, 'All'),
            ],
          ),
        ),
        Expanded(
          child: _tab == 1
              ? _myBusinessesTab()
              : _tab == 2
                  ? _followingTab()
                  : _allBusinessesTab(),
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
          if (index == 2 && _following.isEmpty) _loadFollowing();
          if (index == 3) _loadCategories();
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

  // ─── Tab 1 — My Businesses ───────────────────────────────────────────────

  Widget _myBusinessesTab() {
    if (_loadingMine) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF1B4748)));
    }
    return RefreshIndicator(
      onRefresh: _loadMyBusinesses,
      color: const Color(0xFF1B4748),
      child: _myBusinesses.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 60),
                const Center(
                  child: Text('You have not created any business listings.',
                      style: TextStyle(color: Color(0xFF1B4748))),
                ),
                const SizedBox(height: 16),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _openAddBusiness,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B4748),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12)),
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('Create Business',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            )
          : ListView.builder(
              itemCount: _myBusinesses.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    child: ElevatedButton.icon(
                      onPressed: _openAddBusiness,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B4748),
                          padding: const EdgeInsets.symmetric(vertical: 12)),
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text('Create New Business',
                          style: TextStyle(color: Colors.white)),
                    ),
                  );
                }
                return _myBusinessCard(
                    _myBusinesses[index - 1] as Map<String, dynamic>);
              },
            ),
    );
  }

  Widget _myBusinessCard(Map<String, dynamic> business) {
    final name = business['name'] ?? '';
    final hero = business['hero'];
    final published = business['published'] ?? false;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BusinessDetailScreen(businessId: business['id']),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
              child: hero != null && hero.toString().isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: hero,
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                          height: 140, color: const Color(0xFF1B4748)))
                  : Container(height: 140, color: const Color(0xFF1B4748)),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: const Color(0xFF1B4748),
              child: Text(name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFFF8BB25),
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  if (published) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _openEditBusiness(business),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1B4748)),
                        child: const Text('Edit'),
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
                                type: 'business',
                                item: business,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF8BB25),
                            foregroundColor: Colors.black87),
                        child: const Text('Feature'),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _deleteBusiness(business['id']),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF48900)),
                      child: const Text('Delete',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Tab 2 — Following ───────────────────────────────────────────────────

  Widget _followingTab() {
    if (_loadingFollowing) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF1B4748)));
    }
    if (_following.isEmpty) {
      return const Center(
          child: Text('You are not following any businesses.',
              style: TextStyle(color: Color(0xFF1B4748))));
    }
    return RefreshIndicator(
      onRefresh: _loadFollowing,
      color: const Color(0xFF1B4748),
      child: ListView.builder(
        itemCount: _following.length,
        itemBuilder: (context, index) => _followingCard(_following[index]),
      ),
    );
  }

  Widget _followingCard(Map<String, dynamic> business) {
    final name = business['name'] ?? '';
    final hero = business['hero'];
    final hasUpdates = business['has_updates'] ?? false;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BusinessDetailScreen(businessId: business['id']),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(8)),
                  child: hero != null && hero.toString().isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: hero,
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                              height: 140, color: const Color(0xFF1B4748)))
                      : Container(height: 140, color: const Color(0xFF1B4748)),
                ),
                if (hasUpdates)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8BB25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Updated',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: const Color(0xFF1B4748),
              child: Text(name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFFF8BB25),
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _unfollow(business['id']),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1B4748)),
                      child: const Text('Unfollow'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Tab 3 — All Businesses ──────────────────────────────────────────────

  Widget _allBusinessesTab() {
    return Column(
      children: [
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
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final isSelected = _selectedCategory == cat['id'];
                      return GestureDetector(
                        onTap: () {
                          final category = _categories.firstWhere(
                              (c) => c['id'] == cat['id'],
                              orElse: () => {});
                          setState(() {
                            _selectedCategory = cat['id'];
                            _subcategories = category['sub_categories'] ?? [];
                            _businesses = [];
                            _currentPage = 1;
                            _filterSubcategory = null;
                          });
                          _loadBusinesses(refresh: true);
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
                          child: Text(cat['name'] ?? '',
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
              if (_selectedCategory != null)
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
        if (_hasActiveFilters)
          Container(
            height: 40,
            color: Colors.grey.shade50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              children: [
                if (_filterSubcategory != null)
                  ActiveFilterChip(
                    label: _subcategories.firstWhere(
                            (s) => s['id'] == _filterSubcategory,
                            orElse: () => {'name': 'Sub Cat'})['name'] ??
                        '',
                    onRemove: () {
                      setState(() => _filterSubcategory = null);
                      _loadBusinesses(refresh: true);
                    },
                  ),
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
                      _loadBusinesses(refresh: true);
                    },
                  ),
                if (_filterCity != null)
                  ActiveFilterChip(
                    label: _cities.firstWhere((c) => c['id'] == _filterCity,
                            orElse: () => {'name': 'City'})['name'] ??
                        '',
                    onRemove: () {
                      setState(() {
                        _filterCity = null;
                        _filterArea = null;
                      });
                      _loadBusinesses(refresh: true);
                    },
                  ),
                if (_filterArea != null)
                  ActiveFilterChip(
                    label: _areas.firstWhere((a) => a['id'] == _filterArea,
                            orElse: () => {'name': 'Area'})['name'] ??
                        '',
                    onRemove: () {
                      setState(() => _filterArea = null);
                      _loadBusinesses(refresh: true);
                    },
                  ),
                if (_filterBusinessType != null)
                  ActiveFilterChip(
                    label: _typeLabels[_filterBusinessType] ??
                        _filterBusinessType!,
                    onRemove: () {
                      setState(() => _filterBusinessType = null);
                      _loadBusinesses(refresh: true);
                    },
                  ),
                if (_filterBusinessSize != null)
                  ActiveFilterChip(
                    label: _sizeLabels[_filterBusinessSize] ??
                        _filterBusinessSize!,
                    onRemove: () {
                      setState(() => _filterBusinessSize = null);
                      _loadBusinesses(refresh: true);
                    },
                  ),
              ],
            ),
          ),
        if (_totalCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: Colors.grey.shade50,
            child: Row(
              children: [
                Text('$_totalCount businesses found',
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black45)),
              ],
            ),
          ),
        Expanded(
          child: _selectedCategory == null
              ? const Center(
                  child: Text('Select a category above to start',
                      style: TextStyle(color: Color(0xFF1B4748))))
              : _loadingAll && _businesses.isEmpty
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF1B4748)))
                  : _businesses.isEmpty
                      ? const Center(
                          child: Text('No businesses found',
                              style: TextStyle(color: Color(0xFF1B4748))))
                      : RefreshIndicator(
                          onRefresh: () => _loadBusinesses(refresh: true),
                          color: const Color(0xFF1B4748),
                          child: ListView.builder(
                            controller: _scrollController,
                            itemCount: _businesses.length + (_hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _businesses.length) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(
                                        color: Color(0xFF1B4748)),
                                  ),
                                );
                              }
                              return _businessCard(_businesses[index]);
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _businessCard(Map<String, dynamic> business) {
    final name = business['name'] ?? '';
    final logo = business['logo'];
    final description = business['description'] ?? '';
    final categories = business['categories'] as List? ?? [];

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BusinessDetailScreen(businessId: business['id']),
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
                            color: Color(0xFF1B4748))),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description.length > 80
                            ? '${description.substring(0, 80)}...'
                            : description,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54),
                      ),
                    ],
                    if (categories.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        categories
                            .map((c) => c['name']?.toString() ?? '')
                            .join(', '),
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black45),
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

  Widget _logoPlaceholder() => Container(
        width: 70,
        height: 70,
        color: const Color(0xFF1B4748).withValues(alpha: 0.1),
        child: const Icon(Icons.business, color: Color(0xFF1B4748), size: 32),
      );
}
