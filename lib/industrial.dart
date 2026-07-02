import 'package:flutter/material.dart';

/// Industrial control-terminal design tokens + shared chrome for TGT Scan.
///
/// The look is a ruggedized handheld HMI: gunmetal enclosures, recessed
/// instrument fields, safety-amber accents and hazard striping.
class Ind {
  Ind._();

  static const bg = Color(0xFF14181C); // gunmetal enclosure
  static const panel = Color(0xFF1C2228); // raised panel
  static const inset = Color(0xFF0E1216); // recessed field well
  static const border = Color(0xFF313A44);
  static const amber = Color(0xFFFFB100); // safety amber — the one accent
  static const amberDim = Color(0xFF8A6200);
  static const amberTint = Color(0xFF1F1B10); // required-field wash
  static const text = Color(0xFFE6EBEF);
  static const textDim = Color(0xFF7E8B98);
  static const ok = Color(0xFF3FB96A);
  static const danger = Color(0xFFFF5247);

  static const mono = 'monospace';

  /// Stencil caption used on every panel header and field label.
  static const label = TextStyle(
    fontSize: 10.5,
    fontWeight: FontWeight.w700,
    color: textDim,
    letterSpacing: 1.6,
  );
}

/// 45° amber/black hazard striping — the app's signature accent.
class HazardStripe extends StatelessWidget {
  final double height;
  const HazardStripe({super.key, this.height = 6});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _HazardPainter()),
    );
  }
}

class _HazardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Ind.inset);
    final amber = Paint()..color = Ind.amber;
    const w = 13.0;
    final h = size.height;
    for (double x = -h; x < size.width + h; x += w * 2) {
      final p = Path()
        ..moveTo(x, h)
        ..lineTo(x + h, 0)
        ..lineTo(x + h + w, 0)
        ..lineTo(x + w, h)
        ..close();
      canvas.drawPath(p, amber);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A labelled instrument panel: stencil header bar + bordered body.
class IndPanel extends StatelessWidget {
  final String label;
  final Widget child;
  final Widget? trailing;
  const IndPanel({
    super.key,
    required this.label,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Ind.panel,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Ind.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Ind.border)),
            ),
            child: Row(
              children: [
                Container(width: 3, height: 12, color: Ind.amber),
                const SizedBox(width: 8),
                Text(label, style: Ind.label.copyWith(color: Ind.text)),
                const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(10), child: child),
        ],
      ),
    );
  }
}

/// Glowing status LED + label, e.g. ONLINE / OFFLINE / SYNC.
class StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const StatusPill({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Ind.inset,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Ind.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color, blurRadius: 6, spreadRadius: 0.5),
              ],
            ),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              fontFamily: Ind.mono,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
