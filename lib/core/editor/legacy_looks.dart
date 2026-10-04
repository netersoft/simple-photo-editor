import 'dart:math' as math;

import 'package:filmkit/filmkit.dart';

import '../services/i18n/translations.g.dart';

typedef _Rgb = (double, double, double);

/// The color filters of the Java app (Android media effects), recreated as 3D LUTs so that
/// filmkit's preview and export apply them identically. Fish eye, grain, sharpen and
/// vignette are not color transforms, so they have no LUT equivalent; rotation and
/// mirroring are the editor's Rotate tool.
abstract final class LegacyLooks {
  static final Map<Translations, List<Look>> _cache = {};

  /// The looks named in the language of [t] (`context.t`).
  static List<Look> of(Translations t) => _cache[t] ??= _build(t);

  static List<Look> _build(Translations t) => [
    Look.generate(t.filters.autoFix, (r, g, b) => _saturate(_contrast(_gamma((r, g, b), 0.9), 0.12), 1.12)),
    Look.generate(t.filters.brightness, (r, g, b) => _gamma((r, g, b), 0.7)),
    Look.generate(t.filters.contrast, (r, g, b) => _contrast((r, g, b), 0.4)),
    Look.generate(t.filters.documentary, (r, g, b) => _contrast(_saturate((r, g, b), 0.35), 0.2)),
    Look.generate(t.filters.dualTone, (r, g, b) {
      // Luminance mapped from a deep blue to a warm yellow.
      final y = _luma(r, g, b);
      return (_mix(0.1, 1, y), _mix(0.1, 0.92, y), _mix(0.35, 0.45, y));
    }),
    Look.generate(t.filters.fillLight, (r, g, b) {
      // Lifts the shadows, leaves the highlights.
      double f(double x) => x + 0.35 * x * (1 - x) * (1 - x) * 2;
      return (f(r), f(g), f(b));
    }),
    Look.generate(t.filters.grayscale, (r, g, b) {
      final y = _luma(r, g, b);
      return (y, y, y);
    }),
    Look.generate(t.filters.lomish, (r, g, b) => _saturate(_sCurve((r * 1.04, g, b * 0.94), 0.8), 1.25)),
    Look.generate(t.filters.negative, (r, g, b) => (1 - r, 1 - g, 1 - b)),
    Look.generate(t.filters.posterize, (r, g, b) {
      double f(double x) => (x * 4).floorToDouble().clamp(0, 3) / 3;
      return (f(r), f(g), f(b));
    }),
    Look.generate(t.filters.saturate, (r, g, b) => _saturate((r, g, b), 1.6)),
    Look.generate(t.filters.sepia, _sepia),
    Look.generate(t.filters.temperature, (r, g, b) => (r * 1.1 + 0.02, g * 1.02, b * 0.85)),
    Look.generate(t.filters.tint, (r, g, b) => (r * 1.05 + 0.02, g * 0.92, b * 1.05 + 0.02)),
    Look.generate(t.filters.crossProcess, (r, g, b) => (_sCurve1(r, 0.9), _sCurve1(g, 0.5), b * 0.7 + 0.15)),
    Look.generate(t.filters.blackAndWhite, (r, g, b) {
      final y = _sCurve1(_sCurve1(_luma(r, g, b), 1), 1);
      return (y, y, y);
    }),
  ];
}

double _luma(double r, double g, double b) => 0.2126 * r + 0.7152 * g + 0.0722 * b;

double _mix(double a, double b, double t) => a + (b - a) * t;

double _sCurve1(double x, double amount) {
  final c = x.clamp(0.0, 1.0);
  return _mix(c, c * c * (3 - 2 * c), amount);
}

_Rgb _sCurve(_Rgb c, double amount) => (_sCurve1(c.$1, amount), _sCurve1(c.$2, amount), _sCurve1(c.$3, amount));

_Rgb _contrast(_Rgb c, double amount) {
  double f(double x) => 0.5 + (x - 0.5) * (1 + amount);
  return (f(c.$1), f(c.$2), f(c.$3));
}

_Rgb _gamma(_Rgb c, double gamma) {
  double f(double x) => math.pow(x.clamp(0.0, 1.0), gamma).toDouble();
  return (f(c.$1), f(c.$2), f(c.$3));
}

_Rgb _saturate(_Rgb c, double amount) {
  final y = _luma(c.$1, c.$2, c.$3);
  return (y + (c.$1 - y) * amount, y + (c.$2 - y) * amount, y + (c.$3 - y) * amount);
}

_Rgb _sepia(double r, double g, double b) =>
    (math.min(1, 0.393 * r + 0.769 * g + 0.189 * b), math.min(1, 0.349 * r + 0.686 * g + 0.168 * b), math.min(1, 0.272 * r + 0.534 * g + 0.131 * b));
