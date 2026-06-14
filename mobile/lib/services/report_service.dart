import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:bike_ai_analyzer/models/ride_model.dart';
import 'package:bike_ai_analyzer/models/event_model.dart';
import 'package:bike_ai_analyzer/core/utils/formatters.dart';

class ReportService {
  static final ReportService instance = ReportService._();
  ReportService._();

  Future<String?> exportPdf(RideModel ride) async {
    final events = ride.events;
    final file = await _generate(ride, events);
    return file?.path;
  }

  Future<File?> _generate(RideModel ride, List<RideEvent> events) async {
    final pdf = pw.Document();

    // Cover page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
        ),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(24),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFF0A0A0F),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'BIKE AI ANALYZER',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Ride Analysis Report',
                    style: const pw.TextStyle(
                      color: PdfColor.fromInt(0xFF00D4FF),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 32),
            pw.Text(
              'Ride Summary',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 16),
            _buildSummaryTable(ride),
            pw.SizedBox(height: 32),
            pw.Text(
              'Score Breakdown',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 16),
            _buildScoreTable(ride),
          ],
        ),
      ),
    );

    // Events page
    if (events.isNotEmpty) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Event Timeline',
                style: pw.TextStyle(
                    fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 16),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FlexColumnWidth(3),
                },
                children: [
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _tableHeader('Time'),
                      _tableHeader('Event'),
                      _tableHeader('Severity'),
                      _tableHeader('Description'),
                    ],
                  ),
                  ...events.map((e) => pw.TableRow(
                        children: [
                          _tableCell(Formatters.formatTime(e.timestamp)),
                          _tableCell(e.type.replaceAll('_', ' ')),
                          _tableCell(e.severity),
                          _tableCell(e.description),
                        ],
                      )),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Stats page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Statistical Summary',
              style: pw.TextStyle(
                  fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 16),
            _buildStatsSection(ride, events),
          ],
        ),
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/ride_report_${ride.id.substring(0, 8)}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  pw.Widget _tableHeader(String text) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(
          text,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
        ),
      );

  pw.Widget _tableCell(String text) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
      );

  pw.Widget _buildSummaryTable(RideModel ride) {
    final dur = ride.endTime != null
        ? ride.endTime!.difference(ride.startTime)
        : Duration.zero;
    final rows = [
      ['Date', Formatters.formatDate(ride.startTime)],
      ['Start Time', Formatters.formatTime(ride.startTime)],
      ['Duration', '${dur.inMinutes}m ${dur.inSeconds.remainder(60)}s'],
      ['Distance', '${ride.distanceKm.toStringAsFixed(2)} km'],
      ['Max Speed', '${ride.maxSpeedKmh.toStringAsFixed(0)} km/h'],
      ['Avg Speed', '${ride.avgSpeedKmh.toStringAsFixed(0)} km/h'],
      ['Context', ride.ridingContext ?? 'Unknown'],
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: rows
          .map((r) => pw.TableRow(children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(r[0],
                      style:
                          pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(r[1]),
                ),
              ]))
          .toList(),
    );
  }

  pw.Widget _buildScoreTable(RideModel ride) {
    final rows = [
      ['Skill Score', '${(ride.skillScore ?? 0).toStringAsFixed(1)}/100'],
      ['Danger Score', '${(ride.dangerScore ?? 0).toStringAsFixed(1)}/100'],
      ['Safety Rating', ride.safetyRating ?? 'N/A'],
      ['Aggression Score', '${(ride.aggressionScore ?? 0).toStringAsFixed(1)}/100'],
      ['Accident Probability',
          '${((ride.accidentProbability ?? 0) * 100).toStringAsFixed(1)}%'],
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: rows
          .map((r) => pw.TableRow(children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(r[0],
                      style:
                          pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(r[1]),
                ),
              ]))
          .toList(),
    );
  }

  pw.Widget _buildStatsSection(RideModel ride, List<RideEvent> events) {
    final eventCounts = <String, int>{};
    for (final e in events) {
      eventCounts[e.type] = (eventCounts[e.type] ?? 0) + 1;
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Event Frequency',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        ...eventCounts.entries.map((entry) => pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(entry.key.replaceAll('_', ' ')),
                pw.Text('${entry.value}x'),
              ],
            )),
        if (eventCounts.isEmpty) pw.Text('No events recorded'),
        pw.SizedBox(height: 24),
        pw.Text(
          'This report was generated by Bike AI Analyzer.',
          style: const pw.TextStyle(color: PdfColors.grey),
        ),
      ],
    );
  }

  Future<void> shareReport(File pdf) async {
    await Share.shareXFiles([XFile(pdf.path)],
        subject: 'Bike Ride Analysis Report');
  }
}
