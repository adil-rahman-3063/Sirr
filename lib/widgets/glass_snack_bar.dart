import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum GlassSnackBarType { info, success, warning, error }

class AppSnackBar {
  /// Show a custom glassmorphic floating SnackBar with circled edges matching the theme
  static void show(
    BuildContext context, {
    required String message,
    String? title,
    IconData? icon,
    GlassSnackBarType type = GlassSnackBarType.info,
    Duration duration = const Duration(seconds: 3),
    Widget? action,
  }) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.hideCurrentSnackBar();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    Color accentColor;
    IconData defaultIcon;

    switch (type) {
      case GlassSnackBarType.success:
        accentColor = const Color(0xFF5FAF6F);
        defaultIcon = Icons.check_circle_rounded;
        break;
      case GlassSnackBarType.warning:
        accentColor = const Color(0xFFE5A93C);
        defaultIcon = Icons.warning_amber_rounded;
        break;
      case GlassSnackBarType.error:
        accentColor = colorScheme.error;
        defaultIcon = Icons.error_outline_rounded;
        break;
      case GlassSnackBarType.info:
        accentColor = colorScheme.primary;
        defaultIcon = Icons.notifications_active_rounded;
        break;
    }

    final effectiveIcon = icon ?? defaultIcon;

    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF181824).withValues(alpha: 0.82)
                        : const Color(0xFFFFFFFF).withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.16),
                        blurRadius: 20,
                        spreadRadius: -2,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.35),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          effectiveIcon,
                          color: accentColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (title != null && title.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  title,
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            Text(
                              message,
                              style: GoogleFonts.amiri(
                                fontSize: 14,
                                height: 1.3,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.onSurface.withValues(alpha: 0.95),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (action != null) ...[
                        const SizedBox(width: 8),
                        action,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        duration: duration,
        padding: EdgeInsets.zero,
      ),
    );
  }

  static void showSuccess(
    BuildContext context,
    String message, {
    String? title,
    IconData? icon,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      message: message,
      title: title,
      icon: icon,
      type: GlassSnackBarType.success,
      duration: duration,
    );
  }

  static void showWarning(
    BuildContext context,
    String message, {
    String? title,
    IconData? icon,
    Duration duration = const Duration(seconds: 4),
  }) {
    show(
      context,
      message: message,
      title: title,
      icon: icon,
      type: GlassSnackBarType.warning,
      duration: duration,
    );
  }

  static void showInfo(
    BuildContext context,
    String message, {
    String? title,
    IconData? icon,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      message: message,
      title: title,
      icon: icon,
      type: GlassSnackBarType.info,
      duration: duration,
    );
  }

  static void showError(
    BuildContext context,
    String message, {
    String? title,
    IconData? icon,
    Duration duration = const Duration(seconds: 4),
  }) {
    show(
      context,
      message: message,
      title: title,
      icon: icon,
      type: GlassSnackBarType.error,
      duration: duration,
    );
  }
}
