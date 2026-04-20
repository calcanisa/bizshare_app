import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  // Account info
  int? _accountId;
  Set<int> _interestProjectIds = {};
  bool _loadingAccount = true;

  // Tab
  int _tab = 1;

  // Tab 1 – Your Projects
  List<dynamic> _myProjects = [];
  bool _loadingMine = false;

  // Tab 2 – Your Interests
  List<dynamic> _myInterests = [];
  bool _loadingInterests = false;

  // Tab 3 – All Projects
  List<dynamic> _allProjects = [];
  bool _loadingAll = false;
  int _currentPage = 1;
  int _totalCount = 0;
  bool _hasNext = false;
  bool _hasPrev = false;
  int _selectedPageSize = 20;
  String _selectedOrdering = 'date-last';

  // Filter state (applied)
  List<dynamic> _categories = [];
  int? _filterCategory;
  String? _filterStage;
  String? _filterTeamSize;
  String? _filterLookingFor;

  // Temp filter state (in-sheet)
  int? _tempCategory;
  String? _tempStage;
  String? _tempTeamSize;
  String? _tempLookingFor;

  bool get _hasActiveFilters =>
      _filterCategory != null ||
      _filterStage != null ||
      _filterTeamSize != null ||
      _filterLookingFor != null;

  static const _stageOptions = [
    ('idea', 'Idea'),
    ('startup', 'Startup'),
    ('growth', 'Growth'),
    ('expansion', 'Expansion'),
    ('mature', 'Mature'),
  ];

  static const _teamSizeOptions = [
    ('1', '1 to 10'),
    ('11', '11 to 20'),
    ('21', '21 to 30'),
    ('31', '31 to 40'),
    ('41', '41 to 50'),
    ('50+', 'More than 50'),
  ];

  static const _lookingForOptions = [
    ('investor', 'Investor'),
    ('partner', 'Partner'),
    ('provider', 'Provider'),
    ('coach', 'Mentor'),
  ];

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  Future<void> _loadAccount() async {
    try {
      final api = context.read<ApiService>();
      final response = await api.dio.get('/api/v1/users/current/');
      final data = response.data;
      final interests = data['interests'] as List? ?? [];
      setState(() {
        _accountId = data['id'];
        _interestProjectIds = interests.map<int>((i) {
          final proj = i['project'];
          return proj is int ? proj : int.tryParse(proj.toString()) ?? 0;
        }).toSet();
        _loadingAccount = false;
      });
    } catch (_) {
      setState(() => _loadingAccount = false);
    }
    _loadMyProjects();
    _loadCategories();
  }

  Future<void> _loadMyProjects() async {
    setState(() => _loadingMine = true);
    try {
      final api = context.read<ApiService>();
      final response = await api.dio.get('/api/v1/projects/user/');
      final data = response.data;
      setState(
          () => _myProjects = data is List ? data : (data['results'] ?? []));
    } catch (_) {
      _showSnack('Could not load your projects. Try again.');
    }
    setState(() => _loadingMine = false);
  }

  Future<void> _loadMyInterests() async {
    setState(() => _loadingInterests = true);
    try {
      final api = context.read<ApiService>();
      final response = await api.dio.get('/api/v1/projects/interests/');
      final data = response.data;
      setState(
          () => _myInterests = data is List ? data : (data['results'] ?? []));
    } catch (_) {
      _showSnack('Could not load your interests. Try again.');
    }
    setState(() => _loadingInterests = false);
  }

  Future<void> _fetchAllProjects({int page = 1}) async {
    if (_loadingAll) return;
    setState(() => _loadingAll = true);
    try {
      final api = context.read<ApiService>();
      final params = <String, dynamic>{
        'page_size': _selectedPageSize,
        'ordering': _selectedOrdering,
      };
      if (page > 1) params['page'] = page;
      if (_filterCategory != null) params['category'] = _filterCategory;
      if (_filterStage != null) params['stage'] = _filterStage;
      if (_filterTeamSize != null) params['team_size'] = _filterTeamSize;
      if (_filterLookingFor != null) params['looking_for'] = _filterLookingFor;

      final response =
          await api.dio.get('/api/v1/projects/', queryParameters: params);
      setState(() {
        _allProjects = response.data['results'] as List? ?? [];
        _totalCount = response.data['count'] ?? 0;
        _hasNext = response.data['next'] != null;
        _hasPrev = response.data['previous'] != null;
        _currentPage = page;
      });
    } catch (_) {
      _showSnack('Could not load projects. Try again.');
    }
    setState(() => _loadingAll = false);
  }

  Future<void> _loadCategories() async {
    if (_categories.isNotEmpty) return;
    try {
      final api = context.read<ApiService>();
      final response = await api.dio.get('/api/v1/directory/categories/');
      final data = response.data;
      setState(
          () => _categories = data is List ? data : (data['results'] ?? []));
    } catch (_) {}
  }

  Future<void> _deleteProject(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Project'),
        content: const Text(
            'Are you sure you want to delete this project? This cannot be undone.'),
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
      await api.dio.delete('/api/v1/projects/project/$id/d/');
      setState(() {
        _myProjects.removeWhere((p) => p['id'] == id);
        _allProjects.removeWhere((p) => p['id'] == id);
      });
      _showSnack('Project deleted successfully');
    } catch (_) {
      _showSnack('Could not delete project. Try again.');
    }
  }

  Future<void> _deleteInterest(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Interest'),
        content: const Text(
            'Are you sure you want to delete this interest? This cannot be undone.'),
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
      await api.dio.delete('/api/v1/projects/interest/$id/d/');
      setState(() => _myInterests.removeWhere((i) => i['id'] == id));
      _showSnack('Interest deleted successfully');
    } catch (_) {
      _showSnack('Could not delete interest. Try again.');
    }
  }

  bool _hasShownInterest(int projectId) =>
      _interestProjectIds.contains(projectId);

  String _capitalize(String? s) {
    if (s == null || s.isEmpty) return '';
    return s[0].toUpperCase() + s.substring(1);
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _openFilterSheet() async {
    await _loadCategories();
    _tempCategory = _filterCategory;
    _tempStage = _filterStage;
    _tempTeamSize = _filterTeamSize;
    _tempLookingFor = _filterLookingFor;

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
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
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
                      const Text('Project Filters',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            _tempCategory = null;
                            _tempStage = null;
                            _tempTeamSize = null;
                            _tempLookingFor = null;
                          });
                        },
                        child: const Text('Reset',
                            style: TextStyle(color: Color(0xFFf8b324))),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      _filterLabel('Category'),
                      _filterDropdown<int>(
                        value: _tempCategory,
                        hint: 'All Categories',
                        items: _categories
                            .map((c) => DropdownMenuItem<int>(
                                  value: c['id'],
                                  child: Text(c['name'] ?? ''),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setSheetState(() => _tempCategory = v),
                      ),
                      const SizedBox(height: 16),
                      _filterLabel('Project Stage'),
                      _filterDropdown<String>(
                        value: _tempStage,
                        hint: 'All Stages',
                        items: _stageOptions
                            .map((s) => DropdownMenuItem<String>(
                                  value: s.$1,
                                  child: Text(s.$2),
                                ))
                            .toList(),
                        onChanged: (v) => setSheetState(() => _tempStage = v),
                      ),
                      const SizedBox(height: 16),
                      _filterLabel('Team Size'),
                      _filterDropdown<String>(
                        value: _tempTeamSize,
                        hint: 'Any Size',
                        items: _teamSizeOptions
                            .map((s) => DropdownMenuItem<String>(
                                  value: s.$1,
                                  child: Text(s.$2),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setSheetState(() => _tempTeamSize = v),
                      ),
                      const SizedBox(height: 16),
                      _filterLabel('Looking For'),
                      _filterDropdown<String>(
                        value: _tempLookingFor,
                        hint: 'Any Type',
                        items: _lookingForOptions
                            .map((s) => DropdownMenuItem<String>(
                                  value: s.$1,
                                  child: Text(s.$2),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setSheetState(() => _tempLookingFor = v),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _filterCategory = _tempCategory;
                          _filterStage = _tempStage;
                          _filterTeamSize = _tempTeamSize;
                          _filterLookingFor = _tempLookingFor;
                        });
                        Navigator.pop(context);
                        _fetchAllProjects(page: 1);
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

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loadingAccount) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF094a25)));
    }
    return Column(
      children: [
        Container(
          color: const Color(0xFF094a25),
          child: Row(
            children: [
              _tabBtn(1, 'Your Projects'),
              _tabBtn(2, 'Your Interests'),
              _tabBtn(3, 'All Projects'),
            ],
          ),
        ),
        Expanded(
          child: _tab == 1
              ? _myProjectsTab()
              : _tab == 2
                  ? _myInterestsTab()
                  : _allProjectsTab(),
        ),
      ],
    );
  }

  Widget _tabBtn(int index, String label) {
    final active = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _tab = index);
          if (index == 2 && _myInterests.isEmpty) _loadMyInterests();
          if (index == 3 && _allProjects.isEmpty) {
            _fetchAllProjects(page: 1);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          color: active ? Colors.white : const Color(0xFF094a25),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: active ? const Color(0xFF094a25) : Colors.white60,
                fontSize: 12,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              )),
        ),
      ),
    );
  }

  // ─── Tab 1 — Your Projects ───────────────────────────────────────────────

  Widget _myProjectsTab() {
    if (_loadingMine) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF094a25)));
    }
    if (_myProjects.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('You have not created any projects.',
                style: TextStyle(color: Color(0xFF094a25))),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {}, // TODO: open create project modal
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF094a25)),
              child: const Text('Create One',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadMyProjects,
      color: const Color(0xFF094a25),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _myProjects.length,
        itemBuilder: (context, index) =>
            _myProjectCard(_myProjects[index] as Map<String, dynamic>),
      ),
    );
  }

  Widget _myProjectCard(Map<String, dynamic> project) {
    final title = project['title'] ?? '';
    final description = project['description'] ?? '';
    final imageUrl = project['image'];
    final category = project['category'] as Map<String, dynamic>?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
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
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _imagePlaceholder())
                  : _imagePlaceholder(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF094a25))),
                  const SizedBox(height: 4),
                  Text(
                      description.length > 80
                          ? '${description.substring(0, 80)}...'
                          : description,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54)),
                  if (category != null) ...[
                    const SizedBox(height: 4),
                    Text('Category: ${category['name'] ?? ''}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black45)),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {}, // TODO: edit project
                          style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF094a25),
                              padding: const EdgeInsets.symmetric(vertical: 4)),
                          child: const Text('Edit',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _deleteProject(project['id']),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFbc2023),
                              padding: const EdgeInsets.symmetric(vertical: 4)),
                          child: const Text('Delete',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Tab 2 — Your Interests ──────────────────────────────────────────────

  Widget _myInterestsTab() {
    if (_loadingInterests) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF094a25)));
    }
    if (_myInterests.isEmpty) {
      return const Center(
        child: Text('You have not shown interest in any projects.',
            style: TextStyle(color: Color(0xFF094a25))),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadMyInterests,
      color: const Color(0xFF094a25),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _myInterests.length,
        itemBuilder: (context, index) =>
            _interestCard(_myInterests[index] as Map<String, dynamic>),
      ),
    );
  }

  Widget _interestCard(Map<String, dynamic> interest) {
    final motive = interest['motive'] ?? '';
    final message = interest['message'] ?? '';
    final project = interest['project'] as Map<String, dynamic>? ?? {};
    final projectTitle = project['title'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _interestRow('Motive', _capitalize(motive)),
            const SizedBox(height: 8),
            _interestRow(
                'Project',
                projectTitle.length > 30
                    ? '${projectTitle.substring(0, 30)}...'
                    : projectTitle),
            const SizedBox(height: 8),
            if (message.isNotEmpty)
              Text(
                  message.length > 80
                      ? '${message.substring(0, 80)}...'
                      : message,
                  style: const TextStyle(fontSize: 12, color: Colors.black87)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {}, // TODO: edit interest
                    style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF094a25),
                        padding: const EdgeInsets.symmetric(vertical: 4)),
                    child: const Text('Edit', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _deleteInterest(interest['id']),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFbc2023),
                        padding: const EdgeInsets.symmetric(vertical: 4)),
                    child: const Text('Delete',
                        style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _interestRow(String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
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
      );

  // ─── Tab 3 — All Projects ────────────────────────────────────────────────

  Widget _allProjectsTab() {
    return Column(
      children: [
        // Controls bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedOrdering,
                    isDense: true,
                    style:
                        const TextStyle(fontSize: 12, color: Color(0xFF094a25)),
                    items: const [
                      DropdownMenuItem(
                          value: 'date-last', child: Text('Newest First')),
                      DropdownMenuItem(
                          value: 'date-first', child: Text('Oldest First')),
                      DropdownMenuItem(
                          value: 'title-asc', child: Text('Title A-Z')),
                      DropdownMenuItem(
                          value: 'title-des', child: Text('Title Z-A')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _selectedOrdering = v);
                      _fetchAllProjects(page: 1);
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
                if (_filterCategory != null)
                  _activeChip(
                    _categories.firstWhere((c) => c['id'] == _filterCategory,
                            orElse: () => {'name': 'Category'})['name'] ??
                        '',
                    () {
                      setState(() => _filterCategory = null);
                      _fetchAllProjects(page: 1);
                    },
                  ),
                if (_filterStage != null)
                  _activeChip(
                    _stageOptions
                        .firstWhere((s) => s.$1 == _filterStage,
                            orElse: () => ('', _filterStage!))
                        .$2,
                    () {
                      setState(() => _filterStage = null);
                      _fetchAllProjects(page: 1);
                    },
                  ),
                if (_filterTeamSize != null)
                  _activeChip(
                    _teamSizeOptions
                        .firstWhere((s) => s.$1 == _filterTeamSize,
                            orElse: () => ('', _filterTeamSize!))
                        .$2,
                    () {
                      setState(() => _filterTeamSize = null);
                      _fetchAllProjects(page: 1);
                    },
                  ),
                if (_filterLookingFor != null)
                  _activeChip(
                    _lookingForOptions
                        .firstWhere((s) => s.$1 == _filterLookingFor,
                            orElse: () => ('', _filterLookingFor!))
                        .$2,
                    () {
                      setState(() => _filterLookingFor = null);
                      _fetchAllProjects(page: 1);
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
                Text('$_totalCount projects found',
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
                          _fetchAllProjects(page: 1);
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
          child: _loadingAll
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF094a25)))
              : _allProjects.isEmpty
                  ? const Center(
                      child: Text('No projects available',
                          style: TextStyle(color: Color(0xFF094a25))))
                  : RefreshIndicator(
                      onRefresh: () => _fetchAllProjects(page: 1),
                      color: const Color(0xFF094a25),
                      child: ListView.builder(
                        itemCount: _allProjects.length + 1,
                        itemBuilder: (context, index) {
                          if (index == _allProjects.length) {
                            return _paginationBar();
                          }
                          return _allProjectCard(
                              _allProjects[index] as Map<String, dynamic>);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _allProjectCard(Map<String, dynamic> project) {
    final title = project['title'] ?? '';
    final description = project['description'] ?? '';
    final imageUrl = project['image'];
    final stage = project['stage'];
    final lookingFor = project['looking_for'];
    final projectSize = project['project_size'];
    final isOwner = _accountId != null &&
        project['user'] is Map &&
        (project['user'] as Map)['id'] == _accountId;
    final interested = _hasShownInterest(project['id']);

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _imagePlaceholder())
                      : _imagePlaceholder(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF094a25))),
                      const SizedBox(height: 5),
                      Text(
                          description.length > 100
                              ? '${description.substring(0, 100)}...'
                              : description,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black87)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (stage != null)
                        _metaRow(
                            'Project Stage', _capitalize(stage.toString())),
                      if (lookingFor != null)
                        _metaRow(
                            'Looking For', _capitalize(lookingFor.toString())),
                      if (lookingFor == 'investor' && projectSize != null)
                        _metaRow('Funding Size', 'R$projectSize'),
                    ],
                  ),
                ),
                if (isOwner) ...[
                  OutlinedButton(
                    onPressed: () {}, // TODO: edit project
                    style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF094a25),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4)),
                    child: const Text('Edit', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton(
                    onPressed: () => _deleteProject(project['id']),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFbc2023),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4)),
                    child: const Text('Delete',
                        style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ] else
                  ElevatedButton(
                    onPressed: interested
                        ? null
                        : () {}, // TODO: open show interest modal
                    style: ElevatedButton.styleFrom(
                        backgroundColor: interested
                            ? Colors.grey.shade400
                            : const Color(0xFF094a25),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8)),
                    child: Text(interested ? 'Interest Shown' : 'Show Interest',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
              ],
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
            _pageBtn('First', () => _fetchAllProjects(page: 1)),
            _pageBtn('‹ Prev', () => _fetchAllProjects(page: _currentPage - 1)),
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
            _pageBtn('Next ›', () => _fetchAllProjects(page: _currentPage + 1)),
            _pageBtn('Last', () => _fetchAllProjects(page: totalPages)),
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

  // ─── Shared helpers ──────────────────────────────────────────────────────

  Widget _metaRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(
          children: [
            Text('$label: ',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54)),
            Text(value,
                style: const TextStyle(fontSize: 11, color: Colors.black87)),
          ],
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

  Widget _imagePlaceholder() => Container(
        width: 80,
        height: 80,
        color: const Color(0xFF094a25).withOpacity(0.1),
        child: const Icon(Icons.rocket_launch_outlined,
            color: Color(0xFF094a25), size: 30),
      );
}
