import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../dashboard/dashboard_screen.dart';
import '../directory/directory_screen.dart';
import '../mail/mail_screen.dart';
import '../alerts/alerts_screen.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = -1;
  final List<int> _history = [];

  final List<Map<String, dynamic>> _sections = [
    {'title': 'Alerts', 'icon': Icons.notifications_outlined},
    {'title': 'Classifieds', 'icon': Icons.sell_outlined},
    {'title': 'Contacts', 'icon': Icons.contacts_outlined},
    {'title': 'Directory', 'icon': Icons.business},
    {'title': 'Events', 'icon': Icons.event_outlined},
    {'title': 'Jobs', 'icon': Icons.work_outline},
    {'title': 'Leads', 'icon': Icons.people_outline},
    {'title': 'Mail', 'icon': Icons.mail_outline},
    {'title': 'Opportunities', 'icon': Icons.trending_up},
    {'title': 'Products', 'icon': Icons.shopping_bag_outlined},
    {'title': 'Profile', 'icon': Icons.person_outline},
    {'title': 'Projects', 'icon': Icons.lightbulb_outline},
    {'title': 'Websites', 'icon': Icons.language},
  ];

  void _navigateTo(int index) {
    setState(() {
      _history.add(_currentIndex);
      _currentIndex = index;
    });
  }

  void _goBack() {
    if (_history.isNotEmpty) {
      setState(() {
        _currentIndex = _history.removeLast();
      });
    } else {
      SystemNavigator.pop();
    }
  }

  Widget _currentScreen() {
    if (_currentIndex == -1)
      return DashboardScreen(
        onProfileTap: () =>
            _navigateTo(_sections.indexWhere((s) => s['title'] == 'Profile')),
      );
    switch (_sections[_currentIndex]['title']) {
      case 'Directory':
        return const DirectoryScreen();
      case 'Mail':
        return const MailScreen();
      case 'Alerts':
        return const AlertsScreen();
      case 'Profile':
        return const ProfileScreen();
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
          title: Image.asset('assets/img/sesha.png', height: 35),
          actions: [
            IconButton(
              icon: const Icon(Icons.mail_outline, color: Colors.white),
              onPressed: () => _navigateTo(
                  _sections.indexWhere((s) => s['title'] == 'Mail')),
            ),
            IconButton(
              icon:
                  const Icon(Icons.notifications_outlined, color: Colors.white),
              onPressed: () => _navigateTo(
                  _sections.indexWhere((s) => s['title'] == 'Alerts')),
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: () =>
                  Provider.of<AuthProvider>(context, listen: false).logout(),
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
                          const Color(0xFF094a25).withOpacity(0.1),
                      onTap: () {
                        _navigateTo(-1);
                        Navigator.pop(context);
                      },
                    ),
                    ..._sections.asMap().entries.map((entry) {
                      final index = entry.key;
                      final section = entry.value;
                      return ListTile(
                        leading: Icon(section['icon'] as IconData,
                            color: const Color(0xFF094a25)),
                        title: Text(section['title'] as String),
                        selected: _currentIndex == index,
                        selectedTileColor:
                            const Color(0xFF094a25).withOpacity(0.1),
                        onTap: () {
                          _navigateTo(index);
                          Navigator.pop(context);
                        },
                      );
                    }),
                    const Divider(),
                    _drawerItem(
                        Icons.account_circle_outlined, 'Account', () {}),
                    _drawerItem(Icons.settings_outlined, 'Settings', () {}),
                    const Divider(),
                    _drawerItem(Icons.logout, 'Logout', () {
                      Provider.of<AuthProvider>(context, listen: false)
                          .logout();
                    }),
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
        body: _currentScreen(),
      ),
    );
  }

  ListTile _drawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF094a25)),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  Widget _footerLink(String title) {
    return GestureDetector(
      onTap: () {},
      child: Text(title,
          style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF094a25),
              decoration: TextDecoration.underline)),
    );
  }
}
