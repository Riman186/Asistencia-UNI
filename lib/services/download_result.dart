/// Resultado de un intento de descarga/guardado de un reporte.
///
/// Se comparte entre las implementaciones web y nativa para que la UI no
/// necesite saber en qué plataforma se está ejecutando.
class DownloadResult {
  /// El archivo se entregó al usuario (descarga del navegador, hoja de
  /// compartir o guardado en disco).
  const DownloadResult.saved([this.message]) : isCancelled = false;

  /// El usuario canceló el diálogo de guardado.
  const DownloadResult.cancelled()
      : message = null,
        isCancelled = true;

  /// Mensaje opcional para mostrar al usuario. `null` cuando la plataforma ya
  /// dio su propia confirmación visual (por ejemplo la hoja de compartir).
  final String? message;

  /// `true` sólo si el usuario abandonó el diálogo de guardado.
  final bool isCancelled;
}
