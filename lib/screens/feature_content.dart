import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/cart_provider.dart';

class FeatureScreen extends StatefulWidget {
  final String type;
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

  bool _featureTop = false;
  bool _featureHighlight = false;
  bool _featureReduced = false;
  bool _featureUrgent = false;

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

  void _submit() {
    if (_selectedFeatures.isEmpty) {
      _showError('Please choose at least one feature.');
      return;
    }
    if (_selectedPeriod == null) {
      _showError('Please choose a period.');
      return;
    }

    final itemName = widget.item['name'] ?? widget.item['title'] ?? 'item';
    final periodLabel = _periods
        .firstWhere((p) => p.$1 == _selectedPeriod,
            orElse: () => ('', _selectedPeriod!, 0))
        .$2;

    final cart = context.read<CartProvider>();
    cart.addItem(CartItem(
      id: 'feature_${widget.item['id']}_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Feature ${widget.type} "$itemName" (${_selectedFeatures.join(", ")}) for $periodLabel',
      price: _totalCost.toDouble(),
      type: 'feature',
      contentType: widget.type,
      contentId: widget.item['id'] is int
          ? widget.item['id'] as int
          : int.tryParse(widget.item['id'].toString()),
      feature: true,
      featureTypes: _selectedFeatures,
    ));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Added to cart. Go to your cart to complete payment.'),
        backgroundColor: _green,
      ),
    );
    Navigator.pop(context);
  }

  void _showError(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: _red));

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
              Text(itemName,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold, color: _green)),
              const SizedBox(height: 4),
              if (isClassified) ...[
                Text(
                  'Days left before this ad expires: ${_daysLeft + 1}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
              ],
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _red.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _red.withOpacity(0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: _red, size: 16),
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
                    const Text('Choose features that apply',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _green)),
                    const SizedBox(height: 12),
                    _featureCheckbox('Top of lists', 'R10/day', _featureTop,
                        (v) => setState(() => _featureTop = v ?? false)),
                    _featureCheckbox('Highlighted', 'R8/day', _featureHighlight,
                        (v) => setState(() => _featureHighlight = v ?? false)),
                    if (isClassified)
                      _featureCheckbox('Reduced', 'R5/day', _featureReduced,
                          (v) => setState(() => _featureReduced = v ?? false)),
                    if (isClassifiedOrJob)
                      _featureCheckbox('Urgent', 'R10/day', _featureUrgent,
                          (v) => setState(() => _featureUrgent = v ?? false)),
                    const Divider(height: 24),
                    Row(
                      children: [
                        const Text('Cost per day:',
                            style: TextStyle(fontSize: 13, color: Colors.black54)),
                        const SizedBox(width: 8),
                        Text('R$_pricePerDay',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: _green)),
                      ],
                    ),
                    const SizedBox(height: 16),
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
                    Row(
                      children: [
                        const Text('Feature Cost:',
                            style: TextStyle(fontSize: 13, color: Colors.black54)),
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
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'The feature will start once paid. Go to your cart to complete payment.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Add to Cart',
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