import 'package:flutter/material.dart';

class AddSocialScreen extends StatefulWidget {
  final String action; // 'add' | 'edit'
  final Map<String, dynamic>? network; // existing data for edit
  final List<dynamic> existing; // already added networks, to prevent duplicates

  const AddSocialScreen({
    super.key,
    required this.action,
    this.network,
    this.existing = const [],
  });

  @override
  State<AddSocialScreen> createState() => _AddSocialScreenState();
}

class _AddSocialScreenState extends State<AddSocialScreen> {
  static const _green = Color(0xFF1B4748);
  static const _red = Color(0xFFF48900);

  static const _networks = [
    'facebook',
    'instagram',
    'x',
    'linkedin',
    'pinterest',
    'tumblr',
    'tiktok',
    'snapchat',
    'wechat',
    'youtube',
  ];

  String? _selectedNetwork;
  final _urlCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.action == 'edit' && widget.network != null) {
      _selectedNetwork = widget.network!['network'] as String?;
      _urlCtrl.text = widget.network!['url'] ?? '';
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  String _normalizeUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;
    if (!trimmed.toLowerCase().startsWith('http://') &&
        !trimmed.toLowerCase().startsWith('https://')) {
      return 'https://$trimmed';
    }
    return trimmed;
  }

  bool _isValidUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  void _submit() {
    if (_selectedNetwork == null) {
      _showError('Please select a network.');
      return;
    }

    final url = _normalizeUrl(_urlCtrl.text);

    if (!_isValidUrl(url)) {
      _showError('Please enter a valid URL.');
      return;
    }

    if (widget.action == 'add') {
      final alreadyAdded = widget.existing
          .any((e) => (e['network'] as String?) == _selectedNetwork);
      if (alreadyAdded) {
        _showError('$_selectedNetwork is already added.');
        return;
      }
      if (widget.existing.length >= 5) {
        _showError('You can only add up to 5 social profiles.');
        return;
      }
    }

    Navigator.pop(context, {
      'network': _selectedNetwork,
      'url': url,
    });
  }

  void _showError(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: _red));

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.action == 'edit';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        title: Text(isEdit ? 'Edit Social Profile' : 'Add Social Profile'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Network dropdown
              const Text('Network',
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
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedNetwork,
                    isExpanded: true,
                    hint: Text('Select network',
                        style:
                            TextStyle(color: Colors.grey[400], fontSize: 13)),
                    icon: const Icon(Icons.keyboard_arrow_down,
                        color: _green, size: 20),
                    items: _networks
                        .map((n) => DropdownMenuItem(
                            value: n,
                            child: Row(
                              children: [
                                Icon(_networkIcon(n), color: _green, size: 18),
                                const SizedBox(width: 10),
                                Text(
                                  n[0].toUpperCase() + n.substring(1),
                                  style: const TextStyle(
                                      fontSize: 13, color: Colors.black87),
                                ),
                              ],
                            )))
                        .toList(),
                    onChanged: isEdit
                        ? null // network locked in edit mode
                        : (v) => setState(() {
                              _selectedNetwork = v;
                              _urlCtrl.clear();
                            }),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // URL
              const Text('Profile URL',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87)),
              const SizedBox(height: 6),
              TextField(
                controller: _urlCtrl,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: InputDecoration(
                  hintText: 'https://...',
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
                ),
              ),
              const SizedBox(height: 32),

              // Buttons
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
                      child: Text(
                        isEdit ? 'Save' : 'Add',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
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
                      child: Text(
                        isEdit ? 'Cancel' : 'Done',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _networkIcon(String network) {
    switch (network) {
      case 'facebook':
        return Icons.facebook;
      case 'youtube':
        return Icons.play_circle_outline;
      case 'linkedin':
        return Icons.work_outline;
      case 'x':
        return Icons.close; // closest built-in to X logo
      default:
        return Icons.link;
    }
  }
}
