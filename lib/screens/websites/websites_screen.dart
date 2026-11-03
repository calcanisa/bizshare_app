import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import '../websites/website_screen.dart';
import 'add_website.dart';

class WebsitesScreen extends StatefulWidget {
  const WebsitesScreen({super.key});

  @override
  State<WebsitesScreen> createState() => _WebsitesScreenState();
}

class _WebsitesScreenState extends State<WebsitesScreen> {
  int? _accountId;
  String? _membershipType;
  bool _loadingAccount = true;

  int _tab = 1;

  List<dynamic> _myListings = [];
  bool _loadingMine = false;

  List<dynamic> _allListings = [];
  bool _loadingAll = false;
  int _currentPage = 1;
  int _totalCount = 0;
  bool _hasNext = false;
  bool _hasPrev = false;
  int _selectedPageSize = 20;
  String _selectedOrdering = 'title-asc';

  List<dynamic> _types = [];
  List<dynamic> _categories = [];

  int? _filterType;
  int? _filterCategory;
  int? _tempType;
  int? _tempCategory;

  bool get _hasActiveFilters => _filterType != null || _filterCategory != null;

  int get _webLimit {
    switch (_membershipType) {
      case 'silverM':
      case 'silverY':
        return 10;
      case 'goldM':
      case 'goldY':
        return 15;
      default:
        return 5;
    }
  }

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
      setState(() {
        _accountId = data['id'];
        _membershipType = membership?['mem_type'];
        _loadingAccount = false;
      });
    } catch (_) {
      setState(() => _loadingAccount = false);
    }
    _loadMyListings();
  }

  Future<void> _loadMyListings() async {
    setState(() => _loadingMine = true);
    try {
      final api = context.read<ApiService>();
      final response = await api.dio.get('/api/v1/websites/current/');
      final data = response.data;
      setState(
          () => _myListings = data is List ? data : (data['results'] ?? []));
    } catch (_) {
      _showSnack('Could not load your listings. Try again.');
    }
    setState(() => _loadingMine = false);
  }

  Future<void> _fetchAllListings({int page = 1}) async {
    if (_loadingAll) return;
    setState(() => _loadingAll = true);
    try {
      final api = context.read<ApiService>();
      final params = <String, dynamic>{
        'page_size': _selectedPageSize,
        'ordering': _selectedOrdering,
      };
      if (page > 1) params['page'] = page;
      if (_filterType != null) params['web_type'] = _filterType;
      if (_filterCategory != null) params['category'] = _filterCategory;

      final response = await api.dio
          .get('/api/v1/websites/filter/', queryParameters: params);
      setState(() {
        _allListings = response.data['results'] as List? ?? [];
        _totalCount = response.data['count'] ?? 0;
        _hasNext = response.data['next'] != null;
        _hasPrev = response.data['previous'] != null;
        _currentPage = page;
      });
    } catch (_) {
      _showSnack('Could not load websites. Try again.');
    }
    setState(() => _loadingAll = false);
  }

  Future<void> _loadFilterData() async {
    try {
      final api = context.read<ApiService>();
      if (_types.isEmpty) {
        final res = await api.dio.get('/api/v1/websites/types/');
        final data = res.data;
        setState(() => _types = data is List ? data : (data['results'] ?? []));
      }
      if (_categories.isEmpty) {
        final res = await api.dio.get('/api/v1/websites/categories/');
        final data = res.data;
        setState(
            () => _categories = data is List ? data : (data['results'] ?? []));
      }
    } catch (_) {}
  }

  Future<void> _deleteListing(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Listing'),
        content: const Text('Are you sure you want to delete this listing?'),
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
      await api.dio.delete('/api/v1/websites/d/$id/');
      setState(() {
        _myListings.removeWhere((l) => l['id'] == id);
        _allListings.removeWhere((l) => l['id'] == id);
      });
      _showSnack('Listing deleted successfully');
    } catch (_) {
      _showSnack('Could not delete listing. Try again.');
    }
  }

  Future<void> _openAddWebsite() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddWebsiteScreen(
          action: 'add',
          count: _myListings.length,
          limit: _webLimit,
        ),
      ),
    );
    if (result != null && mounted) _loadMyListings();
  }

  Future<void> _openEditWebsite(Map<String, dynamic> listing) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddWebsiteScreen(
          action: 'edit',
          listing: listing,
        ),
      ),
    );
    if (result != null && mounted) _loadMyListings();
  }

  Future<void> _openUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showSnack('Could not open URL');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _openFilterSheet() async {
    await _loadFilterData();
    _tempType = _filterType;
    _tempCategory = _filterCategory;
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
          initialChildSize: 0.55,
          maxChildSize: 0.85,
          minChildSize: 0.35,
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
                      const Text('Filter Websites',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setSheetState(() {
                          _tempType = null;
                          _tempCategory = null;
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
                      _filterLabel('Type'),
                      _filterDropdown<int>(
                        value: _tempType,
                        hint: 'All Types',
                        items: _types
                            .map((t) => DropdownMenuItem<int>(
                                  value: t['id'],
                                  child: Text(t['name'] ?? ''),
                                ))
                            .toList(),
                        onChanged: (v) => setSheetState(() => _tempType = v),
                      ),
                      const SizedBox(height: 16),
                      _filterLabel('Category'),
                      _filterDropdown<int>(
                        value: _tempCategory,
                        hint: 'All Categories',
                        items: _categories
                            .map((c) => DropdownMenuItem<int>(
                                  value: c['id'],
                                  child: Text(c['name'] ?? ''),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setSheetState(() => _tempCategory = v),
                      ),
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
                          _filterCategory = _tempCategory;
                        });
                        Navigator.pop(context);
                        _fetchAllListings(page: 1);
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

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loadingAccount) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF1B4748)));
    }
    return Column(
      children: [
        Container(
          color: const Color(0xFF1B4748),
          child: Row(
            children: [
              _tabBtn(1, 'Your Listings'),
              _tabBtn(2, 'All Listings'),
            ],
          ),
        ),
        Expanded(
          child: _tab == 1 ? _myListingsTab() : _allListingsTab(),
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
          if (index == 2 && _allListings.isEmpty) {
            _loadFilterData();
            _fetchAllListings(page: 1);
          }
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

  // ─── Tab 1 — Your Listings ────────────────────────────────────────────────

  Widget _myListingsTab() {
    if (_loadingMine) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF1B4748)));
    }

    final atLimit = _myListings.length >= _webLimit;

    return Column(
      children: [
        Container(
          color: Colors.grey.shade50,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text('${_myListings.length} / $_webLimit listings used',
                  style: const TextStyle(fontSize: 12, color: Colors.black45)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: atLimit ? null : _openAddWebsite,
                icon: const Icon(Icons.add, size: 16),
                label:
                    const Text('Add Website', style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      atLimit ? Colors.grey.shade400 : const Color(0xFFF8BB25),
                  foregroundColor: Colors.black87,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
            ],
          ),
        ),
        if (atLimit)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFF8BB25).withOpacity(0.15),
            child: Text(
                'You\'ve reached your $_webLimit listing limit. Upgrade your membership to add more.',
                style: const TextStyle(fontSize: 12, color: Colors.black87)),
          ),
        Expanded(
          child: _myListings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('You do not have any listings.',
                          style: TextStyle(color: Color(0xFF1B4748))),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _openAddWebsite,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B4748)),
                        child: const Text('Add One',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadMyListings,
                  color: const Color(0xFF1B4748),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _myListings.length,
                    itemBuilder: (context, index) => _myListingCard(
                        _myListings[index] as Map<String, dynamic>),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _myListingCard(Map<String, dynamic> listing) {
    final name = listing['name'] ?? '';
    final imageUrl = listing['image'];
    final type = listing['type'] as Map<String, dynamic>?;
    final category = listing['category'] as Map<String, dynamic>?;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WebsiteDetailScreen(websiteId: listing['id']),
        ),
      ),
      child: Container(
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
          child: Row(
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
                    Text(name,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B4748))),
                    const SizedBox(height: 4),
                    if (type != null) _metaRow('Type', type['name'] ?? ''),
                    if (category != null)
                      _metaRow('Category', category['name'] ?? ''),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _openEditWebsite(listing),
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
                          child: OutlinedButton(
                            onPressed: () {}, // TODO: feature
                            style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFF8BB25),
                                side:
                                    const BorderSide(color: Color(0xFFF8BB25)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4)),
                            child: const Text('Feature',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _deleteListing(listing['id']),
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Tab 2 — All Listings ─────────────────────────────────────────────────

  Widget _allListingsTab() {
    return Column(
      children: [
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
                    value: _selectedOrdering,
                    isDense: true,
                    style:
                        const TextStyle(fontSize: 12, color: Color(0xFF1B4748)),
                    items: const [
                      DropdownMenuItem(
                          value: 'title-asc', child: Text('Name A-Z')),
                      DropdownMenuItem(
                          value: 'title-des', child: Text('Name Z-A')),
                      DropdownMenuItem(
                          value: 'date-first', child: Text('Date First')),
                      DropdownMenuItem(
                          value: 'date-last', child: Text('Date Last')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _selectedOrdering = v);
                      _fetchAllListings(page: 1);
                    },
                  ),
                ),
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
                if (_filterType != null)
                  _activeChip(
                    _types.firstWhere((t) => t['id'] == _filterType,
                            orElse: () => {'name': 'Type'})['name'] ??
                        '',
                    () {
                      setState(() => _filterType = null);
                      _fetchAllListings(page: 1);
                    },
                  ),
                if (_filterCategory != null)
                  _activeChip(
                    _categories.firstWhere((c) => c['id'] == _filterCategory,
                            orElse: () => {'name': 'Category'})['name'] ??
                        '',
                    () {
                      setState(() => _filterCategory = null);
                      _fetchAllListings(page: 1);
                    },
                  ),
              ],
            ),
          ),
        if (_totalCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            color: Colors.grey.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$_totalCount websites found',
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
                          _fetchAllListings(page: 1);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        Expanded(
          child: _loadingAll
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF1B4748)))
              : _allListings.isEmpty
                  ? const Center(
                      child: Text('No websites to display',
                          style: TextStyle(color: Color(0xFF1B4748))))
                  : RefreshIndicator(
                      onRefresh: () => _fetchAllListings(page: 1),
                      color: const Color(0xFF1B4748),
                      child: ListView.builder(
                        itemCount: _allListings.length + 1,
                        itemBuilder: (context, index) {
                          if (index == _allListings.length) {
                            return _paginationBar();
                          }
                          return _allListingCard(
                              _allListings[index] as Map<String, dynamic>);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _allListingCard(Map<String, dynamic> listing) {
    final name = listing['name'] ?? '';
    final description = listing['description'] ?? '';
    final imageUrl = listing['image'];
    final type = listing['type'] as Map<String, dynamic>?;
    final category = listing['category'] as Map<String, dynamic>?;
    final url = listing['url'];
    final isOwner = _accountId != null &&
        listing['user'] is Map &&
        (listing['user'] as Map)['id'] == _accountId;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WebsiteDetailScreen(websiteId: listing['id']),
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
                        Text(name,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1B4748))),
                        const SizedBox(height: 5),
                        Text(
                            description.length > 100
                                ? '${description.substring(0, 100)}...'
                                : description,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black87)),
                        const SizedBox(height: 6),
                        if (type != null) _metaRow('Type', type['name'] ?? ''),
                        if (category != null)
                          _metaRow('Category', category['name'] ?? ''),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (url != null && url.toString().isNotEmpty)
                    GestureDetector(
                      onTap: () => _openUrl(url.toString()),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.open_in_new,
                              size: 14, color: Color(0xFF1B4748)),
                          SizedBox(width: 4),
                          Text('See Website',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF1B4748),
                                  decoration: TextDecoration.underline,
                                  decorationColor: Color(0xFF1B4748))),
                        ],
                      ),
                    ),
                  const Spacer(),
                  if (isOwner) ...[
                    OutlinedButton(
                      onPressed: () => _openEditWebsite(listing),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1B4748),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4)),
                      child: const Text('Edit', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton(
                      onPressed: () {}, // TODO: feature
                      style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFF8BB25),
                          side: const BorderSide(color: Color(0xFFF8BB25)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4)),
                      child:
                          const Text('Feature', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton(
                      onPressed: () => _deleteListing(listing['id']),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF48900),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4)),
                      child: const Text('Delete',
                          style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
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
            _pageBtn('First', () => _fetchAllListings(page: 1)),
            _pageBtn('‹ Prev', () => _fetchAllListings(page: _currentPage - 1)),
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
            _pageBtn('Next ›', () => _fetchAllListings(page: _currentPage + 1)),
            _pageBtn('Last', () => _fetchAllListings(page: totalPages)),
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
                      color: Color(0xFF1B4748))),
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

  Widget _imagePlaceholder() => Container(
        width: 80,
        height: 80,
        color: const Color(0xFF1B4748).withValues(alpha: 0.1),
        child: const Icon(Icons.language, color: Color(0xFF1B4748), size: 30),
      );
}
