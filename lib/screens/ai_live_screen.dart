import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/live_audio_service.dart';

class AiLiveScreen extends StatefulWidget {
  const AiLiveScreen({super.key});

  @override
  State<AiLiveScreen> createState() => _AiLiveScreenState();
}

class _AiLiveScreenState extends State<AiLiveScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _waveController;
  late AnimationController _sparkleController;
  late AnimationController _dropController;
  bool _introPhase = true; // sparkle in center
  bool _droppingPhase = false; // sparkle dropping to bottom

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Continuous wave animation
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    // Sparkle rotation
    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    // Drop animation (sparkle moving from center to bottom)
    _dropController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Start session
    if (!liveAudioService.isLive) {
      liveAudioService.startLiveSession();
    }

    // Listen for connected state to trigger the drop animation
    liveAudioService.stateStream.listen((state) {
      if (state == LiveSessionState.listening && _introPhase && mounted) {
        setState(() {
          _introPhase = false;
          _droppingPhase = true;
        });
        _dropController.forward().then((_) {
          if (mounted) {
            setState(() => _droppingPhase = false);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _waveController.dispose();
    _sparkleController.dispose();
    _dropController.dispose();
    liveAudioService.stopLiveSession();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      liveAudioService.handleAppBackground();
    } else if (state == AppLifecycleState.resumed) {
      liveAudioService.handleAppForeground();
    }
  }

  Future<void> _stopLiveAndExit() async {
    await liveAudioService.stopLiveSession();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final topPadding = MediaQuery.of(context).padding.top;

    // The main container takes up most of the screen from the top down,
    // leaving space at the bottom for the buttons.
    final buttonsAreaHeight = 140.0 + bottomPadding;
    final mainContainerHeight = screenHeight - buttonsAreaHeight;

    return Scaffold(
      backgroundColor: Colors.black, // Pure black background for the button area
      body: StreamBuilder<LiveSessionState>(
        stream: liveAudioService.stateStream,
        initialData: liveAudioService.currentState,
        builder: (context, stateSnapshot) {
          final state = stateSnapshot.data ?? LiveSessionState.disconnected;

          return StreamBuilder<double>(
            stream: liveAudioService.amplitudeStream,
            initialData: 0.0,
            builder: (context, ampSnapshot) {
              final amplitude = ampSnapshot.data ?? 0.0;

              return Stack(
                children: [
                  // ── Ambient background glow (visible behind the bottom buttons) ──
                  if (!_introPhase)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: buttonsAreaHeight + 40,
                      child: AnimatedBuilder(
                        animation: _waveController,
                        builder: (context, _) {
                          return CustomPaint(
                            painter: _AmbientGlowPainter(
                              animationValue: _waveController.value,
                              state: state,
                              amplitude: amplitude,
                            ),
                          );
                        },
                      ),
                    ),

                  // ── Main Top Container (with rounded bottom corners) ──
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: mainContainerHeight,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(40),
                        bottomRight: Radius.circular(40),
                      ),
                      child: Container(
                        color: const Color(0xFF131314), // Very dark grey background for the top area
                        child: Stack(
                          children: [
                            // ── Aurora Wave Animation (at the bottom of this container) ──
                            Positioned.fill(
                              child: AnimatedBuilder(
                                animation: _waveController,
                                builder: (context, _) {
                                  return CustomPaint(
                                    painter: _AuroraPainter(
                                      animationValue: _waveController.value,
                                      state: state,
                                      amplitude: amplitude,
                                    ),
                                  );
                                },
                              ),
                            ),

                            // ── Top bar: icon + "Live" ──
                            Positioned(
                              top: topPadding + 16,
                              left: 0,
                              right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.auto_awesome,
                                      color: Colors.white.withValues(alpha: 0.9), size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Live',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // ── Sparkle intro (center, then drops) ──
                            if (_introPhase || _droppingPhase)
                              AnimatedBuilder(
                                animation: _dropController,
                                builder: (context, _) {
                                  // Sparkle starts at center, drops to bottom of container
                                  final startY = mainContainerHeight * 0.45;
                                  final endY = mainContainerHeight - 60;
                                  final currentY = _droppingPhase
                                      ? lerpDouble(startY, endY, Curves.easeInCubic.transform(_dropController.value))!
                                      : startY;

                                  final sparkleOpacity = _droppingPhase
                                      ? (1.0 - _dropController.value).clamp(0.0, 1.0)
                                      : 1.0;

                                  final sparkleScale = _droppingPhase
                                      ? lerpDouble(1.0, 0.4, _dropController.value)!
                                      : 1.0;

                                  return Positioned(
                                    left: screenWidth / 2 - 20,
                                    top: currentY - 20,
                                    child: Opacity(
                                      opacity: sparkleOpacity,
                                      child: Transform.scale(
                                        scale: sparkleScale,
                                        child: AnimatedBuilder(
                                          animation: _sparkleController,
                                          builder: (context, _) {
                                            return CustomPaint(
                                              painter: _SparklePainter(
                                                rotation: _sparkleController.value * 2 * pi,
                                              ),
                                              size: const Size(40, 40),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Bottom controls: Hold + End ──
                  Positioned(
                    bottom: bottomPadding + 24,
                    left: 0,
                    right: 0,
                    child: AnimatedOpacity(
                      opacity: _introPhase ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 500),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Hold/Pause button
                          GestureDetector(
                            onTap: () {
                              if (!_introPhase) {
                                liveAudioService.toggleMute();
                                setState(() {});
                              }
                            },
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: liveAudioService.isMuted
                                        ? const Color(0xFF3A3A3E)
                                        : const Color(0xFF2A2A2E),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.pause_rounded,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  liveAudioService.isMuted ? 'Tiếp tục' : 'Giữ',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 56),

                          // End button
                          GestureDetector(
                            onTap: () {
                              if (!_introPhase) {
                                _stopLiveAndExit();
                              }
                            },
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEA4335), // Google Red
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Kết thúc',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// 4-pointed Gemini sparkle star
class _SparklePainter extends CustomPainter {
  final double rotation;
  _SparklePainter({required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.translate(-center.dx, -center.dy);

    final path = Path();
    final cx = size.width / 2;
    final cy = size.height / 2;
    final hw = size.width / 2;
    final hh = size.height / 2;
    const p = 0.15;

    path.moveTo(cx, cy - hh);
    path.quadraticBezierTo(cx + hw * p, cy - hh * p, cx + hw, cy);
    path.quadraticBezierTo(cx + hw * p, cy + hh * p, cx, cy + hh);
    path.quadraticBezierTo(cx - hw * p, cy + hh * p, cx - hw, cy);
    path.quadraticBezierTo(cx - hw * p, cy - hh * p, cx, cy - hh);
    path.close();

    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF4285F4), Color(0xFFEA4335), Color(0xFF4285F4)],
      ).createShader(Rect.fromCenter(center: center, width: size.width, height: size.height));

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SparklePainter old) => old.rotation != rotation;
}

/// Organic aurora wave effect that fills the rounded container
class _AuroraPainter extends CustomPainter {
  final double animationValue;
  final LiveSessionState state;
  final double amplitude;

  _AuroraPainter({
    required this.animationValue,
    required this.state,
    required this.amplitude,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = animationValue * 2 * pi;

    // Amplitude factor
    double amp = 0.5;
    if (state == LiveSessionState.listening) {
      amp = 0.6 + (amplitude * 2.0).clamp(0.0, 1.5);
    } else if (state == LiveSessionState.aiSpeaking) {
      amp = 1.0 + sin(t) * 0.3;
    } else if (state == LiveSessionState.paused) {
      amp = 0.2;
    }

    // Base background for the container (very dark grey)
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF131314),
    );

    // Draw the mountain-like aurora waves
    // Layer 1: Wide, dark background fog (Purple/Blue)
    _drawAuroraLayer(
      canvas, size, t,
      yOffset: size.height * 0.70,
      waveHeight: 80 * amp,
      opacity: 0.4,
      phaseShift: 0,
      blurSigma: 60,
    );

    // Layer 2: Main wavy layer
    _drawAuroraLayer(
      canvas, size, t,
      yOffset: size.height * 0.75,
      waveHeight: 100 * amp,
      opacity: 0.6,
      phaseShift: 1.5,
      blurSigma: 30,
    );

    // Layer 3: Sharp foreground peaks
    _drawAuroraLayer(
      canvas, size, t,
      yOffset: size.height * 0.82,
      waveHeight: 120 * amp,
      opacity: 0.8,
      phaseShift: 3.0,
      blurSigma: 15,
    );

    // Central bright hotspot glow to simulate the "cyan" peak on the left-center
    final hotspotPaint = Paint()
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 40 * amp.clamp(0.5, 1.5))
      ..color = const Color(0xFF00E5FF).withValues(alpha: (0.3 * amp).clamp(0.0, 0.6));

    canvas.drawCircle(
      Offset(size.width * 0.35 + sin(t * 0.7) * 20, size.height * 0.85),
      60 * amp.clamp(0.5, 1.5),
      hotspotPaint,
    );
  }

  void _drawAuroraLayer(
    Canvas canvas, Size size, double t, {
    required double yOffset,
    required double waveHeight,
    required double opacity,
    required double phaseShift,
    required double blurSigma,
  }) {
    final path = Path();
    path.moveTo(0, size.height);

    // Build organic mountain-range wave shape
    for (double x = 0; x <= size.width; x += 5) {
      final nx = x / size.width;
      
      // Combine multiple sine waves for organic peaks and valleys
      // We want a peak on the left (cyan area), a peak in the middle (blue), and a slope on the right (purple)
      final y = yOffset
          - sin(nx * pi * 1.5 + t + phaseShift) * waveHeight * 0.5
          - sin(nx * pi * 3.0 - t * 0.7 + phaseShift * 0.5) * waveHeight * 0.3
          - cos(nx * pi * 2.0 + t * 1.2) * waveHeight * 0.2;
          
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.close();

    // Gradient fill: Cyan (Left) -> Blue (Center) -> Purple (Right)
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          const Color(0xFF00BCD4).withValues(alpha: opacity), // Cyan
          const Color(0xFF2979FF).withValues(alpha: opacity), // Bright Blue
          const Color(0xFF651FFF).withValues(alpha: opacity * 0.8), // Deep Purple
        ],
        stops: const [0.1, 0.5, 0.9],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter old) {
    return old.animationValue != animationValue ||
        old.state != state ||
        old.amplitude != amplitude;
  }
}

/// A highly blurred ambient glow that sits behind the bottom buttons, 
/// matching the colors of the aurora above it.
class _AmbientGlowPainter extends CustomPainter {
  final double animationValue;
  final LiveSessionState state;
  final double amplitude;

  _AmbientGlowPainter({
    required this.animationValue,
    required this.state,
    required this.amplitude,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = animationValue * 2 * pi;

    double amp = 0.5;
    if (state == LiveSessionState.listening) {
      amp = 0.6 + (amplitude * 2.0).clamp(0.0, 1.5);
    } else if (state == LiveSessionState.aiSpeaking) {
      amp = 1.0 + sin(t) * 0.3;
    } else if (state == LiveSessionState.paused) {
      amp = 0.2;
    }

    final blurPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);

    // Cyan glow on the left
    canvas.drawCircle(
      Offset(size.width * 0.2, size.height * 0.5),
      80 * amp,
      blurPaint..color = const Color(0xFF00BCD4).withValues(alpha: 0.15 * amp),
    );

    // Blue glow in the center
    canvas.drawCircle(
      Offset(size.width * 0.5 + sin(t) * 20, size.height * 0.5),
      100 * amp,
      blurPaint..color = const Color(0xFF2979FF).withValues(alpha: 0.2 * amp),
    );

    // Purple glow on the right
    canvas.drawCircle(
      Offset(size.width * 0.8, size.height * 0.5),
      90 * amp,
      blurPaint..color = const Color(0xFF651FFF).withValues(alpha: 0.15 * amp),
    );
  }

  @override
  bool shouldRepaint(covariant _AmbientGlowPainter old) {
    return old.animationValue != animationValue ||
        old.state != state ||
        old.amplitude != amplitude;
  }
}
