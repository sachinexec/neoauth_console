// Renders the launcher icons in assets/branding/ from the logo in
// lib/ui/app_logo.dart, so they always match the in-app logo. After changing
// the logo:
//
//   fvm flutter test tool/render_brand_assets.dart
//   fvm dart run flutter_launcher_icons
//
// A widget test only because that is where Flutter will render off screen.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoauth_console/ui/app_logo.dart';

void main() {
  /// [child] laid out in a [size]-pixel square, saved as `assets/branding/[name]`.
  Future<void> render(WidgetTester tester, String name, double size, Widget child) async {
    tester.view.physicalSize = Size.square(size);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(key: key, child: SizedBox.square(dimension: size, child: child)),
      ),
    );
    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('assets/branding/$name').writeAsBytes(png!.buffer.asUint8List());
    });
  }

  Widget gradient() => const DecoratedBox(decoration: BoxDecoration(gradient: LogoColors.gradient));

  /// The mark in a [size]-wide square whose top is at [top], centred across.
  Widget markAt(double top, double size) => Positioned(
        top: top,
        left: 0,
        right: 0,
        child: Center(child: SizedBox.square(dimension: size, child: const AppLogoMark())),
      );

  /// The dev build's mark: an amber band from [top] down, "DEV" [inset] below its top edge.
  Widget devBand(double top, double inset, double fontSize) => Positioned(
        top: top,
        bottom: 0,
        left: 0,
        right: 0,
        child: ColoredBox(
          color: const Color(0xFFF59E0B),
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(top: inset),
              child: Text(
                'DEV',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w900,
                  fontSize: fontSize,
                  height: 1,
                  letterSpacing: fontSize * 0.12,
                  color: const Color(0xFF3B2300),
                ),
              ),
            ),
          ),
        ),
      );

  setUpAll(() async {
    Directory('assets/branding').createSync(recursive: true);
    // Tests draw text in a placeholder font unless given a real one.
    final font = File('${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/Roboto-Black.ttf');
    await (FontLoader('Roboto')..addFont(font.readAsBytes().then((b) => ByteData.view(b.buffer)))).load();
  });

  // Full bleed: the store and the OS round the corners themselves, and iOS
  // rejects an icon with transparency. Dev is the same icon with a band across
  // the bottom, the mark lifted and shrunk to clear it.
  testWidgets('launcher icons', (tester) async {
    await render(tester, 'icon_prod.png', 1024, Stack(fit: StackFit.expand, children: [gradient(), markAt(0, 1024)]));
    await render(
      tester,
      'icon_dev.png',
      1024,
      Stack(fit: StackFit.expand, children: [gradient(), markAt(20, 800), devBand(820, 48, 112)]),
    );
  });

  // Android 8+ masks the icon to the launcher's shape and only promises the
  // middle 66 of 108dp, a circle 0.61 of the canvas across. The shield stays
  // inside it, and dev's band shows as the bottom of the circle with "DEV"
  // where the circle is still wide enough for it.
  testWidgets('adaptive icon layers', (tester) async {
    await render(tester, 'icon_background.png', 1024, gradient());
    await render(tester, 'icon_foreground.png', 1024, Stack(fit: StackFit.expand, children: [markAt(184, 656)]));
    await render(
      tester,
      'icon_foreground_dev.png',
      1024,
      Stack(fit: StackFit.expand, children: [markAt(184, 492), devBand(676, 20, 76)]),
    );
  });
}
