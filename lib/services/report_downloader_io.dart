import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';

import 'download_result.dart';

/// Implementación para plataformas nativas (móvil y escritorio).
///
/// Este archivo nunca se compila para web: `report_downloader.dart` lo
/// reemplaza por `report_downloader_web.dart` mediante import condicional, por
/// lo que `dart:io` sólo se referencia donde existe.
Future<DownloadResult> downloadReport({
  required Uint8List bytes,
  required String fileName,
}) async {
  if (Platform.isAndroid || Platform.isIOS) {
    // === MÓVIL: USAR SHARE (WhatsApp, Email, Archivos) ===
    await Printing.sharePdf(bytes: bytes, filename: fileName);
    return const DownloadResult.saved();
  }

  // === ESCRITORIO: USAR "GUARDAR COMO..." ===
  final String? outputFile = await FilePicker.platform.saveFile(
    dialogTitle: 'Guardar Reporte de Asistencia',
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: ['pdf'],
  );

  if (outputFile == null) return const DownloadResult.cancelled();

  await File(outputFile).writeAsBytes(bytes);
  return DownloadResult.saved('Guardado en: $outputFile');
}
