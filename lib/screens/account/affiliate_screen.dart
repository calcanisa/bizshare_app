import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';

class AffiliateSection extends StatefulWidget {
  const AffiliateSection({super.key});

  @override
  State<AffiliateSection> createState() => _AffiliateSectionState();
}

class _AffiliateSectionState extends State<AffiliateSection> {
  static const _dark = Color(0xFF1B4748);
  static const _teal = Color(0xFF296968);
  static const _orange = Color(0xFFF48900);

  bool _loading = true;
  bool _loadError = false;
  bool _busy = false;
  bool _accepted = false;
  bool _editingDetails = false;
  Map<String, dynamic> _data = {};

  final _amountCtrl = TextEditingController();
  final _walletAmountCtrl = TextEditingController();
  final _holderCtrl = TextEditingController();
  final _bankCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  final _branchCtrl = TextEditingController();
  final _idCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _walletAmountCtrl.dispose();
    _holderCtrl.dispose();
    _bankCtrl.dispose();
    _accountCtrl.dispose();
    _branchCtrl.dispose();
    _idCtrl.dispose();
    super.dispose();
  }

  double _num(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  Map<String, dynamic> get _rules =>
      _data['rules'] is Map ? Map<String, dynamic>.from(_data['rules']) : {};

  Map<String, dynamic> get _rates => _data['commission_rates'] is Map
      ? Map<String, dynamic>.from(_data['commission_rates'])
      : {};

  bool get _canWithdraw =>
      _num(_data['available']) >= _num(_rules['min_balance']);

  String _errorText(Object e, String fallback) {
    if (e is DioException) {
      final d = e.response?.data;
      if (d is Map) {
        if (d['error'] is String) return d['error'];
        if (d['detail'] is String) return d['detail'];
        if (d.values.isNotEmpty) {
          final first = d.values.first;
          if (first is List && first.isNotEmpty && first.first is String) {
            return first.first;
          }
        }
      }
    }
    return fallback;
  }

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return '';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final local = date.toLocal();
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }

  bool _isPending(Map c) {
    final at = DateTime.tryParse(c['available_at']?.toString() ?? '');
    return at != null && at.isAfter(DateTime.now());
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? _orange : _dark,
    ));
  }

  Future<bool> _confirm(String msg) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(msg),
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
    return result == true;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = false;
    });
    try {
      final api = context.read<ApiService>();
      final res = await api.dio.get('/api/v1/users/affiliate/');
      if (!mounted) return;
      setState(() => _data =
          res.data is Map ? Map<String, dynamic>.from(res.data as Map) : {});
    } catch (_) {
      if (mounted) setState(() => _loadError = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(Future<void> Function(ApiService api) action,
      String success, String fallback) async {
    setState(() => _busy = true);
    try {
      await action(context.read<ApiService>());
      _snack(success);
      await _load();
    } catch (e) {
      _snack(_errorText(e, fallback), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    if (!_accepted) return;
    await _run(
      (api) => api.dio
          .post('/api/v1/users/affiliate/join/', data: {'accept_terms': true}),
      'Welcome to the BizShare Affiliate Program.',
      'Could not join right now. Try again.',
    );
  }

  Future<void> _leave() async {
    final ok = await _confirm(
        'Leave the affiliate program? You will stop earning commission on future payments.');
    if (!ok) return;
    await _run(
      (api) => api.dio.post('/api/v1/users/affiliate/leave/'),
      'You have left the affiliate program.',
      'Could not leave right now. Try again.',
    );
  }

  Future<void> _saveDetails() async {
    final details = {
      'account_holder': _holderCtrl.text.trim(),
      'bank_name': _bankCtrl.text.trim(),
      'account_number': _accountCtrl.text.trim(),
      'branch_code': _branchCtrl.text.trim(),
      'id_number': _idCtrl.text.trim(),
    };
    await _run(
      (api) async {
        await api.dio.put('/api/v1/users/affiliate/payout-details/',
            data: details);
        _holderCtrl.clear();
        _bankCtrl.clear();
        _accountCtrl.clear();
        _branchCtrl.clear();
        _idCtrl.clear();
        if (mounted) setState(() => _editingDetails = false);
      },
      'Payout details saved.',
      'Could not save your details. Check them and try again.',
    );
  }

  double? _parseAmount(TextEditingController ctrl) {
    final value = double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
    if (value == null || value <= 0) {
      _snack('Enter a valid amount.', error: true);
      return null;
    }
    return value;
  }

  Future<void> _withdraw() async {
    final value = _parseAmount(_amountCtrl);
    if (value == null) return;
    final ok =
        await _confirm('Request a withdrawal of R${value.toStringAsFixed(2)}?');
    if (!ok) return;
    await _run(
      (api) async {
        await api.dio.post('/api/v1/users/withdraw/',
            data: {'amount': value.toStringAsFixed(2)});
        _amountCtrl.clear();
      },
      'Withdrawal requested. We will pay it into your bank account.',
      'Could not request the withdrawal. Try again.',
    );
  }

  Future<void> _moveToWallet() async {
    final value = _parseAmount(_walletAmountCtrl);
    if (value == null) return;
    final ok = await _confirm(
        'Move R${value.toStringAsFixed(2)} to your BizShare Wallet? This cannot be withdrawn to a bank account afterwards.');
    if (!ok) return;
    await _run(
      (api) async {
        await api.dio.post('/api/v1/users/affiliate/to-wallet/',
            data: {'amount': value.toStringAsFixed(2)});
        _walletAmountCtrl.clear();
      },
      'R${value.toStringAsFixed(2)} moved to your wallet.',
      'Could not move your earnings. Try again.',
    );
  }

  Future<void> _copy(dynamic text) async {
    final value = text?.toString() ?? '';
    if (value.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value));
    _snack('Copied.');
  }

  Future<void> _openTerms() async {
    await launchUrl(Uri.parse('https://bizshare.co.za/terms/'),
        mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator(color: _dark)),
      );
    }
    if (_loadError) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text('Could not load your affiliate details.',
                style: TextStyle(color: _orange, fontSize: 14)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(backgroundColor: _dark),
              child: const Text('Try again',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: _data['is_affiliate'] == true ? _member() : _joinView(),
    );
  }

  Widget _title(String text) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10, top: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: const Color(0xFFE8F3F2),
            borderRadius: BorderRadius.circular(4)),
        child: Text(text,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: _dark)),
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            SizedBox(
                width: 170,
                child: Text(label,
                    style: const TextStyle(fontSize: 13, color: _teal))),
            Expanded(
                child: Text(value,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87))),
          ],
        ),
      );

  Widget _button(String label, VoidCallback? onPressed, {Color color = _dark}) =>
      ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: Colors.grey.shade300,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white)),
      );

  Widget _field(TextEditingController ctrl, String hint,
          {TextInputType type = TextInputType.text, int? maxLength}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: ctrl,
          keyboardType: type,
          maxLength: maxLength,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            hintText: hint,
            counterText: '',
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      );

  Widget _joinView() {
    final rules = _rules;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title('BizShare Affiliate Program'),
        const Text(
            'Join for free and earn a commission every time a business you refer pays for a BizShare membership, including every renewal.',
            style: TextStyle(fontSize: 13, height: 1.5)),
        const SizedBox(height: 12),
        _row('Silver monthly:', 'R${_rates['silverM'] ?? ''} per payment'),
        _row('Gold monthly:', 'R${_rates['goldM'] ?? ''} per payment'),
        _row('Silver yearly:', 'R${_rates['silverY'] ?? ''} per payment'),
        _row('Gold yearly:', 'R${_rates['goldY'] ?? ''} per payment'),
        const SizedBox(height: 8),
        Text(
            'Commission is pending for ${rules['hold_days'] ?? ''} days, then available. You can withdraw once you have R${rules['min_balance'] ?? ''} available, up to R${rules['max_per_withdrawal'] ?? ''} at a time and R${rules['max_per_month'] ?? ''} per month.',
            style: const TextStyle(fontSize: 13, height: 1.5)),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: _accepted,
              activeColor: _dark,
              onChanged: (v) => setState(() => _accepted = v ?? false),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Wrap(
                  children: [
                    const Text('I am 18 or older and I accept the ',
                        style: TextStyle(fontSize: 13)),
                    GestureDetector(
                      onTap: _openTerms,
                      child: const Text('affiliate terms',
                          style: TextStyle(
                              fontSize: 13,
                              color: _teal,
                              decoration: TextDecoration.underline)),
                    ),
                    const Text('.', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _button(_busy ? 'Joining...' : 'Join Now',
            !_accepted || _busy ? null : _join),
      ],
    );
  }

  Widget _member() {
    final payout = _data['payout_details'] is Map
        ? Map<String, dynamic>.from(_data['payout_details'])
        : null;
    final commissions = _data['commissions'] is List
        ? (_data['commissions'] as List).whereType<Map>().toList()
        : <Map>[];
    final withdrawals = _data['withdrawals'] is List
        ? (_data['withdrawals'] as List).whereType<Map>().toList()
        : <Map>[];
    final showDetailsForm = payout == null || _editingDetails;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title('BizShare Affiliate'),
        const Text(
            'When you promote BizShare, always say that you are a BizShare affiliate and that you earn a commission if someone signs up or pays through your link or code.',
            style: TextStyle(fontSize: 13, height: 1.5)),
        _title('Your Link and Code'),
        Row(
          children: [
            Expanded(
              child: SelectableText(_data['link']?.toString() ?? '',
                  style: const TextStyle(fontSize: 13)),
            ),
            const SizedBox(width: 8),
            _button('Copy Link', () => _copy(_data['link']), color: _teal),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Text('Code: ',
                style: TextStyle(fontSize: 13, color: _teal)),
            Expanded(
              child: SelectableText(_data['code']?.toString() ?? '',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold)),
            ),
            _button('Copy Code', () => _copy(_data['code']), color: _teal),
          ],
        ),
        _title('Earnings'),
        _row('Available:', 'R${_data['available'] ?? '0.00'}'),
        _row('Pending:', 'R${_data['pending'] ?? '0.00'}'),
        _row('Earned in total:', 'R${_data['earned_total'] ?? '0.00'}'),
        _row('Withdrawn this month:',
            'R${_data['withdrawn_this_month'] ?? '0.00'}'),
        _row('Businesses referred:',
            '${_data['referrals'] ?? 0} (${_data['paying_referrals'] ?? 0} paying)'),
        _title('Move to Wallet'),
        const Text(
            'Move any amount of your available earnings into your BizShare Wallet instantly, to spend on features and leads. Earnings moved to your wallet cannot be withdrawn to a bank account.',
            style: TextStyle(fontSize: 13, height: 1.5)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _field(_walletAmountCtrl, 'Amount (R)',
                  type: const TextInputType.numberWithOptions(decimal: true)),
            ),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _button(
                  'Move to Wallet',
                  _busy || _num(_data['available']) <= 0
                      ? null
                      : _moveToWallet,
                  color: _teal),
            ),
          ],
        ),
        _title('Withdraw to Bank'),
        if (showDetailsForm) ...[
          const Text(
              'Add the South African bank account in your own name that we should pay into.',
              style: TextStyle(fontSize: 13, height: 1.5)),
          const SizedBox(height: 10),
          _field(_holderCtrl, 'Account holder name'),
          _field(_bankCtrl, 'Bank name'),
          _field(_accountCtrl, 'Account number', type: TextInputType.number),
          _field(_branchCtrl, 'Branch code', type: TextInputType.number),
          _field(_idCtrl, 'SA ID number',
              type: TextInputType.number, maxLength: 13),
          Row(
            children: [
              _button('Save Details', _busy ? null : _saveDetails),
              if (payout != null) ...[
                const SizedBox(width: 10),
                _button('Cancel', () => setState(() => _editingDetails = false),
                    color: _orange),
              ],
            ],
          ),
        ] else ...[
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                  'Paying to ${payout['account_holder'] ?? ''}, ${payout['bank_name'] ?? ''} ${payout['account_number'] ?? ''} ',
                  style: const TextStyle(fontSize: 13)),
              GestureDetector(
                onTap: () => setState(() => _editingDetails = true),
                child: const Text('Change',
                    style: TextStyle(
                        fontSize: 13,
                        color: _teal,
                        decoration: TextDecoration.underline)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _field(_amountCtrl, 'Amount (R)',
                    type:
                        const TextInputType.numberWithOptions(decimal: true)),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _button('Request Withdrawal',
                    _busy || !_canWithdraw ? null : _withdraw),
              ),
            ],
          ),
          if (!_canWithdraw)
            Text(
                'You can withdraw once you have at least R${_rules['min_balance'] ?? ''} available.',
                style: const TextStyle(fontSize: 12, color: _teal)),
        ],
        _title('Recent Commission'),
        if (commissions.isEmpty)
          const Text('No commission yet. Share your link to get started.',
              style: TextStyle(fontSize: 13, color: _teal))
        else
          ...commissions.map((c) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                        flex: 4,
                        child: Text(_formatDate(c['created_at']),
                            style: const TextStyle(fontSize: 13))),
                    Expanded(
                        flex: 3,
                        child: Text(c['interval']?.toString() ?? '',
                            style: const TextStyle(fontSize: 13))),
                    Expanded(
                      flex: 3,
                      child: Text(
                          'R${c['amount'] ?? ''}${_isPending(c) ? ' pending' : ''}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              )),
        _title('Withdrawals and Transfers'),
        if (withdrawals.isEmpty)
          const Text('No withdrawals yet.',
              style: TextStyle(fontSize: 13, color: _teal))
        else
          ...withdrawals.map((w) {
            final status = w['destination'] == 'wallet'
                ? 'To wallet'
                : w['status'] == 'paid'
                    ? 'Paid to bank'
                    : w['status'] == 'rejected'
                        ? 'Rejected'
                        : 'Pending';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                      flex: 4,
                      child: Text(_formatDate(w['created_at']),
                          style: const TextStyle(fontSize: 13))),
                  Expanded(
                      flex: 3,
                      child:
                          Text(status, style: const TextStyle(fontSize: 13))),
                  Expanded(
                      flex: 3,
                      child: Text('R${w['amount'] ?? ''}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 13))),
                ],
              ),
            );
          }),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerRight,
          child: _button(
              'Leave Affiliate Program', _busy ? null : _leave,
              color: _orange),
        ),
      ],
    );
  }
}
