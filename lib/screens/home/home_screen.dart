import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../dashboard/dashboard_screen.dart';
import '../directory/directory_screen.dart';
import '../mail/mail_screen.dart';
import '../alerts/alerts_screen.dart';
import '../profile/profile_screen.dart';
import '../classifieds/classifieds_screen.dart';
import '../events/events_screen.dart';
import '../jobs/jobs_screen.dart';
import '../leads/leads_screen.dart';
import '../opportunities/opportunities_screen.dart';
import '../projects/projects_screen.dart';
import '../websites/websites_screen.dart';
import '../account/account_screen.dart';
import '../settings/settings_screen.dart';
import '../people/people_screen.dart';
import '../products/products_screen.dart';
import '../services/services_screen.dart';
import '../cart/cart_screen.dart';
import '../bookmarks/bookmarks_screen.dart';
import '../contacts/contacts_screen.dart';
import '../../providers/cart_provider.dart';
import '../give_feedback.dart';
import '../help_screen.dart';
import '../../widgets/sesh_agent.dart';
import '../../services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = -1;
  Map<String, dynamic> _seshaSettings = {};
  final List<int> _history = [];

  final List<Map<String, dynamic>> _sections = [
    {'title': 'Account', 'icon': Icons.account_circle_outlined},
    {'title': 'Settings', 'icon': Icons.settings_outlined},
    {'title': 'Profile', 'icon': Icons.person_outline},
    {'title': 'Alerts', 'icon': Icons.notifications_outlined},
    {'title': 'Mail', 'icon': Icons.mail_outline},
    {'title': 'Cart', 'icon': Icons.shopping_cart_outlined},
    {'title': 'Bookmarks', 'icon': Icons.bookmark_outline},
    {'title': 'Classifieds', 'icon': Icons.sell_outlined},
    {'title': 'Contacts', 'icon': Icons.contacts_outlined},
    {'title': 'Directory', 'icon': Icons.business},
    {'title': 'Events', 'icon': Icons.event_outlined},
    {'title': 'Jobs', 'icon': Icons.work_outline},
    {'title': 'Leads', 'icon': Icons.people_outline},
    {'title': 'Opportunities', 'icon': Icons.trending_up},
    {'title': 'People', 'icon': Icons.group_outlined},
    {'title': 'Products', 'icon': Icons.shopping_bag_outlined},
    {'title': 'Projects', 'icon': Icons.lightbulb_outline},
    {'title': 'Services', 'icon': Icons.miscellaneous_services_outlined},
    {'title': 'Websites', 'icon': Icons.language},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().apiService.refreshIfNeeded();
    });
    _loadSeshaSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<AuthProvider>().apiService.refreshIfNeeded();
    }
  }

  void _navigateTo(int index) {
    setState(() {
      _history.add(_currentIndex);
      _currentIndex = index;
    });
  }

  void _navigateToNamed(String name) {
    final index = _sections.indexWhere((s) => s['title'] == name);
    if (index != -1) _navigateTo(index);
  }

  void _goBack() {
    if (_history.isNotEmpty) {
      setState(() => _currentIndex = _history.removeLast());
    } else {
      SystemNavigator.pop();
    }
  }

  Future<void> _loadSeshaSettings() async {
    try {
      final api = context.read<ApiService>();
      final res = await api.dio.get('/api/v1/sesha/settings/');
      setState(() => _seshaSettings = res.data as Map<String, dynamic>);
    } catch (_) {}
  }

  Widget _currentScreen() {
    if (_currentIndex == -1) {
      return DashboardScreen(
        onProfileTap: () => _navigateToNamed('Profile'),
        onNavigate: _navigateToNamed,
      );
    }
    switch (_sections[_currentIndex]['title']) {
      case 'Account':
        return const AccountScreen();
      case 'Bookmarks':
        return const BookmarksScreen();
      case 'Contacts':
        return const ContactsScreen();
      case 'Cart':
        return const CartScreen();
      case 'Directory':
        return const DirectoryScreen();
      case 'Mail':
        return const MailScreen();
      case 'Alerts':
        return const AlertsScreen();
      case 'Profile':
        return const ProfileScreen();
      case 'Classifieds':
        return const ClassifiedsScreen();
      case 'Events':
        return const EventsScreen();
      case 'Jobs':
        return const JobsScreen();
      case 'Leads':
        return const LeadsScreen();
      case 'Opportunities':
        return const OpportunitiesScreen();
      case 'People':
        return const PeopleScreen();
      case 'Products':
        return const ProductsScreen();
      case 'Projects':
        return const ProjectsScreen();
      case 'Services':
        return const ServicesScreen();
      case 'Settings':
        return const SettingsScreen();
      case 'Websites':
        return const WebsitesScreen();
      default:
        return Center(
          child: Text(
            _sections[_currentIndex]['title'] as String,
            style: const TextStyle(fontSize: 24, color: Color(0xFF094a25)),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF094a25),
          iconTheme: const IconThemeData(color: Colors.white),
          titleSpacing: 0,
          title: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: GestureDetector(
              onTap: () => setState(() {
                _history.add(_currentIndex);
                _currentIndex = -1;
              }),
              child: Image.asset('assets/img/sesha.png', height: 40),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.mail_outline, color: Colors.white),
              onPressed: () => _navigateToNamed('Mail'),
            ),
            IconButton(
              icon:
                  const Icon(Icons.notifications_outlined, color: Colors.white),
              onPressed: () => _navigateToNamed('Alerts'),
            ),
            Consumer<CartProvider>(
              builder: (context, cart, _) => Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_cart_outlined,
                        color: Colors.white),
                    onPressed: () => _navigateToNamed('Cart'),
                  ),
                  if (cart.isNotEmpty)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Color(0xFFbc2023),
                          shape: BoxShape.circle,
                        ),
                        constraints:
                            const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          '${cart.itemCount}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        drawer: Drawer(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    DrawerHeader(
                      decoration: const BoxDecoration(color: Color(0xFF094a25)),
                      child: Center(
                        child: Image.asset('assets/img/sesha.png', height: 60),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.dashboard_outlined,
                          color: Color(0xFF094a25)),
                      title: const Text('Dashboard'),
                      selected: _currentIndex == -1,
                      selectedTileColor:
                          const Color(0xFF094a25).withValues(alpha: 0.1),
                      onTap: () {
                        setState(() {
                          _history.add(_currentIndex);
                          _currentIndex = -1;
                        });
                        Navigator.pop(context);
                      },
                    ),
                    const Divider(height: 1),
                    _sectionHeader('User'),
                    _navItem('Account'),
                    _navItem('Settings'),
                    _navItem('Profile'),
                    const Divider(height: 1),
                    _sectionHeader('Engagement'),
                    _navItem('Alerts'),
                    _navItem('Mail'),
                    _navItem('Cart'),
                    _navItem('Bookmarks'),
                    const Divider(height: 1),
                    _sectionHeader('Applications'),
                    _navItem('Classifieds'),
                    _navItem('Contacts'),
                    _navItem('Directory'),
                    _navItem('Events'),
                    _navItem('Jobs'),
                    _navItem('Leads'),
                    _navItem('Opportunities'),
                    _navItem('People'),
                    _navItem('Products'),
                    _navItem('Projects'),
                    _navItem('Services'),
                    _navItem('Websites'),
                    const Divider(height: 1),
                    _sectionHeader('Help'),
                    ListTile(
                      dense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      leading: const Icon(Icons.help_outline,
                          size: 20, color: Color(0xFF094a25)),
                      title: const Text('Help',
                          style:
                              TextStyle(fontSize: 14, color: Colors.black87)),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => HelpScreen(),
                            ));
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading:
                          const Icon(Icons.logout, color: Color(0xFFbc2023)),
                      title: const Text('Logout',
                          style: TextStyle(color: Color(0xFFbc2023))),
                      onTap: () {
                        Navigator.pop(context);
                        Provider.of<AuthProvider>(context, listen: false)
                            .logout();
                      },
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.black12)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        _footerLink('About'),
                        _footerLink('Terms'),
                        _footerLink('Privacy'),
                        _footerLink('Cookies'),
                        _footerLink('Feedback'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text('© 2026 Sesha. All rights reserved.',
                        style: TextStyle(fontSize: 11, color: Colors.black45)),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: Stack(
          children: [
            _currentScreen(),
            SeshAgent(
              enabled: _seshaSettings['ai_agent'] == true &&
                  _seshaSettings['ai_agent_maintenance'] != true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.black45,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _navItem(String title) {
    final index = _sections.indexWhere((s) => s['title'] == title);
    final isSelected = _currentIndex == index;
    final icon =
        index != -1 ? _sections[index]['icon'] as IconData : Icons.circle;

    if (index == -1) {
      return ListTile(
        dense: true,
        leading: Icon(icon, size: 18, color: Colors.black26),
        title: Text(title,
            style: const TextStyle(fontSize: 14, color: Colors.black38)),
      );
    }

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      leading: Icon(icon,
          size: 20, color: isSelected ? Colors.white : const Color(0xFF094a25)),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: const Color(0xFF094a25),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      onTap: () {
        _navigateTo(index);
        Navigator.pop(context);
      },
    );
  }

  Widget _footerLink(String title) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        switch (title) {
          case 'Feedback':
            Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const FeedbackScreen(),
                ));
            break;
          case 'Help':
            Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HelpScreen(),
                ));
            break;
          case 'About':
          case 'Terms':
          case 'Privacy':
          case 'Cookies':
            final slugs = {
              'About': 'about',
              'Terms': 'terms',
              'Privacy': 'privacy',
              'Cookies': 'cookies',
            };
            final url = Uri.parse('https://sesha.co.za/sesha-${slugs[title]}');
            launchUrl(url, mode: LaunchMode.externalApplication);
            break;
        }
      },
      child: Text(title,
          style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF094a25),
              decoration: TextDecoration.underline)),
    );
  }
}
