import 'package:bawarii_ui/bawarii_ui.dart';
import 'package:flutter/material.dart';

import '../../theme/ref_colors.dart';

/// Banner severities. Every severity uses
/// a text-on-tint ink, never the saturated semantic token, on its soft fill.
enum RbBannerSeverity { error, warning, info }

class _SeverityStyle {
  const _SeverityStyle(this.fill, this.border, this.text);
  final Color fill;
  final Color border;
  final Color text;
}

const _severityStyles = {
  RbBannerSeverity.error: _SeverityStyle(
    BawariiColors.errorSoft,
    BawariiColors.error,
    RefColors.errorInk,
  ),
  RbBannerSeverity.warning: _SeverityStyle(
    BawariiColors.warningSoft,
    BawariiColors.warning,
    RefColors.warningInk,
  ),
  RbBannerSeverity.info: _SeverityStyle(
    BawariiColors.trustSoft,
    BawariiColors.trust,
    BawariiColors.trust,
  ),
};

/// A severity-coloured inline banner.
///
/// [rail] renders a 4dp leading colour bar instead of a full border — used
/// for the unverified-details and flagged-fields banners.
class RbBanner extends StatelessWidget {
  const RbBanner({
    super.key,
    required this.severity,
    required this.title,
    this.body,
    this.icon,
    this.action,
    this.onAction,
    this.rail = false,
  });

  final RbBannerSeverity severity;
  final String title;
  final String? body;
  final IconData? icon;
  final String? action;
  final VoidCallback? onAction;
  final bool rail;

  @override
  Widget build(BuildContext context) {
    final style = _severityStyles[severity]!;
    return Semantics(
      liveRegion: true,
      child: Container(
        decoration: BoxDecoration(
          color: style.fill,
          borderRadius: BorderRadius.circular(BawariiRadii.r10),
          border: rail ? null : Border.all(color: style.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (rail) Container(width: 4, color: style.border),
              Expanded(
                child: Padding(
                  padding: rail
                      ? const EdgeInsets.all(14)
                      : const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        icon ?? Icons.warning_amber_rounded,
                        size: rail ? 18 : 16,
                        color: style.text,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: BawariiTextStyles.bodySmall.copyWith(
                                color: style.text,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (body != null) ...[
                              const SizedBox(height: 3),
                              Text(
                                body!,
                                style: BawariiTextStyles.fine.copyWith(
                                  color: style.text,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (action != null) ...[
                        const SizedBox(width: 8),
                        _BannerAction(
                          label: action!,
                          color: style.text,
                          onTap: onAction,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BannerAction extends StatelessWidget {
  const _BannerAction({required this.label, required this.color, this.onTap});

  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Center(
            child: Text(
              label,
              style: BawariiTextStyles.fine.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
