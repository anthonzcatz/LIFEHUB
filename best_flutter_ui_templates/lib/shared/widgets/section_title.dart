import 'package:flutter/material.dart';
import '../../app/lifehub_theme.dart';

/// Section header used across dashboard and module screens
/// (adapted from the template's TitleView).
class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    this.actionText,
    this.onAction,
  });

  final String title;
  final String? actionText;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 24, top: 12, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: LifeHubTheme.fontName,
                fontWeight: FontWeight.w500,
                fontSize: 18,
                letterSpacing: 0.5,
                color: LifeHubTheme.lightText,
              ),
            ),
          ),
          if (actionText != null)
            InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: onAction,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Row(
                  children: [
                    Text(
                      actionText!,
                      style: const TextStyle(
                        fontFamily: LifeHubTheme.fontName,
                        fontSize: 16,
                        letterSpacing: 0.5,
                        color: LifeHubTheme.nearlyDarkBlue,
                      ),
                    ),
                    const SizedBox(
                      height: 38,
                      width: 26,
                      child: Icon(
                        Icons.arrow_forward,
                        color: LifeHubTheme.darkText,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
