import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _tab = 1;
  bool _loading = true;
  bool _saving = false;
  bool _editing = false;
  bool _hasMembership = false;

  // Settings model — mirrors the Django UserSettings fields
  Map<String, dynamic> _settings = {
    'gotodash': false,
    'loginalert': false,
    'darkmode': false,
    'smallmenu': false,
    'hide_profile': false,
    'hide_hero': false,
    'hide_photo': false,
    'hide_about': false,
    'hide_content': false,
    'hide_galleries': false,
    'hide_phone': false,
    'hide_email': false,
    'hide_resume': false,
    'email_msg_biz': false,
    'email_classified_interest': false,
    'email_event_msg': false,
    'email_job_interest': false,
    'email_new_lead': false,
    'email_lead_response': false,
    'email_apply_opportunity': false,
    'email_use_code': false,
  };

  // Snapshot for cancel
  Map<String, dynamic> _originalSettings = {};

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      final results = await Future.wait([
        api.dio.get('/api/v1/usersettings/'),
        api.dio.get('/api/v1/users/current/'),
      ]);
      final settingsData = results[0].data as Map<String, dynamic>;
      final accountData = results[1].data as Map<String, dynamic>;

      setState(() {
        // Merge loaded values into defaults (handles missing keys gracefully)
        settingsData.forEach((k, v) {
          if (_settings.containsKey(k)) _settings[k] = v;
        });
        _originalSettings = Map<String, dynamic>.from(_settings);
        _hasMembership = accountData['membership'] != null;
      });
    } catch (_) {
      _showSnack('Could not load settings. Try again.');
    }
    setState(() => _loading = false);
  }

  Future<void> _saveSettings() async {
    setState(() => _saving = true);
    try {
      final api = context.read<ApiService>();
      await api.dio.patch('/api/v1/usersettings/u/', data: _settings);
      setState(() {
        _originalSettings = Map<String, dynamic>.from(_settings);
        _editing = false;
      });
      _showSnack('Settings updated successfully');
    } catch (_) {
      _showSnack('Could not save settings. Try again.');
    }
    setState(() => _saving = false);
  }

  void _cancelEditing() {
    setState(() {
      _settings = Map<String, dynamic>.from(_originalSettings);
      _editing = false;
    });
  }

  void _toggle(String key, bool value) {
    if (!_editing) return;
    setState(() => _settings[key] = value);
  }

  bool _get(String key) => _settings[key] == true;

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF1B4748)));
    }

    return Column(
      children: [
        // Tab bar + edit/save buttons
        Container(
          color: const Color(0xFF1B4748),
          child: Column(
            children: [
              // Edit / Save / Cancel buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!_editing)
                      _headerBtn(
                          'Edit',
                          const Color(0xFFF8BB25),
                          Colors.black87,
                          () => setState(() => _editing = true)),
                    if (_editing) ...[
                      _headerBtn('Save', const Color(0xFF1B4748), Colors.white,
                          _saving ? null : _saveSettings,
                          border: true),
                      const SizedBox(width: 8),
                      _headerBtn('Cancel', const Color(0xFFF48900),
                          Colors.white, _cancelEditing),
                    ],
                  ],
                ),
              ),
              // Tabs
              Row(
                children: [
                  _tabBtn(1, 'Account'),
                  _tabBtn(2, 'Display'),
                  _tabBtn(3, 'Notifications'),
                ],
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadSettings,
            color: const Color(0xFF1B4748),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: _tab == 1
                  ? _accountTab()
                  : _tab == 2
                      ? _displayTab()
                      : _notificationsTab(),
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
        onTap: () => setState(() => _tab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          color: active ? Colors.white : const Color(0xFF1B4748),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: active ? const Color(0xFF1B4748) : Colors.white60,
                fontSize: 12,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              )),
        ),
      ),
    );
  }

  Widget _headerBtn(String label, Color bg, Color fg, VoidCallback? onTap,
      {bool border = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: border ? Border.all(color: Colors.white54) : null,
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13, color: fg, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ─── Tab 1 — Account ─────────────────────────────────────────────────────

  Widget _accountTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Security'),
        _settingTile(
          'loginalert',
          'Alert me about account login',
          'Receive an alert whenever your account is logged into.',
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ─── Tab 2 — Display ─────────────────────────────────────────────────────

  Widget _displayTab() {
    final profileHidden = _get('hide_profile');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Public Profile'),
        _settingTile(
          'hide_profile',
          'Hide Public Profile',
          'Make your profile invisible to other users.',
        ),
        if (!profileHidden) ...[
          _sectionHeader('Personal Information'),
          _settingTile(
              'hide_hero', 'Hide Hero Image', 'Hide your cover/hero image.'),
          _settingTile('hide_photo', 'Hide Photo',
              'Hide your profile photo from public view.'),
          _settingTile(
              'hide_about', 'Hide About', 'Hide your about/bio section.'),
          _settingTile('hide_content', 'Hide User Created Content',
              'Hide content you\'ve posted from your profile.'),
          _settingTile(
              'hide_galleries', 'Hide Galleries', 'Hide your image galleries.'),
          _settingTile('hide_phone', 'Hide Phone', 'Hide your phone number.'),
          _settingTile('hide_email', 'Hide Email',
              'Hide your email address from public view.'),
        ],
        if (_hasMembership) ...[
          _sectionHeader('Professional Information'),
          _settingTile('hide_resume', 'Hide Resume',
              'Hide your resume/CV from your profile.'),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  // ─── Tab 3 — Notifications ───────────────────────────────────────────────

  Widget _notificationsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Business Profile'),
        _settingTile(
          'email_msg_biz',
          'Email me if someone sends my business a message',
          null,
        ),
        if (_hasMembership) ...[
          _sectionHeader('Classifieds'),
          _settingTile(
            'email_classified_interest',
            'Email me if someone sends me a message about one of my ads',
            null,
          ),
        ],
        _sectionHeader('Events'),
        _settingTile(
          'email_event_msg',
          'Email me if someone sends my event a message',
          null,
        ),
        if (_hasMembership) ...[
          _sectionHeader('Jobs'),
          _settingTile(
            'email_job_interest',
            'Email me if someone shows interest in one of my jobs',
            null,
          ),
        ],
        _sectionHeader('Leads'),
        _settingTile(
          'email_new_lead',
          'Email me if a new lead arrives',
          null,
        ),
        _settingTile(
          'email_lead_response',
          'Email me when a business responds to my request',
          null,
        ),
        if (_hasMembership) ...[
          _sectionHeader('Opportunities'),
          _settingTile(
            'email_apply_opportunity',
            'Email me if someone applies to an opportunity of mine',
            null,
          ),
        ],
        _sectionHeader('Affiliate Program'),
        _settingTile(
          'email_use_code',
          'Email me if someone uses my code for a purchase',
          null,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ─── Shared widgets ──────────────────────────────────────────────────────

  Widget _sectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFF1B4748),
      child: Text(title,
          style: const TextStyle(
              color: Color(0xFFF8BB25),
              fontWeight: FontWeight.bold,
              fontSize: 13)),
    );
  }

  Widget _settingTile(String key, String label, String? subtitle) {
    final value = _get(key);
    final isActive = _editing;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.black12)),
      ),
      child: SwitchListTile(
        value: value,
        activeThumbColor: const Color(0xFF1B4748),
        onChanged: isActive ? (v) => _toggle(key, v) : null,
        title: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.black87 : Colors.black54,
          ),
        ),
        subtitle: subtitle != null
            ? Text(subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.black45))
            : null,
      ),
    );
  }
}
