import 'package:bawarii_ui/bawarii_ui.dart';
import 'package:flutter/material.dart';

import '../models/reference_workflow.dart';

/// A tappable card presenting a KYC workflow choice.
///
/// Shows an icon circle, title, subtitle (up to two lines —: the
/// previous single-line clip truncated "Afghan e-Tazkira" on a 360dp
/// screen), use-case pill chip, and chevron. Press state swaps to a
/// `trustSoft` fill with a `trust` border, 100ms.
class WorkflowCard extends StatefulWidget {
  const WorkflowCard({super.key, required this.workflow, required this.onTap});

  final ReferenceWorkflow workflow;
  final VoidCallback onTap;

  @override
  State<WorkflowCard> createState() => _WorkflowCardState();
}

class _WorkflowCardState extends State<WorkflowCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final (icon, title, subtitle, useCase) = switch (widget.workflow) {
      ReferenceWorkflow.documentOnly => (
        Icons.badge_outlined,
        'Document Only',
        'Front and back of an Afghan e-Tazkira',
        'Low-friction onboarding',
      ),
      ReferenceWorkflow.documentAndLiveness => (
        Icons.face_retouching_natural_outlined,
        'Document + Liveness',
        'Document capture plus an active selfie challenge',
        'High-assurance KYC',
      ),
    };

    return Semantics(
      label: '$title. $subtitle. $useCase.',
      button: true,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapCancel: () => _setPressed(false),
        onTapUp: (_) => _setPressed(false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          constraints: const BoxConstraints(minHeight: 96),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _pressed ? BawariiColors.trustSoft : BawariiColors.paper,
            border: Border.all(
              color: _pressed ? BawariiColors.trust : BawariiColors.hairline,
              width: _pressed ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(BawariiRadii.r20),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: BawariiColors.trustSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 22, color: BawariiColors.trust),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: BawariiTextStyles.heading),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: BawariiTextStyles.bodySmall.copyWith(
                        color: BawariiColors.ink70,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 10,
                      ),
                      decoration: BoxDecoration(
                        color: BawariiColors.trustSoft,
                        borderRadius: BorderRadius.circular(
                          BawariiRadii.pill,
                        ),
                      ),
                      child: Text(
                        useCase,
                        style: BawariiTextStyles.fine.copyWith(
                          color: BawariiColors.trust,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: BawariiColors.ink30,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
