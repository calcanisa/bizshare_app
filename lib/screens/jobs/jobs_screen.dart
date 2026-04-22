import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../widgets/filter_chip_bar.dart';
import '../jobs/job_screen.dart';
import '../jobs/add_job.dart';

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  int _tab = 1;

  // Tab 1 - My Jobs
  List<dynamic> _myJobs = [];
  bool _loadingMine = false;

  // Tab 2 - Applied Jobs
  List<dynamic> _appliedJobs = [];
  bool _loadingApplied = false;

  // Tab 3 - All Jobs
  List<dynamic> _provinces = [];
  List<dynamic> _cities = [];
  List<dynamic> _areas = [];
  List<dynamic> _sectors = [];
  List<dynamic> _functions = [];
  List<dynamic> _jobs = [];
  bool _loadingAll = false;
  bool _hasMore = false;
  int _currentPage = 1;
  int _totalCount = 0;
  int? _selectedProvince;
  final ScrollController _scrollController = ScrollController();

  // Filter state
  int? _filterCity;
  int? _filterArea;
  int? _filterSector;
  int? _filterFunction;
  String? _filterContractType;
  String? _filterWorkEnvironment;

  // Temp filter state
  int? _tempCity;
  int? _tempArea;
  int? _tempSector;
  int? _tempFunction;
  String? _tempContractType;
  String? _tempWorkEnvironment;

  final Map<String, String> _contractTypes = {
    'fulltime': 'Full Time',
    'parttime': 'Part Time',
    'temporary': 'Temporary',
    'contract': 'Contract',
    'internship': 'Internship',
    'freelance': 'Freelance',
  };

  final Map<String, String> _workEnvironments = {
    'office': 'Office',
    'hybrid': 'Hybrid',
    'remote': 'Remote',
  };

  bool get _hasActiveFilters =>
      _filterCity != null ||
      _filterSector != null ||
      _filterFunction != null ||
      _filterContractType != null ||
      _filterWorkEnvironment != null;

  @override
  void initState() {
    super.initState();
    _loadMyJobs();
    _loadProvinces();
    _loadSectors();
    _loadFunctions();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        if (!_loadingAll && _hasMore) _loadMoreJobs();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMyJobs() async {
    setState(() => _loadingMine = true);
    try {
      final api = context.read<ApiService>();
      final response = await api.dio.get('/api/v1/jobs/user/current/');
      setState(() => _myJobs = response.data ?? []);
    } catch (_) {}
    setState(() => _loadingMine = false);
  }

  Future<void> _loadAppliedJobs() async {
    setState(() => _loadingApplied = true);
    try {
      final api = context.read<ApiService>();
      final response = await api.dio.get('/api/v1/jobs/current/applied/');
      setState(() => _appliedJobs = response.data ?? []);
    } catch (_) {}
    setState(() => _loadingApplied = false);
  }

  Future<void> _loadProvinces() async {
    try {
      final api = context.read<ApiService>();
      final response = await api.dio.get('/api/v1/locations/provinces/');
      final data = response.data;
      setState(
          () => _provinces = data is List ? data : (data['results'] ?? []));
    } catch (_) {}
  }

  Future<void> _loadCities(int provinceId) async {
    try {
      final api = context.read<ApiService>();
      final response =
          await api.dio.get('/api/v1/locations/cities/$provinceId/');
      final data = response.data;
      setState(() => _cities = data is List ? data : (data['results'] ?? []));
    } catch (_) {}
  }

  Future<void> _loadAreas(int cityId) async {
    try {
      final api = context.read<ApiService>();
      final response = await api.dio.get('/api/v1/locations/areas/$cityId/');
      final data = response.data;
      setState(() => _areas = data is List ? data : (data['results'] ?? []));
    } catch (_) {}
  }

  Future<void> _loadSectors() async {
    try {
      final api = context.read<ApiService>();
      final response =
          await api.dio.get('/api/v1/directory/business/categories/');
      final data = response.data;
      setState(() => _sectors = data is List ? data : (data['results'] ?? []));
    } catch (_) {}
  }

  Future<void> _loadFunctions() async {
    try {
      final api = context.read<ApiService>();
      final response = await api.dio.get('/api/v1/jobs/functions/');
      final data = response.data;
      setState(
          () => _functions = data is List ? data : (data['results'] ?? []));
    } catch (_) {}
  }

  Future<void> _loadJobs({bool refresh = false}) async {
    if (_loadingAll || _selectedProvince == null) return;
    if (refresh) {
      setState(() {
        _jobs = [];
        _currentPage = 1;
        _hasMore = false;
        _totalCount = 0;
      });
    }
    setState(() => _loadingAll = true);
    try {
      final api = context.read<ApiService>();
      final params = <String, dynamic>{
        'page': _currentPage,
        'province': _selectedProvince,
      };
      if (_filterCity != null) params['city'] = _filterCity;
      if (_filterArea != null) params['area'] = _filterArea;
      if (_filterSector != null) params['industry'] = _filterSector;
      if (_filterFunction != null) params['function'] = _filterFunction;
      if (_filterContractType != null)
        params['contract_type'] = _filterContractType;
      if (_filterWorkEnvironment != null)
        params['job_setting'] = _filterWorkEnvironment;

      final response =
          await api.dio.get('/api/v1/jobs/', queryParameters: params);
      final results = response.data['results'] as List? ?? [];
      setState(() {
        _jobs.addAll(results);
        _currentPage++;
        _hasMore = response.data['next'] != null;
        _totalCount = response.data['count'] ?? 0;
      });
    } catch (_) {}
    setState(() => _loadingAll = false);
  }

  Future<void> _loadMoreJobs() async => await _loadJobs();

  Future<void> _deleteJob(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Job'),
        content: const Text(
            'Are you sure you want to delete this job? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final api = context.read<ApiService>();
      await api.dio.delete('/api/v1/job/$id/d/');
      setState(() => _myJobs.removeWhere((j) => j['id'] == id));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Job deleted')));
      }
    } catch (_) {}
  }

  void _openAddJob() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddJobModal(
          action: 'add',
          onSave: (data) {
            Navigator.pop(context);
            setState(() => _myJobs.insert(0, data));
          },
          onCancel: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _openEditJob(Map<String, dynamic> job) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddJobModal(
          action: 'edit',
          job: job,
          onSave: (data) {
            Navigator.pop(context);
            final i = _myJobs.indexWhere((j) => j['id'] == data['id']);
            if (i != -1) setState(() => _myJobs[i] = data);
          },
          onCancel: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Future<void> _removeApplication(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Application'),
        content:
            const Text('Are you sure you want to cancel this application?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final api = context.read<ApiService>();
      await api.dio.delete('/api/v1/jobs/applications/$id/d/');
      setState(() => _appliedJobs.removeWhere((a) => a['id'] == id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Application cancelled')));
      }
    } catch (_) {}
  }

  bool _isExpired(Map<String, dynamic> job) {
    final createdAt = job['created_at'];
    if (createdAt == null) return false;
    final created = DateTime.tryParse(createdAt);
    if (created == null) return false;
    final expiry = DateTime(created.year, created.month + 1, created.day);
    return DateTime.now().isAfter(expiry);
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return '';
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${date.day} ${months[date.month]} ${date.year}';
  }

  void _openFilterSheet() async {
    _tempCity = _filterCity;
    _tempArea = _filterArea;
    _tempSector = _filterSector;
    _tempFunction = _filterFunction;
    _tempContractType = _filterContractType;
    _tempWorkEnvironment = _filterWorkEnvironment;

    if (_selectedProvince != null && _cities.isEmpty) {
      await _loadCities(_selectedProvince!);
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
                      const Text('Filter Jobs',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            _tempCity = null;
                            _tempArea = null;
                            _tempSector = null;
                            _tempFunction = null;
                            _tempContractType = null;
                            _tempWorkEnvironment = null;
                            _cities = [];
                            _areas = [];
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
                      if (_cities.isNotEmpty) ...[
                        _filterLabel('City'),
                        _filterDropdown<int>(
                          value: _tempCity,
                          hint: 'All Cities',
                          items: _cities
                              .map((c) => DropdownMenuItem<int>(
                                    value: c['id'],
                                    child: Text(c['name'] ?? ''),
                                  ))
                              .toList(),
                          onChanged: (v) async {
                            setSheetState(() {
                              _tempCity = v;
                              _tempArea = null;
                              _areas = [];
                            });
                            if (v != null) {
                              await _loadAreas(v);
                              setSheetState(() {});
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_areas.isNotEmpty) ...[
                        _filterLabel('Area'),
                        _filterDropdown<int>(
                          value: _tempArea,
                          hint: 'All Areas',
                          items: _areas
                              .map((a) => DropdownMenuItem<int>(
                                    value: a['id'],
                                    child: Text(a['name'] ?? ''),
                                  ))
                              .toList(),
                          onChanged: (v) => setSheetState(() => _tempArea = v),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_sectors.isNotEmpty) ...[
                        _filterLabel('Industry'),
                        _filterDropdown<int>(
                          value: _tempSector,
                          hint: 'All Industries',
                          items: _sectors
                              .map((s) => DropdownMenuItem<int>(
                                    value: s['id'],
                                    child: Text(s['name'] ?? ''),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setSheetState(() => _tempSector = v),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_functions.isNotEmpty) ...[
                        _filterLabel('Function'),
                        _filterDropdown<int>(
                          value: _tempFunction,
                          hint: 'All Functions',
                          items: _functions
                              .map((f) => DropdownMenuItem<int>(
                                    value: f['id'],
                                    child: Text(f['name'] ?? ''),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setSheetState(() => _tempFunction = v),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _filterLabel('Contract Type'),
                      _filterDropdown<String>(
                        value: _tempContractType,
                        hint: 'All Contract Types',
                        items: _contractTypes.entries
                            .map((e) => DropdownMenuItem<String>(
                                  value: e.key,
                                  child: Text(e.value),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setSheetState(() => _tempContractType = v),
                      ),
                      const SizedBox(height: 16),
                      _filterLabel('Work Environment'),
                      _filterDropdown<String>(
                        value: _tempWorkEnvironment,
                        hint: 'All Environments',
                        items: _workEnvironments.entries
                            .map((e) => DropdownMenuItem<String>(
                                  value: e.key,
                                  child: Text(e.value),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setSheetState(() => _tempWorkEnvironment = v),
                      ),
                      const SizedBox(height: 24),
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
                          _filterCity = _tempCity;
                          _filterArea = _tempArea;
                          _filterSector = _tempSector;
                          _filterFunction = _tempFunction;
                          _filterContractType = _tempContractType;
                          _filterWorkEnvironment = _tempWorkEnvironment;
                        });
                        Navigator.pop(context);
                        _loadJobs(refresh: true);
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
                child:
                    Text(hint, style: const TextStyle(color: Colors.black45)),
              ),
              ...items,
            ],
            onChanged: onChanged,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: const Color(0xFF094a25),
          child: Row(
            children: [
              _tabBtn(1, 'My Jobs'),
              _tabBtn(2, 'Applied'),
              _tabBtn(3, 'All Jobs'),
            ],
          ),
        ),
        Expanded(
          child: _tab == 1
              ? _myJobsTab()
              : _tab == 2
                  ? _appliedTab()
                  : _allJobsTab(),
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
          if (index == 2 && _appliedJobs.isEmpty) _loadAppliedJobs();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          color: active ? Colors.white : const Color(0xFF094a25),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: active ? const Color(0xFF094a25) : Colors.white60,
                fontSize: 13,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              )),
        ),
      ),
    );
  }

  Widget _myJobsTab() {
    if (_loadingMine) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF094a25)));
    }

    final currentJobs = _myJobs.where((j) => !_isExpired(j)).toList();
    final expiredJobs = _myJobs.where((j) => _isExpired(j)).toList();

    if (_myJobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('You have not added any jobs yet.',
                style: TextStyle(color: Color(0xFF094a25))),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _openAddJob,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF094a25)),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add A Job',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMyJobs,
      color: const Color(0xFF094a25),
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: ElevatedButton.icon(
              onPressed: _openAddJob,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF094a25),
                  minimumSize: const Size(double.infinity, 44)),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add New Job',
                  style: TextStyle(color: Colors.white)),
            ),
          ),
          if (currentJobs.isNotEmpty) ...[
            _listHeader('Current Jobs'),
            ...currentJobs.map((j) => _myJobCard(j)),
          ],
          if (expiredJobs.isNotEmpty) ...[
            _listHeader('Expired Jobs'),
            ...expiredJobs.map((j) => _myJobCard(j, expired: true)),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _listHeader(String title) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: const Color(0xFF094a25),
        margin: const EdgeInsets.only(bottom: 4),
        child: Text(title,
            style: const TextStyle(
                color: Color(0xFFf8b324), fontWeight: FontWeight.bold)),
      );

  Widget _myJobCard(Map<String, dynamic> job, {bool expired = false}) {
    final title = job['title'] ?? '';
    final image = job['image'];

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => JobDetailScreen(jobId: job['id']),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: expired ? Colors.grey.shade100 : Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: image != null && image.toString().isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: image,
                        width: 70,
                        height: 70,
                        fit: BoxFit.contain,
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
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF094a25))),
                    if (!expired) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _openEditJob(job),
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF094a25),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4)),
                              child: const Text('Edit',
                                  style: TextStyle(fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _deleteJob(job['id']),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFbc2023),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4)),
                              child: const Text('Delete',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _appliedTab() {
    if (_loadingApplied) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF094a25)));
    }
    if (_appliedJobs.isEmpty) {
      return const Center(
        child: Text('You have not applied for any jobs.',
            style: TextStyle(color: Color(0xFF094a25))),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadAppliedJobs,
      color: const Color(0xFF094a25),
      child: ListView.builder(
        itemCount: _appliedJobs.length,
        itemBuilder: (context, index) {
          final application = _appliedJobs[index];
          final job = application['job'] ?? {};
          final jobTitle = job['title'] ?? 'Unknown Job';
          final appliedOn = _formatDate(application['created_at']);

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(jobTitle,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF094a25))),
                const SizedBox(height: 4),
                Text('Applied on: $appliedOn',
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black45)),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => _removeApplication(application['id']),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFbc2023),
                      padding: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 12)),
                  child: const Text('Cancel Application',
                      style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _allJobsTab() {
    return Column(
      children: [
        // Province selector + filter button
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: _provinces.length,
                    itemBuilder: (context, index) {
                      final prov = _provinces[index];
                      final isSelected = _selectedProvince == prov['id'];
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedProvince = prov['id'];
                            _jobs = [];
                            _currentPage = 1;
                            _filterCity = null;
                            _filterArea = null;
                            _cities = [];
                            _areas = [];
                          });
                          _loadCities(prov['id']);
                          _loadJobs(refresh: true);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF094a25)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: const Color(0xFF094a25), width: 1),
                          ),
                          child: Text(prov['name'] ?? '',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF094a25))),
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (_selectedProvince != null)
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
                if (_filterCity != null)
                  ActiveFilterChip(
                    label: _cities.firstWhere((c) => c['id'] == _filterCity,
                            orElse: () => {'name': 'City'})['name'] ??
                        '',
                    onRemove: () {
                      setState(() {
                        _filterCity = null;
                        _filterArea = null;
                      });
                      _loadJobs(refresh: true);
                    },
                  ),
                if (_filterSector != null)
                  ActiveFilterChip(
                    label: _sectors.firstWhere((s) => s['id'] == _filterSector,
                            orElse: () => {'name': 'Industry'})['name'] ??
                        '',
                    onRemove: () {
                      setState(() => _filterSector = null);
                      _loadJobs(refresh: true);
                    },
                  ),
                if (_filterFunction != null)
                  ActiveFilterChip(
                    label: _functions.firstWhere(
                            (f) => f['id'] == _filterFunction,
                            orElse: () => {'name': 'Function'})['name'] ??
                        '',
                    onRemove: () {
                      setState(() => _filterFunction = null);
                      _loadJobs(refresh: true);
                    },
                  ),
                if (_filterContractType != null)
                  ActiveFilterChip(
                    label: _contractTypes[_filterContractType] ??
                        _filterContractType!,
                    onRemove: () {
                      setState(() => _filterContractType = null);
                      _loadJobs(refresh: true);
                    },
                  ),
                if (_filterWorkEnvironment != null)
                  ActiveFilterChip(
                    label: _workEnvironments[_filterWorkEnvironment] ??
                        _filterWorkEnvironment!,
                    onRemove: () {
                      setState(() => _filterWorkEnvironment = null);
                      _loadJobs(refresh: true);
                    },
                  ),
              ],
            ),
          ),
        if (_totalCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: Colors.grey.shade50,
            child: Text('$_totalCount jobs found',
                style: const TextStyle(fontSize: 12, color: Colors.black45)),
          ),
        Expanded(
          child: _selectedProvince == null
              ? const Center(
                  child: Text('Select a province above to start',
                      style: TextStyle(color: Color(0xFF094a25))))
              : _loadingAll && _jobs.isEmpty
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF094a25)))
                  : _jobs.isEmpty
                      ? const Center(
                          child: Text('No jobs found',
                              style: TextStyle(color: Color(0xFF094a25))))
                      : RefreshIndicator(
                          onRefresh: () => _loadJobs(refresh: true),
                          color: const Color(0xFF094a25),
                          child: ListView.builder(
                            controller: _scrollController,
                            itemCount: _jobs.length + (_hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _jobs.length) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(
                                        color: Color(0xFF094a25)),
                                  ),
                                );
                              }
                              return _jobCard(_jobs[index]);
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _jobCard(Map<String, dynamic> job) {
    final title = job['title'] ?? '';
    final image = job['image'];
    final description = job['description'] ?? '';
    final industry = job['industry']?['name'] ?? '';
    final function = job['function']?['name'] ?? '';
    final createdAt = job['created_at'];
    String location = '';
    if (job['area'] != null) {
      location = job['area']['city']?['name'] ?? '';
    } else if (job['city'] != null) {
      location = job['city']['name'] ?? '';
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => JobDetailScreen(jobId: job['id']),
        ),
      ),
      child: Container(
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
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: image != null && image.toString().isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: image,
                        width: 70,
                        height: 70,
                        fit: BoxFit.contain,
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
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF094a25))),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description.length > 100
                            ? '${description.substring(0, 100)}...'
                            : description,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54),
                      ),
                    ],
                    const SizedBox(height: 4),
                    if (industry.isNotEmpty) _detail('Sector', industry),
                    if (function.isNotEmpty) _detail('Function', function),
                    if (location.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 12, color: Colors.black45),
                          const SizedBox(width: 2),
                          Text(location,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.black45)),
                        ],
                      ),
                    if (createdAt != null)
                      _detail('Posted', _formatDate(createdAt)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.black26),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detail(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(
          children: [
            Text('$label: ',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF094a25))),
            Text(value,
                style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ],
        ),
      );

  Widget _imagePlaceholder() => Container(
        width: 70,
        height: 70,
        color: const Color(0xFF094a25).withOpacity(0.1),
        child:
            const Icon(Icons.work_outline, color: Color(0xFF094a25), size: 32),
      );
}
