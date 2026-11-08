import 'dart:async';

import 'package:bawarii_kyc/bawarii_kyc.dart';
import 'package:bawarii_ui/bawarii_ui.dart';
import 'package:camera/camera.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../env.dart';
import '../models/reference_workflow.dart';
import '../prefill_capturing_kyc_repository.dart';
import '../reference_backend_client.dart';
import '../utils/backend_errors.dart';
import '../widgets/arming_view.dart';
import '../widgets/id_illustration.dart';
import '../widgets/pre_capture_instruction_row.dart';
import '../widgets/primitives/rb_banner.dart';
import '../widgets/primitives/rb_sticky_bar.dart';
import '../widgets/primitives/test_environment_strip.dart';
import '../widgets/session_status_line.dart';
import 'error_screen.dart';
import 'prefill_confirm_screen.dart';
import 'result_screen.dart';

enum _PreCaptureState {
  initializing,
  ready,
  error403,
  errorNetwork,
  errorCapacity,
  offline,
  arming,
  capturing,
}

/// S2 — PreCaptureScreen: instructions + session init,
/// plus the H arming/handoff state it owns.
///
/// Owns the session lifecycle: creates the KYC session, manages Dio and
/// HttpKycRepository, handles 403/503/network/offline errors, requests
/// camera permission on Start tap, arms for a minimum 400ms before handing
/// off, and mounts the SDK widget inline when capturing begins.
///
/// Navigation:
///   onComplete → fetchPrefill → PrefillConfirmScreen or ResultScreen
///   onError    → ErrorScreen(sdkError / systemBusy / cameraUnavailable / sessionExpired)
///   onSessionExpired → dispose + re-init in place with expired banner
///   onAbort / onCancel → popUntil(isFirst)
class PreCaptureScreen extends StatefulWidget {
  const PreCaptureScreen({
    super.key,
    required this.workflow,
    this.showExpiredBanner = false,
    // Injected for tests — production code uses defaults.
    this.clientOverride,
    this.permissionChecker,
    this.connectivityChecker,
    this.camerasOverride,
  });

  final ReferenceWorkflow workflow;

  /// When true, shows the "session expired" warning banner immediately.
  final bool showExpiredBanner;

  /// Optional override for [ReferenceBackendClient] — used in tests.
  final ReferenceBackendClient? clientOverride;

  /// Optional override for the camera permission check — used in tests.
  /// Should return true if the app has/can get camera permission.
  final Future<bool> Function()? permissionChecker;

  /// Optional override for the connectivity check — used in tests. Should
  /// return true when the device believes it has a network connection.
  final Future<bool> Function()? connectivityChecker;

  /// Optional override for `availableCameras()` — used in tests, where the
  /// `camera` plugin has no platform implementation to query. Production
  /// code always calls `availableCameras()` itself.
  final List<CameraDescription>? camerasOverride;

  @override
  State<PreCaptureScreen> createState() => _PreCaptureScreenState();
}

class _PreCaptureScreenState extends State<PreCaptureScreen> {
  late final ReferenceBackendClient _client;
  final _uuid = const Uuid();

  _PreCaptureState _state = _PreCaptureState.initializing;
  bool _showExpiredBanner = false;

  // Session data stored after successful init.
  String? _sessionId;
  String? _uploadToken;
  String? _uploadBaseUrl;
  List<CameraDescription> _cameras = [];

  Dio? _sessionDio;
  IKycRepository? _repo;

  // / — capacity (`OCR_BUSY`) auto-retry: 8s, 15s, 30s, then stop.
  int _capacityAttempt = 0;
  int _capacitySecondsRemaining = 0;
  bool _capacityExhausted = false;
  Timer? _capacityCountdownTimer;
  Timer? _capacityFireTimer;

  @override
  void initState() {
    super.initState();
    _client = widget.clientOverride ?? ReferenceBackendClient();
    _showExpiredBanner = widget.showExpiredBanner;
    _startFlow();
  }

  @override
  void dispose() {
    _capacityCountdownTimer?.cancel();
    _capacityFireTimer?.cancel();
    _disposeRepo();
    super.dispose();
  }

  void _disposeRepo() {
    _repo?.dispose();
    _repo = null;
    _sessionDio?.close();
    _sessionDio = null;
  }

  Future<bool> _hasConnectivity() async {
    if (widget.connectivityChecker != null) {
      return widget.connectivityChecker!();
    }
    try {
      // Bounded: environments with no platform channel handler (widget
      // tests, desktop) can leave this call pending indefinitely rather
      // than rejecting it, so a bare try/catch alone isn't sufficient.
      final result = await Connectivity()
          .checkConnectivity()
          .timeout(const Duration(seconds: 2));
      return !result.contains(ConnectivityResult.none);
    } catch (_) {
      // Fail open rather than falsely claim offline; `startKyc` will
      // surface a real network error if the device genuinely has none.
      return true;
    }
  }

  Future<void> _startFlow() async {
    final online = await _hasConnectivity();
    if (!mounted) return;
    if (!online) {
      setState(() => _state = _PreCaptureState.offline);
      return;
    }
    _initSession();
  }

  Future<void> _initSession() async {
    _cancelCapacityTimers();
    setState(() {
      _state = _PreCaptureState.initializing;
    });

    try {
      // startKyc first so 403/503/network errors propagate with the correct state.
      final response = await _client.startKyc(
        documentType: 'E_TAZKIRA',
        referenceId: _uuid.v4(),
        workflow: widget.workflow.apiValue,
      );

      // availableCameras() may throw MissingPluginException in test/desktop
      // environments — degrade silently to an empty list rather than surfacing
      // a false network error.
      List<CameraDescription> cameras;
      if (widget.camerasOverride != null) {
        cameras = widget.camerasOverride!;
      } else {
        try {
          cameras = await availableCameras();
        } catch (_) {
          cameras = [];
        }
      }

      if (!mounted) return;

      _capacityAttempt = 0;
      _capacityExhausted = false;
      setState(() {
        _cameras = cameras;
        _sessionId = response.sessionId;
        _uploadToken = response.uploadToken;
        _uploadBaseUrl = response.uploadBaseUrl;
        _state = _PreCaptureState.ready;
        _showExpiredBanner = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      if (isUnauthorised(e)) {
        setState(() => _state = _PreCaptureState.error403);
      } else if (isCapacityBusy(e)) {
        setState(() => _state = _PreCaptureState.errorCapacity);
        _startCapacityRetry();
      } else {
        setState(() => _state = _PreCaptureState.errorNetwork);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _state = _PreCaptureState.errorNetwork);
    }
  }

  void _cancelCapacityTimers() {
    _capacityCountdownTimer?.cancel();
    _capacityFireTimer?.cancel();
  }

  /// — three auto-retry attempts at 8s / 15s / 30s. Once
  /// exhausted, "Try now" remains the only way to retry.
  void _startCapacityRetry() {
    if (_capacityAttempt >= capacityRetryDelaysSeconds.length) {
      setState(() => _capacityExhausted = true);
      return;
    }
    final delaySeconds = capacityRetryDelaysSeconds[_capacityAttempt];
    _capacityAttempt++;

    setState(() {
      _capacitySecondsRemaining = delaySeconds;
      _capacityExhausted = false;
    });
    _capacityCountdownTimer?.cancel();
    _capacityCountdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _capacitySecondsRemaining = (_capacitySecondsRemaining - 1).clamp(
          0,
          delaySeconds,
        );
      });
      if (_capacitySecondsRemaining == 0) t.cancel();
    });

    _capacityFireTimer?.cancel();
    _capacityFireTimer = Timer(Duration(seconds: delaySeconds), () {
      if (mounted) _initSession();
    });
  }

  void _onCapacityRetryNow() {
    _cancelCapacityTimers();
    _initSession();
  }

  void _onOfflineRetry() => _startFlow();

  Future<void> _onStartTap() async {
    // Request camera permission before mounting the SDK.
    final granted = widget.permissionChecker != null
        ? await widget.permissionChecker!()
        : await _requestCameraPermission();

    if (!mounted) return;
    if (!granted) {
      Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute<void>(
          builder: (_) => const ErrorScreen(
            errorCode: ReferenceErrorCode.cameraUnavailable,
          ),
        ),
      );
      return;
    }

    // — arm for a minimum of 400ms before handing off to the SDK, so
    // a fast camera-init never flashes past and a slow one never shows a
    // black frame.
    setState(() => _state = _PreCaptureState.arming);
    final armingStopwatch = Stopwatch()..start();

    // Create Dio + repo from stored session data. Wrapped so prefill is
    // captured while the upload token is still live;
    // see PrefillCapturingKycRepository for why this can't simply happen in
    // _onSdkComplete after the flow finishes.
    final dio = Dio(BaseOptions(baseUrl: _uploadBaseUrl!));
    final repo = PrefillCapturingKycRepository(
      HttpKycRepository(
        dio: dio,
        uploadToken: _uploadToken!,
        docType: 'E_TAZKIRA',
        environment: Env.bawariiEnvironment,
      ),
    );

    final remaining =
        const Duration(milliseconds: 400) - armingStopwatch.elapsed;
    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
    }

    if (!mounted) {
      repo.dispose();
      dio.close();
      return;
    }

    setState(() {
      _sessionDio = dio;
      _repo = repo;
      _state = _PreCaptureState.capturing;
    });
  }

  Future<bool> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  void _onSessionExpired() {
    if (!mounted) return;
    _disposeRepo();
    setState(() {
      _showExpiredBanner = true;
      _state = _PreCaptureState.initializing;
    });
    _initSession();
  }

  Future<void> _onSdkComplete(String sessionId) async {
    // The real prefill fetch already happened inside PrefillCapturingKycRepository
    // the moment both document sides were ACCEPTED — before the upload token
    // was burned. This just reads back whatever it captured (null for
    // document_only, which has no pre-burn window — see that class's doc).
    BawariiPrefillData? prefill;
    try {
      prefill = await _repo!.fetchPrefill(sessionId);
    } catch (_) {
      prefill = null;
    }

    // Dispose repo + Dio before routing.
    _disposeRepo();

    if (!mounted) return;

    final allEmpty = prefill == null ||
        ((prefill.fullName == null || prefill.fullName!.isEmpty) &&
            (prefill.nationalId == null || prefill.nationalId!.isEmpty) &&
            (prefill.dateOfBirth == null || prefill.dateOfBirth!.isEmpty));

    if (allEmpty) {
      Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute<void>(
          builder: (_) => ResultScreen(sessionId: sessionId),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute<void>(
          builder: (_) => PrefillConfirmScreen(
            prefillData: prefill!,
            sessionId: sessionId,
          ),
        ),
      );
    }
  }

  /// The two message keys a `precondition` error carries for a retake-class
  /// refusal — see [_onSdkError].
  static const _retakeInFlowMessageKeys = {
    'error.side_mismatch',
    'error.mrz_viz_mismatch',
  };

  /// Maps an SDK error to the reference app's error-screen code, or `null`
  /// when the SDK has already recovered in place and this screen must do
  /// nothing: a `precondition` error for a retake-class
  /// refusal means the SDK has already reopened its own capture screen for
  /// the same side, so there is no error for this screen to show.
  ReferenceErrorCode? _referenceErrorCodeFor(BawariiKycError error) {
    if (error.kind == BawariiKycErrorKind.precondition &&
        _retakeInFlowMessageKeys.contains(error.message)) {
      return null;
    }
    return switch (error.kind) {
      BawariiKycErrorKind.cameraPermissionDenied =>
        ReferenceErrorCode.cameraUnavailable,
      BawariiKycErrorKind.sessionExpired => ReferenceErrorCode.sessionExpired,
      // / — a 503 from the SDK's own upload calls is a capacity
      // signal, not a generic capture failure; rate limiting gets the same
      // "not your fault, safe" framing since neither is the user's doing.
      BawariiKycErrorKind.serverError ||
      BawariiKycErrorKind.rateLimited =>
        ReferenceErrorCode.systemBusy,
      // A configuration problem (untrusted/missing liveness model, or an
      // environment mismatch) is terminal and never
      // retried, same as any other SDK-side failure this reference app
      // doesn't have a more specific code for. A `precondition` error this
      // screen doesn't recognise (i.e. not one of the retake-class message
      // keys above) falls in here too, same as today.
      BawariiKycErrorKind.processing ||
      BawariiKycErrorKind.configuration ||
      BawariiKycErrorKind.precondition =>
        ReferenceErrorCode.sdkError,
    };
  }

  void _onSdkError(BawariiKycError error) {
    final errorCode = _referenceErrorCodeFor(error);
    if (errorCode == null) {
      // keep the repo alive — the SDK's own capture screen is
      // already back on screen for this side, so disposing it (or
      // navigating away) here would tear down a flow that is still live.
      return;
    }
    _disposeRepo();
    if (!mounted) return;
    Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute<void>(
        builder: (_) => ErrorScreen(
          errorCode: errorCode,
          workflow: widget.workflow,
          exceptionMessage: error.message,
          sessionId: _sessionId,
          retryAfterSeconds: error.retryAfterSeconds,
        ),
      ),
    );
  }

  void _onAbortOrCancel() {
    _disposeRepo();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    // When capturing, hand the full screen to the SDK.
    if (_state == _PreCaptureState.capturing) {
      return switch (widget.workflow) {
        ReferenceWorkflow.documentAndLiveness => BawariiKycPage(
            repository: _repo!,
            sessionId: _sessionId!,
            cameras: _cameras,
            onComplete: (session) => _onSdkComplete(_sessionId!),
            onError: _onSdkError,
            onSessionExpired: _onSessionExpired,
            onAbort: _onAbortOrCancel,
            // This screen already showed the "get ready" preparation step —
            // skip the SDK's own intro so the arming handoff lands straight
            // on the camera instead of a second prep screen.
            skipIntro: true,
          ),
        ReferenceWorkflow.documentOnly => BawariiDocumentCaptureView(
            repository: _repo!,
            sessionId: _sessionId!,
            cameras: _cameras,
            side: DocSide.front,
            documentType: 'E_TAZKIRA',
            workflow: 'document_only',
            onComplete: (_) => _onSdkComplete(_sessionId!),
            onError: _onSdkError,
            onCancel: _onAbortOrCancel,
          ),
      };
    }

    final isLoading = _state == _PreCaptureState.initializing;
    final isReady = _state == _PreCaptureState.ready;
    final isArming = _state == _PreCaptureState.arming;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.workflow.displayName),
        leading: SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Cancel',
          ),
        ),
      ),
      body: isArming ? const ArmingView() : _buildReadyBody(isLoading, isReady),
    );
  }

  Widget _buildReadyBody(bool isLoading, bool isReady) {
    final liveness = widget.workflow == ReferenceWorkflow.documentAndLiveness;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 16),
                const TestEnvironmentStrip(),
                const SizedBox(height: 16),
                IdIllustration(liveness: liveness),
                const SizedBox(height: 24),
                Text(
                  'Have your ID ready',
                  textAlign: TextAlign.center,
                  style: BawariiTextStyles.titleLarge,
                ),
                if (liveness) ...[
                  const SizedBox(height: 8),
                  Text(
                    "You'll also complete a selfie check",
                    textAlign: TextAlign.center,
                    style: BawariiTextStyles.body.copyWith(
                      color: BawariiColors.ink70,
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                ..._buildInstructionRows(),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.lock_outline,
                      size: 14,
                      color: BawariiColors.ink50,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Your data is processed securely. '
                        'It is never stored by this app.',
                        textAlign: TextAlign.center,
                        style: BawariiTextStyles.fine.copyWith(
                          color: BawariiColors.ink70,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        RbStickyBar(
          children: [
            if (_currentBanner case final banner?)
              banner
            else
              SessionStatusLine(
                phase: isReady
                    ? SessionStatusPhase.ready
                    : SessionStatusPhase.initialising,
              ),
            Semantics(
              label: isLoading
                  ? 'Starting session, please wait'
                  : 'Start verification',
              button: true,
              child: ElevatedButton(
                onPressed: isReady ? _onStartTap : null,
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: BawariiColors.bone,
                        ),
                      )
                    : const Text('Start'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Banner precedence: offline > capacity > 403 > network > expired.
  Widget? get _currentBanner {
    if (_state == _PreCaptureState.offline) {
      return RbBanner(
        severity: RbBannerSeverity.error,
        icon: Icons.wifi_off,
        title:
            "You're offline. Connect to the internet to start a verification.",
        action: 'Try again',
        onAction: _onOfflineRetry,
      );
    }
    if (_state == _PreCaptureState.errorCapacity) {
      return RbBanner(
        severity: RbBannerSeverity.warning,
        icon: Icons.hourglass_empty,
        title: _capacityExhausted
            ? 'Our verification service is busy. Automatic retries stopped.'
            : 'Our verification service is busy. Trying again in '
                '${_capacitySecondsRemaining}s…',
        action: 'Try now',
        onAction: _onCapacityRetryNow,
      );
    }
    if (_state == _PreCaptureState.error403) {
      return RbBanner(
        severity: RbBannerSeverity.error,
        title: 'This workflow requires a valid enterprise API key. '
            'Check your app configuration.',
        action: 'Try again',
        onAction: _initSession,
      );
    }
    if (_state == _PreCaptureState.errorNetwork) {
      return RbBanner(
        severity: RbBannerSeverity.error,
        title: 'Could not reach the Bawarii service. Check your connection.',
        action: 'Try again',
        onAction: _initSession,
      );
    }
    if (_showExpiredBanner) {
      return const RbBanner(
        severity: RbBannerSeverity.warning,
        title: 'Your session expired — starting a new one…',
      );
    }
    return null;
  }

  List<Widget> _buildInstructionRows() {
    final rows = switch (widget.workflow) {
      ReferenceWorkflow.documentOnly => [
          (
            Icons.crop_free,
            'Photograph the front of your Tazkira',
          ),
          (Icons.flip, 'Then the back side'),
          (
            Icons.verified_outlined,
            "We'll process and return a result in seconds",
          ),
        ],
      ReferenceWorkflow.documentAndLiveness => [
          (
            Icons.crop_free,
            'Photograph the front and back of your Tazkira',
          ),
          (
            Icons.face_outlined,
            'Complete a short selfie challenge',
          ),
          (
            Icons.verified_outlined,
            "We'll verify and return a result in seconds",
          ),
        ],
    };

    final widgets = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      final (icon, text) = rows[i];
      if (i > 0) widgets.add(const SizedBox(height: 16));
      // — icons are decorative; the row's text carries the meaning.
      widgets.add(PreCaptureInstructionRow(icon: icon, text: text));
    }
    return widgets;
  }
}
