import 'package:flutter/material.dart';

/// Puntos de quiebre usados en toda la aplicación.
///
/// Están alineados con los tamaños habituales de dispositivo: teléfono en
/// vertical, tablet / teléfono en horizontal, y navegador de escritorio.
abstract final class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 1024;

  /// Ancho máximo de una columna de contenido. Evita que las listas y los
  /// formularios se estiren de borde a borde en un monitor ancho.
  static const double content = 900;

  /// Ancho máximo para formularios (login, registro), que se leen mejor
  /// estrechos.
  static const double form = 460;
}

/// Tamaño de pantalla actual, derivado del ancho disponible.
enum ScreenSize { mobile, tablet, desktop }

extension ResponsiveContext on BuildContext {
  Size get screenSizePx => MediaQuery.sizeOf(this);

  double get screenWidth => MediaQuery.sizeOf(this).width;

  double get screenHeight => MediaQuery.sizeOf(this).height;

  ScreenSize get screenSize {
    final double width = screenWidth;
    if (width < Breakpoints.mobile) return ScreenSize.mobile;
    if (width < Breakpoints.tablet) return ScreenSize.tablet;
    return ScreenSize.desktop;
  }

  bool get isMobile => screenSize == ScreenSize.mobile;
  bool get isTablet => screenSize == ScreenSize.tablet;
  bool get isDesktop => screenSize == ScreenSize.desktop;

  /// `true` en teléfonos en horizontal o ventanas muy bajas, donde conviene
  /// reducir márgenes verticales.
  bool get isShort => screenHeight < 640;

  /// Elige un valor según el tamaño de pantalla. `tablet` y `desktop` caen al
  /// valor anterior si no se especifican.
  T responsive<T>(T mobile, {T? tablet, T? desktop}) {
    switch (screenSize) {
      case ScreenSize.mobile:
        return mobile;
      case ScreenSize.tablet:
        return tablet ?? mobile;
      case ScreenSize.desktop:
        return desktop ?? tablet ?? mobile;
    }
  }

  /// Margen horizontal estándar del contenido.
  double get gutter => responsive(16, tablet: 24, desktop: 32);
}

/// Centra el contenido y limita su ancho máximo.
///
/// En un teléfono es prácticamente transparente (ocupa todo el ancho); en un
/// navegador de escritorio evita líneas de texto y tarjetas desmesuradamente
/// anchas.
class ResponsiveContainer extends StatelessWidget {
  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.content,
    this.padding = EdgeInsets.zero,
    this.alignment = Alignment.topCenter,
    this.shrinkVertically = false,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final AlignmentGeometry alignment;

  /// Ajusta el alto al del contenido en lugar de ocupar todo el disponible.
  ///
  /// Necesario donde las restricciones de alto son holgadas pero acotadas (por
  /// ejemplo un `bottomNavigationBar`): sin esto el `Align` se estiraría hasta
  /// el alto máximo permitido.
  final bool shrinkVertically;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      heightFactor: shrinkVertically ? 1.0 : null,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Número de columnas para una grilla de tarjetas, según el ancho disponible.
int responsiveColumns(
  double width, {
  double minItemWidth = 280,
  int maxColumns = 4,
}) {
  final int columns = (width / minItemWidth).floor();
  return columns.clamp(1, maxColumns);
}
