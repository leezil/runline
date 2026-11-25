import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../app/app_spacing.dart';

enum AppButtonVariant { primary, outlined, text, danger }

enum AppButtonSize { medium, large }

/// Shared button for primary actions, secondary outline actions, and text links.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.icon,
    this.expand = true,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final bool expand;
  final bool isLoading;

  double get _height => switch (size) {
    AppButtonSize.medium => 48,
    AppButtonSize.large => 56,
  };

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null && !isLoading;
    final foregroundColor = switch (variant) {
      AppButtonVariant.primary => Colors.white,
      AppButtonVariant.outlined || AppButtonVariant.text => AppColors.primary,
      AppButtonVariant.danger => Colors.white,
    };

    final child = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: foregroundColor),
          )
        : icon == null
        ? Text(label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: AppSpacing.xs),
              Text(label),
            ],
          );

    final button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
        onPressed: isEnabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.subText,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: child,
      ),
      AppButtonVariant.outlined => OutlinedButton(
        onPressed: isEnabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: foregroundColor,
          disabledForegroundColor: AppColors.subText,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: child,
      ),
      AppButtonVariant.text => TextButton(
        onPressed: isEnabled ? onPressed : null,
        style: TextButton.styleFrom(foregroundColor: foregroundColor),
        child: child,
      ),
      AppButtonVariant.danger => FilledButton(
        onPressed: isEnabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFD92D20),
          foregroundColor: foregroundColor,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.subText,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: child,
      ),
    };

    final constrainedButton = SizedBox(height: _height, child: button);
    return expand ? SizedBox(width: double.infinity, child: constrainedButton) : constrainedButton;
  }
}
