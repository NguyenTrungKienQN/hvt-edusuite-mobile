import 'package:flutter/material.dart';

/// Một mảng màu (blob) trong orb — toạ độ [points] chuẩn hoá 0..1,
/// lấy trực tiếp từ phân vùng K-means + contour trên ảnh Celia gốc
/// (không phải vẽ tay/đoán). Giữ nguyên toạ độ khi tuning màu.
class OrbBlob {
  const OrbBlob(this.points, this.color, this.blurSigma);
  final List<Offset> points; // normalized 0..1
  final Color color;
  final double blurSigma;
}

/// Bộ 6 blob mặc định (idle) — trích xuất từ ảnh tham chiếu gốc.
final List<OrbBlob> defaultOrbBlobs = [
  // cam — mảng lớn phía trên/phải
  const OrbBlob([
    Offset(0.404, 0.0), Offset(0.689, 0.044), Offset(0.884, 0.209),
    Offset(0.96, 0.471), Offset(0.569, 0.44), Offset(0.462, 0.196),
    Offset(0.267, 0.28), Offset(0.209, 0.12),
  ], Color(0xFFFCC485), 14),
  // tím — thân giữa
  const OrbBlob([
    Offset(0.249, 0.369), Offset(0.511, 0.404), Offset(0.782, 0.547),
    Offset(0.689, 0.689), Offset(0.244, 0.529), Offset(0.236, 0.773),
  ], Color(0xFFCCA3F4), 14),
  // xanh cyan — đáy
  const OrbBlob([
    Offset(0.769, 0.742), Offset(0.609, 0.996), Offset(0.347, 0.996),
    Offset(0.209, 0.911), Offset(0.338, 0.916), Offset(0.244, 0.533),
  ], Color(0xFF91D1F7), 12),
  // hồng — vệt "lửa" phần trên
  const OrbBlob([
    Offset(0.507, 0.4), Offset(0.356, 0.418), Offset(0.244, 0.364),
    Offset(0.262, 0.311), Offset(0.373, 0.222), Offset(0.476, 0.213),
  ], Color(0xFFF593C6), 10),
  // hồng — vệt "lửa" phần dưới-trái (cùng màu, nối liền phần trên)
  const OrbBlob([
    Offset(0.178, 0.644), Offset(0.271, 0.876), Offset(0.182, 0.84),
    Offset(0.058, 0.667), Offset(0.173, 0.431),
  ], Color(0xFFF593C6), 10),
  // xanh-tím đậm — túi nhỏ dưới-phải
  const OrbBlob([
    Offset(0.88, 0.773), Offset(0.649, 0.942), Offset(0.773, 0.782),
    Offset(0.72, 0.667), Offset(0.791, 0.52), Offset(0.933, 0.498),
  ], Color(0xFF8780FA), 10),
];

/// Xoay hue toàn bộ danh sách blob — dùng để sinh biến thể màu theo state.
List<OrbBlob> rotateBlobHue(List<OrbBlob> blobs, double degrees) {
  return blobs.map((b) {
    final hsl = HSLColor.fromColor(b.color);
    final newHue = (hsl.hue + degrees) % 360;
    final color = hsl.withHue(newHue < 0 ? newHue + 360 : newHue).toColor();
    return OrbBlob(b.points, color, b.blurSigma);
  }).toList();
}

class OrbBlobsPainter extends CustomPainter {
  OrbBlobsPainter({required this.blobs, required this.wobble});

  final List<OrbBlob> blobs;
  final double wobble; // -1..1, tạo chuyển động nhẹ cho các blob

  /// Vẽ đường cong mượt xuyên qua danh sách điểm (kỹ thuật smooth-path
  /// chuẩn cho Canvas: control point = điểm thật, end point = trung điểm
  /// tới điểm kế tiếp).
  Path _smoothPath(List<Offset> pts) {
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var i = 0; i < pts.length; i++) {
      final cur = pts[i];
      final next = pts[(i + 1) % pts.length];
      final mid = Offset((cur.dx + next.dx) / 2, (cur.dy + next.dy) / 2);
      path.quadraticBezierTo(cur.dx, cur.dy, mid.dx, mid.dy);
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // nền lót nhẹ để không hở khoảng trắng ở biên giáp giữa các blob
    final basePaint = Paint()
      ..shader = LinearGradient(
        colors: [blobs.first.color, blobs[2].color],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, basePaint);

    for (var i = 0; i < blobs.length; i++) {
      final b = blobs[i];
      // mỗi blob dao động nhẹ độc lập theo index để không bị "đơ"
      final dx = wobble * 0.015 * (i.isEven ? 1 : -1);
      final dy = wobble * 0.012 * (i.isEven ? -1 : 1);
      final offsets = b.points
          .map((p) => Offset((p.dx + dx) * size.width, (p.dy + dy) * size.height))
          .toList();
      final path = _smoothPath(offsets);
      final paint = Paint()
        ..color = b.color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, b.blurSigma);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant OrbBlobsPainter oldDelegate) {
    return oldDelegate.wobble != wobble || oldDelegate.blobs != blobs;
  }
}
