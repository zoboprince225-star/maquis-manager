import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../format.dart';
import 'export_service.dart';

String _csvEscape(Object v) {
  final s = v.toString();
  if (s.contains(';') || s.contains('"') || s.contains('\n')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

/// CSV avec séparateur « ; » et BOM UTF-8 pour s'ouvrir correctement dans Excel
List<int> toCsv(ExportTable t) {
  final b = StringBuffer();
  b.writeln(t.headers.map<String>(_csvEscape).join(';'));
  for (final r in t.rows) {
    b.writeln(r.map<String>(_csvEscape).join(';'));
  }
  if (t.totalRow != null) {
    b.writeln(t.totalRow!.map<String>(_csvEscape).join(';'));
  }
  return [0xEF, 0xBB, 0xBF, ...utf8.encode(b.toString())];
}

CellValue _cell(Object v) =>
    v is int ? IntCellValue(v) : TextCellValue(v.toString());

List<int> toXlsx(ExportTable t) {
  final ex = Excel.createExcel();
  final sheet = ex[ex.getDefaultSheet()!];
  sheet.appendRow([TextCellValue(t.title)]);
  sheet.appendRow([for (final h in t.headers) TextCellValue(h)]);
  for (final r in t.rows) {
    sheet.appendRow([for (final c in r) _cell(c)]);
  }
  if (t.totalRow != null) {
    sheet.appendRow([for (final c in t.totalRow!) _cell(c)]);
  }
  return ex.save() ?? <int>[];
}

String _safe(String s) => s
    .replaceAll('’', "'")
    .replaceAll('‘', "'")
    .replaceAll('“', '"')
    .replaceAll('”', '"')
    .replaceAll('…', '...')
    .replaceAll('×', 'x')
    .replaceAll('·', '-')
    .replaceAll('–', '-')
    .replaceAll('—', '-')
    .replaceAll('€', 'EUR');

Future<List<int>> toPdf(ExportTable t, String establishment) async {
  final doc = pw.Document();
  String cell(int col, Object v) => (v is int && t.moneyCols.contains(col))
      ? fcfa(v)
      : _safe(v.toString());
  List<String> line(List<Object> r) =>
      [for (var i = 0; i < r.length; i++) cell(i, r[i])];
  final data = <List<String>>[
    for (final r in t.rows) line(r),
    if (t.totalRow != null) line(t.totalRow!),
  ];
  final numeric = <int, pw.Alignment>{
    for (var i = 0; i < t.headers.length; i++)
      if (t.moneyCols.contains(i) ||
          (t.rows.isNotEmpty && t.rows.first[i] is int))
        i: pw.Alignment.centerRight,
  };
  final landscape = t.headers.length > 6;
  doc.addPage(pw.MultiPage(
    pageFormat: landscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(28),
    build: (ctx) => [
      pw.Text(_safe(establishment),
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.Text(_safe(t.title), style: const pw.TextStyle(fontSize: 12)),
      pw.SizedBox(height: 10),
      pw.TableHelper.fromTextArray(
        headers: [for (final h in t.headers) _safe(h)],
        data: data,
        headerStyle:
            pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        cellStyle: const pw.TextStyle(fontSize: 8),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        cellAlignments: numeric,
      ),
    ],
  ));
  return doc.save();
}

/// Écrit le fichier dans le dossier temporaire puis ouvre le partage Android
Future<void> shareBytes(
    List<int> bytes, String fileName, String mime, String subject) async {
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/$fileName');
  await f.writeAsBytes(bytes, flush: true);
  await Share.shareXFiles([XFile(f.path, mimeType: mime)],
      subject: subject, text: subject);
}
