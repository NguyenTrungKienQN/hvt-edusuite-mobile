enum OrbState { idle, listening, thinking, speaking }

class OrbStateConfig {
  final Duration duration;
  final double hueShift;      // độ xoay màu so với palette gốc
  final double swirlAmplitude; // biên độ dao động của bezier control point
  final double scale;          // scale nhẹ để tạo cảm giác "thở"

  const OrbStateConfig({
    required this.duration,
    required this.hueShift,
    required this.swirlAmplitude,
    required this.scale,
  });

  static const Map<OrbState, OrbStateConfig> presets = {
    OrbState.idle: OrbStateConfig(
      duration: Duration(seconds: 8),
      hueShift: 0,
      swirlAmplitude: 0.05,
      scale: 1.0,
    ),
    OrbState.listening: OrbStateConfig(
      duration: Duration(seconds: 3),
      hueShift: 0,
      swirlAmplitude: 0.12,
      scale: 1.04,
    ),
    OrbState.thinking: OrbStateConfig(
      duration: Duration(seconds: 5),
      hueShift: 25,
      swirlAmplitude: 0.09,
      scale: 1.0,
    ),
    OrbState.speaking: OrbStateConfig(
      duration: Duration(milliseconds: 1800),
      hueShift: -15,
      swirlAmplitude: 0.16,
      scale: 1.06,
    ),
  };
}
