import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';

class AddPostModal extends StatefulWidget {
  final String action; // 'add' or 'edit'
  final int businessId;
  final Map<String, dynamic>? post;
  final void Function(Map<String, dynamic> data) onSave;
  final VoidCallback onCancel;

  const AddPostModal({
    super.key,
    required this.action,
    required this.businessId,
    this.post,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<AddPostModal> createState() => _AddPostModalState();
}

class _AddPostModalState extends State<AddPostModal> {
  final _bodyController = TextEditingController();
  bool _saving = false;
  bool _accepted = false;

  final List<File> _newImages = [];
  List<String> _existingImages = [];
  final List<int> _removedIds = [];

  static const int _maxMedia = 4;

  @override
  void initState() {
    super.initState();
    if (widget.action == 'edit' && widget.post != null) {
      _bodyController.text = widget.post!['body'] ?? '';
      final images = widget.post!['images'] as List? ?? [];
      _existingImages = images
          .map((img) => img['image']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
      _accepted = true;
    }
  }

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    final total = _newImages.length + _existingImages.length;
    if (total >= _maxMedia) {
      _showSnack('Maximum $_maxMedia media files allowed');
      return;
    }
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;
    final remaining = _maxMedia - total;
    setState(() {
      _newImages.addAll(picked.take(remaining).map((f) => File(f.path)));
    });
  }

  Future<void> _save() async {
    if (widget.action == 'add' && !_accepted) {
      _showSnack('You must accept the terms');
      return;
    }
    if (_bodyController.text.trim().length < 10) {
      _showSnack('Body cannot be less than 10 characters');
      return;
    }

    setState(() => _saving = true);
    try {
      final api = context.read<ApiService>();
      final formData = FormData();
      formData.fields.addAll([
        MapEntry('business', widget.businessId.toString()),
        MapEntry('body', _bodyController.text.trim()),
      ]);

      for (final id in _removedIds) {
        formData.fields.add(MapEntry('media_to_remove', id.toString()));
      }

      for (final file in _newImages) {
        formData.files.add(MapEntry(
            'media',
            await MultipartFile.fromFile(file.path,
                filename: file.path.split('/').last)));
      }

      late Map<String, dynamic> result;
      if (widget.action == 'add') {
        final res = await api.dio
            .post('/api/v1/directory/business/post/c/', data: formData);
        result = res.data;
      } else {
        final id = widget.post!['id'];
        final res = await api.dio
            .put('/api/v1/directory/business/post/$id/u/', data: formData);
        result = res.data;
      }
      widget.onSave(result);
    } catch (_) {
      _showSnack('Something went wrong. Please try again.');
    }
    setState(() => _saving = false);
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bodyLen = _bodyController.text.length;
    final totalMedia = _newImages.length + _existingImages.length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF094a25),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.action == 'edit' ? 'Edit Post' : 'Create Post',
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: widget.onCancel,
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Body
          TextField(
            controller: _bodyController,
            maxLines: 6,
            maxLength: 500,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'What would you like to share with your customers?',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF094a25)),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 16),

          // Media section
          const Text('You are limited to 4 uploads in total.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.black45)),
          const SizedBox(height: 10),

          // Existing images
          if (_existingImages.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_existingImages.length, (i) {
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        _existingImages[i],
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _existingImages.removeAt(i);
                          });
                        },
                        child: _closeBtn(),
                      ),
                    ),
                  ],
                );
              }),
            ),
            const SizedBox(height: 8),
          ],

          // New images
          if (_newImages.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_newImages.length, (i) {
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.file(
                        _newImages[i],
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: () => setState(() => _newImages.removeAt(i)),
                        child: _closeBtn(),
                      ),
                    ),
                  ],
                );
              }),
            ),
            const SizedBox(height: 8),
          ],

          if (totalMedia < _maxMedia)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _pickMedia,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF094a25),
                  side: const BorderSide(color: Color(0xFF094a25)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text('Add Media'),
              ),
            ),

          const SizedBox(height: 20),

          // Terms
          if (widget.action == 'add') ...[
            Row(
              children: [
                Checkbox(
                  value: _accepted,
                  activeColor: const Color(0xFF094a25),
                  onChanged: (v) => setState(() => _accepted = v ?? false),
                ),
                const Text('I accept the '),
                GestureDetector(
                  onTap: () {},
                  child: const Text('terms',
                      style: TextStyle(
                          color: Color(0xFF094a25),
                          decoration: TextDecoration.underline)),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF094a25),
                    disabledBackgroundColor: Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Save',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFbc2023),
                    side: const BorderSide(color: Color(0xFFbc2023)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontSize: 15)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _closeBtn() => Container(
        width: 20,
        height: 20,
        decoration: const BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.close, color: Colors.white, size: 12),
      );
}
