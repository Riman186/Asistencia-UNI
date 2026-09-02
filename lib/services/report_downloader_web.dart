import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'download_result.dart';

/// Implementación para Flutter Web.
///
/// Genera un `Blob` en memoria con el PDF y dispara una descarga real del
/// navegador mediante un `<a download>` temporal, igual que cualquier otro
/// enlace de descarga de una página web. Funciona tanto en compilación a
/// JavaScript como a WebAssembly.
Future<DownloadResult> downloadReport({
  required Uint8List bytes,
  required String fileName,
}) async {
  final web.Blob blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/pdf'),
  );

  final String url = web.URL.createObjectURL(blob);
  final web.HTMLAnchorElement anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..style.display = 'none';

  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();

  // Se libera el objeto en el siguiente ciclo para que Safari alcance a
  // iniciar la descarga antes de que la URL deje de ser válida.
  Future<void>.delayed(const Duration(seconds: 1), () {
    web.URL.revokeObjectURL(url);
  });

  return DownloadResult.saved('Descargando "$fileName"...');
}
