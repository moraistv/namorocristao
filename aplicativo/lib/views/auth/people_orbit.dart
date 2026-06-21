import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Ilustração "órbita de pessoas" da tela de login (estilo radar),
/// com as cores do Namoro Cristão (dourado + navy).
class PeopleOrbit extends StatelessWidget {
  final double size;
  const PeopleOrbit({super.key, this.size = 300});

  static const _gold = Color(0xFFD4AF37);
  static const _navy = Color(0xFF111D40);

  // Avatares ao redor: (ângulo em graus, diâmetro, url).
  static const List<List<dynamic>> _people = [
    [268, 60, "https://randomuser.me/api/portraits/men/32.jpg"],
    [212, 64, "https://randomuser.me/api/portraits/women/68.jpg"],
    [168, 52, "https://randomuser.me/api/portraits/women/65.jpg"],
    [124, 50, "https://randomuser.me/api/portraits/men/45.jpg"],
    [80, 56, "https://randomuser.me/api/portraits/women/44.jpg"],
    [36, 54, "https://randomuser.me/api/portraits/women/12.jpg"],
    [340, 50, "https://randomuser.me/api/portraits/men/76.jpg"],
  ];

  Offset _pos(double angleDeg, double radius) {
    final rad = angleDeg * math.pi / 180;
    final c = size / 2;
    return Offset(c + radius * math.cos(rad), c - radius * math.sin(rad));
  }

  @override
  Widget build(BuildContext context) {
    // Mesmo raio da linha tracejada, para os avatares ficarem centrados nela.
    final orbitR = size / 2 - 1;
    final children = <Widget>[];

    // Órbita tracejada.
    children.add(Positioned.fill(
      child: CustomPaint(painter: _DashedCirclePainter(_gold.withOpacity(0.35))),
    ));

    // Círculos concêntricos centrais (efeito radar).
    children.add(_circle(size * 0.62, _gold.withOpacity(0.10)));
    children.add(_circle(size * 0.46, Colors.white));
    children.add(_circle(size * 0.34, _gold.withOpacity(0.18)));
    children.add(_circle(size * 0.24, Colors.white));

    // Avatar central.
    children.add(_avatar(
        _pos(0, 0), size * 0.20, "https://randomuser.me/api/portraits/women/79.jpg",
        ring: true));

    // Avatares ao redor.
    for (final p in _people) {
      final angle = (p[0] as num).toDouble();
      final d = (p[1] as num).toDouble();
      children.add(_avatar(_pos(angle, orbitR), d, p[2] as String));
    }

    // Pino decorativo (dourado) no topo-direita.
    final pinPos = _pos(50, orbitR * 1.12);
    children.add(Positioned(
      left: pinPos.dx - 14,
      top: pinPos.dy - 14,
      child: _decoCircle(28, const Icon(Icons.location_on, color: _gold, size: 18)),
    ));

    // Balão de conversa embaixo-esquerda.
    final chatPos = _pos(200, orbitR * 1.14);
    children.add(Positioned(
      left: chatPos.dx - 18,
      top: chatPos.dy - 18,
      child: _decoCircle(
          36,
          const Icon(Icons.more_horiz, color: _navy, size: 20),
          color: _gold.withOpacity(0.85)),
    ));

    return SizedBox(
      width: size,
      height: size,
      child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: children),
    );
  }

  Widget _circle(double d, Color color) => Center(
        child: Container(
          width: d,
          height: d,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      );

  Widget _avatar(Offset center, double d, String url, {bool ring = false}) {
    return Positioned(
      left: center.dx - d / 2,
      top: center.dy - d / 2,
      child: Container(
        width: d,
        height: d,
        padding: EdgeInsets.all(ring ? 5 : 3),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            placeholder: (_, __) =>
                Container(color: _gold.withOpacity(0.15)),
            errorWidget: (_, __, ___) => Container(
                color: _gold.withOpacity(0.15),
                child: const Icon(Icons.person, color: Colors.white)),
          ),
        ),
      ),
    );
  }

  Widget _decoCircle(double d, Widget child, {Color color = Colors.white}) =>
      Container(
        width: d,
        height: d,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 8,
                offset: const Offset(0, 3)),
          ],
        ),
        child: child,
      );
}

class _DashedCirclePainter extends CustomPainter {
  final Color color;
  _DashedCirclePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 1;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    const dash = 6.0, gap = 7.0;
    final circumference = 2 * math.pi * radius;
    final count = (circumference / (dash + gap)).floor();
    final dashAngle = dash / radius;
    final gapAngle = gap / radius;
    double a = 0;
    final rect = Rect.fromCircle(center: center, radius: radius);
    for (int i = 0; i < count; i++) {
      canvas.drawArc(rect, a, dashAngle, false, paint);
      a += dashAngle + gapAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter old) => old.color != color;
}
