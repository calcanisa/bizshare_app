import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../../providers/auth_provider.dart';

class FeatureScreen extends StatefulWidget {
  final String type; // 'business' | 'classified' | 'job' | 'event' | etc.
  final Map<String, dynamic> item;

  const FeatureScreen({
    super.key,
    required this.type,
    required this.item,
  });

  @override
  State<FeatureScreen> createState() => _FeatureScreenState();
}

class _FeatureScreenState extends State<FeatureScreen> {
  static const _green = Color(0xFF094a25);
  static const _red = Color(0xFFbc2023);
  static const _yellow = Color(0xFFf8b324);

  // Feature selections
  bool _featureTop = false;
  bool _featureHighlight = false;
  bool _featureReduced = false;
  bool _featureUrgent = false;
  bool _useBalance = false;
  bool _saving = false;

  String? _selectedPeriod;

  static const _rates = {
    'top': 10,
    'highlight': 8,
    'urgent': 10,
    'reduced': 5,
  };

  static const _periods = [
    ('one_month', 'One month', 30),
    ('three_weeks', 'Three weeks', 21),
    ('two_weeks', 'Two weeks', 14),
    ('one_week', 'One week', 7),
  ];

  // ── Computed ──────────────────────────────────────────────────────────────

  List<String> get _selectedFeatures {
    final list = <String>[];
    if (_featureTop) list.add('top');
    if (_featureHighlight) list.add('highlight');
    if (_featureReduced) list.add('reduced');
    if (_featureUrgent) list.add('urgent');
    return list;
  }

  int get _pricePerDay =>
      _selectedFeatures.fold(0, (total, f) => total + (_rates[f] ?? 0));

  int get _periodDays {
    final p = _periods.firstWhere((p) => p.$1 == _selectedPeriod,
        orElse: () => ('', '', 0));
    return p.$3;
  }

  int get _totalCost => _pricePerDay * _periodDays;

  int get _daysLeft {
    final createdAt =
        DateTime.tryParse(widget.item['created_at']?.toString() ?? '');
    if (createdAt == null) return 30;
    final expiry = createdAt.add(const Duration(days: 30));
    return expiry.difference(DateTime.now()).inDays;
  }

  List<({String value, String label, int days})> get _availablePeriods {
    final isClassified = widget.type == 'classified';
    return _periods
        .where((p) => !isClassified || _daysLeft >= p.$3 - 2)
        .map((p) => (value: p.$1, label: p.$2, days: p.$3))
        .toList();
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_selectedFeatures.isEmpty) {
      _showError('Please choose at least one feature.');
      return;
    }
    if (_selectedPeriod == null) {
      _showError('Please choose a period.');
      return;
    }

    if (_useBalance) {
      await _payWithBalance();
    } else {
      _addToCart();
    }
  }

  void _addToCart() {
    final itemName = widget.item['name'] ?? widget.item['title'] ?? 'item';
    final periodLabel = _periods
        .firstWhere((p) => p.$1 == _selectedPeriod,
            orElse: () => ('', _selectedPeriod!, 0))
        .$2;

    Navigator.pop(context, {
      'feature': _selectedFeatures,
      'type': 'feature',
      'content_type': widget.type,
      'content_id': widget.item['id'],
      'period': _selectedPeriod,
      'title':
          'Feature ${widget.type} "$itemName" (${_selectedFeatures.join(", ")}) for $periodLabel',
      'price': _totalCost,
      'feature_code': _generateCode(),
    });
  }

  Future<void> _payWithBalance() async {
    setState(() => _saving = true);
    final auth = context.read<AuthProvider>();
    try {
      await auth.apiService.dio.post(
        '/api/v1/features/c/',
        data: {
          'features': _selectedFeatures,
          'content_type': widget.type,
          'content_id': widget.item['id'],
          'period': _selectedPeriod,
          'use_balance': true,
          'cost': _totalCost,
        },
      );
      if (!mounted) return;
      _showSuccess('Feature started successfully.');
      Navigator.pop(context, true);
    } on DioException catch (e) {
      _showError(
          e.response?.data?['error'] ?? 'Could not apply feature. Try again.');
    } catch (_) {
      _showError('Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _generateCode() {
    final now = DateTime.now();
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final year = now.year;
    final rand = (1000 + DateTime.now().millisecond * 9).toString();
    return '${day}${month}${year}c${rand}';
  }

  void _showError(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: _red));

  void _showSuccess(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: _green));

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final itemName = widget.item['name'] ?? widget.item['title'] ?? '';
    final isClassified = widget.type == 'classified';
    final isClassifiedOrJob =
        widget.type == 'classified' || widget.type == 'job';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        title: Text('Feature ${widget.type}'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Item name
              Text(itemName,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _green)),
              const SizedBox(height: 4),

              // Classified days left
              if (isClassified) ...[
                Text(
                  'Days left before this ad expires: ${_daysLeft + 1}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
              ],

              // No refunds warning
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
                        color: _red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'There are no refunds on features. You cannot remove any existing features.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Feature options + cost side by side
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Feature checkboxes
                    const Text('Choose features that apply',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _green)),
                    const SizedBox(height: 12),
                    _featureCheckbox(
                      'Top of lists',
                      'R10/day',
                      _featureTop,
                      (v) => setState(() => _featureTop = v ?? false),
                    ),
                    _featureCheckbox(
                      'Highlighted',
                      'R8/day',
                      _featureHighlight,
                      (v) => setState(() => _featureHighlight = v ?? false),
                    ),
                    if (isClassified)
                      _featureCheckbox(
                        'Reduced',
                        'R5/day',
                        _featureReduced,
                        (v) => setState(() => _featureReduced = v ?? false),
                      ),
                    if (isClassifiedOrJob)
                      _featureCheckbox(
                        'Urgent',
                        'R10/day',
                        _featureUrgent,
                        (v) => setState(() => _featureUrgent = v ?? false),
                      ),

                    const Divider(height: 24),

                    // Cost per day
                    Row(
                      children: [
                        const Text('Cost per day:',
                            style:
                                TextStyle(fontSize: 13, color: Colors.black54)),
                        const SizedBox(width: 8),
                        Text('R$_pricePerDay',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: _green)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Period selector
                    const Text('Select period',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedPeriod,
                          isExpanded: true,
                          hint: Text('Select a period',
                              style: TextStyle(
                                  color: Colors.grey[400], fontSize: 13)),
                          icon: const Icon(Icons.keyboard_arrow_down,
                              color: _green, size: 20),
                          items: _availablePeriods
                              .map((p) => DropdownMenuItem(
                                  value: p.value,
                                  child: Text(p.label,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.black87))))
                              .toList(),
                          onChanged: _availablePeriods.isEmpty
                              ? null
                              : (v) => setState(() => _selectedPeriod = v),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Total cost
                    Row(
                      children: [
                        const Text('Feature Cost:',
                            style:
                                TextStyle(fontSize: 13, color: Colors.black54)),
                        const SizedBox(width: 8),
                        Text('R$_totalCost',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _yellow)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Use balance toggle
              Row(
                children: [
                  Checkbox(
                    value: _useBalance,
                    activeColor: _green,
                    onChanged: (v) => setState(() => _useBalance = v ?? false),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _useBalance = !_useBalance),
                    child: const Text('Use ad account balance instead of cart',
                        style: TextStyle(fontSize: 13, color: Colors.black87)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Payment note
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  _useBalance
                      ? 'If you tap Submit the feature will start immediately.'
                      : 'The feature will start once paid. Go to your cart to complete payment.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
              const SizedBox(height: 28),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : _submit,
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
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Submit',
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

  Widget _featureCheckbox(
    String label,
    String rate,
    bool value,
    ValueChanged<bool?> onChanged,
  ) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Checkbox(
              value: value,
              activeColor: _green,
              onChanged: onChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(label,
                  style: const TextStyle(fontSize: 13, color: Colors.black87)),
            ),
            Text(rate,
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500)),
          ],
        ),
      );
}
