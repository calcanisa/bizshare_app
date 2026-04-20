import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/api_service.dart';
import 'package:provider/provider.dart';

class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({super.key});

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  List<dynamic> _businesses = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 1;
  String _search = '';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadBusinesses();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        if (!_isLoading && _hasMore) _loadBusinesses();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadBusinesses({bool refresh = false}) async {
    if (_isLoading) return;
    if (refresh) {
      setState(() {
        _businesses = [];
        _page = 1;
        _hasMore = true;
      });
    }
    setState(() => _isLoading = true);
    try {
      final api = context.read<ApiService>();
      final params = <String, dynamic>{'page': _page};
      if (_search.isNotEmpty) params['search'] = _search;
      final response = await api.dio.get('/api/v1/directory/businesses/', queryParameters: params);
      final results = response.data['results'] as List? ?? [];
      setState(() {
        _businesses.addAll(results);
        _page++;
        _hasMore = response.data['next'] != null;
      });
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search businesses...',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF094a25)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF094a25)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  ),
                  onSubmitted: (value) {
                    _search = value;
                    _loadBusinesses(refresh: true);
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  _search = _searchController.text;
                  _loadBusinesses(refresh: true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF094a25),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Search', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _loadBusinesses(refresh: true),
            color: const Color(0xFF094a25),
            child: _businesses.isEmpty && !_isLoading
                ? const Center(child: Text('No businesses found'))
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _businesses.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _businesses.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(color: Color(0xFF094a25)),
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
    final logo = business['logo'];
    final name = business['name'] ?? '';
    final description = business['description'] ?? '';
    final branches = business['branches'] as List? ?? [];
    String location = '';
    if (branches.isNotEmpty) {
      final branch = branches[0];
      final city = branch['city']?['name'] ?? branch['area']?['city']?['name'] ?? '';
      final province = branch['city']?['province']?['name'] ?? branch['area']?['city']?['province']?['name'] ?? '';
      if (city.isNotEmpty) location = '$province / $city';
    }
    final categories = business['categories'] as List? ?? [];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: logo != null
                  ? CachedNetworkImage(
                      imageUrl: logo,
                      width: 70, height: 70,
                      fit: BoxFit.contain,
                      placeholder: (_, __) => _logoPlaceholder(),
                      errorWidget: (_, __, ___) => _logoPlaceholder(),
                    )
                  : _logoPlaceholder(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF094a25))),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description.length > 100 ? '${description.substring(0, 100)}...' : description,
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                  if (location.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 12, color: Colors.black45),
                        const SizedBox(width: 2),
                        Text(location, style: const TextStyle(fontSize: 11, color: Colors.black45)),
                      ],
                    ),
                  ],
                  if (categories.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: categories.take(3).map((cat) {
                        final catName = cat['name'] ?? '';
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF094a25),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(catName, style: const TextStyle(color: Colors.white, fontSize: 10)),
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

  Widget _logoPlaceholder() {
    return Container(
      width: 70, height: 70,
      color: const Color(0xFF094a25).withOpacity(0.1),
      child: const Icon(Icons.business, color: Color(0xFF094a25), size: 32),
    );
  }
}