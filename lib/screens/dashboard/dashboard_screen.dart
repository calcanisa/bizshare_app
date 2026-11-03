import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../services/api_service.dart';
import '../../utils/account_notifiers.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onProfileTap;
  final void Function(String)? onNavigate;
  final Map<String, dynamic> seshaSettings;

  const DashboardScreen({
    super.key,
    this.onProfileTap,
    this.onNavigate,
    this.seshaSettings = const {},
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late DashboardProvider _provider;

  bool _isEnabled(String? settingKey) {
    if (settingKey == null) return true;
    if (widget.seshaSettings.isEmpty) return false;
    return widget.seshaSettings[settingKey] == true;
  }

  @override
  void initState() {
    super.initState();
    _provider = DashboardProvider(context.read<ApiService>());
    _provider.load();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Consumer<DashboardProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF1B4748)));
          }
          return RefreshIndicator(
            onRefresh: provider.load,
            color: const Color(0xFF1B4748),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  _systemAlert(provider.systemMessage),
                  _membershipBadge(provider),
                  _profileSection(provider),
                  _countsSection(provider),
                  _statsSection(provider),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFF1B4748),
      child: Text(title,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
    );
  }

  Widget _systemAlert(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFF1B4748),
      child: Text(
        message.length > 80 ? '${message.substring(0, 80)}...' : message,
        style: const TextStyle(color: Color(0xFFF8BB25), fontSize: 13),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _membershipBadge(DashboardProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: () {
              widget.onNavigate?.call('Account');
              Future.delayed(const Duration(milliseconds: 300), () {
                accountEditUpgradeNotifier.value = true;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: provider.membershipColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${provider.membershipLabel} Member',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_ios,
                      color: Colors.white70, size: 11),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileSection(DashboardProvider provider) {
    final profile = provider.account?['profile'];
    final firstName = profile?['first_name'] ?? '';
    final lastName = profile?['last_name'] ?? '';
    final about = profile?['about'] ?? '';
    final picture = profile?['profile_picture'];
    final views = provider.count('profiles.ProfileView');
    final clicks = provider.count('profiles.ProfileClick');

    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 4),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Profile'),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: widget.onProfileTap,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: picture != null
                        ? Image.network(
                            picture,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _profilePlaceholder(),
                          )
                        : _profilePlaceholder(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: widget.onProfileTap,
                        child: Text(
                          '$firstName $lastName',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1B4748)),
                        ),
                      ),
                      if (about.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          about.length > 200
                              ? '${about.substring(0, 200)}...'
                              : about,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black54),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _statChip('Views', views),
                          const SizedBox(width: 16),
                          _statChip('Clicks', clicks),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profilePlaceholder() {
    return Container(
      width: 80,
      height: 80,
      color: const Color(0xFF1B4748).withValues(alpha: 0.1),
      child: const Icon(Icons.person, color: Color(0xFF1B4748), size: 40),
    );
  }

  Widget _statChip(String label, int value) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.black45)),
        Text('$value',
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B4748))),
      ],
    );
  }

  Widget _countsSection(DashboardProvider provider) {
    // setting: null means always visible
    final allItems = [
      {
        'key': 'directory.Business',
        'label': 'Businesses',
        'icon': Icons.business,
        'route': 'Directory',
        'setting': null
      },
      {
        'key': 'classifieds.Classified',
        'label': 'Classifieds',
        'icon': Icons.sell_outlined,
        'route': 'Classifieds',
        'setting': 'classifieds'
      },
      {
        'key': 'events.Event',
        'label': 'Events',
        'icon': Icons.event_outlined,
        'route': 'Events',
        'setting': 'events'
      },
      {
        'key': 'jobs.Job',
        'label': 'Jobs',
        'icon': Icons.work_outline,
        'route': 'Jobs',
        'setting': 'jobs'
      },
      {
        'key': 'directory.ServiceLeadMatches',
        'label': 'Leads',
        'icon': Icons.people_outline,
        'route': 'Leads',
        'setting': null
      },
      {
        'key': 'opportunities.Opportunity',
        'label': 'Opportunities',
        'icon': Icons.trending_up,
        'route': 'Opportunities',
        'setting': 'opportunities'
      },
      {
        'key': 'projects.Project',
        'label': 'Projects',
        'icon': Icons.lightbulb_outline,
        'route': 'Projects',
        'setting': 'projects'
      },
      {
        'key': 'websites.Website',
        'label': 'Websites',
        'icon': Icons.language,
        'route': 'Websites',
        'setting': null
      },
    ];

    final items = allItems
        .where((item) => _isEnabled(item['setting'] as String?))
        .toList();

    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Applications'),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 16,
              children: items.map((item) {
                final width = (MediaQuery.of(context).size.width - 56) / 4;
                return GestureDetector(
                  onTap: () => widget.onNavigate?.call(item['route'] as String),
                  child: SizedBox(
                    width: width,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B4748),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(item['icon'] as IconData,
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${provider.count(item['key'] as String)}',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1B4748)),
                        ),
                        Text(
                          item['label'] as String,
                          style: const TextStyle(
                              fontSize: 10, color: Colors.black87),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsSection(DashboardProvider provider) {
    final allStats = [
      {
        'key': 'directory.Business',
        'label': 'Businesses',
        'icon': Icons.business,
        'route': 'Directory',
        'setting': null,
        'viewKey': 'directory.BusinessView',
        'clickKey': 'directory.BusinessClick',
        'extraKey': null,
        'extraLabel': null
      },
      {
        'key': 'classifieds.Classified',
        'label': 'Classifieds',
        'icon': Icons.sell_outlined,
        'route': 'Classifieds',
        'setting': 'classifieds',
        'viewKey': 'classifieds.ClassifiedView',
        'clickKey': 'classifieds.ClassifiedClick',
        'extraKey': null,
        'extraLabel': null
      },
      {
        'key': 'events.Event',
        'label': 'Events',
        'icon': Icons.event_outlined,
        'route': 'Events',
        'setting': 'events',
        'viewKey': 'events.EventView',
        'clickKey': 'events.EventClick',
        'extraKey': null,
        'extraLabel': null
      },
      {
        'key': 'jobs.Job',
        'label': 'Jobs',
        'icon': Icons.work_outline,
        'route': 'Jobs',
        'setting': 'jobs',
        'viewKey': 'jobs.JobView',
        'clickKey': 'jobs.JobClick',
        'extraKey': 'jobs.JobApplication',
        'extraLabel': 'Applications'
      },
      {
        'key': 'opportunities.Opportunity',
        'label': 'Opportunities',
        'icon': Icons.trending_up,
        'route': 'Opportunities',
        'setting': 'opportunities',
        'viewKey': 'opportunities.OpportunityView',
        'clickKey': 'opportunities.OpportunityClick',
        'extraKey': 'opportunities.OpportunityApplicationsReceived',
        'extraLabel': 'Applications'
      },
      {
        'key': 'projects.Project',
        'label': 'Projects',
        'icon': Icons.lightbulb_outline,
        'route': 'Projects',
        'setting': 'projects',
        'viewKey': 'projects.ProjectView',
        'clickKey': 'projects.ProjectClick',
        'extraKey': 'projects.ProjectInterestReceived',
        'extraLabel': 'Interests'
      },
      {
        'key': 'websites.Website',
        'label': 'Websites',
        'icon': Icons.language,
        'route': 'Websites',
        'setting': null,
        'viewKey': 'websites.WebsiteView',
        'clickKey': 'websites.WebsiteClick',
        'extraKey': null,
        'extraLabel': null
      },
    ];

    final visible = allStats
        .where((s) =>
            _isEnabled(s['setting'] as String?) &&
            provider.count(s['key'] as String) > 0)
        .toList();

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Statistics'),
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'No content created yet — statistics will appear here once you start adding content.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF1B4748)),
                ),
              ),
            )
          else
            ...visible.map((s) => _statRow(provider, s)),
        ],
      ),
    );
  }

  Widget _statRow(DashboardProvider provider, Map<String, dynamic> s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.black12))),
      child: Row(
        children: [
          Icon(s['icon'] as IconData, color: const Color(0xFF1B4748), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => widget.onNavigate?.call(s['route'] as String),
              child: Text(
                s['label'] as String,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1B4748),
                    decoration: TextDecoration.underline,
                    decorationColor: Color(0xFF1B4748)),
              ),
            ),
          ),
          _miniStat('Views', provider.count(s['viewKey'] as String)),
          const SizedBox(width: 16),
          _miniStat('Clicks', provider.count(s['clickKey'] as String)),
          if (s['extraKey'] != null) ...[
            const SizedBox(width: 16),
            _miniStat(s['extraLabel'] as String,
                provider.count(s['extraKey'] as String)),
          ],
        ],
      ),
    );
  }

  Widget _miniStat(String label, int value) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.black54)),
        Text('$value',
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B4748))),
      ],
    );
  }
}
