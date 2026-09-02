import 'dart:typed_data';

import 'download_result.dart';
import 'report_downloader_io.dart'
    if (dart.library.js_interop) 'report_downloader_web.dart' as platform;

export 'download_result.dart';

/// Entrega un PDF ya generado al usuario usando el mecanismo propio de cada
/// plataforma:
///
/// * **Web:** descarga directa del navegador (`Blob` + `<a download>`).
/// * **Android / iOS:** hoja de compartir del sistema.
/// * **Windows / macOS / Linux:** diálogo "Guardar como...".
Future<DownloadResult> downloadReport({
  required Uint8List bytes,
  required String fileName,
}) {
  return platform.downloadReport(bytes: bytes, fileName: fileName);
}
