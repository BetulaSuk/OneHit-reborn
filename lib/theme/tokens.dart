import 'package:flutter/painting.dart';

/// Design tokens. Every length is a multiple of [unit].
abstract final class OH {
  static const double unit = 4;

  // Strip geometry.
  static const double stripWidth = 80 * unit; // 320
  static const double stripHeight = 13 * unit; // 52
  static const double rowGap = unit; // between preview rows
  static const double rowPitch = stripHeight + rowGap;
  static const double radius = stripHeight / 2; // full pill
  static const double disc = 9 * unit; // 36
  static const double padStart = 2 * unit;
  static const double padEnd = 4 * unit;
  static const double gap = 3 * unit;

  /// Transparent margin around the content so the shadow is not clipped.
  static const double margin = 6 * unit;

  // Ground and ink.
  static const Color ground = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF111114);
  static const Color inkSoft = Color(0xFF55555E);
  static const Color discFill = Color(0xFFF0F0F3);

  // State colours: the only colour in the system. Each state has a track
  // (the unfilled ring), a lap (first hour) and a deeper overflow lap (time
  // past one hour), all one hue at full ring saturation.
  static const Color runTrack = Color(0xFFEDF9D9);
  static const Color runLap = Color(0xFFA3E635);
  static const Color runOver = Color(0xFF6CC417);

  static const Color pauseTrack = Color(0xFFFFF2CF);
  static const Color pauseLap = Color(0xFFFFC233);
  static const Color pauseOver = Color(0xFFF59E0B);
  static const Color pauseInk = Color(0xFF7A4E00);

  // Ended: the ring closes into a solid red pill with white ink.
  static const Color endRing = Color(0xFFE0123F);
  static const Color endInk = Color(0xFFFFFFFF);

  /// What the ended pill fades toward in preview rows.
  static const Color endTrack = Color(0xFFFDE2E8);

  static const Color addInk = Color(0xFF157A32);
  static const Color addFill = Color(0xFFE7F8EA);

  static const List<BoxShadow> lift = [
    BoxShadow(color: Color(0x1F000000), offset: Offset(0, 8), blurRadius: 24),
    BoxShadow(color: Color(0x14000000), offset: Offset(0, 1), blurRadius: 3),
  ];

  static const String face = 'Segoe UI Variable Display';
  static const List<String> faceFallback = ['Segoe UI', 'Microsoft YaHei UI'];
  static const double bodySize = 15;

  /// The user's font (settings): the family for all text, and the body
  /// size. The time keeps its 4:3 step above the body.
  static String userFace = face;
  static double userSize = bodySize;

  static TextStyle get itemText => TextStyle(
    fontFamily: userFace,
    fontFamilyFallback: faceFallback,
    fontSize: userSize,
    // Microsoft YaHei UI has no semibold: anything above 400 renders its CJK
    // bold next to lighter Latin. 400 keeps one weight per line and leaves
    // the bold time a clear step above.
    fontWeight: FontWeight.w400,
    height: 1.2,
    letterSpacing: -0.1,
    color: ink,
  );

  static TextStyle get timeText => TextStyle(
    fontFamily: userFace,
    fontFamilyFallback: faceFallback,
    fontSize: (userSize * 4 / 3).roundToDouble(),
    fontWeight: FontWeight.w700,
    height: 1,
    color: ink,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static const Duration quick = Duration(milliseconds: 180);
  static const Duration settle = Duration(milliseconds: 320);
}
