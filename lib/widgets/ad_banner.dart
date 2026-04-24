import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

class AdBanner extends StatefulWidget {
  final String speed;
  final bool enabled;

  const AdBanner({super.key, this.speed = 'slow', this.enabled = true});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  Map<String, dynamic>? _ad;
  bool _loading = true;
  bool _viewRecorded = false;

  @override
  void initState() {
    super.initState();
    _fetchAd();
  }

  Future<void> _fetchAd() async {
    try {
      final api = context.read<ApiService>();
      final res = await api.dio.get('/api/v1/ads/${widget.speed}/');
      final data = res.data;
      // endpoint may return a list or single object
      if (data is List && data.isNotEmpty) {
        setState(() => _ad = data[0] as Map<String, dynamic>);
      } else if (data is Map<String, dynamic>) {
        setState(() => _ad = data);
      }
    } catch (_) {
      // fail silently — no ad shown
    }
    setState(() => _loading = false);
    if (_ad != null) _recordView();
  }

  Future<void> _recordView() async {
    if (_viewRecorded || _ad == null) return;
    _viewRecorded = true;
    try {
      final api = context.read<ApiService>();
      await api.dio.post('/api/v1/ads/${_ad!['id']}/v/');
    } catch (_) {}
  }

  Future<void> _recordClick() async {
    if (_ad == null) return;
    try {
      final api = context.read<ApiService>();
      await api.dio.post('/api/v1/ads/click/', data: {'ad': _ad!['id']});
    } catch (_) {}
  }

  Future<void> _openLink() async {
    final link = _ad?['ad_link']?.toString();
    if (link == null || link.isEmpty) return;
    await _recordClick();
    String url = link;
    if (!url.startsWith('http')) url = 'https://$url';
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    if (_ad == null) return const SizedBox.shrink();

    final image = _ad!['ad_image']?.toString();
    final title = _ad!['title']?.toString() ?? '';
    final adText = _ad!['ad_text']?.toString() ?? '';
    final hasImage = image != null && image.isNotEmpty;

    return GestureDetector(
      onTap: _openLink,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ad label
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: const BoxDecoration(
                color: Color(0xFF094a25),
                borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
              ),
              child: const Text('Sponsored',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 10, letterSpacing: 0.5)),
            ),

            // Image
            if (hasImage)
              ClipRRect(
                borderRadius: BorderRadius.zero,
                child: CachedNetworkImage(
                  imageUrl: image!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),

            // Text content
            if (title.isNotEmpty || adText.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title.isNotEmpty)
                      Text(title,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF094a25))),
                    if (adText.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(adText,
                          style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                              height: 1.4)),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
