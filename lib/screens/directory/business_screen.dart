import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import 'dart:convert';
import '../directory/add_company_post.dart';
import '../../providers/auth_provider.dart';
import '../directory/add_product.dart';
import '../report_screen.dart';
import '../add_social.dart';
import 'package:dio/dio.dart';
import 'add_business_service.dart';
import 'add_business_review.dart';
import '../gallery/add_video_gallery.dart';
import '../gallery/add_picture_gallery.dart';
import '../mail/send_message.dart';
import '../feature_content.dart';

class BusinessDetailScreen extends StatefulWidget {
  final int businessId;

  const BusinessDetailScreen({super.key, required this.businessId});

  @override
  State<BusinessDetailScreen> createState() => _BusinessDetailScreenState();
}

class _BusinessDetailScreenState extends State<BusinessDetailScreen> {
  Map<String, dynamic>? _business;
  bool _loading = true;
  int? _accountId;

  // Tabs
  int _bizTab = 1;
  List<dynamic> _posts = [];
  // Reviews
  List<dynamic> _reviews = [];
  int _reviewsPage = 1;
  int _reviewsTotalPages = 1;
  bool _loadingReviews = false;
  int? _replyingTo;
  final _replyController = TextEditingController();

  // Contact tab
  bool _showPhone = false;
  bool _showWhats = false;

  // Gallery lightbox
  List<dynamic> _lightboxImages = [];
  int _lightboxIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadBusiness();
    _loadAccount();
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  int? _productLimit;

  Future<void> _loadAccount() async {
    try {
      final api = context.read<ApiService>();
      final results = await Future.wait([
        api.dio.get('/api/v1/users/current/'),
        api.dio.get('/api/v1/limits/'),
      ]);
      final account = results[0].data;
      final limits = results[1].data;
      final membership = account is Map ? account['membership'] : null;
      final memType = membership is Map && membership['is_active'] != false
          ? membership['mem_type']?.toString() ?? ''
          : '';
      final tier = memType.startsWith('silver')
          ? 'silver'
          : memType.startsWith('gold')
              ? 'gold'
              : 'bronze';
      final limit = limits is Map ? limits['${tier}_business_products'] : null;
      if (!mounted) return;
      setState(() {
        _accountId = account is Map ? account['id'] : null;
        _productLimit = limit is int ? limit : int.tryParse('$limit');
      });
    } catch (_) {}
  }

  Future<void> _loadBusiness() async {
    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      final res =
          await api.dio.get('/api/v1/directory/business/${widget.businessId}/');
      setState(() => _business = res.data);
      _posts = List.from(res.data['business_posts'] ?? []);
      // Mark as seen
      api.dio
          .post('/api/v1/directory/business/${widget.businessId}/follow/seen/');
    } catch (_) {
      _showSnack('Could not load business. Try again.');
    }
    setState(() => _loading = false);
  }

  Future<void> _loadReviews({int page = 1}) async {
    setState(() => _loadingReviews = true);
    try {
      final api = context.read<ApiService>();
      final res = await api.dio.get(
          '/api/v1/directory/business/${widget.businessId}/reviews/',
          queryParameters: {'page': page});
      setState(() {
        _reviews = res.data['results'] as List? ?? [];
        _reviewsTotalPages = res.data['total_pages'] ?? 1;
        _reviewsPage = page;
      });
    } catch (_) {}
    setState(() => _loadingReviews = false);
  }

  Future<void> _toggleFollow() async {
    try {
      final api = context.read<ApiService>();
      final res = await api.dio
          .post('/api/v1/directory/business/${widget.businessId}/follow/');
      final status = res.data['status'];
      setState(() {
        final followers = _business!['followers'] as List? ?? [];
        if (status == 'followed') {
          followers.add({'user': _accountId, 'business': widget.businessId});
        } else {
          followers.removeWhere((f) => f['user'] == _accountId);
        }
        _business!['followers'] = followers;
      });
    } catch (_) {
      _showSnack('Could not update follow status.');
    }
  }

  static const _socialImages = {
    'facebook': '/src/assets/img/facebook.png',
    'x': '/src/assets/img/x.webp',
    'linkedin': '/src/assets/img/linkedin.webp',
    'instagram': '/src/assets/img/instagram.webp',
    'pinterest': '/src/assets/img/pinterest.webp',
    'youtube': '/src/assets/img/youtube-icon.png',
    'tumblr': '/src/assets/img/tumblr-icon.png',
  };

  List<Map<String, dynamic>> _currentSocials() {
    final raw = _business?['social_profiles'];
    dynamic list = raw;
    if (raw is String && raw.isNotEmpty) {
      try {
        list = jsonDecode(raw);
      } catch (_) {
        list = [];
      }
    }
    if (list is Map) list = [list];
    if (list is! List) return [];
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> _saveSocialProfile(
      Map<String, dynamic> data, Map<String, dynamic>? original) async {
    final auth = context.read<AuthProvider>();
    final network = data['network'] as String?;
    final url = data['url'] as String?;
    if (network == null || url == null) return;
    final entry = {
      'network': network,
      'url': url,
      'imageUrl': _socialImages[network] ?? '',
    };
    final socials = _currentSocials();
    if (original != null) {
      final index =
          socials.indexWhere((s) => s['network'] == original['network']);
      if (index == -1) {
        socials.add(entry);
      } else {
        socials[index] = entry;
      }
    } else {
      if (socials.any((s) => s['network'] == network)) {
        _showSnack('The $network network is already added');
        return;
      }
      if (socials.length >= 5) {
        _showSnack('You are only allowed up to 5 profiles');
        return;
      }
      socials.add(entry);
    }
    try {
      await auth.apiService.dio.patch(
        '/api/v1/directory/business/${widget.businessId}/u/',
        data: {'social_profiles': socials},
      );
      if (mounted) _loadBusiness();
    } on DioException catch (e) {
      final body = e.response?.data;
      _showSnack(body is Map && body['error'] != null
          ? body['error'].toString()
          : 'Could not save. Try again.');
    } catch (_) {
      _showSnack('Something went wrong. Try again.');
    }
  }

  Future<void> _submitReviewResponse(int reviewId) async {
    if (_replyController.text.trim().isEmpty) return;
    try {
      final api = context.read<ApiService>();
      final res = await api.dio
          .post('/api/v1/directory/business/review/$reviewId/respond/', data: {
        'response': _replyController.text.trim(),
        'review': reviewId,
      });
      if (res.statusCode == 201) {
        setState(() {
          final review = _reviews.firstWhere((r) => r['id'] == reviewId,
              orElse: () => null);
          if (review != null) {
            (review['responses'] as List?)?.add(res.data);
          }
          _replyingTo = null;
          _replyController.clear();
        });
        _showSnack('Response submitted');
      }
    } catch (_) {
      _showSnack('Could not submit response. Try again.');
    }
  }

  bool get _isOwner {
    if (_accountId == null || _business == null) return false;
    final user = _business!['user'];
    if (user is Map) return user['id'] == _accountId;
    return user == _accountId;
  }

  bool get _isFollowing {
    final followers = _business?['followers'] as List? ?? [];
    return followers.any((f) => f['user'] == _accountId);
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  void _openLightbox(List<dynamic> images, int index) {
    setState(() {
      _lightboxImages = images;
      _lightboxIndex = index;
    });
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => _LightboxDialog(
        images: images,
        initialIndex: index,
      ),
    );
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

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B4748),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _business?['name'] ?? 'Business',
          style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: _buildAppBarActions(),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1B4748)))
          : _business == null
              ? const Center(child: Text('Business not found'))
              : RefreshIndicator(
                  onRefresh: _loadBusiness,
                  color: const Color(0xFF1B4748),
                  child: CustomScrollView(
                    slivers: [
                      // Hero image
                      SliverToBoxAdapter(child: _heroSection()),
                      // Info card
                      SliverToBoxAdapter(child: _infoCard()),
                      // Tab bar
                      SliverToBoxAdapter(child: _tabBar()),
                      // Tab content
                      SliverToBoxAdapter(child: _tabContent()),
                    ],
                  ),
                ),
    );
  }

  List<Widget> _buildAppBarActions() {
    if (_business == null) return [];
    final actions = <Widget>[];
    if (!_isOwner) {
      actions.add(TextButton(
        onPressed: () async {
          await SendMessageSheet.show(
            context,
            origin: 'business',
            title: 'Message ${_business!['name'] ?? 'Business'}',
            targetId: widget.businessId,
            recipientName: _business!['name']?.toString(),
          );
        },
        child: const Text('Contact',
            style: TextStyle(color: Colors.white70, fontSize: 12)),
      ));
      actions.add(TextButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReviewScreen(
                action: 'add',
                businessId: widget.businessId,
              ),
            ),
          );
          if (result != null && mounted) _loadReviews();
        },
        child: const Text('Review',
            style: TextStyle(color: Colors.white70, fontSize: 12)),
      ));
      actions.add(TextButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReportScreen(
              contentId: widget.businessId,
              type: 'businesses',
            ),
          ),
        ),
        child: const Text('Report',
            style: TextStyle(color: Colors.white70, fontSize: 12)),
      ));
    } else {
      actions.add(TextButton(
        onPressed: () {}, // TODO: edit
        child: const Text('Edit',
            style: TextStyle(color: Color(0xFFF8BB25), fontSize: 12)),
      ));
      actions.add(TextButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FeatureScreen(
                type: 'business',
                item: _business!,
              ),
            ),
          );
        },
        child: const Text('Feature',
            style: TextStyle(color: Colors.white70, fontSize: 12)),
      ));
    }
    return actions;
  }

  // ─── Hero ─────────────────────────────────────────────────────────────────

  Widget _heroSection() {
    final hero = _business?['hero'];
    return Stack(
      children: [
        SizedBox(
          width: double.infinity,
          height: 180,
          child: hero != null
              ? CachedNetworkImage(
                  imageUrl: hero,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _heroPlaceholder())
              : _heroPlaceholder(),
        ),
        if (_business?['verified'] == true)
          Positioned(
            bottom: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1B4748),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text('Verified',
                      style: TextStyle(color: Colors.white, fontSize: 11)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _heroPlaceholder() => Container(
        width: double.infinity,
        height: 180,
        color: const Color(0xFF1B4748).withOpacity(0.15),
        child: const Icon(Icons.business, color: Color(0xFF1B4748), size: 60),
      );

  // ─── Info card ───────────────────────────────────────────────────────────

  Widget _infoCard() {
    final logo = _business?['logo'];
    final name = _business?['name'] ?? '';
    final slogan = _business?['slogan'] ?? '';
    final description = _business?['description'] ?? '';
    final phone = _business?['phone'];
    final email = _business?['email'];
    final website = _business?['website'];
    final founded = _business?['founded'];
    final businessType = _business?['business_type'];
    final size = _business?['size'];
    final followers = (_business?['followers'] as List?)?.length ?? 0;
    final categories = _business?['categories'] as List? ?? [];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo + name + follow row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: logo != null
                    ? CachedNetworkImage(
                        imageUrl: logo,
                        width: 72,
                        height: 72,
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
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B4748))),
                    if (slogan.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(slogan,
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic)),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.people_outline,
                            size: 14, color: Colors.black45),
                        const SizedBox(width: 4),
                        Text('$followers followers',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black45)),
                        const Spacer(),
                        if (!_isOwner)
                          ElevatedButton(
                            onPressed: _toggleFollow,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isFollowing
                                  ? const Color(0xFFF48900)
                                  : const Color(0xFF1B4748),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              _isFollowing ? 'Unfollow' : 'Follow',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 14),
            const _SectionLabel('About'),
            const SizedBox(height: 4),
            Text(description,
                style: const TextStyle(
                    fontSize: 13, color: Colors.black87, height: 1.5)),
          ],
          const SizedBox(height: 14),
          // Meta info grid
          Wrap(
            spacing: 0,
            runSpacing: 0,
            children: [
              if (categories.isNotEmpty)
                _infoBlock(
                    'Categories',
                    categories
                        .map((c) => c['parent'] != null
                            ? '${c['parent']['name']} › ${c['name']}'
                            : c['name']?.toString() ?? '')
                        .join('\n')),
              if (founded != null) _infoBlock('Founded', founded.toString()),
              if (businessType != null)
                _infoBlock('Type', _businessTypeLabel(businessType.toString())),
              if (size != null) _infoBlock('Size', _sizeLabel(size.toString())),
              if (phone != null) _infoBlock('Phone', phone.toString()),
              if (email != null) _infoBlock('Email', email.toString()),
              if (website != null && website.toString().isNotEmpty)
                _infoBlockLink('Website', website.toString()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoBlock(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B4748))),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(fontSize: 13, color: Colors.black87)),
            const SizedBox(height: 6),
            const Divider(height: 1),
            const SizedBox(height: 6),
          ],
        ),
      );

  Widget _infoBlockLink(String label, String url) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B4748))),
            const SizedBox(height: 2),
            GestureDetector(
              onTap: () => _openUrl(url),
              child: Text(url,
                  style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF1B4748),
                      decoration: TextDecoration.underline)),
            ),
            const SizedBox(height: 6),
            const Divider(height: 1),
            const SizedBox(height: 6),
          ],
        ),
      );

  Widget _logoPlaceholder() => Container(
        width: 72,
        height: 72,
        color: const Color(0xFF1B4748).withValues(alpha: 0.1),
        child: const Icon(Icons.business, color: Color(0xFF1B4748), size: 32),
      );

  // ─── Tab bar ──────────────────────────────────────────────────────────────

  Widget _tabBar() {
    final tabs = [
      (1, 'Posts'),
      (2, 'Products'),
      (3, 'Services'),
      (4, 'Contact'),
      (5, 'Media'),
      (6, 'Careers'),
      (7, 'Reviews'),
    ];
    return Container(
      color: const Color(0xFF1B4748),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: tabs.map((t) {
            final active = _bizTab == t.$1;
            return GestureDetector(
              onTap: () {
                setState(() => _bizTab = t.$1);
                if (t.$1 == 7 && _reviews.isEmpty) {
                  _loadReviews();
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: active ? Colors.white : const Color(0xFF1B4748),
                  border: active
                      ? null
                      : const Border(right: BorderSide(color: Colors.white12)),
                ),
                child: Text(t.$2,
                    style: TextStyle(
                      color: active ? const Color(0xFF1B4748) : Colors.white70,
                      fontSize: 12,
                      fontWeight: active ? FontWeight.bold : FontWeight.normal,
                    )),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─── Tab content ──────────────────────────────────────────────────────────

  Widget _tabContent() {
    switch (_bizTab) {
      case 1:
        return _postsTab();
      case 2:
        return _productsTab();
      case 3:
        return _servicesTab();
      case 4:
        return _contactTab();
      case 5:
        return _mediaTab();
      case 6:
        return _careersTab();
      case 7:
        return _reviewsTab();
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Posts ─────────────────────────────────────────────────────────────────

  Widget _postsTab() {
    return Column(
      children: [
        if (_isOwner)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddPostModal(
                    action: 'add',
                    businessId: widget.businessId,
                    onSave: (data) {
                      Navigator.pop(context);
                      setState(() => _posts.insert(0, data));
                    },
                    onCancel: () => Navigator.pop(context),
                  ),
                ),
              ),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B4748),
                  minimumSize: const Size(double.infinity, 44),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Create Post',
                  style: TextStyle(color: Colors.white)),
            ),
          ),
        if (_posts.isEmpty)
          _emptyTab('No posts at the moment')
        else
          ..._posts.map((p) => _postCard(p as Map<String, dynamic>)),
      ],
    );
  }

  Widget _postCard(Map<String, dynamic> post) {
    final body = post['body'] ?? '';
    final images = post['images'] as List? ?? [];
    final createdAt = post['created_at'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_timeAgo(createdAt?.toString()),
              style: const TextStyle(fontSize: 11, color: Color(0xFF1B4748))),
          if (images.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 90,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                itemBuilder: (ctx, i) => GestureDetector(
                  onTap: () => _openLightbox(images, i),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: CachedNetworkImage(
                        imageUrl: images[i]['image'] ?? '',
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: 90,
                          height: 90,
                          color: Colors.grey.shade200,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (body.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(body,
                style: const TextStyle(
                    fontSize: 13, color: Colors.black87, height: 1.4)),
          ],
        ],
      ),
    );
  }

  // ── Products ──────────────────────────────────────────────────────────────

  Widget _productsTab() {
    final products = _business?['products'] as List? ?? [];
    final productLimit = _productLimit ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Owner: Add Product button
        if (_isOwner)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: ElevatedButton.icon(
              onPressed: _productLimit == null
                  ? null
                  : () async {
                      final result = await Navigator.push<dynamic>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddProductScreen(
                            action: 'add',
                            businessId: widget.businessId,
                            currentCount: products.length,
                            productLimit: productLimit,
                          ),
                        ),
                      );
                      // Reload the business so the new products appear
                      if (result != null && mounted) {
                        _loadBusiness();
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B4748),
                minimumSize: const Size(double.infinity, 44),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add Product',
                  style: TextStyle(color: Colors.white)),
            ),
          ),

        // Product grid
        if (products.isEmpty)
          _emptyTab('No products to display')
        else
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: products
                  .map((p) => _productCard(p as Map<String, dynamic>))
                  .toList(),
            ),
          ),
      ],
    );
  }

  Widget _productCard(Map<String, dynamic> product) {
    final width = (MediaQuery.of(context).size.width - 44) / 2;
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(10),
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
            // Product image — tapping opens edit for owner
            GestureDetector(
              onTap: _isOwner
                  ? () async {
                      final result = await Navigator.push<dynamic>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddProductScreen(
                            action: 'edit',
                            businessId: widget.businessId,
                            product: product,
                          ),
                        ),
                      );
                      if (result != null && mounted) _loadBusiness();
                    }
                  : null,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: product['image'] != null
                        ? CachedNetworkImage(
                            imageUrl: product['image'],
                            height: 90,
                            width: double.infinity,
                            fit: BoxFit.contain)
                        : Container(
                            height: 90,
                            color: Colors.grey.shade100,
                            child: const Center(
                                child: Icon(Icons.shopping_bag_outlined,
                                    color: Colors.black26))),
                  ),
                  if (_isOwner)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF1B4748).withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.edit,
                            color: Colors.white, size: 12),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(product['title'] ?? '',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B4748)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            if (product['price'] != null) ...[
              const SizedBox(height: 4),
              Text('R${product['price']}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF48900))),
            ],
            if (product['description'] != null) ...[
              const SizedBox(height: 4),
              Text(
                product['description'].toString().length > 60
                    ? '${product['description'].toString().substring(0, 60)}...'
                    : product['description'].toString(),
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
            if (product['url'] != null) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => _openUrl(product['url']),
                child: const Text('View Product',
                    style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF1B4748),
                        decoration: TextDecoration.underline)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Services ──────────────────────────────────────────────────────────────

  Widget _servicesTab() {
    final services = (_business?['services'] as List? ?? [])
        .where((s) => s['service'] != null)
        .toList();

    return Column(
      children: [
        if (_isOwner)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddServiceScreen(
                        action: 'add',
                        businessId: widget.businessId,
                      ),
                    ));
                if (result != null && mounted) _loadBusiness();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B4748),
                minimumSize: const Size(double.infinity, 44),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add Service',
                  style: TextStyle(color: Colors.white)),
            ),
          ),
        if (services.isEmpty)
          _emptyTab('No services to display')
        else
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: services
                  .map((s) => _serviceCard(s as Map<String, dynamic>))
                  .toList(),
            ),
          ),
      ],
    );
  }

  Widget _serviceCard(Map<String, dynamic> service) {
    final serviceName = service['service']?['name'] ?? '';
    final pitch = service['pitch'] ?? '';
    final rate = service['rate'];
    final interval = service['interval'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
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
          Text(serviceName,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B4748))),
          if (pitch.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(pitch.length > 150 ? '${pitch.substring(0, 150)}...' : pitch,
                style: const TextStyle(
                    fontSize: 12, color: Colors.black54, height: 1.4)),
          ],
          if (rate != null) ...[
            const SizedBox(height: 6),
            Text('R$rate${interval != null ? ' per $interval' : ''}',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B4748))),
          ],
        ],
      ),
    );
  }

  // ── Contact ───────────────────────────────────────────────────────────────

  Widget _contactTab() {
    final branches = _business?['branches'] as List? ?? [];
    final socialsRaw = _business?['social_profiles'];
    List<dynamic> socials;
    if (socialsRaw is List) {
      socials = socialsRaw;
    } else if (socialsRaw is String && socialsRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(socialsRaw);
        socials = decoded is List ? decoded : [decoded];
      } catch (_) {
        socials = [];
      }
    } else if (socialsRaw is Map) {
      socials = [socialsRaw];
    } else {
      socials = [];
    }
    final officeHours = _business?['monday_open'] != null;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tabSectionHeader('Branches'),
          if (branches.isEmpty)
            _emptyInline('No branches listed')
          else
            ...branches.map((b) => _branchCard(b as Map<String, dynamic>)),
          const SizedBox(height: 16),
          if (officeHours) ...[
            _tabSectionHeader('Office Hours'),
            _officeHoursCard(),
            const SizedBox(height: 16),
          ],
          _tabSectionHeader('Social Media'),
          if (_isOwner)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddSocialScreen(
                        action: 'add',
                        existing: socials,
                      ),
                    ),
                  );
                  if (result != null && mounted) {
                    await _saveSocialProfile(
                        Map<String, dynamic>.from(result), null);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B4748),
                  minimumSize: const Size(double.infinity, 44),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Add Social Profile',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          if (socials.isEmpty)
            _emptyInline('No social profiles listed')
          else
            ...socials.map((s) => _socialRow(s as Map<String, dynamic>)),
        ],
      ),
    );
  }

  Widget _branchCard(Map<String, dynamic> branch) {
    final city = branch['city'] as Map<String, dynamic>?;
    final area = branch['area'] as Map<String, dynamic>?;
    final branchPhone = branch['phone'];
    final branchWhats = branch['whatsapp'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
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
          Text(branch['name']?.toString() ?? '',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B4748))),
          const SizedBox(height: 6),
          if (branch['street'] != null)
            _metaRow('Street', branch['street'].toString()),
          if (city != null) _metaRow('City', city['name']?.toString() ?? ''),
          if (area != null) _metaRow('Area', area['name']?.toString() ?? ''),
          if (branchPhone != null) ...[
            Row(
              children: [
                const Text('Phone: ',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54)),
                _showPhone
                    ? Text(branchPhone.toString(),
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black87))
                    : GestureDetector(
                        onTap: () => setState(() => _showPhone = true),
                        child: const Text('Show',
                            style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF1B4748),
                                decoration: TextDecoration.underline)),
                      ),
              ],
            ),
          ],
          if (branchWhats != null) ...[
            Row(
              children: [
                const Text('WhatsApp: ',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54)),
                _showWhats
                    ? Text(branchWhats.toString(),
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black87))
                    : GestureDetector(
                        onTap: () => setState(() => _showWhats = true),
                        child: const Text('Show',
                            style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF1B4748),
                                decoration: TextDecoration.underline)),
                      ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _officeHoursCard() {
    const days = [
      ('monday', 'Monday'),
      ('tuesday', 'Tuesday'),
      ('wednesday', 'Wednesday'),
      ('thursday', 'Thursday'),
      ('friday', 'Friday'),
      ('saturday', 'Saturday'),
      ('sunday', 'Sunday'),
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: days.map((d) {
          final open = _business?['${d.$1}_open'];
          final close = _business?['${d.$1}_close'];
          if (open == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Text(d.$2,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54)),
                ),
                Text(
                  open.toString() == 'closed'
                      ? 'Closed'
                      : '$open – ${close ?? ''}',
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _socialRow(Map<String, dynamic> social) {
    final network = social['network'] ?? '';
    final url = social['url'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(_socialIcon(network), color: const Color(0xFF1B4748), size: 20),
          const SizedBox(width: 10),
          Text(network,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B4748))),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () => _openUrl(url),
              child: Text(url,
                  style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1B4748),
                      decoration: TextDecoration.underline),
                  overflow: TextOverflow.ellipsis),
            ),
          ),
          if (_isOwner)
            GestureDetector(
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddSocialScreen(
                      action: 'edit',
                      network: social,
                    ),
                  ),
                );
                if (result != null && mounted) {
                  await _saveSocialProfile(
                      Map<String, dynamic>.from(result), social);
                }
              },
              child: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.edit_outlined,
                    color: Color(0xFF1B4748), size: 18),
              ),
            ),
        ],
      ),
    );
  }

  IconData _socialIcon(String network) {
    switch (network.toLowerCase()) {
      case 'facebook':
        return Icons.facebook;
      case 'youtube':
        return Icons.play_circle_outline;
      case 'linkedin':
        return Icons.work_outline;
      default:
        return Icons.link;
    }
  }

  // ── Media ─────────────────────────────────────────────────────────────────

  Widget _mediaTab() {
    final picGalleries = _business?['picture_galleries'] as List? ?? [];
    final vidGalleries = _business?['video_galleries'] as List? ?? [];

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isOwner) ...[
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddVideoGalleryScreen(
                        action: 'add',
                        target: 'business',
                        targetId: widget.businessId,
                      ),
                    ));
                if (result != null && mounted) _loadBusiness();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B4748),
                minimumSize: const Size(double.infinity, 44),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add Video Gallery',
                  style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => AddPictureGalleryScreen(
                              action: 'add',
                              title: 'Add Picture Gallery',
                              businessId: widget.businessId,
                            )));
                if (result != null && mounted) _loadBusiness();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B4748),
                minimumSize: const Size(double.infinity, 44),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add Picture Gallery',
                  style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 16),
          ],
          if (picGalleries.isEmpty && vidGalleries.isEmpty && !_isOwner)
            _emptyTab('No media to display')
          else ...[
            if (picGalleries.isNotEmpty) ...[
              _tabSectionHeader('Picture Galleries'),
              ...picGalleries
                  .map((g) => _pictureGallery(g as Map<String, dynamic>)),
              const SizedBox(height: 16),
            ],
            if (vidGalleries.isNotEmpty) ...[
              _tabSectionHeader('Video Galleries'),
              ...vidGalleries
                  .map((g) => _videoGallery(g as Map<String, dynamic>)),
            ],
          ],
        ],
      ),
    );
  }

  Widget _pictureGallery(Map<String, dynamic> gallery) {
    final images = gallery['images'] as List? ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(gallery['title']?.toString() ?? '',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B4748))),
            ),
            if (_isOwner)
              GestureDetector(
                onTap: () async {
                  final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddPictureGalleryScreen(
                          action: 'edit',
                          title: 'Edit Picture Gallery',
                          businessId: widget.businessId,
                          gallery: gallery,
                        ),
                      ));
                  if (result != null && mounted) _loadBusiness();
                },
                child: const Icon(Icons.edit_outlined,
                    color: Color(0xFF1B4748), size: 18),
              ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: images.length,
          itemBuilder: (ctx, i) => GestureDetector(
            onTap: () => _openLightbox(images, i),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: CachedNetworkImage(
                imageUrl: images[i]['image'] ?? '',
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    Container(color: Colors.grey.shade200),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _videoGallery(Map<String, dynamic> gallery) {
    final videos = gallery['videos'] as List? ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(gallery['title']?.toString() ?? '',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B4748))),
            ),
            if (_isOwner)
              GestureDetector(
                onTap: () async {
                  final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddVideoGalleryScreen(
                          action: 'edit',
                          target: 'business',
                          targetId: widget.businessId,
                          gallery: gallery,
                        ),
                      ));
                  if (result != null && mounted) _loadBusiness();
                },
                child: const Icon(Icons.edit_outlined,
                    color: Color(0xFF1B4748), size: 18),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ...videos.map((v) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(Icons.play_circle_outline,
                      color: Colors.white, size: 48),
                ),
              ),
            )),
        const SizedBox(height: 12),
      ],
    );
  }

  // ── Careers ───────────────────────────────────────────────────────────────

  Widget _careersTab() {
    final jobs = _business?['jobs'] as List? ?? [];
    if (jobs.isEmpty) {
      return _emptyTab(
          'There are no jobs available at the moment. Check back regularly.');
    }
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: jobs.map((j) => _jobCard(j as Map<String, dynamic>)).toList(),
      ),
    );
  }

  Widget _jobCard(Map<String, dynamic> job) {
    final image = job['image'];
    final description = job['description'] ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: image != null
                ? CachedNetworkImage(
                    imageUrl: image, width: 70, height: 70, fit: BoxFit.contain)
                : Container(
                    width: 70,
                    height: 70,
                    color: Colors.grey.shade100,
                    child:
                        const Icon(Icons.work_outline, color: Colors.black26)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(job['title'] ?? '',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B4748))),
                const SizedBox(height: 4),
                Text(
                    description.length > 150
                        ? '${description.substring(0, 150)}...'
                        : description,
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Reviews ───────────────────────────────────────────────────────────────

  Widget _reviewsTab() {
    if (_loadingReviews) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child:
            Center(child: CircularProgressIndicator(color: Color(0xFF1B4748))),
      );
    }
    if (_reviews.isEmpty) {
      return Column(
        children: [
          _emptyTab('No reviews to display'),
          if (!_isOwner)
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () async {
                  final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReviewScreen(
                          action: 'add',
                          businessId: widget.businessId,
                        ),
                      ));
                  if (result != null && mounted) _loadReviews();
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B4748)),
                child: const Text('Write a Review',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          if (!_isOwner)
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReviewScreen(
                        action: 'add',
                        businessId: widget.businessId,
                      ),
                    ),
                  );
                  if (result != null && mounted) _loadReviews();
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B4748)),
                child: const Text('Write a Review',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          const SizedBox(height: 8),
          ..._reviews.map((r) => _reviewCard(r as Map<String, dynamic>)),
          if (_reviewsTotalPages > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: _reviewsPage > 1
                      ? () => _loadReviews(page: _reviewsPage - 1)
                      : null,
                  child: const Text('Prev'),
                ),
                Text('Page $_reviewsPage of $_reviewsTotalPages',
                    style: const TextStyle(fontSize: 12)),
                TextButton(
                  onPressed: _reviewsPage < _reviewsTotalPages
                      ? () => _loadReviews(page: _reviewsPage + 1)
                      : null,
                  child: const Text('Next'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _reviewCard(Map<String, dynamic> review) {
    final user = review['user'] as Map<String, dynamic>?;
    final profile = user?['profile'] as Map<String, dynamic>?;
    final firstName = profile?['first_name'] ?? '';
    final lastName = profile?['last_name'] ?? '';
    final rating = review['rating'];
    final text = review['review'] ?? '';
    final responses = review['responses'] as List? ?? [];
    final reviewId = review['id'] as int;
    final isMyReview = user?['id'] == _accountId;
    final canRespond = _canRespond(review);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
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
          Row(
            children: [
              Expanded(
                child: Text('$firstName $lastName wrote:',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B4748))),
              ),
              if (rating != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B4748),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('$rating/10',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(text,
              style: const TextStyle(
                  fontSize: 13, color: Colors.black87, height: 1.4)),

          // Responses
          if (responses.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...responses.map((resp) {
              final rUser = resp['user'] as Map<String, dynamic>?;
              final rProfile = rUser?['profile'] as Map<String, dynamic>?;
              final rFirst = rProfile?['first_name'] ?? '';
              final rLast = rProfile?['last_name'] ?? '';
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$rFirst $rLast responded:',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B4748))),
                    const SizedBox(height: 4),
                    Text(resp['response']?.toString() ?? '',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black87)),
                  ],
                ),
              );
            }),
          ],

          // Reply box
          if (_replyingTo == reviewId) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _replyController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Write your response...',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.all(10),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () => _submitReviewResponse(reviewId),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B4748),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6)),
                  child: const Text('Submit',
                      style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => setState(() => _replyingTo = null),
                  child: const Text('Cancel',
                      style: TextStyle(color: Color(0xFFF48900))),
                ),
              ],
            ),
          ] else if (canRespond) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _replyingTo = reviewId),
              child: const Text('Respond',
                  style: TextStyle(color: Color(0xFF1B4748))),
            ),
          ],

          // Owner edit/delete
          if (isMyReview) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                OutlinedButton(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReviewScreen(
                          action: 'edit',
                          businessId: widget.businessId,
                          review: review,
                        ),
                      ),
                    );
                    if (result != null && mounted) _loadReviews();
                  },
                  style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1B4748),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4)),
                  child: const Text('Edit', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        content: const Text('Delete your review?'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel')),
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Delete',
                                  style: TextStyle(color: Color(0xFFF48900)))),
                        ],
                      ),
                    );
                    if (confirm != true) return;
                    try {
                      final api = context.read<ApiService>();
                      await api.dio.delete(
                          '/api/v1/directory/business/review/${review['id']}/d/');
                      if (mounted) _loadReviews();
                    } catch (_) {
                      _showSnack('Could not delete review. Try again.');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF48900),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4)),
                  child: const Text('Delete',
                      style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  bool _canRespond(Map<String, dynamic> review) {
    if (_accountId == null) return false;
    final responses = review['responses'] as List? ?? [];
    final lastResponse = responses.isNotEmpty ? responses.last : null;
    final isOwner = _isOwner;
    final isReviewer = (review['user'] as Map?)?['id'] == _accountId;
    if (!isOwner && !isReviewer) return false;
    if (responses.isEmpty) return isOwner;
    if ((lastResponse['user'] as Map?)?['id'] == _accountId) return false;
    return true;
  }

  // ─── Shared helpers ──────────────────────────────────────────────────────

  Widget _emptyTab(String msg) => Padding(
        padding: const EdgeInsets.all(30),
        child: Center(
          child: Text(msg,
              style: const TextStyle(color: Color(0xFF1B4748), fontSize: 13),
              textAlign: TextAlign.center),
        ),
      );

  Widget _emptyInline(String msg) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(msg,
            style: const TextStyle(fontSize: 12, color: Colors.black45)),
      );

  Widget _tabSectionHeader(String title) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: Colors.black87,
        margin: const EdgeInsets.only(bottom: 8),
        child: Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold)),
      );

  Widget _metaRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
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

  String _businessTypeLabel(String type) {
    const map = {
      'sole': 'Sole Proprietor',
      'partnership': 'Partnership',
      'closed': 'Closed Corporation',
      'public': 'Public Company',
      'personal': 'Personal Liability Company',
      'nonprofit': 'Non Profit',
      'state': 'State Owned',
    };
    return map[type] ?? type;
  }

  String _sizeLabel(String size) {
    const map = {
      '10': '1 to 10 employees',
      '11': '11 to 100',
      '101': '101 to 1000',
      '1001': '1001 to 10,000',
      '10001': 'More than 10,000',
    };
    return map[size] ?? size;
  }
}

// ─── Section label widget ────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B4748),
            letterSpacing: 0.5));
  }
}

// ─── Lightbox dialog ─────────────────────────────────────────────────────────

class _LightboxDialog extends StatefulWidget {
  final List<dynamic> images;
  final int initialIndex;

  const _LightboxDialog({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_LightboxDialog> createState() => _LightboxDialogState();
}

class _LightboxDialogState extends State<_LightboxDialog> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.images[_index]['image']?.toString() ?? '';
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          // Image
          Center(
            child: InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                errorWidget: (_, __, ___) =>
                    const Icon(Icons.broken_image, color: Colors.white),
              ),
            ),
          ),
          // Close
          Positioned(
            top: 40,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
          // Prev
          if (_index > 0)
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: () => setState(() => _index--),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chevron_left,
                      color: Colors.white, size: 28),
                ),
              ),
            ),
          // Next
          if (_index < widget.images.length - 1)
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: () => setState(() => _index++),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chevron_right,
                      color: Colors.white, size: 28),
                ),
              ),
            ),
          // Counter
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                '${_index + 1} / ${widget.images.length}',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _logoPlaceholder() => Container(
      width: 72,
      height: 72,
      color: const Color(0xFF1B4748).withValues(alpha: 0.1),
      child: const Icon(Icons.business, color: Color(0xFF1B4748), size: 32),
    );
