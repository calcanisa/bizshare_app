import 'package:flutter/material.dart';

class HelpScreen extends StatefulWidget {
  final String initialPage;

  const HelpScreen({super.key, this.initialPage = ''});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  static const _green = Color(0xFF1B4748);

  static const _pages = [
    ('', 'Overview'),
    ('account', 'Account'),
    ('advertise', 'Advertise'),
    ('alerts', 'Alerts'),
    ('bookmarks', 'Bookmarks'),
    ('cart', 'Cart'),
    ('classifieds', 'Classifieds'),
    ('dashboard', 'Dashboard'),
    ('directory', 'Directory'),
    ('events', 'Events'),
    ('jobs', 'Jobs'),
    ('leads', 'Leads'),
    ('mail', 'Mail'),
    ('products', 'Products'),
    ('profile', 'Profile'),
    ('services', 'Services'),
    ('settings', 'Settings'),
    ('websites', 'Websites'),
  ];

  late String _activePage;

  @override
  void initState() {
    super.initState();
    _activePage = widget.initialPage;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        title: const Text('Help'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Topic tabs
            Container(
              color: _green,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: _pages.map((p) {
                    final isActive = _activePage == p.$1;
                    return GestureDetector(
                      onTap: () => setState(() => _activePage = p.$1),
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.white
                              : _green.withValues(alpha: 0.0),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isActive ? Colors.white : Colors.white38,
                          ),
                        ),
                        child: Text(
                          p.$2,
                          style: TextStyle(
                            fontSize: 12,
                            color: isActive ? _green : Colors.white,
                            fontWeight:
                                isActive ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _buildContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_activePage) {
      case '':
        return _helpBlock('The Help System', [
          'We want you to be able to use BizShare as easy as possible. We created this help so that you know how to do things that are not self explanatory.',
          'Please tap on the tab above of the section you need assistance with. Should any information be missing or need further explanation please email us at support@bizshare.co.za and we will respond as soon as possible.',
        ]);
      case 'account':
        return _helpBlock('Account Help', [
          'Your account page is one of the more important pages on the app as it controls access, your membership, the affiliate program and other important functions.',
          'The Affiliate tab is where you join the free BizShare Affiliate Program, copy your referral link and code, track your commission and request withdrawals.',
          'To edit your account tap the Edit button. Your account will switch to edit mode where you can update your details section by section.',
        ]);
      case 'advertise':
        return _helpBlock('Advertising Help', [
          'Your account must have a positive balance exceeding R500 in order for you to place any ads.',
          'Advertising on BizShare is easy. Tap the Create button, choose your goal, give your ad a title, add text, a link and schedule when it will run.',
          'You can set a budget per interval — ads stop running when that limit is reached for that time period.',
          'Ads can be extended to display more information when users tap a special button. You can add extra text, more images, a video and an extra link.',
        ]);
      case 'alerts':
        return _helpBlock('Alerts Help', [
          'There are two types of alerts: User Alerts and System Alerts.',
          'User alerts are specific to you as an individual, like when someone messages one of your businesses or applies to one of your jobs.',
          'System alerts are announcements from BizShare about major news or improvements.',
        ]);
      case 'bookmarks':
        return _helpBlock('Bookmarks Help', [
          'Bookmarks let you save specific content pieces to your favourites so you can access them again quickly.',
          'Tap on the tab for the content type you want to see your bookmarks of.',
        ]);
      case 'cart':
        return _helpBlock('Cart Help', [
          'The cart displays all products you have added, with each item showing its price, VAT and a button to remove it.',
          'At the bottom is the total. If you are buying a membership and a BizShare affiliate introduced you, you can enter their affiliate code so they are credited. It does not change your price.',
          'Accept the terms and proceed to payment. Wait for the payment processor to complete before doing anything else.',
        ]);
      case 'classifieds':
        return _helpBlock('Classifieds Help', [
          'Classifieds are for paying members only. Only paying members can create ads and send other advertisers messages.',
          'The first tab shows your own ads. Your ads can be edited or deleted.',
          'The second tab shows all current ads. You can filter ads to find what you are looking for.',
        ]);
      case 'dashboard':
        return _helpBlock('Dashboard Help', [
          'The dashboard is your starting point. At the top is the header with the logo, notifications, mail and cart.',
          'Below is your profile preview with your profile picture and name.',
          'Below your profile is a list of applications available on BizShare. Tap on any application to open it.',
        ]);
      case 'directory':
        return _helpBlock('Directory Help', [
          'The directory lists businesses — your own and those of others. There are two tabs named accordingly.',
          'You can edit, feature and delete your own businesses.',
          'For all businesses, select a category first and businesses for that category will appear.',
        ]);
      case 'events':
        return _helpBlock('Events Help', [
          'The events page has four tabs: your events, all current events, event photos (Silver/Gold members) and venues.',
          'Your events are split into current and past. All events only shows current events — select a province to see events from that province.',
          'Event photos are taken by people at past events. Venues are businesses that host events and can be bookmarked.',
        ]);
      case 'jobs':
        return _helpBlock('Jobs Help', [
          'The jobs page has three tabs: Your Jobs, Jobs Applied For and All Jobs.',
          'Your Jobs lists jobs you created — you can edit or delete them.',
          'Jobs Applied For shows your applications — you can edit or delete an application.',
          'All Jobs shows all available jobs with filters to find the right one.',
        ]);
      case 'leads':
        return _helpBlock('Leads Help', [
          'The leads page has three tabs: your leads, what you are looking for and your requests.',
          'Leads appear automatically when anyone makes a request for products or services that any of your businesses offer.',
        ]);
      case 'mail':
        return _helpBlock('Mail Help', [
          'The mail centre shows all messages sent to you from any of your content items — businesses, events, classifieds and jobs.',
          'Only paying members can send messages related to classified ads or jobs.',
          'Tap on any message to see the full message and reply.',
        ]);
      case 'products':
        return _helpBlock('Products Help', [
          'Products shows items linked from your business profile.',
          'They link to the real product pages on your website — this is to show the type of products you sell.',
          'Add your top products using the Add Product button on your business page.',
        ]);
      case 'profile':
        return _helpBlock('Profile Help', [
          'Your profile is a vital part of BizShare — people can see your skills and why they should connect with you.',
          'Your profile has tabs for General info, Professional info, Content, Contact details and Media.',
          'If you have a membership you can generate a PDF CV from your Professional tab.',
        ]);
      case 'services':
        return _helpBlock('Services Help', [
          'Services shows the professional services your business offers.',
          'Each service has a pitch explaining what makes you better than the competition, and an optional rate.',
          'Add services using the Add Service button on your business page.',
        ]);
      case 'settings':
        return _helpBlock('Settings Help', [
          'Settings control how the app behaves for you.',
          'You can update your password, email, privacy settings and notification preferences.',
          'Some settings are only available to members.',
        ]);
      case 'websites':
        return _helpBlock('Websites Help', [
          'Websites has two tabs: your own websites and all websites.',
          'When you create a business and add a website, an automatic listing is created. You should edit it to add a type and category.',
          'Only single domain websites are allowed — no subdomains or specific pages.',
        ]);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _helpBlock(String title, List<String> paragraphs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.bold, color: _green)),
        const SizedBox(height: 16),
        ...paragraphs.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(p,
                  style: const TextStyle(
                      fontSize: 14, color: Colors.black87, height: 1.6)),
            )),
      ],
    );
  }
}
