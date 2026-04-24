import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import 'package:dio/dio.dart';

class AddPictureGalleryScreen extends StatefulWidget {
  final String action; // 'create' or 'edit'
  final String title;
  final int? profileId;
  final int? businessId;
  final int limit;
  final Map<String, dynamic>? gallery; // populated on edit

  const AddPictureGalleryScreen({
    super.key,
    required this.action,
    required this.title,
    this.profileId,
    this.businessId,
    this.limit = 8,
    this.gallery,
  }) : assert(profileId != null || businessId != null,
            'Either profileId or businessId must be provided');

  @override
  State<AddPictureGalleryScreen> createState() =>
      _AddPictureGalleryScreenState();
}

// Represents a single image slot — either an existing server image or a new local pick
class _GalleryImage {
  final int? existingId;     // set for server images
  final String? existingUrl; // set for server images
  final XFile? newFile;      // set for new picks

  const _GalleryImage.existing({required this.existingId, required this.existingUrl})
      : newFile = null;

  const _GalleryImage.picked({required this.newFile})
      : existingId = null,
        existingUrl = null;

  bool get isExisting => existingId != null;
}

class _AddPictureGalleryScreenState extends State<AddPictureGalleryScreen> {
  final _titleController = TextEditingController();
  final _picker = ImagePicker();

  final List<_GalleryImage> _images = [];
  final List<int> _removedIds = [];

  bool _saving = false;

  // ─── Lifecycle ───────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    if (widget.action == 'edit' && widget.gallery != null) {
      _titleController.text = widget.gallery!['title'] ?? '';
      final existing = widget.gallery!['images'] as List<dynamic>? ?? [];
      for (final img in existing) {
        _images.add(_GalleryImage.existing(
          existingId: img['id'] as int,
          existingUrl: img['image'] as String,
        ));
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  int get _remaining => widget.limit - _images.length;

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? const Color(0xFFbc2023) : const Color(0xFF094a25),
    ));
  }

  // ─── Image picking ────────────────────────────────────────────────────────

  Future<void> _pickImages() async {
    if (_remaining <= 0) {
      _showSnack('You have reached the ${widget.limit}-picture limit.', error: true);
      return;
    }

    final picked = await _picker.pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;

    final allowed = picked.take(_remaining).toList();
    if (allowed.length < picked.length) {
      _showSnack(
          'Only ${allowed.length} image(s) added — limit of ${widget.limit} reached.',
          error: true);
    }

    setState(() {
      for (final f in allowed) {
        _images.add(_GalleryImage.picked(newFile: f));
      }
    });
  }

  void _removeImage(int index) {
    final img = _images[index];
    if (img.isExisting) {
      _removedIds.add(img.existingId!);
    }
    setState(() => _images.removeAt(index));
  }

  // ─── Save ─────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final titleVal = _titleController.text.trim();
    if (titleVal.isEmpty) {
      _showSnack('Gallery title cannot be empty.', error: true);
      return;
    }

    final newFiles =
        _images.where((i) => !i.isExisting).map((i) => i.newFile!).toList();

    final isEdit = widget.action == 'edit';

    // Must have at least one image on create, or something remaining on edit
    if (!isEdit && newFiles.isEmpty) {
      _showSnack('Please add at least one picture.', error: true);
      return;
    }

    setState(() => _saving = true);

    try {
      final api = context.read<ApiService>();

      final formData = FormData.fromMap({'title': titleVal});

      for (final file in newFiles) {
        formData.files.add(MapEntry(
          'images',
          await MultipartFile.fromFile(file.path,
              filename: file.name),
        ));
      }

      String url;
      String method;

      if (widget.profileId != null) {
        formData.fields.add(MapEntry('profile_id', widget.profileId.toString()));
        if (isEdit) {
          formData.fields
              .add(MapEntry('images_to_remove', _removedIds.toString()));
          url = '/api/v1/profiles/gallery/${widget.gallery!['id']}/pictures/u/';
          method = 'put';
        } else {
          url = '/api/v1/profiles/gallery/pictures/c/';
          method = 'post';
        }
      } else {
        formData.fields
            .add(MapEntry('business_id', widget.businessId.toString()));
        if (isEdit) {
          formData.fields
              .add(MapEntry('images_to_remove', _removedIds.toString()));
          url =
              '/api/v1/directory/business/pictures/gallery/${widget.gallery!['id']}/u/';
          method = 'put';
        } else {
          url = '/api/v1/directory/business/pictures/gallery/c/';
          method = 'post';
        }
      }

      late Response response;
      if (method == 'post') {
        response = await api.dio.post(url, data: formData);
      } else {
        response = await api.dio.put(url, data: formData);
      }

      final expectedStatus = isEdit ? 200 : 201;
      if (response.statusCode == expectedStatus) {
        _showSnack('Gallery ${isEdit ? 'updated' : 'created'} successfully.');
        if (mounted) Navigator.pop(context, response.data);
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ??
          e.response?.data?['error'] ??
          'Failed to ${isEdit ? 'update' : 'create'} gallery. Please try again.';
      _showSnack(msg.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title,
            style: const TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF094a25),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Save',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Info banner ───────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFf0f7f3),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF094a25).withOpacity(0.2)),
              ),
              child: Text(
                'You are limited to ${widget.limit} pictures per gallery.',
                style: const TextStyle(fontSize: 13, color: Color(0xFF094a25)),
                textAlign: TextAlign.center,
              ),
            ),

            // ── Gallery title ─────────────────────────────────────────────
            const Text('Gallery Title',
                style:
                    TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 6),
            TextField(
              controller: _titleController,
              maxLength: 50,
              decoration: InputDecoration(
                hintText: 'Gallery Title',
                hintStyle: const TextStyle(color: Colors.black38),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Color(0xFF094a25))),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                counterStyle: const TextStyle(fontSize: 11),
              ),
            ),
            const SizedBox(height: 20),

            // ── Browse button ─────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _saving ? null : _pickImages,
                icon: const Icon(Icons.add_photo_alternate_outlined,
                    color: Color(0xFF094a25)),
                label: Text(
                  _images.isEmpty
                      ? 'Browse for Pictures'
                      : 'Add More (${_images.length}/${widget.limit})',
                  style: const TextStyle(color: Color(0xFF094a25)),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF094a25)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Preview grid ──────────────────────────────────────────────
            if (_images.isNotEmpty)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: _images.length,
                itemBuilder: (ctx, index) {
                  final img = _images[index];
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      // Image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: img.isExisting
                            ? Image.network(
                                img.existingUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                    color: Colors.grey[200],
                                    child: const Icon(Icons.broken_image,
                                        color: Colors.grey)),
                              )
                            : Image.file(
                                File(img.newFile!.path),
                                fit: BoxFit.cover,
                              ),
                      ),
                      // Remove button
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: _saving ? null : () => _removeImage(index),
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: const BoxDecoration(
                              color: Color(0xFFbc2023),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

            const SizedBox(height: 30),

            // ── Cancel button ─────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('Cancel',
                    style: TextStyle(color: Color(0xFFbc2023))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}