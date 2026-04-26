import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/models.dart';

class MenuPdfGenerator {
  // Colori del design system
  static const _forest = PdfColor.fromInt(0xFF2D4A3E);
  static const _terracotta = PdfColor.fromInt(0xFFC4623A);
  //static const _sage = PdfColor.fromInt(0xFF7FA688);
  static const _sageLight = PdfColor.fromInt(0xFFB5CEBC);
  //static const _cream = PdfColor.fromInt(0xFFFAF7F2);
  static const _muted = PdfColor.fromInt(0xFF7A8A82);
  static const _border = PdfColor.fromInt(0xFFE8E2D9);

  static Future<Uint8List> generate({
    required School school,
    required SchoolMenu menu,
  }) async {
    final pdf = pw.Document();

    // Carica font
    final font = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();

    // Raggruppa i giorni per settimana
    final groupedDays = _groupByWeek(
        menu.upcomingDays.isNotEmpty ? menu.upcomingDays : menu.days
          ..sort((a, b) => a.dayDate.compareTo(b.dayDate)));

    // Genera una pagina per ogni settimana
    for (final weekEntry in groupedDays.entries) {
      final weekLabel = weekEntry.key;
      final days = weekEntry.value;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => _buildWeekPage(
            context: context,
            school: school,
            menu: menu,
            weekLabel: weekLabel,
            days: days,
            font: font,
            fontBold: fontBold,
          ),
        ),
      );
    }

    return pdf.save();
  }

  static pw.Widget _buildWeekPage({
    required pw.Context context,
    required School school,
    required SchoolMenu menu,
    required String weekLabel,
    required List<MenuDay> days,
    required pw.Font font,
    required pw.Font fontBold,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // ─── HEADER ──────────────────────────────────────────────
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(20),
          decoration: const pw.BoxDecoration(
            color: _forest,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(12)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        school.name,
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 18,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        school.fullLocationLabel,
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 10,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        menu.title,
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 12,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        weekLabel,
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 10,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 20),

        // ─── GIORNI ───────────────────────────────────────────────
        pw.Expanded(
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: days
                .map((day) => pw.Expanded(
                      child: pw.Container(
                        margin: pw.EdgeInsets.only(
                          right: days.last == day ? 0 : 8,
                        ),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: _border),
                          borderRadius:
                              const pw.BorderRadius.all(pw.Radius.circular(8)),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            // Intestazione giorno
                            pw.Container(
                              width: double.infinity,
                              padding: const pw.EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: const pw.BoxDecoration(
                                color: _sageLight,
                                borderRadius: pw.BorderRadius.only(
                                  topLeft: pw.Radius.circular(8),
                                  topRight: pw.Radius.circular(8),
                                ),
                              ),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    DateFormat('EEEE', 'it_IT')
                                        .format(day.dayDate)
                                        .toUpperCase(),
                                    style: pw.TextStyle(
                                      font: fontBold,
                                      fontSize: 9,
                                      color: _forest,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  pw.Text(
                                    DateFormat('d MMM', 'it_IT')
                                        .format(day.dayDate),
                                    style: pw.TextStyle(
                                      font: fontBold,
                                      fontSize: 12,
                                      color: _forest,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Portate
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: _sortedCourses(day.courses)
                                    .map(
                                      (course) => pw.Padding(
                                        padding:
                                            const pw.EdgeInsets.only(bottom: 6),
                                        child: pw.Column(
                                          crossAxisAlignment:
                                              pw.CrossAxisAlignment.start,
                                          children: [
                                            pw.Text(
                                              course.displayLabel.toUpperCase(),
                                              style: pw.TextStyle(
                                                font: fontBold,
                                                fontSize: 7,
                                                color: _muted,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                            pw.SizedBox(height: 2),
                                            pw.Text(
                                              course.description,
                                              style: pw.TextStyle(
                                                font: font,
                                                fontSize: 9,
                                                color: _forest,
                                              ),
                                            ),
                                            if (course
                                                .allergens.isNotEmpty) ...[
                                              pw.SizedBox(height: 2),
                                              pw.Text(
                                                '⚠ ${course.allergens.join(', ')}',
                                                style: pw.TextStyle(
                                                  font: font,
                                                  fontSize: 7,
                                                  color: _terracotta,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),

        pw.SizedBox(height: 12),

        // ─── FOOTER ───────────────────────────────────────────────
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generato da OggiAMensa',
              style: pw.TextStyle(font: font, fontSize: 8, color: _muted),
            ),
            pw.Text(
              'Generato il ${DateFormat('d MMMM yyyy', 'it_IT').format(DateTime.now())}',
              style: pw.TextStyle(font: font, fontSize: 8, color: _muted),
            ),
          ],
        ),
      ],
    );
  }

  // Raggruppa i giorni per settimana
  static Map<String, List<MenuDay>> _groupByWeek(List<MenuDay> days) {
    final grouped = <String, List<MenuDay>>{};
    for (final day in days) {
      final monday =
          day.dayDate.subtract(Duration(days: day.dayDate.weekday - 1));
      final friday = monday.add(const Duration(days: 4));
      final key =
          '${DateFormat('d MMM', 'it_IT').format(monday)} — ${DateFormat('d MMM yyyy', 'it_IT').format(friday)}';
      grouped.putIfAbsent(key, () => []).add(day);
    }
    return grouped;
  }

  // Ordina le portate nel giusto ordine
  static List<MenuCourse> _sortedCourses(List<MenuCourse> courses) {
    return [...courses]..sort((a, b) =>
        _courseOrder(a.courseType).compareTo(_courseOrder(b.courseType)));
  }

  static int _courseOrder(CourseType type) {
    switch (type) {
      case CourseType.primo:
        return 0;
      case CourseType.secondo:
        return 1;
      case CourseType.contorno:
        return 2;
      case CourseType.frutta:
        return 3;
      case CourseType.dessert:
        return 4;
      case CourseType.custom:
        return 5;
    }
  }
}
