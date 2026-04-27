import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import 'job_application.dart';
import '../report_screen.dart';
import '../feature_content.dart';
import 'add_job.dart';

class JobDetailScreen extends StatefulWidget {
  final int jobId;
  const JobDetailScreen({super.key, required this.jobId});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  Map<String, dynamic>? _job;
  bool _loading = true;
  int? _accountId;
  Set<int> _appliedJobIds = {};

  static const _workScheduleLabels = {
    '8hours': '8 hours per day',
    'overtime': '8 hours per day + overtime',
    'flexible': 'Flexible hours',
    'project': 'Per project',
  };

  static const _contractTypeLabels = {
    'fulltime': 'Full Time',
    'parttime': 'Part Time',
    'temporary': 'Temporary',
    'contract': 'Contract',
    'internship': 'Internship',
    'freelance': 'Freelance',
  };

  static const _equalityLabels = {
    'eeaa': 'EE/AA',
    'nonee': 'Non EE/AA',
  };

  @override
  void initState() {
    super.initState();
    _loadAccount();
    _loadJob();
  }

  Future<void> _loadAccount() async {
    try {
      final api = context.read<ApiService>();
      final res = await api.dio.get('/api/v1/users/current/');
      final apps = res.data['job_applications'] as List? ?? [];
      setState(() {
        _accountId = res.data['id'];
        _appliedJobIds = apps
            .map<int>((a) => int.tryParse(a['job'].toString()) ?? 0)
            .toSet();
      });
    } catch (_) {}
  }

  Future<void> _loadJob() async {
    setState(() => _loading = true);
    debugPrint('Loading job ID: ${widget.jobId}');
    try {
      final api = context.read<ApiService>();
      final res = await api.dio.get('/api/v1/jobs/job/${widget.jobId}/');
      setState(() => _job = res.data);
    } catch (e) {
      debugPrint('_loadJob error: $e');
      _showSnack('Could not load job. Try again.');
    }
    setState(() => _loading = false);
  }

  bool get _isOwner {
    if (_accountId == null || _job == null) return false;
    final user = _job!['user'];
    if (user is Map) return user['id'] == _accountId;
    return user == _accountId;
  }

  bool get _hasApplied => _appliedJobIds.contains(widget.jobId);

  int get _daysLeft {
    final createdAt = _job?['created_at'];
    if (createdAt == null) return 0;
    final created = DateTime.tryParse(createdAt.toString());
    if (created == null) return 0;
    final expiry = created.add(const Duration(days: 30));
    return expiry.difference(DateTime.now()).inDays;
  }

  Future<void> _applyToJob() async {
    if (_hasApplied || _job == null) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JobApplicationScreen(job: _job!),
      ),
    );
    if (result == true && mounted) {
      setState(() => _appliedJobIds.add(widget.jobId));
    }
  }

  String _formatDateTime(String? dateStr) {
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
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${months[local.month]} ${local.year} $h:$m';
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

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
          if (_job != null) ...[
            if (_isOwner) ...[
              TextButton(
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddJobModal(
                        action: 'edit',
                        job: _job!,
                        onSave: (data) {
                          Navigator.pop(context);
                          setState(() => _job = data);
                        },
                        onCancel: () => Navigator.pop(context),
                      ),
                    ),
                  );
                },
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
                        type: 'job',
                        item: _job!,
                      ),
                    ),
                  );
                },
                child: const Text('Feature',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ),
            ] else ...[
              ElevatedButton(
                onPressed: _hasApplied ? null : _applyToJob,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _hasApplied
                      ? Colors.grey.shade400
                      : const Color(0xFF094a25),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  _hasApplied ? 'Applied' : 'Apply',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              const SizedBox(width: 4),
              TextButton(
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReportScreen(
                      contentId: widget.jobId,
                      type: 'jobs',
                    ),
                  ),
                ),
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
          : _job == null
              ? const Center(child: Text('Job not found'))
              : RefreshIndicator(
                  onRefresh: _loadJob,
                  color: const Color(0xFF094a25),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _industryBar(),
                        _imageSection(),
                        _basicDetailsSection(),
                        _requiredSection(),
                        if ((_job?['questions'] as List? ?? []).isNotEmpty)
                          _questionsSection(),
                        if ((_job?['exams'] as List? ?? []).isNotEmpty)
                          _examsSection(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _industryBar() {
    final industry = _job?['industry'] as Map?;
    final function = _job?['function'] as Map?;
    final industryName = industry?['name'] ?? '';
    final functionName = function?['name'] ?? '';
    final title = _job?['title'] ?? '';

    return Column(
      children: [
        Container(
          color: const Color(0xFF0a5c2e),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
              if (industryName.isNotEmpty || functionName.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  [industryName, functionName]
                      .where((s) => s.isNotEmpty)
                      .join(' | '),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _imageSection() {
    final image = _job?['image'];
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: image != null && image.toString().isNotEmpty
            ? CachedNetworkImage(
                imageUrl: image,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _imagePlaceholder())
            : _imagePlaceholder(),
      ),
    );
  }

  Widget _imagePlaceholder() => Container(
        height: 220,
        color: const Color(0xFF094a25).withValues(alpha: 0.1),
        child: const Center(
          child: Icon(Icons.work_outline, color: Color(0xFF094a25), size: 60),
        ),
      );

  Widget _basicDetailsSection() {
    final area = _job?['area'] as Map?;
    String location = '';
    if (area != null) {
      final city = area['city'] as Map?;
      final province = city?['province'] as Map?;
      location = '${province?['name']} / ${city?['name']} / ${area['name']}';
    }

    final createdAt = _job?['created_at'];
    final equality = _job?['equality'];
    final contractType = _job?['contract_type'];
    final workEnv = _job?['work_environment'];
    final workSchedule = _job?['work_schedule'];
    final description = _job?['description'] ?? '';

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Basic Detail'),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (location.isNotEmpty) ...[
                  _detailRow('Job Location', location),
                  const SizedBox(height: 8),
                ],
                if (createdAt != null) ...[
                  _detailRow('Posted', _formatDateTime(createdAt.toString())),
                  const SizedBox(height: 8),
                ],
                if (_daysLeft > 0) ...[
                  _detailRow('Expires in', '$_daysLeft days'),
                  const SizedBox(height: 8),
                ] else ...[
                  _detailRow('Status', 'Expired'),
                  const SizedBox(height: 8),
                ],
                if (equality != null) ...[
                  _detailRow('Equity',
                      _equalityLabels[equality] ?? equality.toString()),
                  const SizedBox(height: 8),
                ],
                if (contractType != null) ...[
                  _detailRow(
                      'Contract Type',
                      _contractTypeLabels[contractType] ??
                          contractType.toString()),
                  const SizedBox(height: 8),
                ],
                if (workEnv != null) ...[
                  _detailRow('Environment', workEnv.toString()),
                  const SizedBox(height: 8),
                ],
                if (workSchedule != null) ...[
                  _detailRow(
                      'Work Schedule',
                      _workScheduleLabels[workSchedule] ??
                          workSchedule.toString()),
                  const SizedBox(height: 8),
                ],
                if (description.isNotEmpty) ...[
                  const Text('Job Description',
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

  Widget _requiredSection() {
    final experience = _job?['experience_required'];
    final education = _job?['education_required'];
    final skills = _job?['skills'] as List? ?? [];
    final duties = _job?['duties'] as List? ?? [];

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Required'),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (experience != null) ...[
                  _detailRow('Experience Required', experience.toString()),
                  const SizedBox(height: 8),
                ],
                if (education != null) ...[
                  _detailRow('Education Required', education.toString()),
                  const SizedBox(height: 8),
                ],
                if (skills.isNotEmpty) ...[
                  const Text('Skills Required',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54)),
                  const SizedBox(height: 8),
                  ...skills.map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.circle,
                                size: 6, color: Color(0xFF094a25)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${s['title'] ?? ''} — ${s['experience'] ?? ''}',
                                style: const TextStyle(
                                    fontSize: 13, color: Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 8),
                ],
                if (duties.isNotEmpty) ...[
                  const Text('Duties',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54)),
                  const SizedBox(height: 8),
                  ...duties.map((d) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.circle,
                                size: 6, color: Color(0xFF094a25)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    d['title']?.toString() ?? '',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF094a25)),
                                  ),
                                  if (d['description'] != null)
                                    Text(
                                      d['description'].toString(),
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.black54),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _questionsSection() {
    final questions = _job?['questions'] as List? ?? [];

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Questions & Exams'),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Questions',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54)),
                const SizedBox(height: 8),
                ...questions.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${e.key + 1}. ',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF094a25))),
                          Expanded(
                            child: Text(
                              '${e.value['title'] ?? ''}?',
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _examsSection() {
    final exams = _job?['exams'] as List? ?? [];

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Exams For This Job'),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Exams to complete: ${exams.length}',
                    style:
                        const TextStyle(fontSize: 13, color: Colors.black54)),
                const SizedBox(height: 12),
                ...exams.map((exam) => Container(
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
                          _detailRow('Duration',
                              '${exam['duration']} ${exam['time_format']}'),
                          const SizedBox(height: 6),
                          _detailRow('Questions',
                              '${(exam['questions'] as List? ?? []).length} Questions'),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
            width: 130,
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
