import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../../providers/auth_provider.dart';

class ReviewScreen extends StatefulWidget {
  final String action; // 'add' | 'edit'
  final int businessId;
  final Map<String, dynamic>? review; // required for edit

  const ReviewScreen({
    super.key,
    required this.action,
    required this.businessId,
    this.review,
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  static const _green = Color(0xFF1B4748);
  static const _red = Color(0xFFF48900);
  static const _yellow = Color(0xFFF8BB25);

  final _serviceNumberCtrl = TextEditingController();
  final _branchCtrl = TextEditingController();
  final _reviewCtrl = TextEditingController();

  int _rating = 0;
  int _hoverRating = 0;
  bool _accepted = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.action == 'edit' && widget.review != null) {
      final r = widget.review!;
      _serviceNumberCtrl.text = r['service_number'] ?? '';
      _branchCtrl.text = r['branch'] ?? '';
      _reviewCtrl.text = r['review'] ?? '';
      _rating = (r['rating'] as num?)?.toInt() ?? 0;
      _accepted = true; // terms not re-shown on edit
    }
  }

  @override
  void dispose() {
    _serviceNumberCtrl.dispose();
    _branchCtrl.dispose();
    _reviewCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_reviewCtrl.text.trim().isEmpty) {
      _showError('Review detail is required.');
      return;
    }
    if (_rating == 0) {
      _showError('Please select a rating.');
      return;
    }
    if (widget.action == 'add' && !_accepted) {
      _showError('You must accept the terms to continue.');
      return;
    }

    setState(() => _saving = true);
    final auth = context.read<AuthProvider>();

    final data = {
      'business': widget.businessId,
      'review': _reviewCtrl.text.trim(),
      'rating': _rating,
      'service_number': _serviceNumberCtrl.text.trim(),
      'branch': _branchCtrl.text.trim(),
    };

    try {
      if (widget.action == 'add') {
        final res = await auth.apiService.dio.post(
          '/api/v1/directory/business/${widget.businessId}/a/review/',
          data: data,
        );
        if (!mounted) return;
        if (res.statusCode == 201) {
          _showSuccess('Review submitted — it will appear after review.');
          Navigator.pop(context, res.data);
        }
      } else {
        final reviewId = widget.review!['id'];
        final res = await auth.apiService.dio.put(
          '/api/v1/directory/business/review/$reviewId/u/',
          data: data,
        );
        if (!mounted) return;
        if (res.statusCode == 200) {
          _showSuccess('Review updated — it will appear after review.');
          Navigator.pop(context, res.data);
        }
      }
    } on DioException catch (e) {
      _showError(
          e.response?.data?['error'] ?? 'Could not save review. Try again.');
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
        title: Text(isEdit ? 'Edit Review' : 'Write a Review'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Warning
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _red.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _red.withValues(alpha: 0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: _red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'We take the posting of false information very seriously. '
                        'Please do not post false information about any company.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Service / reference number
              _label(
                  'Account / Invoice / Reference number or date of incident'),
              const SizedBox(height: 6),
              TextField(
                controller: _serviceNumberCtrl,
                decoration: _inputDeco('Optional'),
              ),
              const SizedBox(height: 16),

              // Branch
              _label('Branch'),
              const SizedBox(height: 6),
              TextField(
                controller: _branchCtrl,
                decoration: _inputDeco('Branch'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              // Review detail
              _label('Review detail', required: true),
              const SizedBox(height: 6),
              TextField(
                controller: _reviewCtrl,
                maxLines: 6,
                decoration: _inputDeco('Please describe your experience'),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 20),

              // Star rating
              _label('How would you rate this business?'),
              const SizedBox(height: 12),
              _StarRating(
                rating: _rating,
                hoverRating: _hoverRating,
                onRate: (s) => setState(() => _rating = s),
                onHover: (s) => setState(() => _hoverRating = s),
                onLeave: () => setState(() => _hoverRating = 0),
              ),
              const SizedBox(height: 6),
              Text(
                _rating > 0
                    ? 'Your rating: $_rating / 10'
                    : 'Tap a star to rate',
                style: TextStyle(
                    fontSize: 12,
                    color: _rating > 0 ? _green : Colors.grey[400],
                    fontWeight:
                        _rating > 0 ? FontWeight.w600 : FontWeight.normal),
              ),
              const SizedBox(height: 20),

              // Terms (add mode only)
              if (!isEdit) ...[
                Row(
                  children: [
                    Checkbox(
                      value: _accepted,
                      activeColor: _green,
                      onChanged: (v) => setState(() => _accepted = v ?? false),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _accepted = !_accepted),
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(fontSize: 13, color: Colors.black87),
                          children: [
                            TextSpan(text: 'I accept the '),
                            TextSpan(
                              text: 'terms',
                              style: TextStyle(
                                color: _green,
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextSpan(text: '.'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              // Buttons
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

  Widget _label(String text, {bool required = false}) => RichText(
        text: TextSpan(
          style: const TextStyle(
              color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 13),
          children: [
            TextSpan(text: text),
            if (required)
              const TextSpan(text: ' *', style: TextStyle(color: _red)),
          ],
        ),
      );

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
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
      );
}

// ─── Star Rating Widget ───────────────────────────────────────────────────────

class _StarRating extends StatelessWidget {
  final int rating;
  final int hoverRating;
  final ValueChanged<int> onRate;
  final ValueChanged<int> onHover;
  final VoidCallback onLeave;

  static const _yellow = Color(0xFFF8BB25);

  const _StarRating({
    required this.rating,
    required this.hoverRating,
    required this.onRate,
    required this.onHover,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      children: List.generate(10, (i) {
        final star = i + 1;
        final active = hoverRating > 0 ? star <= hoverRating : star <= rating;
        return GestureDetector(
          onTap: () => onRate(star),
          child: MouseRegion(
            onEnter: (_) => onHover(star),
            onExit: (_) => onLeave(),
            child: Icon(
              active ? Icons.star_rounded : Icons.star_outline_rounded,
              color: active ? _yellow : Colors.grey[300],
              size: 32,
            ),
          ),
        );
      }),
    );
  }
}
