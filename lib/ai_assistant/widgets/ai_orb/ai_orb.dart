import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'orb_state.dart';
import 'orb_blobs_painter.dart';

class AiOrb extends StatefulWidget {
  const AiOrb({
    super.key,
    this.size = 220,
    this.state = OrbState.idle,
  });

  final double size;
  final OrbState state;

  @override
  State<AiOrb> createState() => _AiOrbState();
}

class _AiOrbState extends State<AiOrb> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: OrbStateConfig.presets[widget.state]!.duration,
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant AiOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _controller.duration = OrbStateConfig.presets[widget.state]!.duration;
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cfg = OrbStateConfig.presets[widget.state]!;
    final blobs = rotateBlobHue(defaultOrbBlobs, cfg.hueShift);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value; // 0 -> 1 -> 0 (reverse: true)
          final wobble = math.sin(t * math.pi) * cfg.swirlAmplitude * 6;
          final scale = 1 + (cfg.scale - 1) * math.sin(t * math.pi);

          return Transform.scale(
            scale: scale,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Lớp 1: các mảng blob màu thật — đây là lớp DUY NHẤT
                  // tạo hình dạng "vạch vạch" của orb. Không thêm overlay
                  // dải sáng/ribbon nào khác.
                  ClipOval(
                    child: CustomPaint(
                      size: Size(widget.size, widget.size),
                      painter: OrbBlobsPainter(blobs: blobs, wobble: wobble),
                    ),
                  ),

                  // Lớp 2: Glossy highlight — vệt sáng góc trên-trái
                  IgnorePointer(
                    child: ClipOval(
                      child: Container(
                        width: widget.size,
                        height: widget.size,
                        decoration: const BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment(-0.4, -0.5),
                            radius: 0.65,
                            colors: [Colors.white38, Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Lớp 3: Rim light — viền sáng mỏng ôm rìa
                  IgnorePointer(
                    child: Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.45),
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
