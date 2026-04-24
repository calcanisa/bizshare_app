import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';

class WebsiteDetailScreen extends StatefulWidget {
  final int websiteId;
  const WebsiteDetailScreen({super.key, required this.websiteId});

  @override
  State<WebsiteDetailScreen> createState() => _WebsiteDetailScreenState();
}

class _WebsiteDetailScreenState extends State<WebsiteDetailScreen> {
  Map<String, dynamic>? _listing;
  bool _loading = true;
  int? _accountId;

  @override
  void initState() {
    super.initState();
    _loadAccount();
    _loadListing();
  }

  Future<void> _loadAccount() async {
    try {
      final api = context.read<ApiService>();
      final res = await api.dio.get('/api/v1/users/current/');
      setState(() => _accountId = res.data['id']);
    } catch (_) {}
  }

  Future<void> _loadListing() async {
    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      final res =
          await api.dio.get('/api/v1/websites/listing/${widget.websiteId}/');
      setState(() => _listing = res.data);
    } catch (_) {
      _showSnack('Could not load listing. Try again.');
    }
    setState(() => _loading = false);
  }

  bool get _isOwner {
    if (_accountId == null || _listing == null) return false;
    final user = _listing!['user'];
    if (user is Map) return user['id'] == _accountId;
    return user == _accountId;
  }

  Future<void> _deleteListing() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Listing'),
        content: const Text(
            'Are you sure you want to delete this listing? This cannot be undone.'),
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
      await api.dio.delete('/api/v1/websites/d/${widget.websiteId}/');
      _showSnack('Listing deleted successfully');
      if (mounted) Navigator.pop(context);
    } catch (_) {
      _showSnack('Could not delete listing. Try again.');
    }
  }

  Future<void> _openUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    String u = url;
    if (!u.startsWith('http')) u = 'https://$u';
    final uri = Uri.tryParse(u);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final name = _listing?['name'] ?? 'Website';
    final category = _listing?['category'] as Map?;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: const Color(0xFF094a25),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name.length > 40 ? '${name.substring(0, 40)}...' : name,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              overflow: TextOverflow.ellipsis,
            ),
            if (category != null)
              Text(
                category['name']?.toString() ?? '',
                style: const TextStyle(color: Color(0xFFf8b324), fontSize: 11),
              ),
          ],
        ),
        actions: [
          if (_listing != null) ...[
            if (_isOwner) ...[
              TextButton(
                onPressed: () {}, // TODO: edit modal
                child: const Text('Edit',
                    style: TextStyle(color: Color(0xFFf8b324), fontSize: 12)),
              ),
              TextButton(
                onPressed: _deleteListing,
                child: const Text('Delete',
                    style: TextStyle(color: Color(0xFFbc2023), fontSize: 12)),
              ),
            ] else
              TextButton(
                onPressed: () {}, // TODO: report
                child: const Text('Report',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ),
          ],
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF094a25)))
          : _listing == null
              ? const Center(child: Text('Listing not found'))
              : RefreshIndicator(
                  onRefresh: _loadListing,
                  color: const Color(0xFF094a25),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _typeBar(),
                        _imageSection(),
                        _detailsSection(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
    );
  }

  // ─── Type bar ─────────────────────────────────────────────────────────────

  Widget _typeBar() {
    final type = _listing?['type'] as Map?;
    final typeName = type?['name'] ?? '';
    if (typeName.isEmpty) return const SizedBox.shrink();
    return Container(
      color: Colors.black87,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        '$typeName Website',
        style: const TextStyle(
            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }

  // ─── Image ────────────────────────────────────────────────────────────────

  Widget _imageSection() {
    final image = _listing?['image'];
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: image != null && image.toString().isNotEmpty
            ? CachedNetworkImage(
                imageUrl: image,
                height: 220,
                width: double.infinity,
                fit: BoxFit.contain,
                errorWidget: (_, __, ___) => _imagePlaceholder())
            : _imagePlaceholder(),
      ),
    );
  }

  Widget _imagePlaceholder() => Container(
        height: 220,
        width: double.infinity,
        color: const Color(0xFF094a25).withValues(alpha: 0.1),
        child: const Icon(Icons.language, color: Color(0xFF094a25), size: 60),
      );

  // ─── Details ──────────────────────────────────────────────────────────────

  Widget _detailsSection() {
    final description = _listing?['description'] ?? '';
    final url = _listing?['url'];

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF094a25),
            child: const Text('Basic Info',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Description',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF094a25))),
                const SizedBox(height: 8),
                Text(description,
                    style: const TextStyle(
                        fontSize: 13, color: Colors.black87, height: 1.6)),
                if (url != null && url.toString().isNotEmpty) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _openUrl(url),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF094a25),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.open_in_new,
                          color: Colors.white, size: 18),
                      label: const Text('Visit the Website',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
