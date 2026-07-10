import 'package:flutter/material.dart';
import 'package:pms_app/core/widgets/app_toast.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:pms_app/features/auth/theme/needil_auth_theme.dart';

/// Google sign-in button with an outlined style and "Coming Soon" badge.
///
/// Tapping it shows a [SnackBar] explaining the feature is not yet available.
/// Uses the official Google brand colours for the 'G' indicator.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({super.key});

  @override
  Widget build(BuildContext context) {
    final borderColor = NeedilAuthTheme.border(context);
    final textColor = NeedilAuthTheme.text(context);
    final primary = NeedilAuthTheme.primary(context);

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: () {
          AppToast.show('Google Sign-In will be available in a future update.', duration: const Duration(seconds: 3));
        },
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Google 'G' logo — multicolour ─────────────────────────
            SizedBox(
              width: 20,
              height: 20,
              child: CustomPaint(painter: _GoogleGPainter()),
            ),
            const SizedBox(width: 12),

            // ── Label ─────────────────────────────────────────────────
            Text(
              'Continue with Google',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),

            const SizedBox(width: 10),

            // ── Coming soon badge — green ─────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: primary.withValues(alpha: 0.08),
              ),
              child: Text(
                'Coming Soon',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints a simplified Google 'G' logo with the four brand colours.
class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 3.5;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // Blue (top-right arc)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      -0.9, // start angle
      1.2,  // sweep
      false,
      paint,
    );

    // Green (bottom-right arc)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      0.3,
      1.2,
      false,
      paint,
    );

    // Yellow (bottom-left arc)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      1.5,
      1.0,
      false,
      paint,
    );

    // Red (top-left arc)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      2.5,
      0.95,
      false,
      paint,
    );

    // Horizontal bar of the G
    final barPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = const Color(0xFF4285F4)
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(center.dx, center.dy),
      Offset(center.dx + radius - strokeWidth, center.dy),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
