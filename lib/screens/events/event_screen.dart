import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../feature_content.dart';

class EventDetailScreen extends StatefulWidget {
  final int eventId;
  const EventDetailScreen({super.key, required this.eventId});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  Map<String, dynamic>? _event;
  bool _loading = true;
  int? _accountId;

  @override
  void initState() {
    super.initState();
    _loadAccount();
    _loadEvent();
  }

  Future<void> _loadAccount() async {
    try {
      final api = context.read<ApiService>();
      final res = await api.dio.get('/api/v1/users/current/');
      setState(() => _accountId = res.data['id']);
    } catch (_) {}
  }

  Future<void> _loadEvent() async {
    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      final res = await api.dio.get('/api/v1/events/event/${widget.eventId}/');
      setState(() => _event = res.data);
    } catch (_) {
      _showSnack('Could not load event. Try again.');
    }
    setState(() => _loading = false);
  }

  bool get _isOwner {
    if (_accountId == null || _event == null) return false;
    final user = _event!['user'];
    if (user is Map) return user['id'] == _accountId;
    return user == _accountId;
  }

  bool get _isExpired {
    final endDate = _event?['end_date'];
    if (endDate == null) return false;
    final dt = DateTime.tryParse(endDate.toString());
    if (dt == null) return false;
    return dt.isBefore(DateTime.now());
  }

  String _eventStatus() {
    final startDate = _event?['start_date'];
    final endDate = _event?['end_date'];
    if (startDate == null) return '';
    final start = DateTime.tryParse(startDate.toString());
    final end = endDate != null ? DateTime.tryParse(endDate.toString()) : null;
    if (start == null) return '';
    final now = DateTime.now();
    if (start.isAfter(now)) return 'Event starts';
    if (end != null && end.isBefore(now)) return 'Event took place';
    return 'Event started';
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return '';
    final local = dt.toLocal();
    const months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${local.day} ${months[local.month]} ${local.year}';
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return '';
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _deleteEvent() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Event'),
        content: const Text(
            'Are you sure you want to delete this event? This cannot be undone.'),
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
      await api.dio.delete('/api/v1/events/event/${widget.eventId}/d/');
      if (mounted) Navigator.pop(context);
    } catch (_) {
      _showSnack('Could not delete event. Try again.');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: const Color(0xFF094a25),
        iconTheme: const IconThemeData(color: Colors.white),
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: GestureDetector(
            onTap: () => Navigator.popUntil(context, (route) => route.isFirst),
            child: Image.asset('assets/img/sesha.png', height: 40),
          ),
        ),
        actions: [
          if (_event != null && !_isExpired) ...[
            if (_isOwner) ...[
              TextButton(
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                onPressed: () {},
                child: const Text('Edit',
                    style: TextStyle(color: Color(0xFFf8b324), fontSize: 12)),
              ),
              TextButton(
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FeatureScreen(
                        type: 'event',
                        item: _event!,
                      ),
                    ),
                  );
                },
                child: const Text('Feature',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ),
              TextButton(
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                onPressed: _deleteEvent,
                child: const Text('Delete',
                    style: TextStyle(color: Color(0xFFbc2023), fontSize: 12)),
              ),
            ] else ...[
              TextButton(
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                onPressed: () {},
                child: const Text('Contact',
                    style: TextStyle(color: Color(0xFFf8b324), fontSize: 12)),
              ),
              TextButton(
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                onPressed: () {},
                child: const Text('Report',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ),
            ],
          ],
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF094a25)))
          : _event == null
              ? const Center(child: Text('Event not found'))
              : RefreshIndicator(
                  onRefresh: _loadEvent,
                  color: const Color(0xFF094a25),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _typeBar(),
                        _flyerSection(),
                        _statusSection(),
                        _basicInfoSection(),
                        _ticketPricesSection(),
                        _venuesSection(),
                        _organizerSection(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
    );
  }

  // ─── Type bar ─────────────────────────────────────────────────────────────

  Widget _typeBar() {
    final eventType = _event?['event_type'] as Map?;
    final typeName = eventType?['name'] ?? '';
    final name = _event?['name'] ?? '';

    return Column(
      children: [
        Container(
          color: const Color(0xFF0a5c2e),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
              if (typeName.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(typeName,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ─── Flyer ────────────────────────────────────────────────────────────────

  Widget _flyerSection() {
    final flyer = _event?['flyer'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: flyer != null
            ? CachedNetworkImage(
                imageUrl: flyer,
                width: double.infinity,
                fit: BoxFit.contain,
                errorWidget: (_, __, ___) => _flyerPlaceholder())
            : _flyerPlaceholder(),
      ),
    );
  }

  Widget _flyerPlaceholder() => Container(
        width: double.infinity,
        height: 200,
        color: const Color(0xFF094a25).withValues(alpha: 0.1),
        child: const Icon(Icons.event_outlined,
            color: Color(0xFF094a25), size: 60),
      );

  // ─── Status section ───────────────────────────────────────────────────────

  Widget _statusSection() {
    final status = _eventStatus();
    final startDate = _event?['start_date'];
    final createdAt = _event?['created_at'];

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (status.isNotEmpty)
            Text(status,
                style: const TextStyle(fontSize: 12, color: Color(0xFF094a25))),
          const SizedBox(height: 4),
          Text(_formatDate(startDate?.toString()),
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF094a25))),
          if (createdAt != null) ...[
            const SizedBox(height: 6),
            Text('Posted on: ${_formatDate(createdAt.toString())}',
                style: const TextStyle(fontSize: 12, color: Colors.black45)),
          ],
          if (_isExpired) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFbc2023),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('Expired',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Basic info ───────────────────────────────────────────────────────────

  Widget _basicInfoSection() {
    final startDate = _event?['start_date'];
    final endDate = _event?['end_date'];
    final repeats = _event?['repeats'] == true;
    final description = _event?['description'] ?? '';

    final repeatDays = <String>[];
    const dayKeys = [
      ('repeat_monday', 'Mondays'),
      ('repeat_tuesday', 'Tuesdays'),
      ('repeat_wednesday', 'Wednesdays'),
      ('repeat_thursday', 'Thursdays'),
      ('repeat_friday', 'Fridays'),
      ('repeat_saturday', 'Saturdays'),
      ('repeat_sunday', 'Sundays'),
    ];
    for (final d in dayKeys) {
      if (_event?[d.$1] == true) repeatDays.add(d.$2);
    }

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Basic Info'),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow('Start Date', _formatDate(startDate?.toString())),
                const SizedBox(height: 8),
                _detailRow('Start Time', _formatTime(startDate?.toString())),
                const SizedBox(height: 8),
                _detailRow('End Date', _formatDate(endDate?.toString())),
                const SizedBox(height: 8),
                _detailRow('End Time', _formatTime(endDate?.toString())),
                const SizedBox(height: 8),
                _detailRow('Repeats', repeats ? 'Yes' : 'No'),
                if (repeats && endDate != null) ...[
                  const SizedBox(height: 8),
                  _detailRow('Repeats Until', _formatDate(endDate.toString())),
                ],
                if (repeatDays.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Repeat Days:',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: repeatDays
                        .map((d) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF094a25)
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(d,
                                  style: const TextStyle(
                                      fontSize: 12, color: Color(0xFF094a25))),
                            ))
                        .toList(),
                  ),
                ],
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Event Detail',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54)),
                  const SizedBox(height: 6),
                  Text(description,
                      style: const TextStyle(
                          fontSize: 13, color: Colors.black87, height: 1.5)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Ticket prices ────────────────────────────────────────────────────────

  Widget _ticketPricesSection() {
    final pricesFrom = _event?['prices_from'];
    final pricesTo = _event?['prices_to'];

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Ticket Prices'),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow(
                  'Prices From',
                  pricesFrom == null ? 'Free of charge' : 'R$pricesFrom',
                ),
                if (pricesTo != null) ...[
                  const SizedBox(height: 8),
                  _detailRow('Prices To', 'R$pricesTo'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Venues ───────────────────────────────────────────────────────────────

  Widget _venuesSection() {
    final venues = _event?['venues'] as List? ?? [];

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Venue${venues.length > 1 ? 's' : ''}'),
          Padding(
            padding: const EdgeInsets.all(16),
            child: venues.isEmpty
                ? const Text('No venue information',
                    style: TextStyle(fontSize: 12, color: Colors.black45))
                : Column(
                    children: venues
                        .map((v) => _venueCard(v as Map<String, dynamic>))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _venueCard(Map<String, dynamic> venue) {
    final area = venue['area'] as Map?;
    final city = area != null ? area['city'] as Map? : venue['city'] as Map?;
    final province = city?['province'] as Map?;
    final areaName = area?['name'];
    final cityName = city?['name'];
    final provinceName = province?['name'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(venue['name']?.toString() ?? '',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFbc2023))),
          const SizedBox(height: 8),
          if (venue['street'] != null)
            _detailRow('Street', venue['street'].toString()),
          if (areaName != null) ...[
            const SizedBox(height: 4),
            _detailRow('Area', areaName.toString()),
          ],
          if (cityName != null) ...[
            const SizedBox(height: 4),
            _detailRow('City', cityName.toString()),
          ],
          if (provinceName != null) ...[
            const SizedBox(height: 4),
            _detailRow('Province', provinceName.toString()),
          ],
        ],
      ),
    );
  }

  // ─── Organizer ────────────────────────────────────────────────────────────

  Widget _organizerSection() {
    final organizer = _event?['organizer'];
    final phone = _event?['organizer_phone'];
    final email = _event?['organizer_email'];
    final website = _event?['event_website'];

    final hasData =
        organizer != null || phone != null || email != null || website != null;

    if (!hasData) return const SizedBox.shrink();

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Event Organizer'),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (organizer != null) ...[
                  _detailRow('Contact', organizer.toString()),
                  const SizedBox(height: 8),
                ],
                if (phone != null) ...[
                  _detailRow('Phone', phone.toString()),
                  const SizedBox(height: 8),
                ],
                if (email != null) ...[
                  _detailRow('Email', email.toString()),
                  const SizedBox(height: 8),
                ],
                if (website != null && website.toString().isNotEmpty)
                  _detailRow('Website', website.toString()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Shared helpers ───────────────────────────────────────────────────────

  Widget _sectionHeader(String title) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: const Color(0xFF094a25),
        child: Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold)),
      );

  Widget _detailRow(String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text('$label:',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 12, color: Colors.black87)),
          ),
        ],
      );
}
