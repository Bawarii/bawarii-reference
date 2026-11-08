import 'package:bawarii_ui/bawarii_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/reference_workflow.dart';
import '../theme/ref_colors.dart';
import '../theme/ref_text_styles.dart';
import '../utils/backend_errors.dart';
import '../widgets/primitives/test_environment_strip.dart';
import 'pre_capture_screen.dart';

/// Canonical error codes for the reference app (the complete error taxonomy: nine codes; six existed, three are new here:
/// [offline], [systemBusy], [retakeExhausted]; a tenth, [unknown], is the
/// catch-all).
enum ReferenceErrorCode {
  /// Camera permission was denied or permanently denied.
  cameraUnavailable,

  /// The API key is invalid or missing (403 from /start_kyc or /result).
  unauthorisedKey,

  /// The prefill endpoint returned 403 — tenant not opted in.
  prefillNotEnabled,

  /// A network error prevented session creation or result retrieval.
  networkError,

  /// The device has no connectivity.
  offline,

  /// HTTP 503 / `OCR_BUSY` via the SDK's `onError`.
  systemBusy,

  /// The session expired and re-initialisation failed.
  sessionExpired,

  /// The SDK reports the retake budget exhausted.
  retakeExhausted,

  /// The SDK raised any other `BawariiKycError`.
  sdkError,

  /// Catch-all for anything not covered above.
  unknown,
}

class _ErrorContent {
  const _ErrorContent({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
    required this.ctaLabel,
    required this.ctaAction,
    this.noSecondary = false,
  });

  final IconData icon;

  /// : severity-appropriate, not uniformly `error` — `trust` for
  /// permission requests and capacity states, `warning` for recoverable,
  /// `error` for genuine failures.
  final Color iconColor;
  final String title;
  final String body;
  final String ctaLabel;
  final VoidCallback ctaAction;
  final bool noSecondary;
}

/// S5 — full-screen error display with a contextual action button and a
/// collapsed, developer-facing "Error details" disclosure.
///
/// For [ReferenceErrorCode.cameraUnavailable], the CTA opens the OS settings
/// so the user can grant the permission without leaving to Settings manually.
class ErrorScreen extends StatefulWidget {
  const ErrorScreen({
    super.key,
    required this.errorCode,
    this.workflow,
    this.exceptionMessage,
    this.sessionId,
    this.retryAfterSeconds,
  });

  final ReferenceErrorCode errorCode;

  /// When non-null, a "Try again" button navigates back with the given workflow.
  final ReferenceWorkflow? workflow;

  /// Raw exception message — shown only inside the collapsed "Error details"
  /// disclosure, never unconditionally.
  final String? exceptionMessage;

  /// Shown alongside the raw exception in "Error details", when known.
  final String? sessionId;

  /// For [ReferenceErrorCode.systemBusy] — overrides the default 8s first
  /// retry delay when the platform supplied a `Retry-After`.
  final int? retryAfterSeconds;

  @override
  State<ErrorScreen> createState() => _ErrorScreenState();
}

class _ErrorScreenState extends State<ErrorScreen> {
  bool _detailsOpen = false;

  @override
  Widget build(BuildContext context) {
    final content = _contentFor(context, widget.errorCode, widget.workflow);

    return Scaffold(
      // — no app bar. Full-bleed state.
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              const TestEnvironmentStrip(),
              const Spacer(),
              Semantics(
                liveRegion: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ExcludeSemantics(
                      child: Icon(content.icon, size: 64, color: content.iconColor),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      content.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: BawariiTextStyles.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      content.body,
                      textAlign: TextAlign.center,
                      maxLines: 4,
                      style: BawariiTextStyles.body.copyWith(color: BawariiColors.ink70),
                    ),
                  ],
                ),
              ),
              if (widget.errorCode == ReferenceErrorCode.systemBusy) ...[
                const SizedBox(height: 16),
                _RetryCountdown(
                  initialSeconds: widget.retryAfterSeconds ?? capacityRetryDelaysSeconds.first,
                ),
              ],
              const SizedBox(height: 16),
              _ErrorDetailsDisclosure(
                open: _detailsOpen,
                onToggle: () => setState(() => _detailsOpen = !_detailsOpen),
                exceptionMessage: widget.exceptionMessage ?? _defaultDetailFor(widget.errorCode),
                sessionId: widget.sessionId,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: content.ctaAction,
                  child: Text(content.ctaLabel),
                ),
              ),
              if (!content.noSecondary) ...[
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                    child: Text(
                      'Return to home',
                      style: BawariiTextStyles.body.copyWith(color: BawariiColors.ink70),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  String? _defaultDetailFor(ReferenceErrorCode code) => switch (code) {
    ReferenceErrorCode.cameraUnavailable =>
      'PlatformException(camera_permission_denied, User denied camera '
          'access, null, null)',
    ReferenceErrorCode.unauthorisedKey => 'HTTP 403 · {"detail":"invalid_api_key"}',
    ReferenceErrorCode.prefillNotEnabled =>
      'HTTP 403 · {"detail":"prefill_not_enabled"}',
    ReferenceErrorCode.networkError =>
      'DioException [connection error]: SocketException: Connection refused',
    ReferenceErrorCode.offline => 'ConnectivityResult.none',
    ReferenceErrorCode.systemBusy => 'HTTP 503 · {"detail":"OCR_BUSY"}',
    ReferenceErrorCode.sessionExpired => 'BawariiKycError(session_expired)',
    ReferenceErrorCode.retakeExhausted =>
      'BawariiKycError(retake_budget_exhausted)',
    ReferenceErrorCode.sdkError => 'BawariiKycError(capture_interrupted)',
    ReferenceErrorCode.unknown => null,
  };

  _ErrorContent _contentFor(
    BuildContext context,
    ReferenceErrorCode code,
    ReferenceWorkflow? workflow,
  ) {
    void pop() => Navigator.of(context).popUntil((r) => r.isFirst);

    // — recoverable states return to S2 with the same workflow when
    // it's known; only a terminal (config/auth) or workflow-unknown state
    // falls back to S1.
    void retry() {
      if (workflow == null) {
        pop();
        return;
      }
      Navigator.of(context).pushAndRemoveUntil<void>(
        MaterialPageRoute<void>(
          builder: (_) => PreCaptureScreen(workflow: workflow),
        ),
        (route) => route.isFirst,
      );
    }

    return switch (code) {
      ReferenceErrorCode.cameraUnavailable => _ErrorContent(
        icon: Icons.no_photography_outlined,
        iconColor: BawariiColors.trust,
        title: 'Camera access is required',
        body: 'Bawarii needs your camera to photograph the document. You '
            'can enable it in Settings.',
        ctaLabel: 'Open Settings',
        ctaAction: openAppSettings,
      ),
      ReferenceErrorCode.unauthorisedKey => _ErrorContent(
        icon: Icons.key_off_outlined,
        iconColor: RefColors.errorInk,
        title: 'API key was rejected',
        body: "The reference backend's API key was refused by the Bawarii "
            'platform. Check the BAWARII_API_KEY value in your backend '
            'configuration.',
        ctaLabel: 'Return to home',
        ctaAction: pop,
        noSecondary: true,
      ),
      ReferenceErrorCode.prefillNotEnabled => _ErrorContent(
        icon: Icons.toggle_off_outlined,
        iconColor: RefColors.warningInk,
        title: 'Prefill is not enabled',
        body: 'This tenant does not have field prefill enabled. Enable it '
            'for your dev tenant to see extracted fields before the '
            'verdict.',
        ctaLabel: 'Continue to result',
        ctaAction: pop,
      ),
      ReferenceErrorCode.networkError => _ErrorContent(
        icon: Icons.cloud_off_outlined,
        iconColor: RefColors.errorInk,
        title: 'Cannot reach the verification service',
        body: 'We could not connect to the Bawarii service. Check that the '
            'backend is running and that this device is on the same '
            'network.',
        ctaLabel: 'Retry',
        ctaAction: retry,
      ),
      ReferenceErrorCode.offline => _ErrorContent(
        icon: Icons.wifi_off,
        iconColor: RefColors.warningInk,
        title: "You're offline",
        body: 'Connect to the internet to run a verification.',
        ctaLabel: 'Retry',
        ctaAction: retry,
      ),
      ReferenceErrorCode.systemBusy => _ErrorContent(
        icon: Icons.hourglass_empty,
        iconColor: BawariiColors.trust,
        title: 'Our verification service is busy',
        body: 'Your document was received and is safe. This is a capacity '
            'limit on our side, not a problem with your photo.',
        ctaLabel: 'Try again',
        ctaAction: retry,
      ),
      ReferenceErrorCode.sessionExpired => _ErrorContent(
        icon: Icons.timer_off_outlined,
        iconColor: RefColors.warningInk,
        title: 'Your session expired',
        body: 'Verification sessions are short-lived for security. '
            'Starting a new one takes a moment.',
        ctaLabel: 'Start a new session',
        ctaAction: retry,
      ),
      ReferenceErrorCode.retakeExhausted => _ErrorContent(
        icon: Icons.filter_center_focus_outlined,
        iconColor: RefColors.warningInk,
        title: 'We could not get a readable image',
        body: 'After several attempts the document still could not be '
            'read. Try again with the card on a flat, dark surface, away '
            'from direct light.',
        ctaLabel: 'Try again',
        ctaAction: retry,
      ),
      ReferenceErrorCode.sdkError => _ErrorContent(
        icon: Icons.error_outline,
        iconColor: RefColors.errorInk,
        title: 'Capture could not be completed',
        body: 'Something interrupted the capture. Your session is still '
            'valid — you can try again.',
        ctaLabel: 'Try again',
        ctaAction: retry,
      ),
      ReferenceErrorCode.unknown => _ErrorContent(
        icon: Icons.help_outline,
        iconColor: RefColors.errorInk,
        title: 'Something went wrong',
        body: 'An unexpected error occurred. The details below may help '
            'your integration team.',
        ctaLabel: 'Retry',
        ctaAction: retry,
      ),
    };
  }
}

class _RetryCountdown extends StatelessWidget {
  const _RetryCountdown({required this.initialSeconds});

  final int initialSeconds;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(BawariiColors.trust),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Retrying automatically in ${initialSeconds}s · attempt 1 of '
          '${capacityRetryDelaysSeconds.length}',
          style: BawariiTextStyles.fine.copyWith(color: BawariiColors.ink70),
        ),
      ],
    );
  }
}

class _ErrorDetailsDisclosure extends StatelessWidget {
  const _ErrorDetailsDisclosure({
    required this.open,
    required this.onToggle,
    required this.exceptionMessage,
    required this.sessionId,
  });

  final bool open;
  final VoidCallback onToggle;
  final String? exceptionMessage;
  final String? sessionId;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BawariiColors.ink10,
        borderRadius: BorderRadius.circular(BawariiRadii.r10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Semantics(
            button: true,
            label: 'Error details, ${open ? 'expanded' : 'collapsed'}',
            child: InkWell(
              onTap: onToggle,
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    const Icon(Icons.code, size: 16, color: BawariiColors.ink70),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Error details',
                        style: BawariiTextStyles.bodySmall.copyWith(
                          color: BawariiColors.ink70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(
                      open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: BawariiColors.ink70,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (exceptionMessage != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: BawariiColors.paper,
                        borderRadius: BorderRadius.circular(BawariiRadii.r6),
                      ),
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(exceptionMessage!, style: RefTextStyles.monoSmall),
                      ),
                    ),
                  if (sessionId != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'Session',
                          style: BawariiTextStyles.fine.copyWith(
                            color: BawariiColors.ink70,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(sessionId!, style: RefTextStyles.monoSmall),
                          ),
                        ),
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(
                              Icons.copy_outlined,
                              size: 16,
                              color: BawariiColors.ink50,
                            ),
                            tooltip: 'Copy session ID',
                            onPressed: () =>
                                Clipboard.setData(ClipboardData(text: sessionId!)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
