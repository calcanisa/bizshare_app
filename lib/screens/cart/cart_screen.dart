import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/cart_provider.dart';
import '../../services/api_service.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  static const double _vatRate = 0.15;

  bool _accepted = false;
  bool _paying = false;
  bool _walletPaying = false;
  bool _validatingCode = false;
  bool _showDiscount = false;
  bool _showCodeInfo = false;
  final double _discountPercentage = 2.0;

  double _walletBalance = 0.0;
  bool _loadingWallet = false;

  final _refCodeController = TextEditingController();
  int? _accountId;

  @override
  void initState() {
    super.initState();
    _loadAccount();
    _loadWallet();
  }

  @override
  void dispose() {
    _refCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadAccount() async {
    try {
      final api = context.read<ApiService>();
      final res = await api.dio.get('/api/v1/users/current/');
      setState(() => _accountId = res.data['id']);
    } catch (_) {}
  }

  Future<void> _loadWallet() async {
    setState(() => _loadingWallet = true);
    try {
      final api = context.read<ApiService>();
      final res = await api.dio.get('/api/v1/wallet/');
      if (res.data['has_wallet'] == true) {
        setState(() => _walletBalance =
            double.tryParse(res.data['balance'].toString()) ?? 0.0);
      }
    } catch (_) {}
    setState(() => _loadingWallet = false);
  }

  double _vatAmount(double price) => price * _vatRate;

  double get _discountAmount {
    final cart = context.read<CartProvider>();
    return cart.subtotal * _discountPercentage / 100;
  }

  double get _cartTotal {
    final cart = context.read<CartProvider>();
    return _showDiscount ? cart.subtotal - _discountAmount : cart.subtotal;
  }

  bool _isCardOnlyCart(CartProvider cart) => cart.items
      .any((i) => ['wallet_topup', 'membership', 'sesha'].contains(i.type));

  bool get _walletHasFunds => _walletBalance >= _cartTotal;

  Future<void> _validateCode(String code) async {
    if (code.trim().isEmpty) return;
    setState(() => _validatingCode = true);
    try {
      final api = context.read<ApiService>();
      final res = await api.dio
          .post('/api/v1/users/passive/c/', data: {'code': code.trim()});
      if (res.data['exists'] == true) {
        setState(() => _showDiscount = true);
        _showSnack('Code is valid — discount applied!');
      } else {
        setState(() {
          _showDiscount = false;
          _refCodeController.clear();
        });
        _showSnack('Code is not valid.');
      }
    } catch (_) {
      setState(() {
        _showDiscount = false;
        _refCodeController.clear();
      });
    }
    setState(() => _validatingCode = false);
  }

  Future<void> _payWithWallet() async {
    final cart = context.read<CartProvider>();
    if (cart.isEmpty || !_accepted) return;
    if (!_walletHasFunds) {
      _showSnack('Insufficient wallet balance. Please fund your wallet.');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pay with Wallet'),
        content:
            Text('Pay R${_cartTotal.toStringAsFixed(2)} from your wallet?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _walletPaying = true);
    try {
      final api = context.read<ApiService>();
      final validTypes = ['feature', 'funding', 'lead', 'verification'];
      final items = cart.items
          .where((i) => validTypes.contains(i.type))
          .map((i) => i.toJson())
          .toList();

      await api.dio.post('/api/v1/products/cart/wallet/', data: {
        'refer_code': _refCodeController.text.trim(),
        'total': _cartTotal,
        'items': items,
      });

      cart.clear();
      _showSnack('Payment successful! Your wallet has been debited.');
      await _loadWallet();
    } catch (e) {
      final response = (e as dynamic)?.response;
      if (response?.data?['error'] == 'insufficient_funds') {
        _showSnack('Insufficient wallet balance. Please fund your wallet.');
      } else {
        _showSnack('Payment failed. Please try again or pay with card.');
      }
    }
    setState(() => _walletPaying = false);
  }

  Future<void> _makePayment() async {
    final cart = context.read<CartProvider>();
    if (cart.isEmpty || !_accepted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Payment'),
        content: const Text(
            'You will be redirected to the payment provider. Please do not close the app until payment is confirmed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Pay Now')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _paying = true);
    try {
      final api = context.read<ApiService>();
      final validTypes = [
        'sesha',
        'membership',
        'feature',
        'funding',
        'lead',
        'verification',
        'wallet_topup'
      ];
      final items = cart.items
          .where((i) => validTypes.contains(i.type))
          .map((i) => i.toJson())
          .toList();
      final total = _cartTotal;

      final response = await api.dio.post('/api/v1/products/cart/c/', data: {
        'refer_code': _refCodeController.text.trim(),
        'items': items,
        'total': total,
      });

      final cartId = response.data['cart_id'];

      final membership = cart.items.firstWhere(
        (i) => i.type == 'membership',
        orElse: () => CartItem(id: '', title: '', price: 0, type: ''),
      );

      final params = <String, String>{
        'merchant_id': '10000100',
        'merchant_key': '46f0cd694581a',
        'return_url': 'https://bizshare.co.za/success',
        'cancel_url': 'https://bizshare.co.za/failure',
        'item_name': 'BizShare Payment',
        'amount': total.toStringAsFixed(2),
        'custom_str1': _accountId?.toString() ?? '',
        'custom_str2': cartId.toString(),
        'm_payment_id': cartId.toString(),
      };

      if (membership.type == 'membership' && membership.memType != null) {
        int? frequency;
        if (membership.memType == 'silverM' || membership.memType == 'goldM')
          frequency = 3;
        else if (membership.memType == 'silverY' ||
            membership.memType == 'goldY') frequency = 6;
        if (frequency != null) {
          final today = DateTime.now().toIso8601String().split('T')[0];
          params['subscription_type'] = '1';
          params['billing_date'] = today;
          params['recurring_amount'] = total.toStringAsFixed(2);
          params['frequency'] = frequency.toString();
          params['cycles'] = '0';
        }
      }

      final queryString = params.entries
          .map((e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      final payFastUrl =
          Uri.parse('https://sandbox.payfast.co.za/eng/process?$queryString');

      if (await canLaunchUrl(payFastUrl)) {
        await launchUrl(payFastUrl, mode: LaunchMode.externalApplication);
      } else {
        _showSnack('Could not open payment page.');
      }
    } catch (_) {
      _showSnack('Could not create cart. Try again.');
    }
    setState(() => _paying = false);
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        final cardOnly = _isCardOnlyCart(cart);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B4748).withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF1B4748).withOpacity(0.2)),
                ),
                child: const Text(
                  'Please do not close the app after making a payment. Wait until the success or failure page appears before navigating away.',
                  style: TextStyle(
                      fontSize: 13, color: Colors.black87, height: 1.5),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Shopping Cart',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B4748))),
              const SizedBox(height: 12),
              if (cart.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05), blurRadius: 4)
                    ],
                  ),
                  child: const Center(
                    child: Text('Your cart is empty.',
                        style: TextStyle(fontSize: 14, color: Colors.black54)),
                  ),
                ),
              if (cart.isNotEmpty) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6)),
                  child: const Row(
                    children: [
                      Expanded(
                          flex: 5,
                          child: Text('Item',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black54))),
                      SizedBox(
                          width: 70,
                          child: Text('VAT (15%)',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black54),
                              textAlign: TextAlign.right)),
                      SizedBox(
                          width: 80,
                          child: Text('Total',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black54),
                              textAlign: TextAlign.right)),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                ...cart.items.map((item) => _cartItemRow(item, cart)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Checkbox(
                      value: _accepted,
                      activeColor: const Color(0xFF1B4748),
                      onChanged: (v) {
                        setState(() => _accepted = v ?? false);
                        if (!(v ?? false))
                          setState(() => _showDiscount = false);
                        if ((v ?? false) &&
                            _refCodeController.text.trim().isNotEmpty) {
                          _validateCode(_refCodeController.text);
                        }
                      },
                    ),
                    const Text('I accept the ', style: TextStyle(fontSize: 13)),
                    GestureDetector(
                      onTap: () async {
                        final uri = Uri.parse('https://bizshare.co.za/terms');
                        if (await canLaunchUrl(uri))
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                      },
                      child: const Text('terms',
                          style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF1B4748),
                              decoration: TextDecoration.underline)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _summaryAndPayment(cart, cardOnly),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _cartItemRow(CartItem item, CartProvider cart) {
    final vat = item.type == 'wallet_topup' ? 0.0 : _vatAmount(item.price);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 3)
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: item.image != null
                ? Image.network(item.image!,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _itemPlaceholder())
                : _itemPlaceholder(),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 5,
            child: Text(
              item.title.length > 60
                  ? '${item.title.substring(0, 60)}...'
                  : item.title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1B4748)),
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(
              item.type == 'wallet_topup' ? '—' : 'R${vat.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12, color: Colors.black45),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(
              'R${item.price.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B4748)),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => cart.removeItem(item.id),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                  color: const Color(0xFFF48900),
                  borderRadius: BorderRadius.circular(4)),
              child: const Center(
                  child: Text('×',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryAndPayment(CartProvider cart, bool cardOnly) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)
            ],
          ),
          child: Column(
            children: [
              _totalRow('Subtotal', 'R${cart.subtotal.toStringAsFixed(2)}'),
              if (_showDiscount) ...[
                const SizedBox(height: 6),
                _totalRow(
                    'Discount (${_discountPercentage.toStringAsFixed(0)}%)',
                    '− R${_discountAmount.toStringAsFixed(2)}',
                    valueColor: const Color(0xFFF8BB25)),
                const Divider(height: 16),
                _totalRow('Total to Pay', 'R${_cartTotal.toStringAsFixed(2)}',
                    bold: true),
              ] else ...[
                const Divider(height: 16),
                _totalRow('Total to Pay', 'R${_cartTotal.toStringAsFixed(2)}',
                    bold: true),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (!cardOnly) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Got a referral code?',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1B4748))),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => setState(() => _showCodeInfo = !_showCodeInfo),
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                          color: Color(0xFF1B4748), shape: BoxShape.circle),
                      child: const Center(
                          child: Text('?',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold))),
                    ),
                  ),
                ],
              ),
              if (_showCodeInfo) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(8)),
                  child: const Text(
                    'This is part of the BizShare Passive affiliate program where members earn a commission and you get a discount. This does not apply to BizShare Passive itself.',
                    style: TextStyle(
                        fontSize: 12, color: Colors.white, height: 1.4),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _refCodeController,
                      decoration: InputDecoration(
                        hintText: 'Enter code for discount',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFF1B4748)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        suffixIcon: _showDiscount
                            ? const Icon(Icons.check_circle,
                                color: Colors.green, size: 18)
                            : null,
                      ),
                      onChanged: (v) {
                        if (v.trim().isEmpty)
                          setState(() => _showDiscount = false);
                      },
                      onSubmitted: (v) {
                        if (_accepted) _validateCode(v);
                      },
                    ),
                  ),
                  if (_validatingCode) ...[
                    const SizedBox(width: 10),
                    const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF1B4748))),
                  ] else if (_refCodeController.text.isNotEmpty &&
                      !_showDiscount) ...[
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _accepted
                          ? () => _validateCode(_refCodeController.text)
                          : null,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B4748),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10)),
                      child: const Text('Apply',
                          style: TextStyle(color: Colors.white, fontSize: 13)),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Wallet Balance',
                        style: TextStyle(fontSize: 12, color: Colors.black54)),
                    const SizedBox(height: 2),
                    _loadingWallet
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Color(0xFF1B4748)))
                        : Text('R${_walletBalance.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: _walletHasFunds
                                  ? const Color(0xFF1B4748)
                                  : const Color(0xFFF48900),
                            )),
                  ],
                ),
                if (!_walletHasFunds)
                  const Text('Insufficient',
                      style: TextStyle(fontSize: 12, color: Color(0xFFF48900))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _accepted &&
                          cart.isNotEmpty &&
                          _walletHasFunds &&
                          !_walletPaying
                      ? _payWithWallet
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF8BB25),
                    foregroundColor: Colors.black87,
                    disabledBackgroundColor: Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _walletPaying
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.black54, strokeWidth: 2))
                      : const Text('Pay with Wallet',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _accepted && cart.isNotEmpty && !_paying
                      ? _makePayment
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B4748),
                    disabledBackgroundColor: Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _paying
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Pay with Card',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
        if (cardOnly) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _accepted && cart.isNotEmpty && !_paying
                  ? _makePayment
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B4748),
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: _paying
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text('Pay R${_cartTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
            ),
          ),
        ],
        if (!_accepted && cart.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('Please accept the terms before paying.',
                style: TextStyle(fontSize: 12, color: Colors.black45),
                textAlign: TextAlign.center),
          ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _totalRow(String label, String value,
      {bool bold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                color: Colors.black54,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        Text(value,
            style: TextStyle(
                fontSize: bold ? 16 : 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                color: valueColor ??
                    (bold ? const Color(0xFF1B4748) : Colors.black87))),
      ],
    );
  }

  Widget _itemPlaceholder() => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFF1B4748).withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(Icons.shopping_cart_outlined,
            color: Color(0xFF1B4748), size: 20),
      );
}
