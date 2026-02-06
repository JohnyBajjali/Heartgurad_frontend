import 'dart:ui';
import 'package:flutter/material.dart';

class HomeLandingScreen extends StatelessWidget {
  final VoidCallback? onOpenPatients;
  final VoidCallback? onOpenUpload;
  final VoidCallback? onOpenGallery;

  const HomeLandingScreen({
    super.key,
    this.onOpenPatients,
    this.onOpenUpload,
    this.onOpenGallery,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final openPatientsFlow = onOpenPatients ?? onOpenUpload;

    return SingleChildScrollView(
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _SoftBackgroundPainter(
                primary: cs.primary,
                secondary: cs.secondary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1160),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeroCard(
                      title: 'ECG Analyzer',
                      subtitle:
                      'Manage patients, upload ECG documents, and explore 12-lead ECG examples.',
                      onOpenPatients: openPatientsFlow,
                      onOpenUpload: openPatientsFlow,
                      onOpenGallery: onOpenGallery,
                    ),
                    const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (context, c) {
                        final wide = c.maxWidth >= 980;
                        final w = wide ? (c.maxWidth - 32) / 3 : c.maxWidth;

                        return Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            _FeatureCard(
                              width: w,
                              icon: Icons.people,
                              title: 'Patients',
                              text:
                              'Browse existing patients, create new ones, and open patient dashboards.',
                              onTap: openPatientsFlow,
                            ),
                            _FeatureCard(
                              width: w,
                              icon: Icons.document_scanner,
                              title: 'Scan & Upload',
                              text:
                              'Capture ECG images, crop them, and upload them to your backend in seconds.',
                              onTap: openPatientsFlow,
                            ),
                            _FeatureCard(
                              width: w,
                              icon: Icons.monitor_heart,
                              title: '12-Lead Gallery',
                              text:
                              'Explore curated 12-lead examples for learning and comparison.',
                              onTap: onOpenGallery,
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    const _InfoCard(
                      title: 'About ECG Analysis',
                      text:
                      'An ECG (electrocardiogram) records the electrical activity of the heart. '
                          'This application helps you organize patient ECG uploads and provides reference 12-lead examples.',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color _glassBg(BuildContext context, {double alphaLight = 0.78, double alphaDark = 0.22}) {
  final cs = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return (isDark ? cs.surface.withValues(alpha: alphaDark) : cs.surface.withValues(alpha: alphaLight));
}

Color _glassBorder(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return cs.outlineVariant.withValues(alpha: 0.55);
}

class _HeroCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onOpenPatients;
  final VoidCallback? onOpenUpload;
  final VoidCallback? onOpenGallery;

  const _HeroCard({
    required this.title,
    required this.subtitle,
    this.onOpenPatients,
    this.onOpenUpload,
    this.onOpenGallery,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: _glassBg(context),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: _glassBorder(context)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 22,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: const SizedBox(height: 255),
            ),
          ),
          Positioned(
            left: -40,
            top: -40,
            bottom: -40,
            width: 240,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomLeft,
                  colors: [
                    cs.primary.withValues(alpha: 0.95),
                    cs.secondary.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: -120,
            top: -120,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.secondary.withValues(alpha: 0.10),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: cs.primary.withValues(alpha: 0.18),
                    border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
                  ),
                  child: Icon(Icons.monitor_heart, color: cs.onPrimary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                          letterSpacing: -0.4,
                          color: cs.onSurface.withValues(alpha: 0.95),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 15.5,
                          height: 1.35,
                          color: cs.onSurface.withValues(alpha: 0.75),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _ActionChip(icon: Icons.people, text: 'Patients', onTap: onOpenPatients),
                          _ActionChip(icon: Icons.upload_file, text: 'ECG Upload', onTap: onOpenUpload),
                          _ActionChip(icon: Icons.menu_book, text: '12-Lead Gallery', onTap: onOpenGallery),
                        ],
                      ),
                      const SizedBox(height: 18),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          height: 88,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: _glassBg(context, alphaLight: 0.80, alphaDark: 0.20),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: _glassBorder(context)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.10),
                                blurRadius: 12,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: CustomPaint(painter: _EcgWavePainter()),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatefulWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  const _ActionChip({
    required this.icon,
    required this.text,
    this.onTap,
  });

  @override
  State<_ActionChip> createState() => _ActionChipState();
}

class _ActionChipState extends State<_ActionChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _hover ? cs.surface : cs.surfaceVariant.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
            boxShadow: [
              if (_hover)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text(widget.text, style: TextStyle(fontWeight: FontWeight.w800, color: cs.onSurface)),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, size: 18, color: cs.onSurface.withValues(alpha: 0.40)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatefulWidget {
  final double width;
  final IconData icon;
  final String title;
  final String text;
  final VoidCallback? onTap;

  const _FeatureCard({
    required this.width,
    required this.icon,
    required this.title,
    required this.text,
    this.onTap,
  });

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      width: widget.width,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(22),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _glassBg(context, alphaLight: 0.92, alphaDark: 0.18),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _glassBorder(context)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: _hover ? 0.14 : 0.10),
                  blurRadius: _hover ? 22 : 14,
                  offset: Offset(0, _hover ? 12 : 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        cs.primary.withValues(alpha: 0.16),
                        cs.secondary.withValues(alpha: 0.12),
                      ],
                    ),
                    border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.50)),
                  ),
                  child: Icon(widget.icon, color: cs.primary),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: cs.onSurface),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: cs.onSurface.withValues(alpha: 0.40)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.text,
                  style: TextStyle(height: 1.35, color: cs.onSurface.withValues(alpha: 0.75)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String text;

  const _InfoCard({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _glassBg(context, alphaLight: 0.92, alphaDark: 0.18),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _glassBorder(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: cs.onSurface)),
          const SizedBox(height: 8),
          Text(text, style: TextStyle(height: 1.4, color: cs.onSurface.withValues(alpha: 0.75))),
        ],
      ),
    );
  }
}

class _SoftBackgroundPainter extends CustomPainter {
  final Color primary;
  final Color secondary;

  _SoftBackgroundPainter({required this.primary, required this.secondary});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..style = PaintingStyle.fill;

    p.color = primary.withValues(alpha: 0.06);
    canvas.drawCircle(Offset(size.width * 0.12, size.height * 0.10), 220, p);

    p.color = secondary.withValues(alpha: 0.05);
    canvas.drawCircle(Offset(size.width * 0.95, size.height * 0.22), 260, p);

    p.color = primary.withValues(alpha: 0.04);
    canvas.drawCircle(Offset(size.width * 0.30, size.height * 0.95), 320, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EcgWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Use a neutral dark-mode friendly color
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.16);

    const step = 18.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final wavePaint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.90)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final midY = size.height * 0.55;
    path.moveTo(0, midY);

    double x = 0;
    while (x < size.width) {
      path.lineTo(x + 10, midY);
      path.lineTo(x + 18, midY - 6);
      path.lineTo(x + 24, midY + 10);
      path.lineTo(x + 28, midY - 26);
      path.lineTo(x + 34, midY + 18);
      path.lineTo(x + 44, midY);
      path.lineTo(x + 62, midY);
      x += 68;
    }

    canvas.drawPath(path, wavePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}