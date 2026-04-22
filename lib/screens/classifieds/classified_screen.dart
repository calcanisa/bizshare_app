import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';

class ClassifiedDetailScreen extends StatefulWidget {
  final int adId;
  const ClassifiedDetailScreen({super.key, required this.adId});

  @override
  State<ClassifiedDetailScreen> createState() => _ClassifiedDetailScreenState();
}

class _ClassifiedDetailScreenState extends State<ClassifiedDetailScreen> {
  Map<String, dynamic>? _ad;
  bool _loading = true;
  int? _accountId;
  bool _hasMembership = false;

  // Image gallery
  Map<String, dynamic>? _mainImage;
  bool _showPhone = false;

  // Message form
  final _messageController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _sendingMessage = false;
  String _messageError = '';

  // Finance calculator
  final _depositController = TextEditingController();
  final _residualController = TextEditingController();
  final _interestController = TextEditingController();
  int _period = 0;
  Map<String, double>? _financeResults;

  static const _propertyTypes = {
    'commercial': 'Commercial',
    'empty': 'Empty Land',
    'farm': 'Farm',
    'flat': 'Flat',
    'gardenflat': 'Garden Flat',
    'house': 'House',
    'holiday': 'Holiday Home',
    'townhouse': 'Townhouse',
    'other': 'Other',
  };

  @override
  void initState() {
    super.initState();
    _loadAccount();
    _loadAd();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _phoneController.dispose();
    _depositController.dispose();
    _residualController.dispose();
    _interestController.dispose();
    super.dispose();
  }

  Future<void> _loadAccount() async {
    try {
      final api = context.read<ApiService>();
      final res = await api.dio.get('/api/v1/users/current/');
      setState(() {
        _accountId = res.data['id'];
        _hasMembership = res.data['membership'] != null;
      });
    } catch (_) {}
  }

  Future<void> _loadAd() async {
    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      final res =
          await api.dio.get('/api/v1/classifieds/classified/${widget.adId}/');
      final data = res.data as Map<String, dynamic>;
      final images = data['images'] as List? ?? [];
      final defaultImg = images.firstWhere((i) => i['default'] == true,
          orElse: () => images.isNotEmpty ? images[0] : null);
      setState(() {
        _ad = data;
        _mainImage = defaultImg;
      });
    } catch (_) {
      _showSnack('Could not load ad. Try again.');
    }
    setState(() => _loading = false);
  }

  bool get _isOwner {
    if (_accountId == null || _ad == null) return false;
    final user = _ad!['user'];
    if (user is Map) return user['id'] == _accountId;
    return user == _accountId;
  }

  int get _daysLeft {
    final createdAt = _ad?['created_at'];
    if (createdAt == null) return 0;
    final created = DateTime.tryParse(createdAt.toString());
    if (created == null) return 0;
    final expiry = created.add(const Duration(days: 30));
    return expiry.difference(DateTime.now()).inDays;
  }

  bool get _isVehicle {
    try {
      final cat = _ad?['category'] as Map?;
      final parent = cat?['parent'] as Map?;
      final grandparent = parent?['parent'] as Map?;
      return grandparent?['name'] == 'Vehicles';
    } catch (_) {
      return false;
    }
  }

  bool get _isProperty {
    try {
      final cat = _ad?['category'] as Map?;
      final parent = cat?['parent'] as Map?;
      final grandparent = parent?['parent'] as Map?;
      return grandparent?['name'] == 'Property';
    } catch (_) {
      return false;
    }
  }

  bool get _isForSale {
    try {
      final cat = _ad?['category'] as Map?;
      final parent = cat?['parent'] as Map?;
      final grandparent = parent?['parent'] as Map?;
      final name = grandparent?['name'] ?? '';
      return name == 'For Sale' || name == 'Vehicles';
    } catch (_) {
      return false;
    }
  }

  String _location() {
    final area = _ad?['area'] as Map?;
    if (area != null) {
      final city = area['city'] as Map?;
      final province = city?['province'] as Map?;
      return '${province?['name']} / ${city?['name']} / ${area['name']}';
    }
    final city = _ad?['city'] as Map?;
    if (city != null) {
      final province = city['province'] as Map?;
      return '${province?['name']} / ${city['name']}';
    }
    return '';
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) {
      setState(() => _messageError = 'Message is required');
      return;
    }
    if (_phoneController.text.trim().length < 10) {
      setState(() => _messageError = 'Phone number must be 10 digits');
      return;
    }
    setState(() {
      _sendingMessage = true;
      _messageError = '';
    });
    try {
      final api = context.read<ApiService>();
      final user = _ad!['user'] as Map;
      await api.dio.post('/api/v1/mailbox/message/c/', data: {
        'receiver': user['id'],
        'sender': _accountId,
        'message': _messageController.text.trim(),
        'number': _phoneController.text.trim(),
        'origin': 'classifieds',
      });
      setState(() {
        _messageController.clear();
        _phoneController.clear();
        _messageError = 'Message sent successfully';
      });
    } catch (_) {
      setState(() => _messageError = 'Could not send message. Try again.');
    }
    setState(() => _sendingMessage = false);
  }

  void _calculateFinance() {
    final price = double.tryParse(_ad?['price']?.toString() ?? '0') ?? 0;
    final deposit = double.tryParse(_depositController.text) ?? 0;
    final residual = double.tryParse(_residualController.text) ?? 0;
    final interest = double.tryParse(_interestController.text) ?? 0;
    if (_period == 0) {
      _showSnack('Please select a payback period');
      return;
    }
    final principal = price - deposit - residual;
    final monthlyRate = interest / 100 / 12;
    double installment;
    if (monthlyRate == 0) {
      installment = principal / _period;
    } else {
      final x = pow(1 + monthlyRate, _period);
      installment = (principal * x * monthlyRate) / (x - 1);
    }
    setState(() {
      _financeResults = {
        'installment': installment,
        'loan_amount': principal,
        'total_interest': installment * _period - principal,
        'total_payment': installment * _period + residual,
      };
    });
  }

  double pow(double base, int exp) {
    double result = 1;
    for (int i = 0; i < exp; i++) {
      result *= base;
    }
    return result;
  }

  Future<void> _deleteAd() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Ad'),
        content: const Text('Are you sure you want to delete this ad?'),
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
      await api.dio.delete('/api/v1/classifieds/${widget.adId}/d/');
      if (mounted) Navigator.pop(context);
    } catch (_) {
      _showSnack('Could not delete ad. Try again.');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _openLightbox() {
    final images = _ad?['images'] as List? ?? [];
    if (images.isEmpty) return;
    final startIndex = images.indexWhere((i) => i['id'] == _mainImage?['id']);
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => _LightboxDialog(
          images: images, initialIndex: startIndex >= 0 ? startIndex : 0),
    );
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
          _ad?['title'] ?? 'Ad',
          style: const TextStyle(color: Colors.white, fontSize: 15),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_ad != null) ...[
            if (_isOwner) ...[
              TextButton(
                onPressed: () {}, // TODO: edit ad
                child: const Text('Edit',
                    style: TextStyle(color: Color(0xFFf8b324), fontSize: 12)),
              ),
              TextButton(
                onPressed: _deleteAd,
                child: const Text('Delete',
                    style: TextStyle(color: Color(0xFFbc2023), fontSize: 12)),
              ),
            ] else
              TextButton(
                onPressed: () {}, // TODO: report
                child: const Text('Report',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ),
          ],
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF094a25)))
          : _ad == null
              ? const Center(child: Text('Ad not found'))
              : RefreshIndicator(
                  onRefresh: _loadAd,
                  color: const Color(0xFF094a25),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _priceBar(),
                        _imageSection(),
                        _adDetails(),
                        if (_isVehicle) _vehicleDetails(),
                        if (_isProperty) _propertyDetails(),
                        _sellerPanel(),
                        if (_hasMembership && !_isOwner) _messagePanel(),
                        if (_isVehicle || _isProperty) _financeCalculator(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
    );
  }

  // ─── Price bar ────────────────────────────────────────────────────────────

  Widget _priceBar() {
    final price = _ad?['price'];
    final terms = _ad?['terms'] ?? '';
    final expired = _ad?['expired'] == true;

    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (price != null) ...[
            Text('R$price',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Text('($terms)',
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
          const Spacer(),
          if (expired)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFbc2023),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('Expired',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            )
          else if (_daysLeft > 0)
            Text('${_daysLeft + 1} days left',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          if (terms == 'negotiable' && !_isOwner) ...[
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: () {}, // TODO: make offer modal
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF094a25),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Make Offer',
                  style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Image section ────────────────────────────────────────────────────────

  Widget _imageSection() {
    final images = _ad?['images'] as List? ?? [];
    final smallImages =
        images.where((i) => i['id'] != _mainImage?['id']).toList();

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Main image
          if (_mainImage != null)
            GestureDetector(
              onTap: _openLightbox,
              child: CachedNetworkImage(
                imageUrl: _mainImage!['image'] ?? '',
                height: 260,
                width: double.infinity,
                fit: BoxFit.contain,
                errorWidget: (_, __, ___) => Container(
                    height: 260,
                    color: Colors.grey.shade100,
                    child: const Icon(Icons.sell_outlined,
                        size: 60, color: Colors.black26)),
              ),
            ),
          // Thumbnails
          if (smallImages.isNotEmpty)
            SizedBox(
              height: 70,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                itemCount: smallImages.length,
                itemBuilder: (ctx, i) => GestureDetector(
                  onTap: () => setState(() => _mainImage = smallImages[i]),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: CachedNetworkImage(
                        imageUrl: smallImages[i]['image'] ?? '',
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                            width: 60, height: 60, color: Colors.grey.shade200),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Ad details ───────────────────────────────────────────────────────────

  Widget _adDetails() {
    final location = _location();
    final adbody = _ad?['adbody'] ?? '';
    final isNew = _ad?['is_new'] == true;
    final category = _ad?['category'] as Map?;
    final categoryName = category?['name'] ?? '';
    final parentName = (category?['parent'] as Map?)?['name'] ?? '';

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (categoryName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                parentName.isNotEmpty
                    ? '$parentName / $categoryName'
                    : categoryName,
                style: const TextStyle(fontSize: 12, color: Colors.black45),
              ),
            ),
          if (location.isNotEmpty) ...[
            _detailRow('Location', location),
            const SizedBox(height: 8),
          ],
          if (_isForSale) ...[
            _detailRow('Condition', isNew ? 'New' : 'Used'),
            const SizedBox(height: 8),
          ],
          const Text('Ad Detail',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF094a25))),
          const SizedBox(height: 6),
          Text(adbody,
              style: const TextStyle(
                  fontSize: 13, color: Colors.black87, height: 1.5)),
        ],
      ),
    );
  }

  // ─── Vehicle details ──────────────────────────────────────────────────────

  Widget _vehicleDetails() {
    final makeModel = _ad?['make_model'] as Map?;
    final make = (makeModel?['parent'] as Map?)?['name'];
    final model = makeModel?['name'];
    final fields = <(String, String?)>[
      ('Make', make),
      ('Model', model),
      ('Body Type', _ad?['body_type']),
      ('Color', _ad?['color']),
      ('Transmission', _ad?['transmission']),
      ('Drive Train', _ad?['drive_type']),
      (
        'Kilometers',
        _ad?['kilometers'] != null ? '${_ad!['kilometers']} km' : null
      ),
      ('Fuel Type', _ad?['fuel_type']),
    ].where((f) => f.$2 != null && f.$2!.isNotEmpty).toList();

    final extras = _ad?['car_extras'] as List? ?? [];

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Vehicle Details'),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: fields
                  .map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _detailRow(f.$1, f.$2!),
                      ))
                  .toList(),
            ),
          ),
          if (extras.isNotEmpty) ...[
            _sectionHeader('Car Extras'),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: extras
                    .map((e) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF094a25).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(e.toString(),
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF094a25))),
                        ))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Property details ─────────────────────────────────────────────────────

  Widget _propertyDetails() {
    final propType = _ad?['property_type'];
    final fields = <(String, String?)>[
      (
        'Property Type',
        propType != null ? _propertyTypes[propType] ?? propType : null
      ),
      ('Size', _ad?['prop_size'] != null ? '${_ad!['prop_size']} m²' : null),
      ('Bedrooms', _ad?['bedrooms']?.toString()),
      ('Bathrooms', _ad?['bathrooms']?.toString()),
      ('Parking', _ad?['parking']?.toString()),
    ].where((f) => f.$2 != null && f.$2!.isNotEmpty).toList();

    final extras = _ad?['prop_extras'] as List? ?? [];

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Property Details'),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: fields
                  .map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _detailRow(f.$1, f.$2!),
                      ))
                  .toList(),
            ),
          ),
          if (extras.isNotEmpty) ...[
            _sectionHeader('Property Extras'),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: extras
                    .map((e) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF094a25).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(e.toString(),
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF094a25))),
                        ))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Seller panel ─────────────────────────────────────────────────────────

  Widget _sellerPanel() {
    final user = _ad?['user'] as Map?;
    final profile = user?['profile'] as Map?;
    final firstName = profile?['first_name'] ?? '';
    final lastName = profile?['last_name'] ?? '';
    final seller = _ad?['seller'];
    final phone = _ad?['phone'];

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Seller Details'),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (firstName.isNotEmpty || lastName.isNotEmpty)
                  _detailRow('Posted by', '$firstName $lastName'.trim()),
                if (seller != null) ...[
                  const SizedBox(height: 8),
                  _detailRow('Seller', seller.toString()),
                ],
                if (phone != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Phone: ',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54)),
                      _showPhone
                          ? Text(phone.toString(),
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black87))
                          : GestureDetector(
                              onTap: () => setState(() => _showPhone = true),
                              child: const Text('Tap to reveal',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF094a25),
                                      decoration: TextDecoration.underline)),
                            ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Message panel ────────────────────────────────────────────────────────

  Widget _messagePanel() {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Send Seller A Message'),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Message',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF094a25))),
                const SizedBox(height: 6),
                TextField(
                  controller: _messageController,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: InputDecoration(
                    hintText: 'Your message',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF094a25)),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 10),
                const Text('Your Phone Number',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF094a25))),
                const SizedBox(height: 6),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  decoration: InputDecoration(
                    hintText: '10-digit number',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF094a25)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
                if (_messageError.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(_messageError,
                      style: TextStyle(
                          fontSize: 12,
                          color: _messageError.contains('successfully')
                              ? Colors.green
                              : const Color(0xFFbc2023))),
                ],
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed:
                      _daysLeft > 0 && !_sendingMessage ? _sendMessage : null,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF094a25),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12)),
                  child: _sendingMessage
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Send Message',
                          style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Finance calculator ───────────────────────────────────────────────────

  Widget _financeCalculator() {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Calculate Finance'),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _financeField(_depositController, 'Deposit Amount'),
                const SizedBox(height: 10),
                _financeField(_residualController, 'Residual / Balloon'),
                const SizedBox(height: 10),
                _financeField(_interestController, 'Interest Rate (%)'),
                const SizedBox(height: 10),
                const Text('Payback Period',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF094a25))),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black26),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _period == 0 ? null : _period,
                      hint: const Text('Select',
                          style: TextStyle(color: Colors.black45)),
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                            value: 12, child: Text('12 Months (1 Year)')),
                        DropdownMenuItem(
                            value: 24, child: Text('24 Months (2 Years)')),
                        DropdownMenuItem(
                            value: 36, child: Text('36 Months (3 Years)')),
                        DropdownMenuItem(
                            value: 48, child: Text('48 Months (4 Years)')),
                        DropdownMenuItem(
                            value: 60, child: Text('60 Months (5 Years)')),
                        DropdownMenuItem(
                            value: 72, child: Text('72 Months (6 Years)')),
                      ],
                      onChanged: (v) => setState(() => _period = v ?? 0),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: _calculateFinance,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF094a25),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12)),
                  child: const Text('Calculate Payment',
                      style: TextStyle(color: Colors.white)),
                ),
                if (_financeResults != null) ...[
                  const SizedBox(height: 16),
                  _sectionHeader('Finance Results'),
                  const SizedBox(height: 10),
                  _financeResultRow(
                      'Monthly Installment', _financeResults!['installment']!),
                  _financeResultRow(
                      'Loan Amount', _financeResults!['loan_amount']!),
                  _financeResultRow(
                      'Total Interest', _financeResults!['total_interest']!),
                  _financeResultRow(
                      'Total Payment', _financeResults!['total_payment']!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _financeField(TextEditingController controller, String label) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF094a25))),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF094a25)),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ],
      );

  Widget _financeResultRow(String label, double value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 13, color: Colors.black54)),
            Text('R${value.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF094a25))),
          ],
        ),
      );

  // ─── Shared helpers ───────────────────────────────────────────────────────

  Widget _sectionHeader(String title) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: const Color(0xFF094a25),
        child: Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold)),
      );

  Widget _detailRow(String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text('$label:',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 12, color: Colors.black87)),
          ),
        ],
      );
}

// ─── Lightbox ────────────────────────────────────────────────────────────────

class _LightboxDialog extends StatefulWidget {
  final List<dynamic> images;
  final int initialIndex;

  const _LightboxDialog({required this.images, required this.initialIndex});

  @override
  State<_LightboxDialog> createState() => _LightboxDialogState();
}

class _LightboxDialogState extends State<_LightboxDialog> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.images[_index]['image']?.toString() ?? '';
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                errorWidget: (_, __, ___) =>
                    const Icon(Icons.broken_image, color: Colors.white),
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
          if (_index > 0)
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () => setState(() => _index--),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: Colors.black45, shape: BoxShape.circle),
                    child: const Icon(Icons.chevron_left,
                        color: Colors.white, size: 28),
                  ),
                ),
              ),
            ),
          if (_index < widget.images.length - 1)
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () => setState(() => _index++),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: Colors.black45, shape: BoxShape.circle),
                    child: const Icon(Icons.chevron_right,
                        color: Colors.white, size: 28),
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                '${_index + 1} / ${widget.images.length}',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
