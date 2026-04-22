import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  int? _accountId;

  // Results
  List<dynamic> _profiles = [];
  bool _loading = false;
  int _currentPage = 1;
  int _totalCount = 0;
  bool _hasNext = false;
  bool _hasPrev = false;
  int _selectedPageSize = 20;
  String _ordering = 'title-asc';

  // Reference data
  List<dynamic> _skills = [];
  List<dynamic> _subcategories = [];
  List<dynamic> _provinces = [];
  List<dynamic> _cities = [];

  // Applied filters
  String _filterSearch = '';
  int? _filterSkill;
  int? _filterSubcategory;
  String? _filterQualification;
  String _filterFieldOfStudy = '';
  int? _filterProvince;
  int? _filterCity;

  // Temp filter state (in-sheet)
  final _searchController = TextEditingController();
  final _fieldOfStudyController = TextEditingController();
  int? _tempSkill;
  int? _tempSubcategory;
  String? _tempQualification;
  int? _tempProvince;
  int? _tempCity;

  bool get _hasActiveFilters =>
      _filterSearch.isNotEmpty ||
      _filterSkill != null ||
      _filterSubcategory != null ||
      _filterQualification != null ||
      _filterFieldOfStudy.isNotEmpty ||
      _filterProvince != null ||
      _filterCity != null;

  static const _qualificationOptions = [
    ('matric', 'Matric / Grade 12'),
    ('certificate', 'Certificate'),
    ('higher_certificate', 'Higher Certificate'),
    ('diploma', 'Diploma'),
    ('advanced_diploma', 'Advanced Diploma'),
    ('bachelor', "Bachelor's Degree"),
    ('honours', 'Honours Degree'),
    ('postgrad_diploma', 'Postgraduate Diploma'),
    ('masters', "Master's Degree"),
    ('mba', 'MBA'),
    ('phd', 'PhD'),
    ('doctorate', 'Doctorate'),
    ('other', 'Other'),
  ];

  @override
  void initState() {
    super.initState();
    _loadReferenceData();
    _loadAccount();
    _fetchProfiles(page: 1);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fieldOfStudyController.dispose();
    super.dispose();
  }

  Future<void> _loadAccount() async {
    try {
      final api = context.read<ApiService>();
      final res = await api.dio.get('/api/v1/users/current/');
      setState(() => _accountId = res.data['id']);
    } catch (_) {}
  }

  Future<void> _loadReferenceData() async {
    try {
      final api = context.read<ApiService>();
      final results = await Future.wait([
        api.dio.get('/api/v1/locations/provinces/'),
        api.dio.get('/api/v1/profiles/skills/'),
      ]);
      final pData = results[0].data;
      final sData = results[1].data;
      setState(() {
        _provinces = pData is List ? pData : (pData['results'] ?? []);
        _skills = sData is List ? sData : (sData['results'] ?? []);
      });
    } catch (_) {}
  }

  Future<void> _loadCities(int provinceId) async {
    try {
      final api = context.read<ApiService>();
      final res = await api.dio.get('/api/v1/locations/cities/',
          queryParameters: {'province': provinceId});
      final data = res.data;
      setState(() => _cities = data is List ? data : (data['results'] ?? []));
    } catch (_) {}
  }

  Future<void> _fetchProfiles({int page = 1}) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      final params = <String, dynamic>{
        'ordering': _ordering,
        'page_size': _selectedPageSize,
      };
      if (page > 1) params['page'] = page;
      if (_filterSearch.isNotEmpty) params['search'] = _filterSearch;
      if (_filterSubcategory != null)
        params['subcategory'] = _filterSubcategory;
      else if (_filterSkill != null) params['skill'] = _filterSkill;
      if (_filterCity != null)
        params['city'] = _filterCity;
      else if (_filterProvince != null) params['province'] = _filterProvince;
      if (_filterQualification != null)
        params['qualification'] = _filterQualification;
      if (_filterFieldOfStudy.isNotEmpty)
        params['field_of_study'] = _filterFieldOfStudy;

      final res =
          await api.dio.get('/api/v1/profiles/', queryParameters: params);
      final data = res.data;
      setState(() {
        _profiles = data['results'] as List? ?? [];
        _totalCount = data['count'] ?? 0;
        _hasNext = data['next'] != null;
        _hasPrev = data['previous'] != null;
        _currentPage = page;
        if (data['subcategories'] != null) {
          _subcategories = data['subcategories'] as List;
        }
      });
    } catch (_) {
      _showSnack('Could not load profiles. Try again.');
    }
    setState(() => _loading = false);
  }

  void _openFilterSheet() async {
    _searchController.text = _filterSearch;
    _fieldOfStudyController.text = _filterFieldOfStudy;
    _tempSkill = _filterSkill;
    _tempSubcategory = _filterSubcategory;
    _tempQualification = _filterQualification;
    _tempProvince = _filterProvince;
    _tempCity = _filterCity;

    if (_tempProvince != null && _cities.isEmpty) {
      await _loadCities(_tempProvince!);
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => _buildFilterSheet(),
    );
  }

  Widget _buildFilterSheet() {
    return StatefulBuilder(
      builder: (context, setSheetState) {
        final tempSubcats = _tempSkill == null
            ? <dynamic>[]
            : _subcategories
                .where((s) =>
                    s['skill'] == _tempSkill || s['parent'] == _tempSkill)
                .toList();

        final tempCities = _tempProvince == null
            ? <dynamic>[]
            : _cities.where((c) => c['province'] == _tempProvince).toList();

        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Header
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFF094a25),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      const Text('Filter People',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            _searchController.clear();
                            _fieldOfStudyController.clear();
                            _tempSkill = null;
                            _tempSubcategory = null;
                            _tempQualification = null;
                            _tempProvince = null;
                            _tempCity = null;
                            _cities = [];
                          });
                        },
                        child: const Text('Reset',
                            style: TextStyle(color: Color(0xFFf8b324))),
                      ),
                    ],
                  ),
                ),
                // Filters
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Name search
                      _filterLabel('Name'),
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by name',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: Color(0xFF094a25)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          prefixIcon: const Icon(Icons.search,
                              size: 18, color: Colors.black45),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Skill
                      _filterLabel('Skill'),
                      _filterDropdown<int>(
                        value: _tempSkill,
                        hint: 'All Skills',
                        items: _skills
                            .map((s) => DropdownMenuItem<int>(
                                  value: s['id'],
                                  child: Text(s['name'] ?? ''),
                                ))
                            .toList(),
                        onChanged: (v) async {
                          setSheetState(() {
                            _tempSkill = v;
                            _tempSubcategory = null;
                          });
                          if (v != null) {
                            // Load subcategories for this skill
                            try {
                              final api = context.read<ApiService>();
                              final res = await api.dio.get(
                                  '/api/v1/profiles/skills/$v/subcategories/');
                              final data = res.data;
                              setState(() => _subcategories = data is List
                                  ? data
                                  : (data['results'] ?? []));
                              setSheetState(() {});
                            } catch (_) {}
                          }
                        },
                      ),
                      if (tempSubcats.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _filterDropdown<int>(
                          value: _tempSubcategory,
                          hint: 'All Sub-skills',
                          items: tempSubcats
                              .map((s) => DropdownMenuItem<int>(
                                    value: s['id'],
                                    child: Text(s['name'] ?? ''),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setSheetState(() => _tempSubcategory = v),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Qualification
                      _filterLabel('Qualification'),
                      _filterDropdown<String>(
                        value: _tempQualification,
                        hint: 'All Qualifications',
                        items: _qualificationOptions
                            .map((q) => DropdownMenuItem<String>(
                                  value: q.$1,
                                  child: Text(q.$2),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setSheetState(() => _tempQualification = v),
                      ),
                      const SizedBox(height: 16),

                      // Field of study
                      _filterLabel('Field of Study'),
                      TextField(
                        controller: _fieldOfStudyController,
                        decoration: InputDecoration(
                          hintText: 'e.g. Software Engineering',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: Color(0xFF094a25)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Province
                      _filterLabel('Province'),
                      _filterDropdown<int>(
                        value: _tempProvince,
                        hint: 'All Provinces',
                        items: _provinces
                            .map((p) => DropdownMenuItem<int>(
                                  value: p['id'],
                                  child: Text(p['name'] ?? ''),
                                ))
                            .toList(),
                        onChanged: (v) async {
                          setSheetState(() {
                            _tempProvince = v;
                            _tempCity = null;
                            _cities = [];
                          });
                          if (v != null) {
                            await _loadCities(v);
                            setSheetState(() {});
                          }
                        },
                      ),
                      if (tempCities.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _filterLabel('City'),
                        _filterDropdown<int>(
                          value: _tempCity,
                          hint: 'All Cities',
                          items: tempCities
                              .map((c) => DropdownMenuItem<int>(
                                    value: c['id'],
                                    child: Text(c['name'] ?? ''),
                                  ))
                              .toList(),
                          onChanged: (v) => setSheetState(() => _tempCity = v),
                        ),
                      ],
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                // Apply
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _filterSearch = _searchController.text.trim();
                          _filterSkill = _tempSkill;
                          _filterSubcategory = _tempSubcategory;
                          _filterQualification = _tempQualification;
                          _filterFieldOfStudy =
                              _fieldOfStudyController.text.trim();
                          _filterProvince = _tempProvince;
                          _filterCity = _tempCity;
                        });
                        Navigator.pop(context);
                        _fetchProfiles(page: 1);
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF094a25),
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('Apply Filters',
                          style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _filterLabel(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF094a25),
                fontSize: 13)),
      );

  Widget _filterDropdown<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black26),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            hint: Text(hint, style: const TextStyle(color: Colors.black45)),
            isExpanded: true,
            items: [
              DropdownMenuItem<T>(
                  value: null,
                  child: Text(hint,
                      style: const TextStyle(color: Colors.black45))),
              ...items,
            ],
            onChanged: onChanged,
          ),
        ),
      );

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Controls bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              // Filter button
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.tune, color: Color(0xFF094a25)),
                    onPressed: _openFilterSheet,
                  ),
                  if (_hasActiveFilters)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFbc2023),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              // Ordering
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _ordering,
                    isDense: true,
                    style:
                        const TextStyle(fontSize: 12, color: Color(0xFF094a25)),
                    items: const [
                      DropdownMenuItem(
                          value: 'title-asc', child: Text('Name A-Z')),
                      DropdownMenuItem(
                          value: 'title-des', child: Text('Name Z-A')),
                      DropdownMenuItem(
                          value: 'date-last', child: Text('Newest First')),
                      DropdownMenuItem(
                          value: 'date-first', child: Text('Oldest First')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _ordering = v);
                      _fetchProfiles(page: 1);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        // Active filter chips
        if (_hasActiveFilters)
          Container(
            height: 40,
            color: Colors.grey.shade50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              children: [
                if (_filterSearch.isNotEmpty)
                  _activeChip('"$_filterSearch"', () {
                    setState(() => _filterSearch = '');
                    _fetchProfiles(page: 1);
                  }),
                if (_filterSkill != null)
                  _activeChip(
                    _skills.firstWhere((s) => s['id'] == _filterSkill,
                            orElse: () => {'name': 'Skill'})['name'] ??
                        '',
                    () {
                      setState(() {
                        _filterSkill = null;
                        _filterSubcategory = null;
                      });
                      _fetchProfiles(page: 1);
                    },
                  ),
                if (_filterSubcategory != null)
                  _activeChip(
                    _subcategories.firstWhere(
                            (s) => s['id'] == _filterSubcategory,
                            orElse: () => {'name': 'Sub-skill'})['name'] ??
                        '',
                    () {
                      setState(() => _filterSubcategory = null);
                      _fetchProfiles(page: 1);
                    },
                  ),
                if (_filterQualification != null)
                  _activeChip(
                    _qualificationOptions
                        .firstWhere((q) => q.$1 == _filterQualification,
                            orElse: () => ('', _filterQualification!))
                        .$2,
                    () {
                      setState(() => _filterQualification = null);
                      _fetchProfiles(page: 1);
                    },
                  ),
                if (_filterFieldOfStudy.isNotEmpty)
                  _activeChip(_filterFieldOfStudy, () {
                    setState(() => _filterFieldOfStudy = '');
                    _fetchProfiles(page: 1);
                  }),
                if (_filterProvince != null)
                  _activeChip(
                    _provinces.firstWhere((p) => p['id'] == _filterProvince,
                            orElse: () => {'name': 'Province'})['name'] ??
                        '',
                    () {
                      setState(() {
                        _filterProvince = null;
                        _filterCity = null;
                      });
                      _fetchProfiles(page: 1);
                    },
                  ),
                if (_filterCity != null)
                  _activeChip(
                    _cities.firstWhere((c) => c['id'] == _filterCity,
                            orElse: () => {'name': 'City'})['name'] ??
                        '',
                    () {
                      setState(() => _filterCity = null);
                      _fetchProfiles(page: 1);
                    },
                  ),
              ],
            ),
          ),

        // Count + page size
        if (_totalCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            color: Colors.grey.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$_totalCount people found',
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black45)),
                Row(
                  children: [
                    const Text('Show: ',
                        style: TextStyle(fontSize: 12, color: Colors.black45)),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedPageSize,
                        isDense: true,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF094a25)),
                        items: [20, 50, 100]
                            .map((s) =>
                                DropdownMenuItem(value: s, child: Text('$s')))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _selectedPageSize = v);
                          _fetchProfiles(page: 1);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

        // Content
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF094a25)))
              : _profiles.isEmpty
                  ? const Center(
                      child: Text('No profiles found',
                          style: TextStyle(color: Color(0xFF094a25))))
                  : RefreshIndicator(
                      onRefresh: () => _fetchProfiles(page: 1),
                      color: const Color(0xFF094a25),
                      child: ListView.builder(
                        itemCount: _profiles.length + 1,
                        itemBuilder: (context, index) {
                          if (index == _profiles.length) {
                            return _paginationBar();
                          }
                          return _profileCard(
                              _profiles[index] as Map<String, dynamic>);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _profileCard(Map<String, dynamic> profile) {
    final firstName = profile['first_name'] ?? '';
    final lastName = profile['last_name'] ?? '';
    final fullName = '$firstName $lastName'.trim();
    final bio = profile['bio']?.toString() ?? '';
    final picture = profile['profile_picture'];
    final status = profile['employment_status'];
    final position = profile['current_position'];
    final company = profile['current_company'];
    final industry = profile['industry'] as Map<String, dynamic>?;
    final location = profile['location'];
    final profileSkills = profile['profile_skills'] as List? ?? [];
    final userId = profile['user'];
    final isOwn = _accountId != null &&
        (userId == _accountId || (userId is Map && userId['id'] == _accountId));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
            // Avatar
            ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: picture != null
                  ? CachedNetworkImage(
                      imageUrl: picture,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _avatarPlaceholder(fullName))
                  : _avatarPlaceholder(fullName),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Row(
                    children: [
                      Expanded(
                        child: Text(fullName,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF094a25))),
                      ),
                      if (!isOwn)
                        const Icon(Icons.bookmark_border,
                            size: 20, color: Color(0xFF094a25)),
                    ],
                  ),
                  const SizedBox(height: 5),

                  // Bio
                  if (bio.isNotEmpty) ...[
                    Text(bio.length > 150 ? '${bio.substring(0, 150)}...' : bio,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54, height: 1.4)),
                    const SizedBox(height: 8),
                  ],

                  // Meta info
                  if (status != null)
                    _metaRow('Status', _capitalize(status.toString())),
                  if (status == 'employed') ...[
                    if (position != null)
                      _metaRow(
                          'Position',
                          company != null
                              ? '$position at $company'
                              : position.toString()),
                  ],
                  if (industry != null)
                    _metaRow('Industry', industry['name'] ?? ''),
                  if (location != null && location.toString().isNotEmpty)
                    _metaRow('Location', location.toString()),

                  // Skills
                  if (profileSkills.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Skills: ',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.black54)),
                        Expanded(
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: profileSkills
                                .map((s) => Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF094a25)
                                            .withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(s['name']?.toString() ?? '',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF094a25))),
                                    ))
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ] else
                    _metaRow('Skills', '—'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paginationBar() {
    if (_totalCount == 0) return const SizedBox.shrink();
    final totalPages = (_totalCount / _selectedPageSize).ceil();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          if (_hasPrev) ...[
            _pageBtn('First', () => _fetchProfiles(page: 1)),
            _pageBtn('‹ Prev', () => _fetchProfiles(page: _currentPage - 1)),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF094a25).withOpacity(0.08),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('Page $_currentPage of $totalPages',
                style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF094a25),
                    fontWeight: FontWeight.bold)),
          ),
          if (_hasNext) ...[
            _pageBtn('Next ›', () => _fetchProfiles(page: _currentPage + 1)),
            _pageBtn('Last', () => _fetchProfiles(page: totalPages)),
          ],
        ],
      ),
    );
  }

  Widget _pageBtn(String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF094a25)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF094a25))),
        ),
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

  Widget _activeChip(String label, VoidCallback onRemove) => Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF094a25).withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF094a25).withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 11, color: Color(0xFF094a25))),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child:
                  const Icon(Icons.close, size: 12, color: Color(0xFF094a25)),
            ),
          ],
        ),
      );

  Widget _avatarPlaceholder(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: const Color(0xFF094a25).withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(initial,
            style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF094a25))),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
