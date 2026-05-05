import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class FieldLabel extends StatelessWidget {
  final String text;
  final bool requiredField;

  const FieldLabel({
    super.key,
    required this.text,
    this.requiredField = false,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: AppColors.textDark,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        children: requiredField
            ? const [
                TextSpan(
                  text: '*',
                  style: TextStyle(
                    color: AppColors.requiredRed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ]
            : [],
      ),
    );
  }
}