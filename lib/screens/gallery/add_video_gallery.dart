import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../../providers/auth_provider.dart';

class AddVideoGalleryScreen extends StatefulWidget {
  final String action; // 'add' | 'edit'
  final String target; // 'business' | 'profile'
  final int targetId; // businessId or profileId
  final Map<String, dynamic>? gallery; // existing gallery for edit
  final int limit;

  const AddVideoGalleryScreen({
    super.key,
    required this.action,
    required this.target,
    required this.targetId,
    this.gallery,
    this.limit = 4,
  });

  @override
  State<AddVideoGalleryScreen> createState() => _AddVideoGalleryScreenState();
}

class _AddVideoGalleryScreenState extends State<AddVideoGalleryScreen> {
  static const _green = Color(0xFF094a25);
  static const _red = Color(0xFFbc2023);

  final _titleCtrl = TextEditingController();
  bool _saving = false;

  // New files picked this session
  final List<File> _newFiles = [];

  // Existing videos (edit mode) — each has 'id' and 'video' url
  List<Map<String, dynamic>> _existingVideos = [];

  // IDs to remove on save
  final List<int> _videosToRemove = [];

  @override
  void initState() {
    super.initState();
    if (widget.action == 'edit' && widget.gallery != null) {
      _titleCtrl.text = widget.gallery!['title'] ?? '';
      final vids = widget.gallery!['videos'] as List? ?? [];
      _existingVideos = List<Map<String, dynamic>>.from(
          vids.map((v) => Map<String, dynamic>.from(v as Map)));
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  int get _totalCount => _existingVideos.length + _newFiles.length;

  Future<void> _pickVideos() async {
    final remaining = widget.limit - _totalCount;
    if (remaining <= 0) {
      _showError('You can only upload ${widget.limit} videos per gallery.');
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickMultipleMedia();

    // Filter to videos only
    final videos = picked
        .where((f) =>
            f.mimeType?.startsWith('video/') ??
            f.path.endsWith('.mp4') || f.path.endsWith('.mov'))
        .take(remaining)
        .map((f) => File(f.path))
        .toList();

    if (videos.isEmpty) {
      _showError('Please select video files only.');
      return;
    }

    // Check 20MB per file
    for (final file in videos) {
      final bytes = await file.length();
      if (bytes > 20 * 1024 * 1024) {
        _showError('Max video size is 20MB. One or more files were skipped.');
        continue;
      }
      if (_totalCount < widget.limit) {
        setState(() => _newFiles.add(file));
      }
    }
  }

  void _removeExisting(int videoId) {
    setState(() {
      _existingVideos.removeWhere((v) => v['id'] == videoId);
      _videosToRemove.add(videoId);
    });
  }

  void _removeNew(int index) {
    setState(() => _newFiles.removeAt(index));
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      _showError('Gallery title cannot be empty.');
      return;
    }
    if (_totalCount == 0) {
      _showError('Please add at least one video.');
      return;
    }

    setState(() => _saving = true);
    final auth = context.read<AuthProvider>();
    final isEdit = widget.action == 'edit';

    try {
      final fields = <String, String>{
        'title': _titleCtrl.text.trim(),
        if (widget.target == 'business')
          'business_id': widget.targetId.toString()
        else
          'profile_id': widget.targetId.toString(),
        if (isEdit && _videosToRemove.isNotEmpty)
          'videos_to_remove': _videosToRemove.toString(),
      };

      final files = <String, File>{};
      for (var i = 0; i < _newFiles.length; i++) {
        files['videos_$i'] = _newFiles[i];
      }

      String url;
      if (widget.target == 'business') {
        url = isEdit
            ? '/api/v1/directory/business/videos/gallery/${widget.gallery!['id']}/u/'
            : '/api/v1/directory/business/videos/gallery/c/';
      } else {
        url = isEdit
            ? '/api/v1/profiles/gallery/${widget.gallery!['id']}/videos/u/'
            : '/api/v1/profiles/gallery/videos/c/';
      }

      final Map<String, dynamic> result;
      if (isEdit) {
        result = await auth.apiService
            .patchMultipart(url, fields: fields, files: files);
      } else {
        result = await auth.apiService
            .postMultipart(url, fields: fields, files: files);
      }

      if (!mounted) return;
      _showSuccess('Gallery ${isEdit ? 'updated' : 'created'} successfully.');
      Navigator.pop(context, result);
    } on DioException catch (e) {
      _showError(
          e.response?.data?['error'] ?? 'Could not save gallery. Try again.');
    } catch (_) {
      _showError('Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: _red));

  void _showSuccess(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: _green));

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.action == 'edit';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        title: Text(isEdit ? 'Edit Video Gallery' : 'Add Video Gallery'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _green.withValues(alpha: 0.2)),
                ),
                child: Text(
                  'Limited to ${widget.limit} videos per gallery. Max 20MB per video.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Text('Gallery Title',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87)),
              const SizedBox(height: 6),
              TextField(
                controller: _titleCtrl,
                maxLength: 50,
                buildCounter: (_,
                        {required currentLength,
                        required isFocused,
                        maxLength}) =>
                    Text('$currentLength / $maxLength',
                        style: TextStyle(
                            fontSize: 11,
                            color: currentLength == maxLength
                                ? _red
                                : Colors.grey[400])),
                decoration: InputDecoration(
                  hintText: 'Gallery title',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _green, width: 1.5)),
                ),
              ),
              const SizedBox(height: 20),

              // Browse button + counter
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _totalCount >= widget.limit ? null : _pickVideos,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.video_library_outlined, size: 18),
                    label: const Text('Browse for Videos'),
                  ),
                  const SizedBox(width: 12),
                  Text('$_totalCount / ${widget.limit}',
                      style: TextStyle(
                          fontSize: 13,
                          color: _totalCount >= widget.limit
                              ? _red
                              : Colors.grey[500],
                          fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 20),

              // Existing videos (edit mode)
              if (_existingVideos.isNotEmpty) ...[
                const Text('Existing Videos',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87)),
                const SizedBox(height: 8),
                ..._existingVideos.map((v) => _ExistingVideoTile(
                      videoUrl: v['video']?.toString() ?? '',
                      onRemove: () => _removeExisting(v['id'] as int),
                    )),
                const SizedBox(height: 16),
              ],

              // New video previews
              if (_newFiles.isNotEmpty) ...[
                const Text('New Videos',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87)),
                const SizedBox(height: 8),
                ..._newFiles.asMap().entries.map((e) => _NewVideoTile(
                      file: e.value,
                      onRemove: () => _removeNew(e.key),
                    )),
                const SizedBox(height: 16),
              ],

              // Buttons
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Save',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _red,
                        side: const BorderSide(color: _red),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Cancel',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Existing video tile (network URL) ───────────────────────────────────────

class _ExistingVideoTile extends StatefulWidget {
  final String videoUrl;
  final VoidCallback onRemove;

  const _ExistingVideoTile({required this.videoUrl, required this.onRemove});

  @override
  State<_ExistingVideoTile> createState() => _ExistingVideoTileState();
}

class _ExistingVideoTileState extends State<_ExistingVideoTile> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.videoUrl.isNotEmpty) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
        ..initialize().then((_) => setState(() {}));
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _VideoTileShell(
        thumbnail: _controller?.value.isInitialized == true
            ? AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!))
            : const _VideoPlaceholder(),
        onRemove: widget.onRemove,
        label: widget.videoUrl.split('/').last,
      );
}

// ─── New video tile (local file) ─────────────────────────────────────────────

class _NewVideoTile extends StatefulWidget {
  final File file;
  final VoidCallback onRemove;

  const _NewVideoTile({required this.file, required this.onRemove});

  @override
  State<_NewVideoTile> createState() => _NewVideoTileState();
}

class _NewVideoTileState extends State<_NewVideoTile> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.file)
      ..initialize().then((_) => setState(() {}));
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _VideoTileShell(
        thumbnail: _controller?.value.isInitialized == true
            ? AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!))
            : const _VideoPlaceholder(),
        onRemove: widget.onRemove,
        label: widget.file.path.split('/').last,
      );
}

// ─── Shared tile shell ────────────────────────────────────────────────────────

class _VideoTileShell extends StatelessWidget {
  final Widget thumbnail;
  final VoidCallback onRemove;
  final String label;

  static const _red = Color(0xFFbc2023);

  const _VideoTileShell({
    required this.thumbnail,
    required this.onRemove,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(7)),
            child: SizedBox(width: 100, height: 70, child: thumbnail),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close, color: _red, size: 18),
          ),
        ],
      ),
    );
  }
}

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[100],
      child: const Center(
        child: Icon(Icons.videocam_outlined, color: Colors.black26, size: 28),
      ),
    );
  }
}
