import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../../providers/auth_provider.dart';

class MakeOfferSheet extends StatefulWidget {
  final int adId;
  final double price;

  const MakeOfferSheet({
    super.key,
    required this.adId,
    required this.price,
  });

  /// Call this to open the sheet. Returns the offer amount if submitted.
  static Future<String?> show(
      BuildContext context, int adId, double price) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => MakeOfferSheet(adId: adId, price: price),
    );
  }

  @override
  State<MakeOfferSheet> createState() => _MakeOfferSheetState();
}

class _MakeOfferSheetState extends State<MakeOfferSheet> {
  static const _green = Color(0xFF094a25);
  static const _red = Color(0xFFbc2023);

  final _offerCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _offerCtrl.dispose();
    super.dispose();
  }

  String get _formattedPrice {
    final parts = widget.price.toStringAsFixed(0).split('');
    final result = StringBuffer();
    for (int i = 0; i < parts.length; i++) {
      if (i > 0 && (parts.length - i) % 3 == 0) result.write(',');
      result.write(parts[i]);
    }
    return result.toString();
  }

  Future<void> _submit() async {
    if (_offerCtrl.text.trim().isEmpty) {
      setState(() => _error = 'The offer amount is required.');
      Future.delayed(const Duration(seconds: 3),
          () => mounted ? setState(() => _error = null) : null);
      return;
    }

    setState(() => _submitting = true);
    final auth = context.read<AuthProvider>();
    try {
      final res = await auth.apiService.dio.post(
        '/api/v1/classifieds/offer/c/',
        data: {
          'ad': widget.adId,
          'offer': _offerCtrl.text.trim(),
        },
      );
      if (!mounted) return;
      if (res.statusCode == 201) {
        Navigator.pop(context, _offerCtrl.text.trim());
      }
    } on DioException catch (e) {
      setState(() =>
          _error = e.response?.data?['error'] ??
              'Could not submit offer. Try again.');
      Future.delayed(const Duration(seconds: 3),
          () => mounted ? setState(() => _error = null) : null);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Try again.');
      Future.delayed(const Duration(seconds: 3),
          () => mounted ? setState(() => _error = null) : null);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          const Text('Make an Offer',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _green)),
          const SizedBox(height: 8),

          // Info
          const Text(
              'Enter the price you\'re willing to pay. The seller will message you if interested.',
              style: TextStyle(fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 16),

          // Selling price
          RichText(
            text: TextSpan(
              style: const TextStyle(
                  fontSize: 13, color: Colors.black87),
              children: [
                const TextSpan(text: 'Selling price: '),
                TextSpan(
                  text: 'R$_formattedPrice',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _green,
                      fontSize: 15),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Offer input
          const Text('Your Offer',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87)),
          const SizedBox(height: 6),
          TextField(
            controller: _offerCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              hintText: 'Numbers only',
              hintStyle:
                  TextStyle(color: Colors.grey[400], fontSize: 13),
              prefixText: 'R ',
              errorText: _error,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: _green, width: 1.5)),
              errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _red)),
            ),
          ),
          const SizedBox(height: 20),

          // Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Make the Offer',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _red,
                    side: const BorderSide(color: _red),
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Cancel',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Terms note
          Center(
            child: Text(
              'Our terms are always applicable.',
              style: TextStyle(fontSize: 11, color: Colors.grey[400]),
            ),
          ),
        ],
      ),
    );
  }
}