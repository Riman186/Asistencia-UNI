import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asistencia_uni/utils/responsive.dart';

/// Monta [child] en una ventana del tamaño indicado.
Widget _sized(Size size, Widget child) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: child,
    ),
  );
}

void main() {
  group('ScreenSize', () {
    testWidgets('clasifica móvil, tablet y escritorio por ancho',
        (tester) async {
      late ScreenSize mobile, tablet, desktop;

      Widget probe(void Function(ScreenSize) sink) => Builder(
            builder: (context) {
              sink(context.screenSize);
              return const SizedBox.shrink();
            },
          );

      await tester.pumpWidget(
          _sized(const Size(380, 800), probe((v) => mobile = v)));
      await tester.pumpWidget(
          _sized(const Size(800, 1000), probe((v) => tablet = v)));
      await tester.pumpWidget(
          _sized(const Size(1440, 900), probe((v) => desktop = v)));

      expect(mobile, ScreenSize.mobile);
      expect(tablet, ScreenSize.tablet);
      expect(desktop, ScreenSize.desktop);
    });

    testWidgets('responsive() cae al valor anterior si falta uno',
        (tester) async {
      late double onTablet, onDesktop;

      await tester.pumpWidget(_sized(
        const Size(800, 1000),
        Builder(builder: (context) {
          onTablet = context.responsive(10, tablet: 20);
          return const SizedBox.shrink();
        }),
      ));
      await tester.pumpWidget(_sized(
        const Size(1440, 900),
        Builder(builder: (context) {
          // Sin `desktop`, hereda el valor de tablet.
          onDesktop = context.responsive(10, tablet: 20);
          return const SizedBox.shrink();
        }),
      ));

      expect(onTablet, 20);
      expect(onDesktop, 20);
    });
  });

  group('ResponsiveContainer', () {
    testWidgets('limita el ancho del contenido en pantallas anchas',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: ResponsiveContainer(
            maxWidth: 600,
            child: SizedBox(
              key: Key('content'),
              height: 100,
              width: double.infinity,
            ),
          ),
        ),
      ));

      expect(tester.getSize(find.byKey(const Key('content'))).width, 600);
    });

    testWidgets('ocupa todo el ancho disponible en un móvil', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: ResponsiveContainer(
            maxWidth: 600,
            child: SizedBox(
              key: Key('content'),
              height: 100,
              width: double.infinity,
            ),
          ),
        ),
      ));

      expect(tester.getSize(find.byKey(const Key('content'))).width, 400);
    });

    testWidgets(
        'con shrinkVertically se ajusta al alto del hijo, no al disponible',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          // Un bottomNavigationBar da restricciones de alto holgadas pero
          // acotadas: sin shrinkVertically el Align se estiraría.
          bottomNavigationBar: ResponsiveContainer(
            shrinkVertically: true,
            child: SizedBox(height: 55, width: double.infinity),
          ),
          body: SizedBox.shrink(),
        ),
      ));

      expect(tester.getSize(find.byType(ResponsiveContainer)).height, 55);
    });
  });

  group('responsiveColumns', () {
    test('escala el número de columnas con el ancho', () {
      expect(responsiveColumns(400, minItemWidth: 280), 1);
      expect(responsiveColumns(600, minItemWidth: 280), 2);
      expect(responsiveColumns(1200, minItemWidth: 280), 4);
      // Nunca supera el máximo indicado.
      expect(responsiveColumns(4000, minItemWidth: 280, maxColumns: 3), 3);
    });
  });
}
