import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BrandPanel extends StatelessWidget {
  const BrandPanel({super.key});

  static const _bg = Color(0xFFF8F0EA);
  static const _primary = Color(0xFF0F5D4F);
  static const _textDark = Color(0xFF161616);
  static const _textMuted = Color(0xFF6F6F6F);
  static const _iconBg = Color(0xFFEFECE4); // Soft cream

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 900;

    final panel = Container(
      decoration: const BoxDecoration(
        color: _bg,
      ),
      clipBehavior: Clip.hardEdge, // Prevent background image from overflowing into the login card
      child: Stack(
        children: [
          // ── Background Image (Monitor, Podium, Leaf, Needle) ──
          if (isDesktop)
            Positioned(
              right: -130, // Clean cutoff on the right of the brand panel
              bottom: -20, // Sit nicely near the bottom
              width: width * 0.50, // Increased size to 50% of the screen width
              child: Image.asset(
                'assets/images/needil-loginbg.png',
                fit: BoxFit.contain,
                alignment: Alignment.bottomRight,
                errorBuilder: (context, error, stackTrace) => const SizedBox(),
              ),
            ),

          // ── Main Content ──
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(
                left: isDesktop ? width * 0.04 : 32, // Decreased margin slightly
                right: isDesktop ? width * 0.13 : 32, // Widen text column slightly
                top: isDesktop ? 32 : 24, // Upper margin starts slightly before (higher)
                bottom: isDesktop ? 32 : 24,
              ),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Centered Logo & Subtitle Block ──
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/needil_logo_cropped.png',
                          height: 42, // Slightly bigger (was 38)
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Text(
                              'needil',
                              style: GoogleFonts.inter(
                                fontSize: 42,
                                fontWeight: FontWeight.w700,
                                color: _primary,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '— CLINIC MANAGEMENT —',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2.5,
                            color: _textMuted,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),

                    // ── Hero Heading ──
                    RichText(
                        text: TextSpan(
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 68, // Reduced by 5% (from 72 to 68)
                            fontWeight: FontWeight.w700,
                            color: _textDark,
                            height: 0.95,
                            letterSpacing: -2.0,
                          ),
                          children: [
                            const TextSpan(text: 'Less paperwork.\n'),
                            const TextSpan(text: 'More '),
                            TextSpan(
                              text: 'patient care.',
                              style: GoogleFonts.cormorantGaramond(
                                fontSize: 68, // Reduced by 5% (from 72 to 68)
                                fontWeight: FontWeight.w700,
                                fontStyle: FontStyle.italic,
                                color: _primary,
                                height: 0.95,
                                letterSpacing: -2.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),

                    // ── Paragraph ──
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Text(
                        'Appointments, patient records, treatments '
                        'and analytics—organized in one simple, '
                        'secure workspace.',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w400,
                          color: _textMuted,
                          height: 1.75,
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Features ──
                    const _FeatureItem(
                      icon: Icons.calendar_today_outlined,
                      title: 'Appointment Scheduling',
                      subtitle: 'Smart calendar with real-time availability',
                    ),
                    const SizedBox(height: 12),
                    const _FeatureItem(
                      icon: Icons.people_outline_rounded,
                      title: 'Patient Management',
                      subtitle: 'All patient records at your fingertips',
                    ),
                    const SizedBox(height: 12),
                    const _FeatureItem(
                      icon: Icons.bar_chart_outlined,
                      title: 'Clinic Analytics',
                      subtitle: 'Insights to grow your practice',
                    ),

                    const SizedBox(height: 40),

                    // ── Trust Badge ──
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: const Color(0xFFE8E6E2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock_outline_rounded,
                              size: 16, color: _textMuted),
                          const SizedBox(width: 8),
                          Text(
                            'Secure  ·  Reliable  ·  Private',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: _textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (isDesktop) {
      return Hero(
        tag: 'auth_brand_panel',
        child: Material(
          type: MaterialType.transparency,
          child: panel,
        ),
      );
    }
    return panel;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Feature Item Component
// ─────────────────────────────────────────────────────────────────────────────

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: BrandPanel._iconBg,
          ),
          child: Icon(
            icon,
            size: 20,
            color: BrandPanel._primary,
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: BrandPanel._textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: BrandPanel._textMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
