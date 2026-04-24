import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';

class ImportContactsScreen extends StatefulWidget {
  const ImportContactsScreen({super.key});

  @override
  State<ImportContactsScreen> createState() => _ImportContactsScreenState();
}

class _ImportContactsScreenState extends State<ImportContactsScreen> {
  static const _green = Color(0xFF094a25);
  static const _red = Color(0xFFbc2023);
  static const _yellow = Color(0xFFf8b324);

  List<Map<String, String>> _parsedContacts = [];
  List<Map<String, String>> _preview = [];
  List<String> _previewColumns = [];
  List<Map<String, dynamic>> _errors = [];
  int _totalRows = 0;
  bool _importing = false;
  String? _fileName;

  // ── File picking ──────────────────────────────────────────────────────────

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'vcf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    final content = String.fromCharCodes(file.bytes!);
    setState(() {
      _fileName = file.name;
      _parsedContacts = [];
      _preview = [];
      _errors = [];
      _totalRows = 0;
    });

    if (file.name.endsWith('.vcf')) {
      _parseVCF(content);
    } else {
      _parseCSV(content);
    }
  }

  // ── CSV parser ────────────────────────────────────────────────────────────

  void _parseCSV(String content) {
    final lines =
        content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return;

    final headers =
        lines[0].split(',').map((h) => h.trim().replaceAll('"', '')).toList();
    final contacts = <Map<String, String>>[];
    final errs = <Map<String, dynamic>>[];

    for (int i = 1; i < lines.length; i++) {
      final values =
          lines[i].split(',').map((v) => v.trim().replaceAll('"', '')).toList();
      final row = <String, String>{};
      for (int j = 0; j < headers.length; j++) {
        row[headers[j]] = j < values.length ? values[j] : '';
      }
      if ((row['first_name'] ?? '').isEmpty ||
          (row['last_name'] ?? '').isEmpty) {
        errs.add({'row': i + 1, 'message': 'Missing first or last name'});
        continue;
      }
      contacts.add(row);
    }

    setState(() {
      _previewColumns = headers;
      _parsedContacts = contacts;
      _totalRows = contacts.length;
      _errors = errs;
      _preview = contacts.take(5).toList();
    });
  }

  // ── VCF parser ────────────────────────────────────────────────────────────

  void _parseVCF(String content) {
    final vcards =
        content.split('BEGIN:VCARD').where((v) => v.trim().isNotEmpty).toList();
    final contacts = <Map<String, String>>[];
    final errs = <Map<String, dynamic>>[];

    for (int i = 0; i < vcards.length; i++) {
      final vcard = vcards[i];

      String _get(String field) {
        final exp = RegExp('$field[^:]*:(.+)', caseSensitive: false);
        final m = exp.firstMatch(vcard);
        return m != null ? m.group(1)!.trim() : '';
      }

      final nLine = _get('N');
      final fnLine = _get('FN');
      final nParts = nLine.split(';');

      String firstName = nParts.length > 1 ? nParts[1] : '';
      String lastName = nParts.isNotEmpty ? nParts[0] : '';

      if (firstName.isEmpty || lastName.isEmpty) {
        final fnParts = fnLine.split(' ');
        firstName = fnParts.isNotEmpty ? fnParts[0] : '';
        lastName = fnParts.length > 1 ? fnParts[1] : '';
      }

      if (firstName.isEmpty || lastName.isEmpty) {
        errs.add({'row': i + 1, 'message': 'Missing name'});
        continue;
      }

      final emailMatch =
          RegExp(r'EMAIL[^:]*:(.+)', caseSensitive: false).firstMatch(vcard);
      final phoneMatch =
          RegExp(r'TEL[^:]*:(.+)', caseSensitive: false).firstMatch(vcard);
      final rawPhone = phoneMatch != null ? phoneMatch.group(1)!.trim() : '';
      final phone = rawPhone.replaceAll(RegExp(r'[^0-9]'), '').substring(
          0, rawPhone.replaceAll(RegExp(r'[^0-9]'), '').length.clamp(0, 10));

      contacts.add({
        'first_name': firstName,
        'last_name': lastName,
        'birthdate': '',
        'email': emailMatch != null ? emailMatch.group(1)!.trim() : '',
        'email_type': 'personal',
        'phone_number': phone,
        'phone_type': 'mobile',
        'whatsapp': 'false',
        'social_url': '',
        'social_network': '',
        'group_name': '',
      });
    }

    setState(() {
      _previewColumns = ['first_name', 'last_name', 'email', 'phone_number'];
      _parsedContacts = contacts;
      _totalRows = contacts.length;
      _errors = errs;
      _preview = contacts.take(5).toList();
    });
  }

  // ── Import ────────────────────────────────────────────────────────────────

  Future<void> _import() async {
    if (_parsedContacts.isEmpty) return;
    setState(() => _importing = true);
    final auth = context.read<AuthProvider>();
    try {
      final res = await auth.apiService.dio.post(
        '/api/v1/contacts/current/i/',
        data: _parsedContacts,
      );
      if (!mounted) return;
      final created = res.data['created'] ?? 0;
      final importErrors = res.data['errors'] as List? ?? [];

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$created contact(s) imported successfully.'),
        backgroundColor: _green,
      ));
      if (importErrors.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${importErrors.length} row(s) had errors and were skipped.'),
          backgroundColor: _red,
        ));
      }
      Navigator.pop(context, created);
    } on DioException catch (e) {
      _showError(e.response?.data?['error'] ??
          'Import failed. Check your file and try again.');
    } catch (_) {
      _showError('Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: _red));

  Future<void> _downloadTemplate() async {
    final uri = Uri.parse(
        'https://sesha.co.za/static/templates/sesha_contacts_template.csv');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        title: const Text('Import Contacts'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info
              Text(
                'Upload a CSV or vCard (.vcf) file to import contacts. '
                'When you import contacts, groups are automatically created. '
                'If you reach your group limit, remaining contacts will be placed in the default "Sesha Contacts" group.',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
              const SizedBox(height: 16),

              // Download template
              GestureDetector(
                onTap: _downloadTemplate,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: _green,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.download, color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text('Download CSV Template',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // File picker
              const Text('Select File',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickFile,
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: _fileName != null ? _green : Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                    color: _fileName != null
                        ? _green.withValues(alpha: 0.05)
                        : Colors.grey[50],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _fileName != null
                            ? Icons.check_circle_outline
                            : Icons.upload_file_outlined,
                        color: _fileName != null ? _green : Colors.grey[400],
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _fileName ?? 'Tap to browse (.csv or .vcf)',
                          style: TextStyle(
                              fontSize: 13,
                              color: _fileName != null
                                  ? Colors.black87
                                  : Colors.grey[400]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_fileName != null)
                        GestureDetector(
                          onTap: () => setState(() {
                            _fileName = null;
                            _parsedContacts = [];
                            _preview = [];
                            _errors = [];
                            _totalRows = 0;
                          }),
                          child: const Icon(Icons.close,
                              size: 16, color: Colors.black45),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Preview table
              if (_preview.isNotEmpty) ...[
                Row(
                  children: [
                    const Text('Preview',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87)),
                    const SizedBox(width: 8),
                    Text('(first ${_preview.length} rows)',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor:
                        WidgetStateProperty.all(_green.withValues(alpha: 0.08)),
                    columnSpacing: 16,
                    headingTextStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _green),
                    dataTextStyle:
                        const TextStyle(fontSize: 11, color: Colors.black87),
                    columns: _previewColumns
                        .map((col) =>
                            DataColumn(label: Text(col.replaceAll('_', ' '))))
                        .toList(),
                    rows: _preview
                        .map((row) => DataRow(
                              cells: _previewColumns
                                  .map((col) => DataCell(Text(row[col] ?? '',
                                      overflow: TextOverflow.ellipsis)))
                                  .toList(),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 8),
                Text('$_totalRows contact(s) ready to import',
                    style: const TextStyle(
                        fontSize: 12,
                        color: _green,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
              ],

              // Errors
              if (_errors.isNotEmpty) ...[
                Text('${_errors.length} row(s) will be skipped:',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _red)),
                const SizedBox(height: 6),
                ..._errors.map((err) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('Row ${err['row']}: ${err['message']}',
                          style: const TextStyle(fontSize: 12, color: _red)),
                    )),
                const SizedBox(height: 16),
              ],

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_parsedContacts.isEmpty || _importing)
                          ? null
                          : _import,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[300],
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _importing
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Import',
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
}
