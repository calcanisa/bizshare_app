import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;

class CvGeneratorScreen extends StatefulWidget {
  final Map<String, dynamic> profile;

  const CvGeneratorScreen({super.key, required this.profile});

  @override
  State<CvGeneratorScreen> createState() => _CvGeneratorScreenState();
}

class _CvGeneratorScreenState extends State<CvGeneratorScreen> {
  static const _green = PdfColor.fromInt(0xFF1B4748);
  static const _lightGrey = PdfColor.fromInt(0xFFf5f5f5);
  static const _textDark = PdfColor.fromInt(0xFF222222);
  static const _textMid = PdfColor.fromInt(0xFF555555);
  static const _textLight = PdfColor.fromInt(0xFF999999);
  static const _divider = PdfColor.fromInt(0xFFeeeeee);

  bool _generating = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final firstName = p['first_name'] ?? '';
    final lastName = p['last_name'] ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B4748),
        foregroundColor: Colors.white,
        title: Text('CV — $firstName $lastName'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Preview card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B4748).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF1B4748).withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.picture_as_pdf_outlined,
                        color: Color(0xFF1B4748), size: 36),
                    const SizedBox(height: 12),
                    Text(
                      '$firstName $lastName — CV',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B4748)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tap Generate to build your CV as a PDF. '
                      'You can then share, print or save it.',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Generate button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _generating ? null : _generate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B4748),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: _generating
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(
                    _generating ? 'Generating...' : 'Generate CV',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      final pdfBytes = await _buildPdf(widget.profile);
      if (!mounted) return;
      final p = widget.profile;
      final name =
          '${p['first_name'] ?? ''}_${p['last_name'] ?? ''}_CV'.trim();
      await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name: name,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not generate CV: $e'),
        backgroundColor: const Color(0xFFF48900),
      ));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<Uint8List> _buildPdf(Map<String, dynamic> p) async {
    final pdf = pw.Document();

    // Load profile photo if available
    pw.MemoryImage? photo;
    final photoUrl = p['profile_picture'] as String?;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      try {
        final res = await http.get(Uri.parse(photoUrl));
        if (res.statusCode == 200) {
          photo = pw.MemoryImage(res.bodyBytes);
        }
      } catch (_) {}
    }

    final firstName = p['first_name'] ?? '';
    final lastName = p['last_name'] ?? '';
    final headline = p['headline'] ?? '';
    final currentPosition = p['current_position'] ?? '';
    final currentCompany = p['current_company'] ?? '';
    final employmentStatus = p['employment_status'] ?? '';
    final about = p['about'] ?? '';
    final contactEmail = p['contact_email'] ?? '';
    final contactNumber = p['contact_number'] ?? '';
    final industry = (p['industry'] as Map?)?['name'] ?? '';

    final locations = p['locations'] as List? ?? [];
    final locationStr = locations.map((loc) {
      final area = loc['area'] as Map?;
      if (area != null) {
        final city = area['city'] as Map?;
        final province = city?['province'] as Map?;
        return '${province?['name'] ?? ''}, ${city?['name'] ?? ''}';
      }
      final city = loc['city'] as Map?;
      final province = city?['province'] as Map?;
      return '${province?['name'] ?? ''}, ${city?['name'] ?? ''}';
    }).where((s) => s.trim() != ',').join(' | ');

    final experiences = p['experiences'] as List? ?? [];
    final educations = p['educations'] as List? ?? [];
    final skills = p['skill_list'] as List? ?? [];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (ctx) => [
          // ── Header ──────────────────────────────────────────────
          pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                  bottom: pw.BorderSide(color: _green, width: 2.5)),
            ),
            padding: const pw.EdgeInsets.only(bottom: 16),
            margin: const pw.EdgeInsets.only(bottom: 20),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (photo != null)
                  pw.Container(
                    width: 90,
                    height: 90,
                    margin: const pw.EdgeInsets.only(right: 20),
                    decoration: pw.BoxDecoration(
                      shape: pw.BoxShape.circle,
                      border:
                          pw.Border.all(color: _green, width: 2),
                      image: pw.DecorationImage(
                          image: photo, fit: pw.BoxFit.cover),
                    ),
                  )
                else
                  pw.Container(
                    width: 90,
                    height: 90,
                    margin: const pw.EdgeInsets.only(right: 20),
                    decoration: pw.BoxDecoration(
                      shape: pw.BoxShape.circle,
                      border:
                          pw.Border.all(color: _green, width: 2),
                      color: _lightGrey,
                    ),
                    child: pw.Center(
                      child: pw.Text('No Photo',
                          style: pw.TextStyle(
                              fontSize: 9, color: _textLight)),
                    ),
                  ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment:
                        pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('$firstName $lastName',
                          style: pw.TextStyle(
                              fontSize: 22,
                              fontWeight: pw.FontWeight.bold,
                              color: _green)),
                      if (headline.isNotEmpty) ...[
                        pw.SizedBox(height: 3),
                        pw.Text(headline,
                            style: pw.TextStyle(
                                fontSize: 12, color: _textMid)),
                      ],
                      if (currentPosition.isNotEmpty &&
                          currentCompany.isNotEmpty) ...[
                        pw.SizedBox(height: 3),
                        pw.Text(
                            '$currentPosition at $currentCompany',
                            style: pw.TextStyle(
                                fontSize: 11, color: _textMid)),
                      ],
                      if (employmentStatus.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(
                          _capitalize(employmentStatus),
                          style: pw.TextStyle(
                              fontSize: 11,
                              color: _green,
                              fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                      if (locationStr.isNotEmpty) ...[
                        pw.SizedBox(height: 3),
                        pw.Text('📍 $locationStr',
                            style: pw.TextStyle(
                                fontSize: 10, color: _textMid)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Contact row ──────────────────────────────────────────
          if (contactEmail.isNotEmpty ||
              contactNumber.isNotEmpty ||
              industry.isNotEmpty) ...[
            pw.Wrap(
              spacing: 20,
              runSpacing: 4,
              children: [
                if (contactEmail.isNotEmpty)
                  _contactChip('✉  $contactEmail'),
                if (contactNumber.isNotEmpty)
                  _contactChip('☎  $contactNumber'),
                if (industry.isNotEmpty)
                  _contactChip('🏢  $industry'),
              ],
            ),
            pw.SizedBox(height: 20),
          ],

          // ── About ────────────────────────────────────────────────
          if (about.isNotEmpty) ...[
            _sectionHeader('About'),
            pw.Text(about,
                style: pw.TextStyle(
                    fontSize: 11,
                    color: _textDark,
                    lineSpacing: 3)),
            pw.SizedBox(height: 20),
          ],

          // ── Experience ───────────────────────────────────────────
          if (experiences.isNotEmpty) ...[
            _sectionHeader('Work Experience'),
            ...experiences.map((exp) {
              final position = exp['position'] ?? '';
              final company = exp['company'] ?? '';
              final started = exp['started'] ?? '';
              final ended = exp['ended'] ?? '';
              final isCurrent = exp['current'] == true;
              final description = exp['description'] ?? '';
              final dateStr = isCurrent
                  ? '$started – Present'
                  : ended.isNotEmpty
                      ? '$started – $ended'
                      : started;
              return _cvItem(
                title: position,
                sub: company,
                date: dateStr,
                description: description,
              );
            }),
            pw.SizedBox(height: 8),
          ],

          // ── Education ────────────────────────────────────────────
          if (educations.isNotEmpty) ...[
            _sectionHeader('Education'),
            ...educations.map((edu) {
              final qual = edu['qualification'] ?? '';
              final institution = edu['institution'] ?? '';
              final field = edu['field_of_study'] ?? '';
              final year = edu['year_completed']?.toString() ?? '';
              return _cvItem(
                title: _capitalize(qual.replaceAll('_', ' ')),
                sub: field.isNotEmpty
                    ? '$institution – $field'
                    : institution,
                date: year,
                description: '',
              );
            }),
            pw.SizedBox(height: 8),
          ],

          // ── Skills ───────────────────────────────────────────────
          if (skills.isNotEmpty) ...[
            _sectionHeader('Skills'),
            pw.Wrap(
              spacing: 6,
              runSpacing: 6,
              children: skills.map((skill) {
                final name = skill['name'] ?? '';
                final exp = skill['experience'] ?? '';
                return pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: _lightGrey,
                    border:
                        pw.Border.all(color: _divider),
                    borderRadius:
                        const pw.BorderRadius.all(
                            pw.Radius.circular(3)),
                  ),
                  child: pw.Text(
                    exp.isNotEmpty ? '$name ($exp)' : name,
                    style: pw.TextStyle(
                        fontSize: 10, color: _textDark),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _sectionHeader(String title) => pw.Container(
        decoration: const pw.BoxDecoration(
            border: pw.Border(
                bottom: pw.BorderSide(color: _divider, width: 1))),
        padding: const pw.EdgeInsets.only(bottom: 5),
        margin: const pw.EdgeInsets.only(bottom: 10),
        child: pw.Text(
          title.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: _green,
            letterSpacing: 1,
          ),
        ),
      );

  pw.Widget _cvItem({
    required String title,
    required String sub,
    required String date,
    required String description,
  }) =>
      pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 12),
        padding: const pw.EdgeInsets.only(bottom: 12),
        decoration: const pw.BoxDecoration(
            border: pw.Border(
                bottom: pw.BorderSide(color: _divider, width: 0.5))),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(title,
                          style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: _textDark)),
                      if (sub.isNotEmpty) ...[
                        pw.SizedBox(height: 2),
                        pw.Text(sub,
                            style: pw.TextStyle(
                                fontSize: 11, color: _textMid)),
                      ],
                    ],
                  ),
                ),
                if (date.isNotEmpty)
                  pw.Text(date,
                      style: pw.TextStyle(
                          fontSize: 10, color: _textLight)),
              ],
            ),
            if (description.isNotEmpty) ...[
              pw.SizedBox(height: 5),
              pw.Text(description,
                  style: pw.TextStyle(
                      fontSize: 11,
                      color: _textMid,
                      lineSpacing: 2)),
            ],
          ],
        ),
      );

  pw.Widget _contactChip(String text) => pw.Text(
        text,
        style: pw.TextStyle(fontSize: 10, color: _textMid),
      );

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}