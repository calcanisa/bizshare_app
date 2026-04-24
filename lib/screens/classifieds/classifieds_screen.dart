import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../widgets/filter_chip_bar.dart';
import '../classifieds/classified_screen.dart';
import '../classifieds/add_classified.dart';

class ClassifiedsScreen extends StatefulWidget {
  const ClassifiedsScreen({super.key});

  @override
  State<ClassifiedsScreen> createState() => _ClassifiedsScreenState();
}

class _ClassifiedsScreenState extends State<ClassifiedsScreen> {
  int _tab = 1;

  // Tab 1 - My Ads
  List<dynamic> _myAds = [];
  bool _loadingMine = false;

  // Tab 2 - All Ads
  List<dynamic> _topCategories = [];
  List<dynamic> _ads = [];
  bool _loadingAll = false;
  bool _hasMore = false;
  int _currentPage = 1;
  int _totalCount = 0;
  int? _selectedCategory;
  final ScrollController _scrollController = ScrollController();

  // Filter state
  List<dynamic> _provinces = [];
  List<dynamic> _cities = [];
  List<dynamic> _areas = [];
  List<dynamic> _subcategories = [];
  int? _filterSubcategory;
  int? _filterProvince;
  int? _filterCity;
  int? _filterArea;
  double? _filterMinPrice;
  double? _filterMaxPrice;

  // Temp filter state
  int? _tempSubcategory;
  int? _tempProvince;
  int? _tempCity;
  int? _tempArea;
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();

  bool get _hasActiveFilters =>
      _filterSubcategory != null ||
      _filterProvince != null ||
      _filterMinPrice != null ||
      _filterMaxPrice != null;

  @override
  void initState() {
    super.initState();
    _loadMyAds();
    _loadTopCategories();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        if (!_loadingAll && _hasMore) _loadMoreAds();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  Future<void> _loadMyAds() async {
    setState(() => _loadingMine = true);
    try {
      final api = context.read<ApiService>();
      final accountRes = await api.dio.get('/api/v1/users/current/');
      final userId = accountRes.data['id'];
      final response = await api.dio.get('/api/v1/classifieds/user/$userId/');
      setState(() => _myAds = response.data ?? []);
    } catch (_) {}
    setState(() => _loadingMine = false);
  }

  Future<void> _loadTopCategories() async {
    try {
      final api = context.read<ApiService>();
      final response = await api.dio.get('/api/v1/classifieds/categories/top/');
      final data = response.data;
      setState(
          () => _topCategories = data is List ? data : (data['results'] ?? []));
    } catch (_) {}
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
      final response =
          await api.dio.get('/api/v1/locations/cities/?province=$provinceId');
      setState(() => _cities = response.data['results'] ?? response.data ?? []);
    } catch (_) {}
  }

  Future<void> _loadAreas(int cityId) async {
    try {
      final api = context.read<ApiService>();
      final response =
          await api.dio.get('/api/v1/locations/areas/?city=$cityId');
      setState(() => _areas = response.data['results'] ?? response.data ?? []);
    } catch (_) {}
  }

  Future<void> _loadAds({bool refresh = false}) async {
    if (_loadingAll || _selectedCategory == null) return;
    if (refresh) {
      setState(() {
        _ads = [];
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
      if (_filterMinPrice != null) params['min_price'] = _filterMinPrice;
      if (_filterMaxPrice != null) params['max_price'] = _filterMaxPrice;

      final response = await api.dio
          .get('/api/v1/classifieds/filter/', queryParameters: params);
      final results = response.data['results'] as List? ?? [];
      setState(() {
        _ads.addAll(results);
        _currentPage++;
        _hasMore = response.data['next'] != null;
        _totalCount = response.data['count'] ?? 0;
      });
    } catch (_) {}
    setState(() => _loadingAll = false);
  }

  Future<void> _loadMoreAds() async => await _loadAds();

  Future<void> _deleteAd(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Ad'),
        content: const Text(
            'Are you sure you want to delete this ad? This cannot be undone.'),
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
      await api.dio.delete('/api/v1/classifieds/$id/d/');
      setState(() => _myAds.removeWhere((a) => a['id'] == id));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Ad deleted')));
      }
    } catch (_) {}
  }

  Future<void> _renewAd(int id) async {
    try {
      final api = context.read<ApiService>();
      await api.dio.post('/api/v1/classifieds/$id/r/');
      await _loadMyAds();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Ad renewed')));
      }
    } catch (_) {}
  }

  void _openAddAd() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddClassifiedModal(
          action: 'add',
          onSave: (data) {
            Navigator.pop(context);
            setState(() => _myAds.insert(0, data));
          },
          onCancel: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _openEditAd(Map<String, dynamic> ad) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddClassifiedModal(
          action: 'edit',
          ad: ad,
          onSave: (data) {
            Navigator.pop(context);
            final i = _myAds.indexWhere((a) => a['id'] == data['id']);
            if (i != -1) setState(() => _myAds[i] = data);
          },
          onCancel: () => Navigator.pop(context),
        ),
      ),
    );
  }

  bool _isExpired(Map<String, dynamic> ad) {
    final createdAt = ad['created_at'];
    if (createdAt == null) return false;
    final created = DateTime.tryParse(createdAt);
    if (created == null) return false;
    final expiry = DateTime(created.year, created.month + 1, created.day);
    return DateTime.now().isAfter(expiry);
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '';
    return 'R${price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

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

  void _openFilterSheet() async {
    await _loadProvinces();
    _tempSubcategory = _filterSubcategory;
    _tempProvince = _filterProvince;
    _tempCity = _filterCity;
    _tempArea = _filterArea;
    _minPriceController.text = _filterMinPrice?.toStringAsFixed(0) ?? '';
    _maxPriceController.text = _filterMaxPrice?.toStringAsFixed(0) ?? '';

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
                      const Text('Filter Ads',
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
                            _minPriceController.clear();
                            _maxPriceController.clear();
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
                      _filterLabel('Price Range'),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _minPriceController,
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
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _maxPriceController,
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
                          _filterSubcategory = _tempSubcategory;
                          _filterProvince = _tempProvince;
                          _filterCity = _tempCity;
                          _filterArea = _tempArea;
                          _filterMinPrice = _minPriceController.text.isNotEmpty
                              ? double.tryParse(_minPriceController.text)
                              : null;
                          _filterMaxPrice = _maxPriceController.text.isNotEmpty
                              ? double.tryParse(_maxPriceController.text)
                              : null;
                        });
                        Navigator.pop(context);
                        _loadAds(refresh: true);
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
              _tabBtn(1, 'My Ads'),
              _tabBtn(2, 'All Ads'),
            ],
          ),
        ),
        Expanded(
          child: _tab == 1 ? _myAdsTab() : _allAdsTab(),
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

  Widget _myAdsTab() {
    if (_loadingMine) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF094a25)));
    }

    final currentAds = _myAds.where((a) => !_isExpired(a)).toList();
    final expiredAds = _myAds.where((a) => _isExpired(a)).toList();

    if (_myAds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('You have not created any ads.',
                style: TextStyle(color: Color(0xFF094a25))),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _openAddAd,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF094a25)),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Create Ad',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMyAds,
      color: const Color(0xFF094a25),
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: ElevatedButton.icon(
              onPressed: _openAddAd,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF094a25),
                  padding: const EdgeInsets.symmetric(vertical: 12)),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Create New Ad',
                  style: TextStyle(color: Colors.white)),
            ),
          ),
          if (currentAds.isNotEmpty) ...[
            _listHeader('Current Classifieds'),
            ...currentAds.map((ad) => _myAdCard(ad, expired: false)),
          ],
          if (expiredAds.isNotEmpty) ...[
            _listHeader('Expired Classifieds'),
            ...expiredAds.map((ad) => _myAdCard(ad, expired: true)),
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

  Widget _myAdCard(Map<String, dynamic> ad, {required bool expired}) {
    final title = ad['title'] ?? '';
    final images = ad['images'] as List? ?? [];
    final defaultImage = images.firstWhere((i) => i['default'] == true,
        orElse: () => images.isNotEmpty ? images[0] : null);
    final imageUrl = defaultImage?['image'];
    final price = ad['price'];
    final createdAt = ad['created_at'];
    String location = '';
    if (ad['area'] != null) {
      location =
          '${ad['area']['city']['province']['name']} / ${ad['area']['city']['name']} / ${ad['area']['name']}';
    } else if (ad['city'] != null) {
      location = '${ad['city']['province']['name']} / ${ad['city']['name']}';
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ClassifiedDetailScreen(adId: ad['id']),
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
                child: imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        width: 90,
                        height: 90,
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
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF094a25))),
                    if (price != null) ...[
                      const SizedBox(height: 4),
                      Text(_formatPrice(price),
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFbc2023))),
                    ],
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 12, color: Colors.black45),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(location,
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.black45),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ],
                    if (createdAt != null) ...[
                      const SizedBox(height: 4),
                      Text('Placed: ${_formatDate(createdAt)}',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.black45)),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (!expired) ...[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {},
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF094a25),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4)),
                              child: const Text('Edit',
                                  style: TextStyle(fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (expired) ...[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _renewAd(ad['id']),
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF094a25),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4)),
                              child: const Text('Renew',
                                  style: TextStyle(fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _deleteAd(ad['id']),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFbc2023),
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _allAdsTab() {
    return Column(
      children: [
        // Category + Filter bar
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
                    itemCount: _topCategories.length,
                    itemBuilder: (context, index) {
                      final cat = _topCategories[index];
                      final isSelected = _selectedCategory == cat['id'];
                      return GestureDetector(
                        onTap: () {
                          final category = _topCategories.firstWhere(
                              (c) => c['id'] == cat['id'],
                              orElse: () => {});
                          setState(() {
                            _selectedCategory = cat['id'];
                            _subcategories = category['sub_categories'] ?? [];
                            _ads = [];
                            _currentPage = 1;
                            _filterSubcategory = null;
                          });
                          _loadAds(refresh: true);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF094a25)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: const Color(0xFF094a25), width: 1),
                          ),
                          child: Text(cat['name'] ?? '',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF094a25))),
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
        // Active filter chips
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
                      _loadAds(refresh: true);
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
                      _loadAds(refresh: true);
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
                      _loadAds(refresh: true);
                    },
                  ),
                if (_filterArea != null)
                  ActiveFilterChip(
                    label: _areas.firstWhere((a) => a['id'] == _filterArea,
                            orElse: () => {'name': 'Area'})['name'] ??
                        '',
                    onRemove: () {
                      setState(() => _filterArea = null);
                      _loadAds(refresh: true);
                    },
                  ),
                if (_filterMinPrice != null)
                  ActiveFilterChip(
                    label: 'Min: R${_filterMinPrice!.toStringAsFixed(0)}',
                    onRemove: () {
                      setState(() => _filterMinPrice = null);
                      _loadAds(refresh: true);
                    },
                  ),
                if (_filterMaxPrice != null)
                  ActiveFilterChip(
                    label: 'Max: R${_filterMaxPrice!.toStringAsFixed(0)}',
                    onRemove: () {
                      setState(() => _filterMaxPrice = null);
                      _loadAds(refresh: true);
                    },
                  ),
              ],
            ),
          ),
        if (_totalCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: Colors.grey.shade50,
            child: Text('$_totalCount ads found',
                style: const TextStyle(fontSize: 12, color: Colors.black45)),
          ),
        Expanded(
          child: _selectedCategory == null
              ? const Center(
                  child: Text('Select a category above to start',
                      style: TextStyle(color: Color(0xFF094a25))))
              : _loadingAll && _ads.isEmpty
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF094a25)))
                  : _ads.isEmpty
                      ? const Center(
                          child: Text('No ads in this category at the moment',
                              style: TextStyle(color: Color(0xFF094a25))))
                      : RefreshIndicator(
                          onRefresh: () => _loadAds(refresh: true),
                          color: const Color(0xFF094a25),
                          child: ListView.builder(
                            controller: _scrollController,
                            itemCount: _ads.length + (_hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _ads.length) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(
                                        color: Color(0xFF094a25)),
                                  ),
                                );
                              }
                              return _adCard(_ads[index]);
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _adCard(Map<String, dynamic> ad) {
    final title = ad['title'] ?? '';
    final images = ad['images'] as List? ?? [];
    final defaultImage = images.firstWhere((i) => i['default'] == true,
        orElse: () => images.isNotEmpty ? images[0] : null);
    final imageUrl = defaultImage?['image'];
    final price = ad['price'];
    final createdAt = ad['created_at'];
    final category = ad['category'];
    String location = '';
    if (ad['area'] != null) {
      location =
          '${ad['area']['city']['province']['name']} / ${ad['area']['city']['name']} / ${ad['area']['name']}';
    } else if (ad['city'] != null) {
      location = '${ad['city']['province']['name']} / ${ad['city']['name']}';
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ClassifiedDetailScreen(adId: ad['id']),
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
                child: imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        width: 90,
                        height: 90,
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
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF094a25))),
                    if (price != null) ...[
                      const SizedBox(height: 4),
                      Text(_formatPrice(price),
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFbc2023))),
                    ],
                    if (category != null && category['parent'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                          '${category['parent']['name']} / ${category['name']}',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.black45)),
                    ],
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 12, color: Colors.black45),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(location,
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.black45),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ],
                    if (createdAt != null) ...[
                      const SizedBox(height: 4),
                      Text('Placed: ${_formatDate(createdAt)}',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.black45)),
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
        width: 90,
        height: 90,
        color: const Color(0xFF094a25).withValues(alpha: 0.1),
        child:
            const Icon(Icons.sell_outlined, color: Color(0xFF094a25), size: 32),
      );
}
