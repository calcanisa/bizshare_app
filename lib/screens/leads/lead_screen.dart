import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../providers/cart_provider.dart';

class LeadDetailScreen extends StatefulWidget {
  final int leadId;
  const LeadDetailScreen({super.key, required this.leadId});

  @override
  State<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends State<LeadDetailScreen> {
  Map<String, dynamic>? _lead;
  bool _loading = true;

  bool _isOwner = false;
  bool _hasPurchased = false;
  bool _hasMembership = false;
  bool _userHasResponded = false;
  int _responseCount = 0;

  static const int _leadPrice = 50;

  @override
  void initState() {
    super.initState();
    _loadLead();
  }

  Future<void> _loadLead() async {
    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      final res = await api.dio
          .get('/api/v1/directory/business/lead/${widget.leadId}/');
      final data = res.data as Map<String, dynamic>;
      setState(() {
        _lead = data;
        _isOwner = data['is_owner'] == true;
        _hasPurchased = data['has_purchased'] == true;
        _hasMembership = data['has_membership'] == true;
        _userHasResponded = data['user_has_responded'] == true;
        _responseCount = data['response_count'] ?? 0;
      });
    } catch (_) {
      _showSnack('Could not load lead. Try again.');
    }
    setState(() => _loading = false);
  }

  Future<void> _deleteLead() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Request'),
        content: const Text(
            'Are you sure you want to delete this request? This cannot be undone.'),
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
      await api.dio
          .delete('/api/v1/directory/business/lead/${widget.leadId}/d/');
      _showSnack('Request deleted successfully');
      if (mounted) Navigator.pop(context);
    } catch (_) {
      _showSnack('Could not delete lead. Try again.');
    }
  }

  void _buyThisLead() {
    final lead = _lead!;
    final price = ((lead['price_per_lead'] ?? _leadPrice) as num).toDouble();
    final serviceName = (lead['service'] as Map?)?['name'] ?? 'Business Lead';

    final cart = context.read<CartProvider>();
    final alreadyInCart =
        cart.items.any((i) => i.id == 'lead_${widget.leadId}');

    if (alreadyInCart) {
      _showSnack('This lead is already in your cart.');
      return;
    }

    cart.addItem(CartItem(
      id: 'lead_${widget.leadId}',
      title: 'Lead: $serviceName',
      price: price,
      type: 'lead',
      contentType: 'businesslead',
      contentId: widget.leadId,
    ));

    _showSnack('Lead added to cart.');
  }

  void _openRespond() {
    // TODO: respond modal
    _showSnack('Respond feature coming soon.');
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return '';
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
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  }

  String _location() {
    final area = _lead?['area'] as Map?;
    if (area != null) {
      final city = area['city'] as Map?;
      final province = city?['province'] as Map?;
      return '${province?['name']} / ${city?['name']} / ${area['name']}';
    }
    final city = _lead?['city'] as Map?;
    if (city != null) {
      final province = city['province'] as Map?;
      return '${province?['name']} / ${city['name']}';
    }
    final userProfile = (_lead?['user'] as Map?)?['profile'] as Map?;
    final locations = userProfile?['locations'] as List?;
    if (locations != null && locations.isNotEmpty) {
      final locCity = locations[0]['city'] as Map?;
      return locCity?['name']?.toString() ?? '';
    }
    return '';
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final serviceName = (_lead?['service'] as Map?)?['name'] ?? 'Lead';

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: const Color(0xFF094a25),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          serviceName,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_isOwner) ...[
            TextButton(
              onPressed: () {}, // TODO: edit lead modal
              child: const Text('Edit',
                  style: TextStyle(color: Color(0xFFf8b324), fontSize: 12)),
            ),
            TextButton(
              onPressed: _deleteLead,
              child: const Text('Delete',
                  style: TextStyle(color: Color(0xFFbc2023), fontSize: 12)),
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF094a25)))
          : _lead == null
              ? const Center(child: Text('Lead not found'))
              : RefreshIndicator(
                  onRefresh: _loadLead,
                  color: const Color(0xFF094a25),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!_isOwner) _responseBar(),
                        _leadBody(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
    );
  }

  // ─── Response bar ─────────────────────────────────────────────────────────

  Widget _responseBar() {
    return Container(
      color: Colors.grey.shade200,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$_responseCount ',
                    style: const TextStyle(
                        color: Color(0xFF094a25),
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                  TextSpan(
                    text:
                        '${_responseCount == 1 ? 'company has' : 'companies have'} responded to this lead',
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (_userHasResponded)
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Color(0xFF094a25), size: 16),
                SizedBox(width: 4),
                Text('You have responded',
                    style: TextStyle(
                        color: Color(0xFF094a25),
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ],
            )
          else
            ElevatedButton(
              onPressed: _openRespond,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF094a25),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Respond to this Lead',
                  style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  // ─── Lead body ────────────────────────────────────────────────────────────

  Widget _leadBody() {
    final lead = _lead!;
    final service = lead['service'] as Map?;
    final category = lead['category'] as Map?;
    final productName = lead['product_name'];
    final amount = lead['amount'];
    final description = lead['description'] ?? '';
    final createdAt = lead['created_at'];
    final user = lead['user'] as Map?;
    final profile = user?['profile'] as Map?;
    final firstName = profile?['first_name'] ?? '';
    final lastName = profile?['last_name'] ?? '';
    final location = _location();
    final email = lead['email'];
    final phone = lead['phone'];
    final pricePerLead = lead['price_per_lead'] ?? _leadPrice;
    final canSeeContact = _isOwner || _hasMembership || _hasPurchased;

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(service?['name']?.toString() ?? '',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF094a25))),
                    if (firstName.isNotEmpty || lastName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Posted by $firstName $lastName'.trim(),
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black45)),
                    ],
                  ],
                ),
              ),
              if (createdAt != null)
                Text(_formatDate(createdAt.toString()),
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black45)),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),

          // Two-column content
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Description'),
                    Text(description,
                        style: const TextStyle(
                            fontSize: 13, color: Colors.black87, height: 1.5)),
                    const SizedBox(height: 16),
                    _fieldLabel('Service'),
                    _fieldValue(service?['name']?.toString() ?? ''),
                    if (productName != null &&
                        productName.toString().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _fieldLabel('Product'),
                      _fieldValue(productName.toString()),
                    ],
                    if (category != null) ...[
                      const SizedBox(height: 12),
                      _fieldLabel('Category'),
                      _fieldValue(category['name']?.toString() ?? ''),
                    ],
                    if (amount != null) ...[
                      const SizedBox(height: 12),
                      _fieldLabel('Budget'),
                      _fieldValue('R$amount', bold: true),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Right column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Location'),
                    _fieldValue(location.isNotEmpty ? location : '—'),
                    const SizedBox(height: 16),

                    // Contact — gated
                    if (canSeeContact) ...[
                      if (email != null && email.toString().isNotEmpty) ...[
                        _fieldLabel('Email'),
                        _fieldValue(email.toString()),
                        const SizedBox(height: 12),
                      ],
                      if (phone != null && phone.toString().isNotEmpty) ...[
                        _fieldLabel('Phone'),
                        _fieldValue(phone.toString()),
                        const SizedBox(height: 12),
                      ],
                      if (_hasPurchased && !_isOwner)
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle,
                                color: Color(0xFF094a25), size: 16),
                            SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'You have purchased this lead',
                                style: TextStyle(
                                    color: Color(0xFF094a25),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Purchase this lead to get the contact details.',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.black54),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _buyThisLead,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFf8b324),
                                  foregroundColor: Colors.black87,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                ),
                                child: Text(
                                  'Buy This Lead — R$pricePerLead',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Widget _fieldLabel(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF094a25))),
      );

  Widget _fieldValue(String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(value,
            style: TextStyle(
                fontSize: 13,
                color: const Color(0xFF094a25),
                fontWeight: bold ? FontWeight.bold : FontWeight.w500)),
      );
}
