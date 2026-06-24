import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Apple Intelligence-style glowing border with fullscreen wave wash.
///
/// Animation phases (based on real frame analysis):
///   Phase 1 (0.0 - 0.3): Light bursts from right edge, WASHES across screen
///   Phase 2 (0.3 - 0.6): Left-side wash appears, both streams meet at top/bottom
///   Phase 3 (0.6 - 0.8): Screen-wide wash recedes back toward edges
///   Phase 4 (0.8 - 1.0): Settles into border-only glow with breathing
///
/// The key insight: during the intro, the glow is NOT just a border stroke —
/// it floods across the entire screen content like a wave of colored light,
/// then contracts back to a border glow for the idle state.
class GlowingBorder extends StatefulWidget {
  final Animation<double> animation;

  const GlowingBorder({Key? key, required this.animation}) : super(key: key);

  @override
  State<GlowingBorder> createState() => _GlowingBorderState();
}

class _GlowingBorderState extends State<GlowingBorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _idleController;

  @override
  void initState() {
    super.initState();
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void dispose() {
    _idleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.animation, _idleController]),
      builder: (context, child) {
        return CustomPaint(
          painter: _AiGlowPainter(
            introProgress: widget.animation.value,
            idlePhase: _idleController.value,
            isReversing: widget.animation.status == AnimationStatus.reverse,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _AiGlowPainter extends CustomPainter {
  final double introProgress;
  final double idlePhase;
  final bool isReversing;

  _AiGlowPainter({
    required this.introProgress,
    required this.idlePhase,
    required this.isReversing,
  });

  /// Apple Intelligence color palette sampled around perimeter.
  Color _sampleColor(double t) {
    t = t % 1.0;
    if (t < 0) t += 1.0;

    const palette = <Color>[
      Color(0xFFFF9500), // 0.00 - Right: Orange
      Color(0xFFFF2D55), // 0.15 - Bottom-right: Hot pink
      Color(0xFFE91E63), // 0.25 - Bottom: Pink/Magenta
      Color(0xFF9C27B0), // 0.40 - Bottom-left: Purple
      Color(0xFF3D5AFE), // 0.50 - Left: Indigo/Blue
      Color(0xFF651FFF), // 0.60 - Top-left: Deep purple
      Color(0xFFD500F9), // 0.75 - Top: Vivid purple
      Color(0xFFFF1744), // 0.85 - Top-right: Deep red
      Color(0xFFFF9500), // 1.00 - Right: Orange (wrap)
    ];
    const stops = <double>[0.0, 0.15, 0.25, 0.40, 0.50, 0.60, 0.75, 0.85, 1.0];

    for (int i = 0; i < stops.length - 1; i++) {
      if (t >= stops[i] && t <= stops[i + 1]) {
        final frac = (t - stops[i]) / (stops[i + 1] - stops[i]);
        return Color.lerp(palette[i], palette[i + 1], frac)!;
      }
    }
    return palette.last;
  }

  /// Intro visibility mask for border glow at perimeter position [t].
  double _introVisibility(double t) {
    if (isReversing) return introProgress;
    
    t = t % 1.0;

    final rightReach = (introProgress / 0.6).clamp(0.0, 1.0) * 0.30;
    final leftReach = ((introProgress - 0.1) / 0.6).clamp(0.0, 1.0) * 0.30;

    final distFromRight = math.min(t, 1.0 - t);
    final distFromLeft = (t - 0.5).abs();

    double vis = 0.0;

    if (distFromRight < rightReach) {
      final edge = 1.0 - (distFromRight / rightReach);
      vis = math.max(vis, (edge * 3.0).clamp(0.0, 1.0));
    }

    if (distFromLeft < leftReach) {
      final edge = 1.0 - (distFromLeft / leftReach);
      vis = math.max(vis, (edge * 3.0).clamp(0.0, 1.0));
    }

    return vis;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (introProgress <= 0.0) return;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(44.0));

    // ── Breathing ──
    final breathe = math.sin(idlePhase * math.pi * 8.0) * 0.5 + 0.5;
    final rotationOffset = idlePhase;

    // ════════════════════════════════════════════════════════════════
    // PART 1: FULLSCREEN SHOCKWAVE WASH (the "expose" effect)
    // Single radial gradient from the power button (right edge).
    // Smooth color fill with a gentle brightness bump at the leading
    // edge — no hard ring, no visible gap.
    // ════════════════════════════════════════════════════════════════

    final washIntensity = _washCurve(introProgress);

    if (!isReversing && washIntensity > 0.001) {
      final w = size.width;
      final h = size.height;
      final maxRadius = math.sqrt(w * w + h * h);

      // Emission point: right edge, ~1/3 from top (power button)
      final emissionPoint = Offset(w, h * 0.35);

      // Wavefront expands over 65% of the intro duration
      final waveProgress = (introProgress / 0.65).clamp(0.0, 1.0);
      final waveRadius =
          Curves.easeOut.transform(waveProgress) * maxRadius * 1.3;

      if (waveRadius > 1.0) {
        final waveRect =
            Rect.fromCircle(center: emissionPoint, radius: waveRadius);

        // ONE single gradient: warm at source → cool further out,
        // with a gentle brightness BUMP near the leading edge (75-90%)
        // so it feels like a soft wave, not a hard ring.
        final wavePaint = Paint()
          ..shader = RadialGradient(
            colors: [
              Color(0xFFFF9500).withOpacity(0.38 * washIntensity), // Source: orange
              Color(0xFFFF6B00).withOpacity(0.30 * washIntensity), // Deep orange
              Color(0xFFFF2D55).withOpacity(0.24 * washIntensity), // Hot pink
              Color(0xFFE91E63).withOpacity(0.18 * washIntensity), // Magenta
              Color(0xFFD500F9).withOpacity(0.14 * washIntensity), // Purple
              Color(0xFF7C4DFF).withOpacity(0.10 * washIntensity), // Violet
              // ↓ Brightness bump — the soft wavefront ↓
              Color(0xFFFF2D55).withOpacity(0.35 * washIntensity), // Wavefront glow
              Color(0xFFE91E63).withOpacity(0.20 * washIntensity), // Wavefront fade
              Colors.transparent,                                   // Beyond wave
            ],
            stops: const [0.0, 0.10, 0.22, 0.36, 0.50, 0.64, 0.78, 0.90, 1.0],
          ).createShader(waveRect);
        canvas.drawRect(rect, wavePaint);
      }
    }

    // ════════════════════════════════════════════════════════════════
    // PART 2: BORDER GLOW (persists after the wave recedes)
    // ════════════════════════════════════════════════════════════════

    final int segments = 48;
    final colors = <Color>[];
    final stops = <double>[];

    for (int i = 0; i <= segments; i++) {
      final t = i / segments;
      final color = _sampleColor(t + rotationOffset);

      double vis = _introVisibility(t);
      if (introProgress >= 1.0) vis = 1.0;

      final breatheOpacity = 0.75 + 0.25 * breathe;
      final alpha = (vis * breatheOpacity).clamp(0.0, 1.0);
      colors.add(color.withOpacity(alpha));
      stops.add(t);
    }

    final shader = SweepGradient(colors: colors, stops: stops).createShader(rect);

    final introThicknessCurve =
        Curves.easeOutCubic.transform(introProgress.clamp(0.0, 1.0));
    final breatheThickness = breathe * 2.0;

    // Layer 1: Wide ambient glow
    final ambientWidth = 8.0 + 28.0 * introThicknessCurve + breatheThickness;
    final ambientBlur = 12.0 + 30.0 * introThicknessCurve;
    final ambientPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ambientWidth
      ..shader = shader
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, ambientBlur);
    canvas.drawRRect(rrect, ambientPaint);

    // Layer 2: Mid glow
    final midWidth = 4.0 + 12.0 * introThicknessCurve + breatheThickness * 0.5;
    final midBlur = 6.0 + 10.0 * introThicknessCurve;
    final midPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = midWidth
      ..shader = shader
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, midBlur);
    canvas.drawRRect(rrect, midPaint);

    // Layer 3: Tight core
    final coreWidth = 2.0 + 4.0 * introThicknessCurve;
    final corePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = coreWidth
      ..shader = shader
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
    canvas.drawRRect(rrect, corePaint);
  }

  /// The wash intensity curve: ramps up quickly, peaks around 0.35,
  /// then gradually fades away by 0.85.
  double _washCurve(double t) {
    if (t < 0.0) return 0.0;
    if (t < 0.15) {
      // Quick ramp up
      return Curves.easeOut.transform(t / 0.15);
    } else if (t < 0.45) {
      // Hold near peak
      return 1.0;
    } else if (t < 0.85) {
      // Gradual fade out
      return Curves.easeInCubic.transform(1.0 - (t - 0.45) / 0.40);
    }
    return 0.0;
  }

  @override
  bool shouldRepaint(covariant _AiGlowPainter oldDelegate) {
    return introProgress != oldDelegate.introProgress ||
        oldDelegate.idlePhase != idlePhase;
  }
}