import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import 'affiliate_screen.dart';
import '../../utils/account_notifiers.dart';
import '../../providers/cart_provider.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  Map<String, dynamic>? _account;
  bool _loading = true;
  Map<String, dynamic> _seshaSettings = {};

  int _tab = 1;
  bool _editing = false;

  bool _chgPass = false;
  bool _chgEmail = false;
  bool _upAcc = false;
  bool _delAcc = false;
  bool _forgot = false;

  bool _correct = false;
  bool _mailSent = false;
  bool _codeAccepted = false;
  bool _submitting = false;

  int _memTab = 1;
  String _memType = '';
  Map<String, dynamic>? _pricing;
  String _reason = '';

  List<dynamic> _orders = [];
  bool _loadingOrders = false;

  // Wallet state
  double _walletBalance = 0.0;
  bool _loadingWallet = false;
  List<dynamic> _transactions = [];
  bool _loadingTx = false;
  String? _txNextPage;
  String _txType = '';
  String _txDirection = '';

  // Fund wallet
  String _fundAmount = '';
  final _fundController = TextEditingController();
  bool _showFundBreakdown = false;

  final _passwordController = TextEditingController();
  final _newEmailController = TextEditingController();
  final _confirmEmailController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();
  final _otherReasonController = TextEditingController();

  final List<TextEditingController> _codeControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _codeFocusNodes = List.generate(6, (_) => FocusNode());

  bool _showPass = false;
  bool _showNewPass = false;
  bool _showConfirmPass = false;

  static const double _minDeposit = 50.0;
  static const double _feeRate = 0.04;

  bool get _affiliatesEnabled => _seshaSettings['passive'] == true;

  String get _membershipLabel {
    final type = _account?['membership']?['mem_type'];
    if (type == null) return 'Bronze';
    if (type.contains('silver')) return 'Silver';
    if (type.contains('gold')) return 'Gold';
    return 'Bronze';
  }

  String get _buttonLabel {
    const ranks = {
      'bronze': 1,
      'silverM': 2,
      'silverY': 2,
      'goldM': 3,
      'goldY': 3
    };
    final currentType = _account?['membership']?['mem_type'];
    final currentRank = ranks[currentType] ?? 0;
    final selectedRank = ranks[_memType] ?? 0;
    if (selectedRank == 0) return 'Select';
    if (selectedRank > currentRank) return 'Upgrade';
    if (selectedRank < currentRank) return 'Downgrade';
    return 'Change';
  }

  int get _passStrength {
    final p = _newPassController.text;
    int s = 0;
    if (p.length >= 8) s++;
    if (RegExp(r'[a-z]').hasMatch(p)) s++;
    if (RegExp(r'[A-Z]').hasMatch(p)) s++;
    if (RegExp(r'[0-9]').hasMatch(p)) s++;
    if (RegExp(r'[^a-zA-Z0-9]').hasMatch(p)) s++;
    return s;
  }

  Color get _passStrengthColor {
    if (_passStrength <= 1) return Colors.red;
    if (_passStrength <= 3) return Colors.orange;
    return Colors.green;
  }

  Map<String, double>? get _breakdown {
    final val = double.tryParse(_fundAmount);
    if (val == null || val < _minDeposit) return null;
    final fee = (val * _feeRate);
    return {
      'gross': val,
      'fee': double.parse(fee.toStringAsFixed(2)),
      'net': double.parse((val - fee).toStringAsFixed(2)),
    };
  }

  @override
  void initState() {
    super.initState();
    _loadSeshaSettings();
    _loadPricing();
    _loadAccount();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (accountEditUpgradeNotifier.value) {
        accountEditUpgradeNotifier.value = false;
        setState(() {
          _editing = true;
          _upAcc = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _newEmailController.dispose();
    _confirmEmailController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    _fundController.dispose();
    _otherReasonController.dispose();
    for (final c in _codeControllers) c.dispose();
    for (final f in _codeFocusNodes) f.dispose();
    super.dispose();
  }

  Future<void> _loadSeshaSettings() async {
    try {
      final api = context.read<ApiService>();
      final res = await api.dio.get('/api/v1/dobiz/settings/');
      if (mounted)
        setState(() => _seshaSettings = res.data as Map<String, dynamic>);
    } catch (_) {}
  }

  Future<void> _loadPricing() async {
    try {
      final api = context.read<ApiService>();
      final res = await api.dio.get('/api/v1/pricing/');
      if (mounted && res.data is Map) {
        setState(() => _pricing = Map<String, dynamic>.from(res.data as Map));
      }
    } catch (_) {}
  }

  double? _price(String key) {
    final v = _pricing?[key];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '');
  }

  String _rand(String key) {
    final v = _price(key);
    if (v == null) return '';
    return v == v.roundToDouble()
        ? 'R${v.toStringAsFixed(0)}'
        : 'R${v.toStringAsFixed(2)}';
  }

  String get _yearlyNote {
    final free = _pricing?['yearly_months_free'];
    final n = free is num ? free.toInt() : int.tryParse(free?.toString() ?? '');
    if (n == null || n <= 0) return '';
    return ' ($n month${n == 1 ? '' : 's'} free)';
  }

  Future<void> _loadAccount() async {
    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      final res = await api.dio.get('/api/v1/users/current/');
      setState(() => _account = res.data);
    } catch (_) {
      _showSnack('Could not load account. Try again.');
    }
    setState(() => _loading = false);
  }

  Future<void> _loadWallet() async {
    if (_loadingWallet) return;
    setState(() => _loadingWallet = true);
    try {
      final api = context.read<ApiService>();
      final res = await api.dio.get('/api/v1/wallet/');
      final balance = res.data['balance'];
      setState(
          () => _walletBalance = double.tryParse(balance.toString()) ?? 0.0);
    } catch (_) {
      _showSnack('Could not load wallet. Try again.');
    }
    setState(() => _loadingWallet = false);
  }

  Future<void> _loadTransactions({bool reset = false}) async {
    if (_loadingTx) return;
    if (reset) {
      setState(() {
        _transactions = [];
        _txNextPage = null;
      });
    }
    setState(() => _loadingTx = true);
    try {
      final api = context.read<ApiService>();
      final params = <String, dynamic>{};
      if (_txType.isNotEmpty) params['transaction_type'] = _txType;
      if (_txDirection.isNotEmpty) params['direction'] = _txDirection;
      final res = await api.dio
          .get('/api/v1/wallet/transactions/', queryParameters: params);
      final data = res.data;
      final results = data is List ? data : (data['results'] as List? ?? []);
      setState(() {
        _transactions = reset ? results : [..._transactions, ...results];
        _txNextPage = data is Map ? data['next'] : null;
      });
    } catch (_) {
      _showSnack('Could not load transactions. Try again.');
    }
    setState(() => _loadingTx = false);
  }

  Future<void> _loadMoreTransactions() async {
    if (_txNextPage == null || _loadingTx) return;
    setState(() => _loadingTx = true);
    try {
      final api = context.read<ApiService>();
      final res = await api.dio.get(_txNextPage!);
      final data = res.data;
      final results = data is List ? data : (data['results'] as List? ?? []);
      setState(() {
        _transactions = [..._transactions, ...results];
        _txNextPage = data is Map ? data['next'] : null;
      });
    } catch (_) {
      _showSnack('Could not load more transactions. Try again.');
    }
    setState(() => _loadingTx = false);
  }

  Future<void> _loadOrders() async {
    if (_orders.isNotEmpty) return;
    setState(() => _loadingOrders = true);
    try {
      final api = context.read<ApiService>();
      final res = await api.dio.get('/api/v1/products/orders/current/');
      final data = res.data;
      setState(() => _orders = data is List ? data : (data['results'] ?? []));
    } catch (_) {
      _showSnack('Could not load orders. Try again.');
    }
    setState(() => _loadingOrders = false);
  }

  Future<void> _checkPassword() async {
    if (_passwordController.text.isEmpty) {
      _showSnack('Enter your current password');
      return;
    }
    setState(() => _submitting = true);
    try {
      final api = context.read<ApiService>();
      await api.dio.post('/api/v1/users/c/p/',
          data: {'password': _passwordController.text});
      setState(() => _correct = true);
    } catch (_) {
      _showSnack('Incorrect password. Try again.');
    }
    setState(() => _submitting = false);
  }

  Future<void> _requestCode() async {
    setState(() => _submitting = true);
    try {
      final api = context.read<ApiService>();
      if (_chgEmail) {
        if (_newEmailController.text.isEmpty ||
            _confirmEmailController.text.isEmpty) {
          _showSnack('Enter and confirm your new email');
          setState(() => _submitting = false);
          return;
        }
        if (_newEmailController.text != _confirmEmailController.text) {
          _showSnack('Emails do not match');
          setState(() => _submitting = false);
          return;
        }
        await api.dio.post('/api/v1/users/request/email/', data: {
          'email': _newEmailController.text,
          'confirm_email': _confirmEmailController.text,
        });
      } else {
        await api.dio.post('/api/v1/users/request/');
      }
      setState(() => _mailSent = true);
    } catch (_) {
      _showSnack('Could not send code. Try again.');
    }
    setState(() => _submitting = false);
  }

  Future<void> _requestForgotPassword() async {
    setState(() => _submitting = true);
    try {
      final api = context.read<ApiService>();
      await api.dio.post('/api/v1/users/fp/');
      setState(() => _mailSent = true);
      _showSnack('Reset code sent to your email');
    } catch (_) {
      _showSnack('Could not send reset email. Try again.');
    }
    setState(() => _submitting = false);
  }

  Future<void> _confirmCode() async {
    final code = _codeControllers.map((c) => c.text).join();
    if (code.length < 6) {
      _showSnack('Enter the full 6-digit code');
      return;
    }
    setState(() => _submitting = true);
    try {
      final api = context.read<ApiService>();
      await api.dio.post('/api/v1/users/confirm/', data: {'code': code});
      setState(() => _codeAccepted = true);
    } catch (_) {
      _showSnack('Invalid code. Please try again.');
    }
    setState(() => _submitting = false);
  }

  Future<void> _savePassword() async {
    if (_newPassController.text != _confirmPassController.text) {
      _showSnack('Passwords do not match');
      return;
    }
    setState(() => _submitting = true);
    try {
      final api = context.read<ApiService>();
      final code = _codeControllers.map((c) => c.text).join();
      await api.dio.post('/api/v1/users/p/c/', data: {
        'password': _newPassController.text,
        'code': code,
      });
      _showSnack('Password changed. You will be logged out.');
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Provider.of<AuthProvider>(context, listen: false).logout();
    } catch (_) {
      _showSnack('Could not change password. Try again.');
    }
    setState(() => _submitting = false);
  }

  Future<void> _saveEmail() async {
    setState(() => _submitting = true);
    try {
      final api = context.read<ApiService>();
      final code = _codeControllers.map((c) => c.text).join();
      await api.dio.post('/api/v1/users/e/c/', data: {
        'email': _newEmailController.text,
        'code': code,
      });
      _showSnack('Email changed. You will be logged out.');
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Provider.of<AuthProvider>(context, listen: false).logout();
    } catch (_) {
      _showSnack('Could not change email. Try again.');
    }
    setState(() => _submitting = false);
  }

  Future<void> _saveMembership() async {
    if (_memType.isEmpty) {
      _showSnack('Select a membership type');
      return;
    }
    final confirm = await _confirm('$_buttonLabel membership?');
    if (!confirm) return;
    setState(() => _submitting = true);
    try {
      final api = context.read<ApiService>();
      if (_memType == 'bronze') {
        await api.dio.delete('/api/v1/products/membership/d/');
        setState(() => _account?['membership'] = null);
        _showSnack('Membership downgraded to Bronze');
        _closeForm();
      } else {
        const plans = {
          'silverM': ('silver_monthly', 'Silver Membership Monthly'),
          'goldM': ('gold_monthly', 'Gold Membership Monthly'),
          'silverY': ('silver_yearly', 'Silver Membership Yearly'),
          'goldY': ('gold_yearly', 'Gold Membership Yearly'),
        };
        final plan = plans[_memType];
        final price = plan == null ? null : _price(plan.$1);
        if (plan == null || price == null) {
          _showSnack(
              'Membership prices are still loading. Try again in a moment.');
        } else {
          final cart = context.read<CartProvider>();
          for (final item in cart.items
              .where((i) => i.type == 'membership')
              .toList()) {
            cart.removeItem(item.id);
          }
          cart.addItem(CartItem(
            id: 'membership_$_memType',
            title: plan.$2,
            price: price,
            type: 'membership',
            memType: _memType,
          ));
          _showSnack(
              'Membership added to your cart. Complete the upgrade in the cart.');
          _closeForm();
          homeSectionNotifier.value = 'Cart';
        }
      }
    } catch (_) {
      _showSnack('Could not update membership. Try again.');
    }
    setState(() => _submitting = false);
  }

  Future<void> _deleteAccount() async {
    if (_reason.isEmpty) {
      _showSnack('Please select a reason');
      return;
    }
    final confirm = await _confirm(
        'Are you sure you want to delete your account? It will be disabled and you will be logged out.');
    if (!confirm) return;
    setState(() => _submitting = true);
    try {
      final api = context.read<ApiService>();
      await api.dio.post('/api/v1/users/d/');
      if (mounted) Provider.of<AuthProvider>(context, listen: false).logout();
    } catch (_) {
      _showSnack('Could not delete account. Try again.');
    }
    if (mounted) setState(() => _submitting = false);
  }

  void _closeForm() {
    setState(() {
      _editing = false;
      _chgPass = false;
      _chgEmail = false;
      _upAcc = false;
      _delAcc = false;
      _forgot = false;
      _correct = false;
      _mailSent = false;
      _codeAccepted = false;
      _memType = '';
      _reason = '';
      _passwordController.clear();
      _newEmailController.clear();
      _confirmEmailController.clear();
      _newPassController.clear();
      _confirmPassController.clear();
      for (final c in _codeControllers) c.clear();
    });
  }

  void _resetActions() {
    setState(() {
      _correct = false;
      _mailSent = false;
      _codeAccepted = false;
      _memType = '';
      _reason = '';
      _passwordController.clear();
      _newEmailController.clear();
      _confirmEmailController.clear();
      _newPassController.clear();
      _confirmPassController.clear();
      for (final c in _codeControllers) c.clear();
    });
  }

  Future<bool> _confirm(String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            content: Text(message),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Confirm')),
            ],
          ),
        ) ==
        true;
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '—';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return '—';
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

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF1B4748)));
    }

    final showAffiliateTab = _affiliatesEnabled;

    return Column(
      children: [
        Container(
          color: const Color(0xFF1B4748),
          child: Row(
            children: [
              _tabBtn(1, 'Account'),
              if (showAffiliateTab) _tabBtn(2, 'Affiliate'),
              _tabBtn(3, 'Wallet'),
              _tabBtn(4, 'Financials'),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _tab == 3
                ? () =>
                    Future.wait([_loadWallet(), _loadTransactions(reset: true)])
                : _loadAccount,
            color: const Color(0xFF1B4748),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: _tab == 1
                  ? _accountTab()
                  : _tab == 2 && showAffiliateTab
                      ? const AffiliateSection()
                      : _tab == 3
                          ? _walletTab()
                          : _financialsTab(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tabBtn(int index, String label) {
    final active = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _tab = index);
          if (index == 3) {
            if (_walletBalance == 0.0) _loadWallet();
            if (_transactions.isEmpty) _loadTransactions(reset: true);
          }
          if (index == 4) _loadOrders();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          color: active ? Colors.white : const Color(0xFF1B4748),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: active ? const Color(0xFF1B4748) : Colors.white60,
                fontSize: 11,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              )),
        ),
      ),
    );
  }

  // ─── Tab 1 — Account ─────────────────────────────────────────────────────

  Widget _accountTab() => _editing ? _editView() : _viewMode();

  Widget _viewMode() {
    final email = _account?['email'] ?? '—';
    final createdAt = _account?['created_at'];
    final updatedAt = _account?['updated_at'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: () => setState(() => _editing = true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF8BB25),
              foregroundColor: Colors.black87,
            ),
            child: const Text('Edit Account'),
          ),
        ),
        const SizedBox(height: 16),
        _detailCard([
          _detailRow('Email', email),
          _detailRow('Joined', _formatDate(createdAt?.toString())),
          _detailRow('Last Update', _formatDate(updatedAt?.toString())),
          _detailRow('Membership', _membershipLabel),
          _detailRow('Wallet Balance', 'R${_walletBalance.toStringAsFixed(2)}'),
        ]),
      ],
    );
  }

  Widget _detailCard(List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)
        ],
      ),
      child: Column(children: rows),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B4748))),
          ),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontSize: 13, color: Colors.black87))),
        ],
      ),
    );
  }

  // ─── Edit View ────────────────────────────────────────────────────────────

  Widget _editView() {
    final anyActive = _chgPass || _chgEmail || _upAcc || _delAcc;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _closeForm,
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Cancel'),
            style:
                TextButton.styleFrom(foregroundColor: const Color(0xFFF48900)),
          ),
        ),
        const SizedBox(height: 8),
        if (!anyActive || _forgot) _infoBox(_editInfoText()),
        const SizedBox(height: 12),
        if (!_forgot) _actionCheckboxes(),
        const SizedBox(height: 16),
        if (anyActive && !_forgot) ...[
          if (!_correct) _passwordStep(),
          if (_correct && !_mailSent) ...[
            if (_chgPass)
              _sendCodePrompt('Click below to send a code to your email.'),
            if (_chgEmail) _changeEmailFields(),
            if (_upAcc) _membershipSelector(),
            if (_delAcc) _deleteAccountFields(),
          ],
          if (_mailSent && !_codeAccepted) _codeEntry(),
          if (_codeAccepted && (_chgPass || _forgot)) _newPasswordFields(),
          if (_codeAccepted && _chgEmail)
            _infoBox(
                'Code accepted. Your email will be updated when you tap Save.'),
          _editActionButtons(),
        ],
        if (_forgot) ...[
          if (!_mailSent) _forgotPasswordStep(),
          if (_mailSent && !_codeAccepted) _codeEntry(),
          if (_codeAccepted) _newPasswordFields(),
          _editActionButtons(),
        ],
      ],
    );
  }

  String _editInfoText() {
    if (_chgEmail)
      return 'If you change your email, a code will be sent to confirm the change. You will be logged out after.';
    if (_chgPass)
      return 'A code will be sent to your email to confirm the password change.';
    if (_upAcc)
      return 'Upgrading gives you more features and higher limits. You can\'t change tier again for 30 days.';
    if (_delAcc)
      return 'Deleting your account disables it and logs you out.';
    return 'Manage your account: change your password or email, upgrade, or delete your account.';
  }

  Widget _infoBox(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B4748).withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1B4748).withOpacity(0.2)),
      ),
      child: Text(text,
          style: const TextStyle(
              fontSize: 13, color: Colors.black87, height: 1.5)),
    );
  }

  Widget _actionCheckboxes() {
    final anyActive = _chgPass || _chgEmail || _upAcc || _delAcc;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
      child: Wrap(
        spacing: 20,
        runSpacing: 12,
        children: [
          if (!anyActive || _chgPass)
            _actionCheckbox('Change Password', _chgPass, (v) {
              _resetActions();
              setState(() => _chgPass = v!);
            }),
          if (!anyActive || _chgEmail)
            _actionCheckbox('Change Email', _chgEmail, (v) {
              _resetActions();
              setState(() => _chgEmail = v!);
            }),
          if (!anyActive || _upAcc)
            _actionCheckbox('Upgrade / Downgrade', _upAcc, (v) {
              _resetActions();
              setState(() => _upAcc = v!);
            }),
          if (!anyActive || _delAcc)
            _actionCheckbox('Delete Account', _delAcc, (v) {
              _resetActions();
              setState(() => _delAcc = v!);
            }),
        ],
      ),
    );
  }

  Widget _actionCheckbox(
      String label, bool value, void Function(bool?) onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
            value: value,
            activeColor: const Color(0xFF1B4748),
            onChanged: onChanged),
        GestureDetector(
          onTap: () => onChanged(!value),
          child: Text(label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF1B4748))),
        ),
      ],
    );
  }

  Widget _passwordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Current Password'),
        Row(
          children: [
            Expanded(
              child: _passField(_passwordController, 'Password', _showPass, () {
                setState(() => _showPass = !_showPass);
              }),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: _submitting ? null : _checkPassword,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B4748),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
              child: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Confirm',
                      style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => setState(() {
            _forgot = true;
            _chgPass = false;
            _chgEmail = false;
            _upAcc = false;
            _delAcc = false;
          }),
          child: const Text('Forgot Password?',
              style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFFF8BB25),
                  decoration: TextDecoration.underline)),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _forgotPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox('A reset code will be sent to your registered email address.'),
        const SizedBox(height: 12),
        Row(
          children: [
            ElevatedButton(
              onPressed: _submitting ? null : _requestForgotPassword,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B4748)),
              child: const Text('Send Reset Code',
                  style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: 10),
            TextButton(
              onPressed: () => setState(() => _forgot = false),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFFF48900))),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _sendCodePrompt(String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: const TextStyle(fontSize: 13, color: Colors.black87)),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: _submitting ? null : _requestCode,
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B4748)),
          child: const Text('Send Code', style: TextStyle(color: Colors.white)),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _changeEmailFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('New Email'),
        _inputField(_newEmailController, 'Enter new email',
            keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 10),
        _sectionLabel('Confirm New Email'),
        _inputField(_confirmEmailController, 'Confirm new email',
            keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: _submitting ? null : _requestCode,
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B4748)),
          child: const Text('Send Code', style: TextStyle(color: Colors.white)),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _codeEntry() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Enter the 6-digit code from your email'),
        const SizedBox(height: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(6, (i) {
            return Container(
              width: 42,
              height: 48,
              margin: const EdgeInsets.only(right: 8),
              child: TextField(
                controller: _codeControllers[i],
                focusNode: _codeFocusNodes[i],
                textAlign: TextAlign.center,
                maxLength: 1,
                keyboardType: TextInputType.number,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  counterText: '',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: Color(0xFF1B4748), width: 2),
                  ),
                ),
                onChanged: (v) {
                  if (v.isNotEmpty && i < 5)
                    _codeFocusNodes[i + 1].requestFocus();
                },
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            ElevatedButton(
              onPressed: _submitting ? null : _confirmCode,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B4748)),
              child: const Text('Submit Code',
                  style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: 10),
            TextButton(
              onPressed: _closeForm,
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFFF48900))),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _newPasswordFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('New Password'),
        _passField(_newPassController, 'New password', _showNewPass,
            () => setState(() => _showNewPass = !_showNewPass),
            onChanged: (_) => setState(() {})),
        if (_newPassController.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Password strength',
              style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _passStrength / 5,
              backgroundColor: Colors.grey.shade200,
              color: _passStrengthColor,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 4),
          const Text('Use 8+ characters with uppercase, numbers and symbols.',
              style: TextStyle(fontSize: 11, color: Colors.black45)),
        ],
        const SizedBox(height: 12),
        _sectionLabel('Confirm Password'),
        _passField(_confirmPassController, 'Confirm password', _showConfirmPass,
            () => setState(() => _showConfirmPass = !_showConfirmPass)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _membershipSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _miniTab(1, 'Monthly'),
            const SizedBox(width: 8),
            _miniTab(2, 'Yearly'),
          ],
        ),
        const SizedBox(height: 12),
        if (_memTab == 1) ...[
          const Text('Membership charged monthly',
              style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 10),
          _memOption('Bronze', 'Free', 'bronze'),
          _memOption('Silver', '${_rand('silver_monthly')} p/m', 'silverM'),
          _memOption('Gold', '${_rand('gold_monthly')} p/m', 'goldM'),
        ] else ...[
          const Text('Membership charged annually',
              style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 10),
          _memOption('Bronze', 'Free', 'bronze'),
          _memOption('Silver', '${_rand('silver_yearly')} a year$_yearlyNote',
              'silverY'),
          _memOption(
              'Gold', '${_rand('gold_yearly')} a year$_yearlyNote', 'goldY'),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _miniTab(int index, String label) {
    final active = _memTab == index;
    return GestureDetector(
      onTap: () => setState(() => _memTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1B4748) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF1B4748)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                color: active ? Colors.white : const Color(0xFF1B4748),
                fontWeight: active ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  Widget _memOption(String label, String price, String value) {
    final currentType = _account?['membership']?['mem_type'];
    String tier(String? t) => t == null
        ? 'bronze'
        : t.startsWith('silver')
            ? 'silver'
            : t.startsWith('gold')
                ? 'gold'
                : t;
    final isCurrent = tier(currentType as String?) == tier(value);
    final disabled = isCurrent || (value != 'bronze' && _pricing == null);
    final isSelected = _memType == value;

    return GestureDetector(
      onTap: disabled ? null : () => setState(() => _memType = value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1B4748).withOpacity(0.08)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color:
                  isSelected ? const Color(0xFF1B4748) : Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: _memType,
              activeColor: const Color(0xFF1B4748),
              onChanged:
                  disabled ? null : (v) => setState(() => _memType = v!),
            ),
            Expanded(
              child: Text('$label — $price',
                  style: TextStyle(
                      fontSize: 13,
                      color: disabled ? Colors.black38 : Colors.black87)),
            ),
            if (isCurrent)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: const Color(0xFF1B4748),
                    borderRadius: BorderRadius.circular(4)),
                child: const Text('Current',
                    style: TextStyle(fontSize: 11, color: Colors.white)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _deleteAccountFields() {
    const reasons = [
      ('novalue', 'Not getting any value from this site'),
      ('bugs', 'Too many bugs & issues'),
      ('spam', 'Getting spammed a lot'),
      ('other', 'Other'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Why do you want to delete your account?'),
        ...reasons.map((r) => RadioListTile<String>(
              value: r.$1,
              groupValue: _reason,
              activeColor: const Color(0xFFF48900),
              title: Text(r.$2, style: const TextStyle(fontSize: 13)),
              onChanged: (v) => setState(() => _reason = v!),
            )),
        if (_reason == 'other') ...[
          _inputField(_otherReasonController, 'Tell us more...', maxLines: 3),
          const SizedBox(height: 8),
        ],
        if (_reason.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF48900).withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: const Color(0xFFF48900).withOpacity(0.3)),
            ),
            child: const Text(
                'You will be logged out and your account disabled for 30 days. After that, all data is permanently deleted.',
                style: TextStyle(fontSize: 12, color: Color(0xFFF48900))),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _editActionButtons() {
    final showSavePass = (_chgPass || _forgot) && _codeAccepted;
    final showSaveEmail = _chgEmail && _codeAccepted;
    final showUpgrade = _upAcc && _correct && _memType.isNotEmpty;
    final showDelete = _delAcc && _correct && _reason.isNotEmpty;

    if (!showSavePass && !showSaveEmail && !showUpgrade && !showDelete) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        if (showSavePass)
          ElevatedButton(
            onPressed: _submitting ? null : _savePassword,
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B4748)),
            child: const Text('Save Password',
                style: TextStyle(color: Colors.white)),
          ),
        if (showSaveEmail)
          ElevatedButton(
            onPressed: _submitting ? null : _saveEmail,
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B4748)),
            child:
                const Text('Save Email', style: TextStyle(color: Colors.white)),
          ),
        if (showUpgrade)
          ElevatedButton(
            onPressed: _submitting ? null : _saveMembership,
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B4748)),
            child:
                Text(_buttonLabel, style: const TextStyle(color: Colors.white)),
          ),
        if (showDelete)
          ElevatedButton(
            onPressed: _submitting ? null : _deleteAccount,
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF48900)),
            child: const Text('Delete Account',
                style: TextStyle(color: Colors.white)),
          ),
        const SizedBox(width: 10),
        TextButton(
          onPressed: _closeForm,
          child:
              const Text('Cancel', style: TextStyle(color: Color(0xFFF48900))),
        ),
      ],
    );
  }


  Widget _walletTab() {
    const fixedAmounts = ['1000', '2500', '5000', '10000', '20000', '50000'];
    final bd = _breakdown;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Balance
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Available Balance',
                        style: TextStyle(fontSize: 12, color: Colors.black54)),
                    const SizedBox(height: 4),
                    _loadingWallet
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Color(0xFF1B4748)))
                        : Text('R${_walletBalance.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1B4748))),
                  ],
                ),
              ),
              const Text('Used for leads, ads & features',
                  style: TextStyle(fontSize: 11, color: Colors.black45)),
            ],
          ),
        ),

        const SizedBox(height: 24),
        _sectionHeader('Fund Wallet'),
        _infoBox(
            'A 4% service fee applies to all deposits — deposit R500 and receive R480 in your wallet. Funding your account clears the cart, so pay for any cart items first.'),
        const SizedBox(height: 16),

        // Fixed amounts
        _sectionLabel('Fixed amount'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: fixedAmounts.map((a) {
            final isSelected = _fundAmount == a;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _fundAmount = a;
                  _fundController.text = a;
                  _showFundBreakdown = true;
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF1B4748)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: isSelected
                          ? const Color(0xFF1B4748)
                          : Colors.grey.shade300),
                ),
                child: Text('R$a',
                    style: TextStyle(
                        fontSize: 13,
                        color: isSelected ? Colors.white : Colors.black87)),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 16),
        _sectionLabel('Custom amount'),
        _inputField(
          _fundController,
          'Minimum R${_minDeposit.toInt()}',
          keyboardType: TextInputType.number,
          onChanged: (v) => setState(() {
            _fundAmount = v;
            _showFundBreakdown = v.isNotEmpty;
          }),
        ),

        // Fee breakdown
        if (_showFundBreakdown && bd != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _breakdownRow('Deposit amount',
                    'R${bd['gross']!.toStringAsFixed(2)}', Colors.black87),
                const SizedBox(height: 8),
                _breakdownRow(
                    'Service fee (4%)',
                    '- R${bd['fee']!.toStringAsFixed(2)}',
                    const Color(0xFFF48900)),
                const Divider(height: 16),
                _breakdownRow(
                    'You receive',
                    'R${bd['net']!.toStringAsFixed(2)}',
                    const Color(0xFF1B4748),
                    bold: true),
              ],
            ),
          ),
        ],

        if (_showFundBreakdown && bd == null && _fundAmount.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Minimum deposit is R${_minDeposit.toInt()}.',
                style: const TextStyle(fontSize: 12, color: Color(0xFFF48900))),
          ),

        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: bd == null
                ? null
                : () {
                    final amount = double.tryParse(_fundAmount) ?? 0;
                    if (amount < _minDeposit) {
                      _showSnack(
                          'Minimum deposit is R${_minDeposit.toInt()}.');
                      return;
                    }
                    context.read<CartProvider>().removeItem('wallet_topup');
                    context.read<CartProvider>().addItem(CartItem(
                          id: 'wallet_topup',
                          title: 'Wallet Top-up — R$_fundAmount',
                          price: amount,
                          type: 'wallet_topup',
                        ));
                    _showSnack(
                        'Added to cart. Complete your top-up in the cart.');
                    homeSectionNotifier.value = 'Cart';
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B4748),
              padding: const EdgeInsets.symmetric(vertical: 14),
              disabledBackgroundColor: Colors.grey.shade300,
            ),
            child: const Text('Fund Wallet',
                style: TextStyle(color: Colors.white, fontSize: 15)),
          ),
        ),

        const SizedBox(height: 32),
        _sectionHeader('Transaction History'),

        // Filters
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _txType.isEmpty ? null : _txType,
                hint: const Text('All Types', style: TextStyle(fontSize: 13)),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(value: '', child: Text('All Types')),
                  DropdownMenuItem(value: 'deposit', child: Text('Deposits')),
                  DropdownMenuItem(value: 'lead', child: Text('Leads')),
                  DropdownMenuItem(value: 'featured', child: Text('Featured')),
                  DropdownMenuItem(value: 'boost', child: Text('Boosts')),
                  DropdownMenuItem(
                      value: 'advertising', child: Text('Advertising')),
                  DropdownMenuItem(value: 'refund', child: Text('Refunds')),
                  DropdownMenuItem(
                      value: 'adjustment', child: Text('Adjustments')),
                ],
                onChanged: (v) {
                  setState(() => _txType = v ?? '');
                  _loadTransactions(reset: true);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _txDirection.isEmpty ? null : _txDirection,
                hint: const Text('All', style: TextStyle(fontSize: 13)),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(value: '', child: Text('All')),
                  DropdownMenuItem(value: 'credit', child: Text('Money In')),
                  DropdownMenuItem(value: 'debit', child: Text('Money Out')),
                ],
                onChanged: (v) {
                  setState(() => _txDirection = v ?? '');
                  _loadTransactions(reset: true);
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        if (_loadingTx && _transactions.isEmpty)
          const Center(
              child: CircularProgressIndicator(color: Color(0xFF1B4748)))
        else if (_transactions.isEmpty)
          const Text('No transactions yet.',
              style: TextStyle(color: Color(0xFF1B4748)))
        else ...[
          ..._transactions.map((tx) => _txRow(tx as Map<String, dynamic>)),
          if (_txNextPage != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Center(
                child: TextButton(
                  onPressed: _loadingTx ? null : _loadMoreTransactions,
                  child: Text(_loadingTx ? 'Loading...' : 'Load More',
                      style: const TextStyle(color: Color(0xFF1B4748))),
                ),
              ),
            ),
        ],

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _breakdownRow(String label, String value, Color valueColor,
      {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, color: Colors.black54)),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                color: valueColor)),
      ],
    );
  }

  Widget _txRow(Map<String, dynamic> tx) {
    final isCredit = tx['direction'] == 'credit';
    final typeLabels = {
      'deposit': 'Wallet Top-up',
      'lead': 'Lead Purchase',
      'featured': 'Featured Listing',
      'boost': 'Boost',
      'advertising': 'Advertising',
      'refund': 'Refund',
      'adjustment': 'Adjustment',
      'purchase': 'Cart Payment',
      'commission': 'Commission',
    };
    final label =
        typeLabels[tx['transaction_type']] ?? tx['transaction_type'] ?? '—';
    final amount = double.tryParse(tx['amount'].toString()) ?? 0.0;
    final fee = tx['service_fee'];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFeeeeee)))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                if (tx['description'] != null &&
                    tx['description'].toString().isNotEmpty)
                  Text(tx['description'].toString(),
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black45)),
                Text(_formatDate(tx['created_at']?.toString()),
                    style:
                        const TextStyle(fontSize: 11, color: Colors.black38)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isCredit ? '+' : '-'}R${amount.toStringAsFixed(2)}',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isCredit
                        ? const Color(0xFF1B4748)
                        : const Color(0xFFF48900)),
              ),
              if (fee != null)
                Text('fee R$fee',
                    style:
                        const TextStyle(fontSize: 11, color: Colors.black38)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Tab 4 — Financials ───────────────────────────────────────────────────

  Widget _financialsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Orders'),
        const SizedBox(height: 8),
        if (_loadingOrders)
          const Center(
              child: CircularProgressIndicator(color: Color(0xFF1B4748)))
        else if (_orders.isEmpty)
          const Text('No orders yet.',
              style: TextStyle(color: Color(0xFF1B4748)))
        else
          ..._orders.map((o) => _orderCard(o as Map<String, dynamic>)),
        const SizedBox(height: 24),
        _sectionHeader('Withdrawals'),
        const SizedBox(height: 8),
        const Text('No withdrawals yet.',
            style: TextStyle(color: Color(0xFF1B4748))),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _orderCard(Map<String, dynamic> order) {
    final items = order['items'] as List? ?? [];
    final total = order['total'];
    final amountPaid = order['amount_paid'] ?? total;
    final hasDiscount = amountPaid != null &&
        total != null &&
        double.tryParse(amountPaid.toString()) != null &&
        double.tryParse(total.toString()) != null &&
        double.parse(amountPaid.toString()) < double.parse(total.toString());
    final discount = hasDiscount
        ? (double.parse(total.toString()) - double.parse(amountPaid.toString()))
            .toStringAsFixed(2)
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)
        ],
      ),
      child: Column(
        children: [
          ...items.map((item) => Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                        child: Text(item['title']?.toString() ?? '',
                            style: const TextStyle(fontSize: 13))),
                    Text('x${item['quantity']}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black45)),
                    const SizedBox(width: 16),
                    Text('R${item['amount']}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B4748))),
                  ],
                ),
              )),
          if (hasDiscount)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                      child: Text('Discount Applied',
                          style: TextStyle(
                              fontSize: 12,
                              color:
                                  const Color(0xFFF8BB25).withOpacity(0.8)))),
                  Text('- R$discount',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFFF8BB25))),
                ],
              ),
            ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Text('Order #${order['id']}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B4748))),
                const SizedBox(width: 10),
                Text(_formatDate(order['created_at']?.toString()),
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black45)),
                const Spacer(),
                Text('R$amountPaid',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF48900))),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => _showInvoiceDialog(order),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF8BB25),
                        borderRadius: BorderRadius.circular(4)),
                    child: const Text('Invoice',
                        style: TextStyle(fontSize: 12, color: Colors.black87)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showInvoiceDialog(Map<String, dynamic> order) {
    final items = order['items'] as List? ?? [];
    final amountPaid = order['amount_paid'] ?? order['total'];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Invoice — Order #${order['id']}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Date: ${_formatDate(order['created_at']?.toString())}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 12),
              const Divider(),
              ...items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(child: Text(item['title']?.toString() ?? '')),
                        Text('x${item['quantity']}  '),
                        Text('R${item['amount']}',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Paid',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('R$amountPaid',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B4748))),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  // ─── Shared helpers ───────────────────────────────────────────────────────

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B4748))),
      );

  Widget _sectionLabel(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B4748))),
      );

  Widget _inputField(
    TextEditingController controller,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    void Function(String)? onChanged,
  }) =>
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF1B4748)),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      );

  Widget _passField(
    TextEditingController controller,
    String hint,
    bool visible,
    VoidCallback onToggle, {
    void Function(String)? onChanged,
  }) =>
      TextField(
        controller: controller,
        obscureText: !visible,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF1B4748)),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          suffixIcon: IconButton(
            icon: Icon(visible ? Icons.visibility_off : Icons.visibility,
                size: 18, color: Colors.black45),
            onPressed: onToggle,
          ),
        ),
      );
}
