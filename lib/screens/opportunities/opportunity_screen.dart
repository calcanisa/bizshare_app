import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import 'opportunity_application.dart';
import '../report_screen.dart';

class OpportunityDetailScreen extends StatefulWidget {
  final int opportunityId;
  const OpportunityDetailScreen({super.key, required this.opportunityId});

  @override
  State<OpportunityDetailScreen> createState() =>
      _OpportunityDetailScreenState();
}

class _OpportunityDetailScreenState extends State<OpportunityDetailScreen> {
  Map<String, dynamic>? _opp;
  bool _loading = true;
  int? _accountId;
  bool _isVerified = false;
  Map<String, dynamic>? _profile;
  List<dynamic> _myApplications = [];

  final Set<int> _openApplications = {};

  @override
  void initState() {
    super.initState();
    _loadAccount();
    _loadOpportunity();
  }

  Future<void> _loadAccount() async {
    try {
      final api = context.read<ApiService>();
      final res = await api.dio.get('/api/v1/users/current/');
      setState(() {
        _accountId = res.data['id'];
        _isVerified = res.data['verified'] == true;
        _profile = res.data['profile'] as Map<String, dynamic>?;
        _myApplications = res.data['applications'] as List? ?? [];
      });
    } catch (_) {}
  }

  Future<void> _loadOpportunity() async {
    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      final res = await api.dio
          .get('/api/v1/opportunities/opportunity/${widget.opportunityId}/');
      setState(() => _opp = res.data);
    } catch (_) {
      _showSnack('Could not load opportunity. Try again.');
    }
    setState(() => _loading = false);
  }

  bool get _isOwner {
    if (_accountId == null || _opp == null) return false;
    final user = _opp!['user'];
    if (user is Map) return user['id'] == _accountId;
    return user == _accountId;
  }

  bool get _isExpired {
    final validUntil = _opp?['valid_until'];
    if (validUntil == null) return false;
    final dt = DateTime.tryParse(validUntil.toString());
    if (dt == null) return false;
    return dt.isBefore(DateTime.now());
  }

  bool get _hasApplied {
    final oppId = widget.opportunityId;
    return _myApplications
        .any((a) => int.tryParse(a['opportunity'].toString()) == oppId);
  }

  Map<String, dynamic>? get _myApplication {
    final oppId = widget.opportunityId;
    try {
      return _myApplications.firstWhere(
              (a) => int.tryParse(a['opportunity'].toString()) == oppId)
          as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  bool get _isOffline {
    final category = _opp?['category'] as Map?;
    return category?['parent'] == 1;
  }

  Future<void> _deleteOpportunity() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Opportunity'),
        content: const Text('Are you sure? This cannot be undone.'),
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
      await api.dio.delete(
          '/api/v1/opportunities/opportunity/${widget.opportunityId}/d/');
      _showSnack('Opportunity deleted');
      if (mounted) Navigator.pop(context);
    } catch (_) {
      _showSnack('Could not delete. Try again.');
    }
  }

  Future<void> _extendOpportunity() async {
    try {
      final api = context.read<ApiService>();
      final res = await api.dio
          .post('/api/v1/opportunities/opportunity/${widget.opportunityId}/e/');
      setState(() => _opp!['valid_until'] = res.data['valid_until']);
      _showSnack('Opportunity extended successfully');
    } catch (_) {
      _showSnack('Could not extend. Try again.');
    }
  }

  Future<void> _acceptApplication(int id) async {
    try {
      final api = context.read<ApiService>();
      await api.dio.post('/api/v1/opportunities/application/$id/accept/');
      _showSnack('Application accepted');
    } catch (_) {
      _showSnack('Could not accept application. Try again.');
    }
  }

  Future<void> _deleteApplication(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Application'),
        content:
            const Text('Are you sure you want to delete this application?'),
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
      await api.dio.delete('/api/v1/opportunities/application/$id/d/');
      setState(() {
        _myApplications.removeWhere((a) => a['id'] == id);
        final apps = _opp?['applications'] as List?;
        apps?.removeWhere((a) => a['id'] == id);
      });
      _showSnack('Application deleted');
    } catch (_) {
      _showSnack('Could not delete application. Try again.');
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return '';
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
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  }

  String _location() {
    final locations = _opp?['locations'] as Map?;
    if (locations == null) return '';
    final area = locations['area'] as Map?;
    if (area != null) {
      final city = area['city'] as Map?;
      final province = city?['province'] as Map?;
      return '${province?['name']} / ${city?['name']} / ${area['name']}';
    }
    final city = locations['city'] as Map?;
    if (city != null) {
      final province = city['province'] as Map?;
      return '${province?['name']} / ${city['name']}';
    }
    return '';
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
        title: Text(
          _opp?['title'] ?? 'Opportunity',
          style: const TextStyle(color: Colors.white, fontSize: 15),
          overflow: TextOverflow.ellipsis,
        ),
        actions: _buildActions(),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF094a25)))
          : _opp == null
              ? const Center(child: Text('Opportunity not found'))
              : RefreshIndicator(
                  onRefresh: _loadOpportunity,
                  color: const Color(0xFF094a25),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _categoryBar(),
                        _imageAndDetails(),
                        if (_isOwner)
                          _applicationsSection()
                        else
                          _myApplicationSection(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
    );
  }

  List<Widget> _buildActions() {
    if (_opp == null) return [];
    final actions = <Widget>[];

    if (_isOwner) {
      if (!_isExpired) {
        actions.add(TextButton(
          onPressed: _extendOpportunity,
          child: const Text('Extend',
              style: TextStyle(color: Color(0xFFf8b324), fontSize: 12)),
        ));
      }
      actions.add(TextButton(
        onPressed: () {}, // TODO: edit opportunity
        child: const Text('Edit',
            style: TextStyle(color: Color(0xFFf8b324), fontSize: 12)),
      ));
      actions.add(TextButton(
        onPressed: _deleteOpportunity,
        child: const Text('Delete',
            style: TextStyle(color: Color(0xFFbc2023), fontSize: 12)),
      ));
    } else {
      if (!_isExpired) {
        actions.add(Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ElevatedButton(
            onPressed: _hasApplied
                ? null
                : () async {
                    final result = await OpportunityApplicationSheet.show(
                      context,
                      action: 'add',
                      opportunity: _opp!,
                      profile: _profile,
                      isVerified: _isVerified,
                    );
                    if (result != null && mounted) {
                      setState(() => _myApplications.add(result));
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _hasApplied ? Colors.grey.shade400 : const Color(0xFFf8b324),
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              _hasApplied ? 'Applied' : 'Apply',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ));
      }
      actions.add(TextButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReportScreen(
              contentId: widget.opportunityId,
              type: 'opportunities',
            ),
          ),
        ),
        child: const Text('Report',
            style: TextStyle(color: Colors.white70, fontSize: 12)),
      ));
    }

    return actions;
  }

  // ─── Category bar ─────────────────────────────────────────────────────────

  Widget _categoryBar() {
    return Container(
      color: Colors.black87,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        _isOffline ? 'Offline Opportunity' : 'Online Opportunity',
        style: const TextStyle(
            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }

  // ─── Image + details ──────────────────────────────────────────────────────

  Widget _imageAndDetails() {
    final image = _opp?['image'];
    final description = _opp?['description'] ?? '';
    final oppValue = _opp?['opp_value'];
    final quoteMe = _opp?['quote_me'] == true;
    final validUntil = _opp?['valid_until'];
    final location = _location();

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (image != null && image.toString().isNotEmpty)
            CachedNetworkImage(
                imageUrl: image,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _imagePlaceholder())
          else
            _imagePlaceholder(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader('Basic Detail'),
                const SizedBox(height: 12),
                if (!_isOffline && location.isNotEmpty) ...[
                  _detailRow('Location', location),
                  const SizedBox(height: 8),
                ],
                if (description.isNotEmpty) ...[
                  Text(description,
                      style: const TextStyle(
                          fontSize: 13, color: Colors.black87, height: 1.5)),
                  const SizedBox(height: 12),
                ],
                if (quoteMe)
                  _detailRow('Quote Me', 'Yes')
                else if (oppValue != null)
                  _detailRow('Value', 'R$oppValue'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                        child: _detailRow('Valid Until',
                            _formatDate(validUntil?.toString()))),
                    if (_isExpired)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFbc2023),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Expired',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() => Container(
        height: 220,
        width: double.infinity,
        color: const Color(0xFF094a25).withValues(alpha: 0.1),
        child:
            const Icon(Icons.trending_up, color: Color(0xFF094a25), size: 60),
      );

  // ─── Applications (owner view) ────────────────────────────────────────────

  Widget _applicationsSection() {
    final applications = _opp?['applications'] as List? ?? [];
    final count = applications.length;
    final shown = applications.take(5).toList();

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
              '$count Application${count != 1 ? 's' : ''} Currently'),
          if (applications.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No applications yet.',
                  style: TextStyle(fontSize: 13, color: Colors.black45)),
            )
          else
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  ...shown.map(
                      (app) => _applicationCard(app as Map<String, dynamic>)),
                  if (count > 5)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF094a25)),
                        child: const Text('Show More'),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _applicationCard(Map<String, dynamic> app) {
    final id = app['id'] as int;
    final pitch = app['pitch'] ?? '';
    final isOpen = _openApplications.contains(id);
    final applicant = app['applicant'] as Map?;
    final profile = applicant?['profile'] as Map?;
    final firstName = profile?['first_name'] ?? '';
    final lastName = profile?['last_name'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOpen
                      ? pitch
                      : pitch.length > 100
                          ? '${pitch.substring(0, 100)}...'
                          : pitch,
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
                if (isOpen && applicant != null) ...[
                  const SizedBox(height: 8),
                  RichText(
                    text: TextSpan(
                      children: [
                        const TextSpan(
                          text: 'Applicant: ',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF094a25)),
                        ),
                        TextSpan(
                          text: '$firstName $lastName'.trim(),
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              ElevatedButton(
                onPressed: () => setState(() {
                  if (isOpen) {
                    _openApplications.remove(id);
                  } else {
                    _openApplications.add(id);
                  }
                }),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF094a25),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(isOpen ? 'Close' : 'Display',
                    style: const TextStyle(color: Colors.white, fontSize: 11)),
              ),
              const SizedBox(height: 6),
              ElevatedButton(
                onPressed: () => _acceptApplication(id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFbc2023),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Accept',
                    style: TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── My application (visitor view) ───────────────────────────────────────

  Widget _myApplicationSection() {
    final myApp = _myApplication;
    if (myApp == null) return const SizedBox.shrink();

    final pitch = myApp['pitch'] ?? '';
    final createdAt = myApp['created_at'];
    final id = myApp['id'] as int?;

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Your Application'),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pitch,
                    style: const TextStyle(
                        fontSize: 13, color: Colors.black87, height: 1.5)),
                if (createdAt != null) ...[
                  const SizedBox(height: 8),
                  Text('Applied ${_formatDate(createdAt.toString())}',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black45)),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () async {
                        final result = await OpportunityApplicationSheet.show(
                          context,
                          action: 'edit',
                          opportunity: _opp!,
                          application: myApp,
                          profile: _profile,
                        );
                        if (result != null && mounted) {
                          setState(() {
                            final i = _myApplications
                                .indexWhere((a) => a['id'] == result['id']);
                            if (i != -1) {
                              _myApplications[i] = result;
                            }
                          });
                        }
                      },
                      style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF094a25),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6)),
                      child: const Text('Edit', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    if (id != null)
                      ElevatedButton(
                        onPressed: () => _deleteApplication(id),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFbc2023),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6)),
                        child: const Text('Delete',
                            style:
                                TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                  ],
                ),
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

  Widget _detailRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text('$label:',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF094a25))),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(fontSize: 12, color: Colors.black87)),
            ),
          ],
        ),
      );
}
