import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  int _tab = 1;
  bool _loading = true;

  List<dynamic> _businessBookmarks = [];
  List<dynamic> _classifiedBookmarks = [];
  List<dynamic> _eventBookmarks = [];
  List<dynamic> _jobBookmarks = [];
  List<dynamic> _profileBookmarks = [];
  List<dynamic> _websiteBookmarks = [];

  static const _tabs = [
    (1, 'Businesses'),
    (2, 'Classifieds'),
    (3, 'Events'),
    (4, 'Jobs'),
    (5, 'Profiles'),
    (6, 'Websites'),
  ];

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      final res = await api.dio.get('/api/v1/users/current/bookmarks/');
      final data = res.data as List? ?? [];
      setState(() {
        _businessBookmarks =
            data.where((b) => b['content_type_name'] == 'business').toList();
        _classifiedBookmarks =
            data.where((b) => b['content_type_name'] == 'classified').toList();
        _eventBookmarks =
            data.where((b) => b['content_type_name'] == 'event').toList();
        _jobBookmarks =
            data.where((b) => b['content_type_name'] == 'job').toList();
        _profileBookmarks =
            data.where((b) => b['content_type_name'] == 'profile').toList();
        _websiteBookmarks =
            data.where((b) => b['content_type_name'] == 'website').toList();
      });
    } catch (_) {
      _showSnack('Could not load bookmarks. Try again.');
    }
    setState(() => _loading = false);
  }

  Future<void> _deleteBookmark(int id, String type, int objectId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Bookmark'),
        content: const Text('Are you sure you want to remove this bookmark?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final api = context.read<ApiService>();
      await api.dio.delete('/api/v1/users/bookmarks/$id/d/');
      setState(() {
        _businessBookmarks.removeWhere((b) => b['id'] == id);
        _classifiedBookmarks.removeWhere((b) => b['id'] == id);
        _eventBookmarks.removeWhere((b) => b['id'] == id);
        _jobBookmarks.removeWhere((b) => b['id'] == id);
        _profileBookmarks.removeWhere((b) => b['id'] == id);
        _websiteBookmarks.removeWhere((b) => b['id'] == id);
      });
      _showSnack('Bookmark removed');
    } catch (_) {
      _showSnack('Could not remove bookmark. Try again.');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  List<dynamic> get _currentList {
    switch (_tab) {
      case 1:
        return _businessBookmarks;
      case 2:
        return _classifiedBookmarks;
      case 3:
        return _eventBookmarks;
      case 4:
        return _jobBookmarks;
      case 5:
        return _profileBookmarks;
      case 6:
        return _websiteBookmarks;
      default:
        return [];
    }
  }

  String _tabEmptyMessage(int tab) {
    switch (tab) {
      case 1:
        return 'You have not bookmarked any businesses';
      case 2:
        return 'You have not bookmarked any classifieds';
      case 3:
        return 'You have not bookmarked any events';
      case 4:
        return 'You have not bookmarked any jobs';
      case 5:
        return 'You have not bookmarked any profiles';
      case 6:
        return 'You have not bookmarked any websites';
      default:
        return 'No bookmarks';
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF094a25)));
    }

    return Column(
      children: [
        // Tab bar — scrollable since 6 tabs
        Container(
          color: const Color(0xFF094a25),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _tabs.map((t) => _tabBtn(t.$1, t.$2)).toList(),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadBookmarks,
            color: const Color(0xFF094a25),
            child: _currentList.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 80),
                      Center(
                        child: Text(
                          _tabEmptyMessage(_tab),
                          style: const TextStyle(
                              color: Color(0xFF094a25), fontSize: 14),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _currentList.length,
                    itemBuilder: (context, index) => _bookmarkCard(
                        _currentList[index] as Map<String, dynamic>, _tab),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _tabBtn(int index, String label) {
    final active = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: active ? Colors.white : const Color(0xFF094a25),
          border: active
              ? null
              : const Border(
                  right: BorderSide(color: Colors.white12, width: 1)),
        ),
        child: Text(label,
            style: TextStyle(
              color: active ? const Color(0xFF094a25) : Colors.white70,
              fontSize: 12,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            )),
      ),
    );
  }

  Widget _bookmarkCard(Map<String, dynamic> bookmark, int tab) {
    final related = bookmark['related_object'] as Map<String, dynamic>?;
    final id = bookmark['id'] as int;
    final objectId = bookmark['object_id'] as int;
    final type = bookmark['content_type_name']?.toString() ?? '';
    final imageUrl = bookmark['image'] ??
        bookmark['logo'] ??
        related?['image'] ??
        related?['logo'];

    // Profile tab — different layout (no image)
    if (tab == 5) {
      final firstName = related?['first_name']?.toString() ?? '';
      final lastName = related?['last_name']?.toString() ?? '';
      return _profileBookmarkCard(
          bookmark, id, type, objectId, firstName, lastName);
    }

    final title =
        related?['title']?.toString() ?? related?['name']?.toString() ?? '';
    final description = related?['description']?.toString() ?? '';

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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: 70,
                      height: 70,
                      fit: BoxFit.contain,
                      errorWidget: (_, __, ___) => _imagePlaceholder(tab))
                  : _imagePlaceholder(tab),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.length > 40 ? '${title.substring(0, 40)}...' : title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF094a25)),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description.length > 70
                          ? '${description.substring(0, 70)}...'
                          : description,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () => _deleteBookmark(id, type, objectId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFbc2023),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Remove',
                        style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileBookmarkCard(
    Map<String, dynamic> bookmark,
    int id,
    String type,
    int objectId,
    String firstName,
    String lastName,
  ) {
    final fullName = '$firstName $lastName'.trim();
    final initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';

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
        child: Row(
          children: [
            // Avatar
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF094a25).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(initial,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF094a25))),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                fullName,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF094a25)),
              ),
            ),
            ElevatedButton(
              onPressed: () => _deleteBookmark(id, type, objectId),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFbc2023),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Remove',
                  style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder(int tab) {
    IconData icon;
    switch (tab) {
      case 1:
        icon = Icons.business;
        break;
      case 2:
        icon = Icons.sell_outlined;
        break;
      case 3:
        icon = Icons.event_outlined;
        break;
      case 4:
        icon = Icons.work_outline;
        break;
      case 6:
        icon = Icons.language;
        break;
      default:
        icon = Icons.bookmark_outline;
    }
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: const Color(0xFF094a25).withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, color: const Color(0xFF094a25), size: 28),
    );
  }
}
