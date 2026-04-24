import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../../providers/auth_provider.dart';

class OpportunityApplicationSheet extends StatefulWidget {
  final String action; // 'add' | 'edit'
  final Map<String, dynamic> opportunity;
  final Map<String, dynamic>? application; // existing for edit
  final Map<String, dynamic>? profile; // logged-in user's profile
  final bool isVerified;

  const OpportunityApplicationSheet({
    super.key,
    required this.action,
    required this.opportunity,
    this.application,
    this.profile,
    this.isVerified = false,
  });

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required String action,
    required Map<String, dynamic> opportunity,
    Map<String, dynamic>? application,
    Map<String, dynamic>? profile,
    bool isVerified = false,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => OpportunityApplicationSheet(
        action: action,
        opportunity: opportunity,
        application: application,
        profile: profile,
        isVerified: isVerified,
      ),
    );
  }

  @override
  State<OpportunityApplicationSheet> createState() =>
      _OpportunityApplicationSheetState();
}

class _OpportunityApplicationSheetState
    extends State<OpportunityApplicationSheet> {
  static const _green = Color(0xFF094a25);
  static const _red = Color(0xFFbc2023);

  final _pitchCtrl = TextEditingController();
  bool _accepted = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.action == 'edit' && widget.application != null) {
      _pitchCtrl.text = widget.application!['pitch'] ?? '';
      _accepted = true;
    }
    _pitchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pitchCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.action == 'add' && !_accepted) {
      _showError('You must accept the terms.');
      return;
    }
    if (_pitchCtrl.text.trim().isEmpty) {
      _showError('Pitch cannot be empty.');
      return;
    }

    setState(() => _submitting = true);
    final auth = context.read<AuthProvider>();
    try {
      if (widget.action == 'edit') {
        final appId = widget.application!['id'];
        final res = await auth.apiService.dio.patch(
          '/api/v1/opportunities/application/$appId/u/',
          data: {'pitch': _pitchCtrl.text.trim()},
        );
        if (!mounted) return;
        if (res.statusCode == 200) Navigator.pop(context, res.data);
      } else {
        final res = await auth.apiService.dio.post(
          '/api/v1/opportunities/application/c/',
          data: {
            'opportunity': widget.opportunity['id'],
            'pitch': _pitchCtrl.text.trim(),
          },
        );
        if (!mounted) return;
        if (res.statusCode == 201) Navigator.pop(context, res.data);
      }
    } on DioException catch (e) {
      _showError(e.response?.data?['error'] ??
          'Could not submit application. Try again.');
    } catch (_) {
      _showError('Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: _red));

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: widget.isVerified ? _notVerifiedView() : _formView(),
    );
  }

  // ── Not verified ──────────────────────────────────────────────────────────

  Widget _notVerifiedView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _handle(),
        const SizedBox(height: 20),
        const Icon(Icons.verified_outlined, color: _green, size: 48),
        const SizedBox(height: 16),
        const Text(
          'You have to be verified to apply for opportunities.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.bold, color: _green),
        ),
        const SizedBox(height: 8),
        const Text(
          'Go to your Account screen to apply for verification.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.black54),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: _red,
              side: const BorderSide(color: _red),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Close',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ),
      ],
    );
  }

  // ── Application form ──────────────────────────────────────────────────────

  Widget _formView() {
    final firstName = widget.profile?['first_name'] ?? '';
    final lastName = widget.profile?['last_name'] ?? '';
    final oppTitle = widget.opportunity['title'] ?? 'Opportunity';
    final isEdit = widget.action == 'edit';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _handle(),
        const SizedBox(height: 16),

        // Title
        Text(
          isEdit ? 'Edit Application' : 'Apply for Opportunity',
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: _green),
        ),
        const SizedBox(height: 4),
        Text(oppTitle,
            style: const TextStyle(fontSize: 13, color: Colors.black54)),
        const SizedBox(height: 16),

        // Applicant name
        if (firstName.isNotEmpty || lastName.isNotEmpty) ...[
          const Text('Person Applying',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54)),
          const SizedBox(height: 4),
          Text(
            '$firstName $lastName'.trim(),
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: _green),
          ),
          const SizedBox(height: 16),
        ],

        // Pitch
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Your Pitch',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87)),
            Text('${_pitchCtrl.text.length} / 1000',
                style: TextStyle(
                    fontSize: 11,
                    color: _pitchCtrl.text.length >= 1000
                        ? _red
                        : Colors.grey[400])),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _pitchCtrl,
          maxLines: 5,
          maxLength: 1000,
          buildCounter: (_,
                  {required currentLength, required isFocused, maxLength}) =>
              const SizedBox.shrink(),
          decoration: InputDecoration(
            hintText:
                'Give compelling reasons why you are ideal for this opportunity.',
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
            contentPadding: const EdgeInsets.all(12),
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
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 16),

        // Terms (add only)
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
          const SizedBox(height: 16),
        ],

        // Buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
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
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _handle() => Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
}
