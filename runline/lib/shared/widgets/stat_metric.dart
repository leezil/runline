import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../app/app_spacing.dart';

class StatMetric extends StatelessWidget {
  const StatMetric({super.key, required this.label, required this.value, this.unit});

  final String label;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: textTheme.bodySmall),
        const SizedBox(height: AppSpacing.xxs),
        RichText(
          text: TextSpan(
            text: value,
            style: textTheme.titleMedium?.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
            children: [
              if (unit != null)
                TextSpan(
                  text: ' $unit',
                  style: textTheme.bodySmall?.copyWith(color: AppColors.subText),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
