import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';

import '../projects/add_interest.dart';

class ProjectDetailScreen extends StatefulWidget {
  final int projectId;
  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  Map<String, dynamic>? _project;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProject();
  }

  Future<void> _loadProject() async {
    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      final res =
          await api.dio.get('/api/v1/projects/project/${widget.projectId}/');
      setState(() => _project = res.data);
    } catch (_) {
      _showSnack('Could not load project. Try again.');
    }
    setState(() => _loading = false);
  }

  bool get _isOwner => _project?['is_owner'] == true;

  Future<void> _deleteProject() async {
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
      await api.dio.delete('/api/v1/projects/project/${widget.projectId}/d/');
      _showSnack('Project successfully deleted');
      if (mounted) Navigator.pop(context);
    } catch (_) {
      _showSnack('Could not delete project. Try again.');
    }
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
          _project?['title'] ?? 'Project',
          style: const TextStyle(color: Colors.white, fontSize: 15),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_project != null) ...[
            if (_isOwner) ...[
              TextButton(
                onPressed: () {}, // TODO: edit modal
                child: const Text('Edit',
                    style: TextStyle(color: Color(0xFFf8b324), fontSize: 12)),
              ),
              TextButton(
                onPressed: _deleteProject,
                child: const Text('Delete',
                    style: TextStyle(color: Color(0xFFbc2023), fontSize: 12)),
              ),
            ],
            if (!_isOwner)
              TextButton(
                onPressed: () {}, // TODO: show interest modal
                child: const Text('Interested',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ),
          ],
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF094a25)))
          : _project == null
              ? const Center(child: Text('Project not found'))
              : RefreshIndicator(
                  onRefresh: _loadProject,
                  color: const Color(0xFF094a25),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _stageBar(),
                        _imageSection(),
                        _detailsSection(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
    );
  }

  // ─── Stage bar ────────────────────────────────────────────────────────────

  Widget _stageBar() {
    final stage = _project?['stage'] ?? '';
    return Container(
      color: Colors.black87,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        stage,
        style: const TextStyle(
            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }

  // ─── Image ────────────────────────────────────────────────────────────────

  Widget _imageSection() {
    final image = _project?['image'];
    return SizedBox(
      width: double.infinity,
      height: 260,
      child: image != null && image.toString().isNotEmpty
          ? CachedNetworkImage(
              imageUrl: image,
              width: double.infinity,
              height: 260,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _imagePlaceholder())
          : _imagePlaceholder(),
    );
  }

  Widget _imagePlaceholder() => Container(
        width: double.infinity,
        height: 260,
        color: const Color(0xFF094a25).withOpacity(0.1),
        child: const Icon(Icons.lightbulb_outline,
            color: Color(0xFF094a25), size: 60),
      );

  // ─── Details ──────────────────────────────────────────────────────────────

  Widget _detailsSection() {
    final category = _project?['category'] as Map?;
    final stage = _project?['stage'];
    final lookingFor = _project?['looking_for'];
    final projectSize = _project?['project_size'];
    final teamSize = _project?['team_size'];
    final description = _project?['description'] ?? '';

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (category != null) ...[
            _detailRow('Category', category['name']?.toString() ?? ''),
            const SizedBox(height: 10),
          ],
          if (stage != null) ...[
            _detailRow('Project Stage', stage.toString()),
            const SizedBox(height: 10),
          ],
          if (lookingFor != null) ...[
            _detailRow('Looking For', lookingFor.toString()),
            const SizedBox(height: 10),
          ],
          if (projectSize != null) ...[
            _detailRow('Project Size', 'R$projectSize'),
            const SizedBox(height: 10),
          ],
          if (teamSize != null) ...[
            _detailRow('Team Size',
                '$teamSize ${int.tryParse(teamSize.toString()) == 1 ? 'person' : 'people'}'),
            const SizedBox(height: 10),
          ],
          if (description.isNotEmpty) ...[
            const Divider(height: 20),
            Text(description,
                style: const TextStyle(
                    fontSize: 13, color: Colors.black87, height: 1.6)),
          ],
        ],
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Widget _detailRow(String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text('$label:',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF094a25),
                    fontWeight: FontWeight.w500)),
          ),
        ],
      );
}
