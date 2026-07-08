import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:pms_app/features/auth/theme/needil_auth_theme.dart';

/// Horizontal divider with centred text, e.g. "or continue with".
///
/// Uses [NeedilAuthTheme] for line and text colours, with 24 px vertical
/// padding for comfortable spacing within auth forms.
class AuthDivider extends StatelessWidget {
  /// The text displayed in the centre of the divider line.
  final String text;

  const AuthDivider({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final dividerColor = NeedilAuthTheme.divider(context);
    final textStyle = GoogleFonts.inter(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: NeedilAuthTheme.textSecondary(context),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: dividerColor,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(text, style: textStyle),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: dividerColor,
            ),
          ),
        ],
      ),
    );
  }
}
