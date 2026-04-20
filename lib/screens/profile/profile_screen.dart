import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _profile;
  bool _loading = true;
  int _userId = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      final accountResponse = await api.dio.get('/api/v1/users/current/');
      _userId = accountResponse.data['id'];
      final response = await api.dio.get('/api/v1/user/$_userId/profile/');
      setState(() => _profile = response.data);
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF094a25)));
    }
    if (_profile == null) {
      return const Center(child: Text('Could not load profile'));
    }
    final firstName = _profile!['first_name'] ?? '';
    final lastName = _profile!['last_name'] ?? '';
    final headline = _profile!['headline'] ?? '';
    final picture = _profile!['profile_picture'];
    final hero = _profile!['hero_picture'];

    return RefreshIndicator(
      onRefresh: _loadProfile,
      color: const Color(0xFF094a25),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            // Hero image
            SizedBox(
              height: 150,
              width: double.infinity,
              child: hero != null && hero.toString().isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: hero,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          Container(color: const Color(0xFF094a25)))
                  : Container(color: const Color(0xFF094a25)),
            ),
            // Profile picture + name
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: picture != null && picture.toString().isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: picture,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _picPlaceholder())
                        : _picPlaceholder(),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$firstName $lastName',
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF094a25))),
                        if (headline.isNotEmpty)
                          Text(headline,
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.black54)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Tab buttons
            Container(
              color: const Color(0xFF094a25),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _tabButton(0, 'General'),
                    _tabButton(1, 'Professional'),
                    _tabButton(2, 'Content'),
                    _tabButton(3, 'Contact'),
                    _tabButton(4, 'Media'),
                  ],
                ),
              ),
            ),
            // Tab content
            _currentTabContent(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(int index, String label) {
    final isActive = _tabController.index == index;
    return GestureDetector(
      onTap: () => setState(() => _tabController.index = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? const Color(0xFFf8b324) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? const Color(0xFFf8b324) : Colors.white60,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _currentTabContent() {
    switch (_tabController.index) {
      case 0:
        return _generalTab();
      case 1:
        return _professionalTab();
      case 2:
        return _contentTab();
      case 3:
        return _contactTab();
      case 4:
        return _mediaTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _picPlaceholder() => Container(
        width: 80,
        height: 80,
        color: const Color(0xFF094a25).withOpacity(0.1),
        child: const Icon(Icons.person, color: Color(0xFF094a25), size: 40),
      );

  Widget _sectionHeader(String title) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: Colors.black87,
        child: Text(title,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
      );

  Widget _labelValue(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Color(0xFF094a25))),
          Expanded(
              child:
                  Text(value, style: const TextStyle(color: Colors.black87))),
        ],
      ),
    );
  }

  Widget _generalTab() {
    final about = _profile!['about'] ?? '';
    final intent = _profile!['intent'] ?? '';
    final affiliates = _profile!['affiliate_links'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (about.isNotEmpty) ...[
          _sectionHeader('Introduction'),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(about, style: const TextStyle(color: Colors.black87)),
          ),
        ],
        if (intent.isNotEmpty) ...[
          _sectionHeader('Why are you here?'),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(intent, style: const TextStyle(color: Colors.black87)),
          ),
        ],
        if (affiliates.isNotEmpty) ...[
          _sectionHeader('Affiliates'),
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Users can earn a commission from the links below',
                style: TextStyle(fontSize: 12, color: Colors.black45)),
          ),
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(8),
              itemCount: affiliates.length,
              itemBuilder: (context, index) {
                final link = affiliates[index];
                return Container(
                  width: 120,
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      CachedNetworkImage(
                          imageUrl: link['image'] ?? '',
                          height: 80,
                          fit: BoxFit.contain,
                          errorWidget: (_, __, ___) => const Icon(Icons.link)),
                      const SizedBox(height: 4),
                      Text(link['affiliate'] ?? '',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF094a25)),
                          textAlign: TextAlign.center),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
        if (about.isEmpty && intent.isEmpty && affiliates.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
                child: Text('No general info available',
                    style: TextStyle(color: Colors.black45))),
          ),
      ],
    );
  }

  Widget _professionalTab() {
    final employmentStatus = _profile!['employment_status'] ?? '';
    final currentPosition = _profile!['current_position'] ?? '';
    final currentCompany = _profile!['current_company'] ?? '';
    final industry = _profile!['industry']?['name'] ?? '';
    final educations = _profile!['educations'] as List? ?? [];
    final skills = _profile!['skill_list'] as List? ?? [];
    final experiences = _profile!['experiences'] as List? ?? [];

    final employmentLabels = {
      'unemployed': 'Unemployed',
      'employed': 'Employed',
      'entrepreneur': 'Entrepreneur',
      'bizowner': 'Business Owner',
      'retired': 'Retired',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (employmentStatus.isNotEmpty)
          _labelValue('Employment Status',
              employmentLabels[employmentStatus] ?? employmentStatus),
        if (industry.isNotEmpty) _labelValue('Industry', industry),
        if (currentPosition.isNotEmpty)
          _labelValue('Current Position', currentPosition),
        if (currentCompany.isNotEmpty)
          _labelValue('Current Company', currentCompany),
        if (educations.isNotEmpty) ...[
          const SizedBox(height: 8),
          _sectionHeader('Education'),
          ...educations.map((edu) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(edu['institution'] ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF094a25))),
                    if ((edu['qualification'] ?? '').isNotEmpty)
                      Text('Qualification: ${edu['qualification']}',
                          style: const TextStyle(fontSize: 13)),
                    if ((edu['field_of_study'] ?? '').isNotEmpty)
                      Text('Field: ${edu['field_of_study']}',
                          style: const TextStyle(fontSize: 13)),
                    if (edu['year_completed'] != null)
                      Text('Year: ${edu['year_completed']}',
                          style: const TextStyle(fontSize: 13)),
                  ],
                ),
              )),
        ],
        if (skills.isNotEmpty) ...[
          const SizedBox(height: 8),
          _sectionHeader('Skills'),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: skills
                  .map((skill) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF094a25),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(skill['name'] ?? skill['title'] ?? '',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12)),
                      ))
                  .toList(),
            ),
          ),
        ],
        if (experiences.isNotEmpty) ...[
          const SizedBox(height: 8),
          _sectionHeader('Working Experience'),
          ...experiences.map((exp) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exp['position'] ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF094a25))),
                    if ((exp['company'] ?? '').isNotEmpty)
                      Text('Company: ${exp['company']}',
                          style: const TextStyle(fontSize: 13)),
                    Text(
                        exp['current'] == true
                            ? 'Current position'
                            : 'Ended: ${exp['ended'] ?? ''}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black45)),
                    if ((exp['description'] ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(exp['description'],
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black87)),
                    ],
                  ],
                ),
              )),
        ],
      ],
    );
  }

  Widget _contentTab() {
    final user = _profile!['user'] as Map<String, dynamic>? ?? {};
    final businesses = user['businesses'] as List? ?? [];
    final events = user['events'] as List? ?? [];
    final projects = user['projects'] as List? ?? [];
    final websites = user['websites'] as List? ?? [];

    final allContent = [
      if (businesses.isNotEmpty)
        {
          'label': 'Businesses',
          'items': businesses,
          'imageKey': 'logo',
          'nameKey': 'name'
        },
      if (events.isNotEmpty)
        {
          'label': 'Events',
          'items': events,
          'imageKey': 'flyer',
          'nameKey': 'name'
        },
      if (projects.isNotEmpty)
        {
          'label': 'Projects',
          'items': projects,
          'imageKey': 'image',
          'nameKey': 'title'
        },
      if (websites.isNotEmpty)
        {
          'label': 'Websites',
          'items': websites,
          'imageKey': 'image',
          'nameKey': 'name'
        },
    ];

    if (allContent.isEmpty) {
      return const Center(
          child:
              Text('No content yet', style: TextStyle(color: Colors.black45)));
    }

    return Column(
      children: allContent.map((section) {
        final items = section['items'] as List;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(section['label'] as String),
            SizedBox(
              height: 160,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(8),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index] as Map<String, dynamic>;
                  final image = item[section['imageKey']] as String?;
                  final name = item[section['nameKey']] as String? ?? '';
                  return Container(
                    width: 120,
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: image != null && image.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: image,
                                  fit: BoxFit.contain,
                                  errorWidget: (_, __, ___) =>
                                      const Icon(Icons.image_not_supported))
                              : const Icon(Icons.image_not_supported,
                                  color: Colors.black26),
                        ),
                        const SizedBox(height: 4),
                        Text(
                            name.length > 20
                                ? '${name.substring(0, 20)}...'
                                : name,
                            style: const TextStyle(fontSize: 11),
                            textAlign: TextAlign.center),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _contactTab() {
    final contactEmail = _profile!['contact_email'] ?? '';
    final contactNumber = _profile!['contact_number'] ?? '';
    final locations = _profile!['locations'] as List? ?? [];
    final socialProfiles = _profile!['social_profiles'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (contactEmail.isNotEmpty || contactNumber.isNotEmpty) ...[
          _sectionHeader('Contact Information'),
          if (contactEmail.isNotEmpty) _labelValue('Email', contactEmail),
          if (contactNumber.isNotEmpty) _labelValue('Phone', contactNumber),
        ],
        if (locations.isNotEmpty) ...[
          const SizedBox(height: 8),
          _sectionHeader('Location'),
          ...locations.map((loc) {
            String locationStr = '';
            if (loc['area'] != null) {
              locationStr =
                  '${loc['area']['city']['province']['name']} / ${loc['area']['city']['name']} / ${loc['area']['name']}';
            } else if (loc['city'] != null) {
              locationStr =
                  '${loc['city']['province']['name']} / ${loc['city']['name']}';
            }
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      color: Color(0xFF094a25), size: 16),
                  const SizedBox(width: 8),
                  Text(locationStr,
                      style: const TextStyle(color: Colors.black87)),
                ],
              ),
            );
          }),
        ],
        if (socialProfiles.isNotEmpty) ...[
          const SizedBox(height: 8),
          _sectionHeader('Social Networks'),
          ...socialProfiles.map((social) => ListTile(
                leading: const Icon(Icons.link, color: Color(0xFF094a25)),
                title: Text(social['network'] ?? ''),
                subtitle: Text(social['url'] ?? '',
                    style: const TextStyle(fontSize: 12)),
              )),
        ],
        if (contactEmail.isEmpty &&
            contactNumber.isEmpty &&
            locations.isEmpty &&
            socialProfiles.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
                child: Text('No contact info available',
                    style: TextStyle(color: Colors.black45))),
          ),
      ],
    );
  }

  Widget _mediaTab() {
    final pictureGalleries = _profile!['picture_galleries'] as List? ?? [];
    final videoGalleries = _profile!['video_galleries'] as List? ?? [];

    if (pictureGalleries.isEmpty && videoGalleries.isEmpty) {
      return const Center(
          child: Text('No media yet', style: TextStyle(color: Colors.black45)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (pictureGalleries.isNotEmpty) ...[
          _sectionHeader('Picture Galleries'),
          ...pictureGalleries.map((gallery) {
            final images = gallery['images'] as List? ?? [];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(gallery['title'] ?? '',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF094a25))),
                ),
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: images.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () => _showImageViewer(images, index),
                        child: Container(
                          width: 120,
                          margin: const EdgeInsets.only(right: 8),
                          child: CachedNetworkImage(
                            imageUrl: images[index]['image'] ?? '',
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                const Icon(Icons.image_not_supported),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          }),
        ],
        if (videoGalleries.isNotEmpty) ...[
          _sectionHeader('Video Galleries'),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Videos available — open on web to view',
                style: TextStyle(color: Colors.black45)),
          ),
        ],
        const SizedBox(height: 40),
      ],
    );
  }

  void _showImageViewer(List images, int startIndex) {
    int currentIndex = startIndex;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            children: [
              Center(
                child: CachedNetworkImage(
                  imageUrl: images[currentIndex]['image'] ?? '',
                  fit: BoxFit.contain,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              if (images.length > 1) ...[
                Positioned(
                  left: 8,
                  top: 0,
                  bottom: 0,
                  child: IconButton(
                    icon: const Icon(Icons.chevron_left,
                        color: Colors.white, size: 36),
                    onPressed: () => setDialogState(() {
                      currentIndex =
                          (currentIndex - 1 + images.length) % images.length;
                    }),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 0,
                  bottom: 0,
                  child: IconButton(
                    icon: const Icon(Icons.chevron_right,
                        color: Colors.white, size: 36),
                    onPressed: () => setDialogState(() {
                      currentIndex = (currentIndex + 1) % images.length;
                    }),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
