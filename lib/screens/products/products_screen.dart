import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  int _tab = 1;

  // Tab 1 — All Products
  List<dynamic> _products = [];
  bool _loadingProducts = false;
  int _currentPage = 1;
  int _totalCount = 0;
  bool _hasNext = false;
  bool _hasPrev = false;
  int _selectedPageSize = 20;
  String _ordering = 'date-last';

  // Tab 2 — Your Requests
  List<dynamic> _requests = [];
  bool _loadingRequests = false;

  // Filter reference data
  List<dynamic> _categories = [];
  List<dynamic> _subcategories = [];

  // Applied filters
  int? _filterCategory;
  int? _filterSubcategory;
  String _filterMinPrice = '';
  String _filterMaxPrice = '';

  // Temp filter state (in-sheet)
  int? _tempCategory;
  int? _tempSubcategory;
  final _minPriceController = TextEditingController();
  final _maxPriceController = TextEditingController();

  bool get _hasActiveFilters =>
      _filterCategory != null ||
      _filterSubcategory != null ||
      _filterMinPrice.isNotEmpty ||
      _filterMaxPrice.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _fetchProducts(page: 1);
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    if (_categories.isNotEmpty) return;
    try {
      final api = context.read<ApiService>();
      final res = await api.dio.get('/api/v1/directory/categories/');
      final data = res.data;
      setState(
          () => _categories = data is List ? data : (data['results'] ?? []));
    } catch (_) {}
  }

  Future<void> _fetchProducts({int page = 1}) async {
    if (_loadingProducts) return;
    setState(() => _loadingProducts = true);
    try {
      final api = context.read<ApiService>();
      final params = <String, dynamic>{
        'ordering': _ordering,
        'page_size': _selectedPageSize,
      };
      if (page > 1) params['page'] = page;
      if (_filterCategory != null) params['category'] = _filterCategory;
      if (_filterSubcategory != null) {
        params['subcategory'] = _filterSubcategory;
      }
      if (_filterMinPrice.isNotEmpty) params['min_price'] = _filterMinPrice;
      if (_filterMaxPrice.isNotEmpty) params['max_price'] = _filterMaxPrice;

      final res = await api.dio
          .get('/api/v1/directory/products/', queryParameters: params);
      final data = res.data;
      setState(() {
        _products = data['results'] as List? ?? [];
        _totalCount = data['count'] ?? 0;
        _hasNext = data['next'] != null;
        _hasPrev = data['previous'] != null;
        _currentPage = page;
        if (data['subcategories'] != null) {
          _subcategories = data['subcategories'] as List;
        }
      });
    } catch (_) {
      _showSnack('Could not load products. Try again.');
    }
    setState(() => _loadingProducts = false);
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
      // Only product requests (have product_name)
      setState(() => _requests =
          (all as List).where((r) => r['product_name'] != null).toList());
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

  void _openFilterSheet() async {
    await _loadCategories();
    _tempCategory = _filterCategory;
    _tempSubcategory = _filterSubcategory;
    _minPriceController.text = _filterMinPrice;
    _maxPriceController.text = _filterMaxPrice;

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
        final tempSubs = _tempCategory == null
            ? <dynamic>[]
            : _subcategories
                .where((s) => s['parent'] == _tempCategory)
                .toList();

        return DraggableScrollableSheet(
          initialChildSize: 0.7,
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
                    color: Color(0xFF094a25),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      const Text('Filter Products',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setSheetState(() {
                          _tempCategory = null;
                          _tempSubcategory = null;
                          _minPriceController.clear();
                          _maxPriceController.clear();
                        }),
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
                        onChanged: (v) {
                          setSheetState(() {
                            _tempCategory = v;
                            _tempSubcategory = null;
                          });
                        },
                      ),
                      if (tempSubs.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _filterDropdown<int>(
                          value: _tempSubcategory,
                          hint: 'All Subcategories',
                          items: tempSubs
                              .map((s) => DropdownMenuItem<int>(
                                    value: s['id'],
                                    child: Text(s['name'] ?? ''),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setSheetState(() => _tempSubcategory = v),
                        ),
                      ],
                      const SizedBox(height: 16),
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
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text('—',
                                style: TextStyle(color: Color(0xFF094a25))),
                          ),
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
                          _filterCategory = _tempCategory;
                          _filterSubcategory = _tempSubcategory;
                          _filterMinPrice = _minPriceController.text.trim();
                          _filterMaxPrice = _maxPriceController.text.trim();
                        });
                        Navigator.pop(context);
                        _fetchProducts(page: 1);
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
          color: const Color(0xFF094a25),
          child: Row(
            children: [
              _tabBtn(1, 'All Products'),
              _tabBtn(2, 'Your Requests'),
            ],
          ),
        ),
        Expanded(
          child: _tab == 1 ? _allProductsTab() : _requestsTab(),
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

  // ─── Tab 1 — All Products ────────────────────────────────────────────────

  Widget _allProductsTab() {
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
                          value: 'price-low', child: Text('Price Low–High')),
                      DropdownMenuItem(
                          value: 'price-high', child: Text('Price High–Low')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _ordering = v);
                      _fetchProducts(page: 1);
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
                if (_filterCategory != null)
                  _activeChip(
                    _categories.firstWhere((c) => c['id'] == _filterCategory,
                            orElse: () => {'name': 'Category'})['name'] ??
                        '',
                    () {
                      setState(() {
                        _filterCategory = null;
                        _filterSubcategory = null;
                      });
                      _fetchProducts(page: 1);
                    },
                  ),
                if (_filterSubcategory != null)
                  _activeChip(
                    _subcategories.firstWhere(
                            (s) => s['id'] == _filterSubcategory,
                            orElse: () => {'name': 'Subcategory'})['name'] ??
                        '',
                    () {
                      setState(() => _filterSubcategory = null);
                      _fetchProducts(page: 1);
                    },
                  ),
                if (_filterMinPrice.isNotEmpty)
                  _activeChip('Min: R$_filterMinPrice', () {
                    setState(() => _filterMinPrice = '');
                    _fetchProducts(page: 1);
                  }),
                if (_filterMaxPrice.isNotEmpty)
                  _activeChip('Max: R$_filterMaxPrice', () {
                    setState(() => _filterMaxPrice = '');
                    _fetchProducts(page: 1);
                  }),
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
                Text('$_totalCount products found',
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
                          _fetchProducts(page: 1);
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
          child: _loadingProducts
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF094a25)))
              : _products.isEmpty
                  ? const Center(
                      child: Text('No products found',
                          style: TextStyle(color: Color(0xFF094a25))))
                  : RefreshIndicator(
                      onRefresh: () => _fetchProducts(page: 1),
                      color: const Color(0xFF094a25),
                      child: ListView.builder(
                        itemCount: _products.length + 1,
                        itemBuilder: (context, index) {
                          if (index == _products.length) {
                            return _paginationBar();
                          }
                          return _productCard(
                              _products[index] as Map<String, dynamic>);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _productCard(Map<String, dynamic> product) {
    final title = product['title'] ?? '';
    final description = product['description'] ?? '';
    final imageUrl = product['image'];
    final price = product['price'];
    final category = product['category'] as Map<String, dynamic>?;
    final business = product['business'] as Map<String, dynamic>?;
    final url = product['url'];

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
            // Image
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
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF094a25))),
                  const SizedBox(height: 4),
                  if (description.isNotEmpty) ...[
                    Text(
                        description.length > 80
                            ? '${description.substring(0, 80)}...'
                            : description,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54)),
                    const SizedBox(height: 6),
                  ],
                  if (price != null) _metaRow('Price', 'R$price'),
                  if (category != null)
                    _metaRow('Category', category['name'] ?? ''),
                  if (business != null)
                    _metaRow('Company', business['name'] ?? ''),
                  if (url != null && url.toString().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => _openUrl(url.toString()),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.open_in_new,
                              size: 13, color: Color(0xFF094a25)),
                          SizedBox(width: 4),
                          Text('View on Website',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF094a25),
                                  decoration: TextDecoration.underline,
                                  decorationColor: Color(0xFF094a25))),
                        ],
                      ),
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

  // ─── Tab 2 — Your Requests ───────────────────────────────────────────────

  Widget _requestsTab() {
    return Column(
      children: [
        // Add request button bar
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
                  backgroundColor: const Color(0xFFf8b324),
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
                  child: CircularProgressIndicator(color: Color(0xFF094a25)))
              : _requests.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                              'You have not submitted any product requests.',
                              style: TextStyle(color: Color(0xFF094a25))),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () {}, // TODO: open add request modal
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF094a25)),
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
                      color: const Color(0xFF094a25),
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
    final productName = request['product_name'] ?? '';
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
            Text(productName,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF094a25))),
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
                    onPressed: () {}, // TODO: open edit request modal
                    style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF094a25),
                        padding: const EdgeInsets.symmetric(vertical: 4)),
                    child: const Text('Edit', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
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
            _pageBtn('First', () => _fetchProducts(page: 1)),
            _pageBtn('‹ Prev', () => _fetchProducts(page: _currentPage - 1)),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF094a25).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('Page $_currentPage of $totalPages',
                style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF094a25),
                    fontWeight: FontWeight.bold)),
          ),
          if (_hasNext) ...[
            _pageBtn('Next ›', () => _fetchProducts(page: _currentPage + 1)),
            _pageBtn('Last', () => _fetchProducts(page: totalPages)),
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
          color: const Color(0xFF094a25).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: const Color(0xFF094a25).withValues(alpha: 0.3)),
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
        width: 90,
        height: 90,
        color: const Color(0xFF094a25).withValues(alpha: 0.1),
        child: const Icon(Icons.shopping_bag_outlined,
            color: Color(0xFF094a25), size: 32),
      );
}
