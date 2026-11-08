import 'dart:async';

import 'package:bawarii_kyc/bawarii_kyc.dart';
import 'package:bawarii_reference_app/models/reference_result.dart';
import 'package:bawarii_reference_app/models/reference_workflow.dart';
import 'package:bawarii_reference_app/screens/error_screen.dart';
import 'package:bawarii_reference_app/screens/home_screen.dart';
import 'package:bawarii_reference_app/screens/pre_capture_screen.dart';
import 'package:bawarii_reference_app/screens/result_screen.dart';
import 'package:bawarii_reference_app/reference_backend_client.dart';
import 'package:bawarii_ui/bawarii_ui.dart';
import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ─── Mocks ───────────────────────────────────────────────────────────────────

class _MockReferenceBackendClient extends Mock
    implements ReferenceBackendClient {}

// ─── Helpers ─────────────────────────────────────────────────────────────────

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: BawariiTheme.light(),
    home: child,
  );
}

// A fake camera description — never actually initialised (the `camera`
// plugin has no platform implementation in a widget test); only used so
// PreCaptureScreen's capturing-state SDK widgets mount with a non-empty
// `cameras` list instead of throwing on an empty one (DocCaptureScreen's
// `cameras.first` fallback).
const _fakeBackCamera = CameraDescription(
  name: 'fake-back',
  lensDirection: CameraLensDirection.back,
  sensorOrientation: 0,
);

/// Returns a client whose startKyc never resolves — keeps screen in loading.
ReferenceBackendClient _makeNeverClient(Completer<StartKycResponse> c) {
  final mock = _MockReferenceBackendClient();
  when(() => mock.startKyc(
        documentType: any(named: 'documentType'),
        referenceId: any(named: 'referenceId'),
        workflow: any(named: 'workflow'),
      )).thenAnswer((_) => c.future);
  return mock;
}

/// Returns a client whose startKyc throws a 403.
ReferenceBackendClient _make403Client() {
  final mock = _MockReferenceBackendClient();
  when(() => mock.startKyc(
        documentType: any(named: 'documentType'),
        referenceId: any(named: 'referenceId'),
        workflow: any(named: 'workflow'),
      )).thenThrow(
    DioException(
      requestOptions: RequestOptions(path: '/reference/start_kyc'),
      response: Response(
        requestOptions: RequestOptions(path: '/reference/start_kyc'),
        statusCode: 403,
      ),
      type: DioExceptionType.badResponse,
    ),
  );
  return mock;
}

/// Returns a client whose startKyc throws a 503 `OCR_BUSY` capacity response.
ReferenceBackendClient _make503Client() {
  final mock = _MockReferenceBackendClient();
  when(() => mock.startKyc(
        documentType: any(named: 'documentType'),
        referenceId: any(named: 'referenceId'),
        workflow: any(named: 'workflow'),
      )).thenThrow(
    DioException(
      requestOptions: RequestOptions(path: '/reference/start_kyc'),
      response: Response(
        requestOptions: RequestOptions(path: '/reference/start_kyc'),
        statusCode: 503,
        data: {'error': 'OCR_BUSY'},
      ),
      type: DioExceptionType.badResponse,
    ),
  );
  return mock;
}

/// Returns a client whose startKyc succeeds immediately.
ReferenceBackendClient _makeReadyClient() {
  final mock = _MockReferenceBackendClient();
  when(() => mock.startKyc(
        documentType: any(named: 'documentType'),
        referenceId: any(named: 'referenceId'),
        workflow: any(named: 'workflow'),
      )).thenAnswer((_) async => StartKycResponse.fromJson({
        'session_id': 'test-session-123',
        'upload_token': 'tok_abc',
        'upload_base_url': 'http://localhost:8080',
        'expires_at': '2099-01-01T00:00:00Z',
        'workflow': 'document_and_liveness',
      }));
  return mock;
}

// ─── HomeScreen tests ─────────────────────────────────────────────────────────

void main() {
  group('HomeScreen', () {
    testWidgets('renders badge + both cards at 360×640 without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrap(const HomeScreen()));
      await tester.pump();

      expect(find.text('TEST ENVIRONMENT'), findsOneWidget);
      expect(find.text('Document Only'), findsOneWidget);
      expect(find.text('Document + Liveness'), findsOneWidget);
      // Confirm no RenderFlex overflow was thrown.
      expect(tester.takeException(), isNull);
    });

    testWidgets('wordmark and tagline are present', (tester) async {
      await tester.pumpWidget(_wrap(const HomeScreen()));
      await tester.pump();

      expect(find.text('BAWARII'), findsOneWidget);
      expect(find.text('Afghan identity. Verified.'), findsOneWidget);
    });

    testWidgets('tapping Document Only card navigates to PreCaptureScreen',
        (tester) async {
      await tester.pumpWidget(_wrap(const HomeScreen()));
      await tester.pump();

      await tester.tap(find.text('Document Only'));
      await tester.pumpAndSettle();

      // PreCaptureScreen title should now be on screen.
      expect(find.text('Document Only'), findsWidgets);
    });

    testWidgets(
        'tapping Document + Liveness card navigates to PreCaptureScreen',
        (tester) async {
      await tester.pumpWidget(_wrap(const HomeScreen()));
      await tester.pump();

      await tester.tap(find.text('Document + Liveness'));
      await tester.pumpAndSettle();

      expect(find.text('Document + Liveness'), findsWidgets);
    });

    testWidgets('"How this works" link opens ArchitectureSheet',
        (tester) async {
      await tester.pumpWidget(_wrap(const HomeScreen()));
      await tester.pump();

      await tester.tap(find.text('How this works'));
      await tester.pumpAndSettle();

      expect(find.text('How This Works'), findsOneWidget);
    });
  });

  // ─── PreCaptureScreen tests ─────────────────────────────────────────────────

  group('PreCaptureScreen', () {
    testWidgets('shows spinner while session initialises', (tester) async {
      // Use a never-completing future to keep screen in initializing state.
      final completer = Completer<StartKycResponse>();
      final client = _makeNeverClient(completer);

      await tester.pumpWidget(
        _wrap(
          PreCaptureScreen(
            workflow: ReferenceWorkflow.documentOnly,
            clientOverride: client,
            connectivityChecker: () async => true,
          ),
        ),
      );

      // One pump: startKyc future is still pending → initializing state.
      await tester.pump();

      // In initializing state the ElevatedButton is disabled and its child
      // is a CircularProgressIndicator, not the text 'Start'.
      final btn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(btn.onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      // Resolve so there are no pending-timer warnings at teardown.
      completer.completeError(Exception('dismissed'));
    });

    testWidgets('shows 403 error banner when startKyc returns 403',
        (tester) async {
      final client = _make403Client();

      await tester.pumpWidget(
        _wrap(
          PreCaptureScreen(
            workflow: ReferenceWorkflow.documentOnly,
            clientOverride: client,
            connectivityChecker: () async => true,
          ),
        ),
      );

      // pumpAndSettle lets the synchronous throw propagate and rebuild.
      await tester.pumpAndSettle();

      expect(
        find.textContaining('valid enterprise API key'),
        findsOneWidget,
      );
    });

    testWidgets('shows expired banner when showExpiredBanner is true',
        (tester) async {
      final client = _makeReadyClient();

      await tester.pumpWidget(
        _wrap(
          PreCaptureScreen(
            workflow: ReferenceWorkflow.documentAndLiveness,
            showExpiredBanner: true,
            clientOverride: client,
            connectivityChecker: () async => true,
          ),
        ),
      );

      await tester.pump(); // let initState fire synchronously

      expect(find.textContaining('session expired'), findsOneWidget);
    });

    // A 503/OCR_BUSY on session creation must read as a capacity
    // message, never as "check your connection".
    testWidgets('shows capacity banner (not a network-error banner) on 503',
        (tester) async {
      final client = _make503Client();

      await tester.pumpWidget(
        _wrap(
          PreCaptureScreen(
            workflow: ReferenceWorkflow.documentOnly,
            clientOverride: client,
            connectivityChecker: () async => true,
          ),
        ),
      );

      // Two bounded pumps (not pumpAndSettle) — enough to flush the
      // connectivity-check microtask and the synchronous 503 throw without
      // advancing the fake clock as far as the 8s auto-retry timer.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.textContaining('busy'), findsOneWidget);
      expect(find.textContaining('Trying again in'), findsOneWidget);
      expect(find.textContaining('Check your connection'), findsNothing);

      // Unmount to cancel the pending retry timers before teardown.
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('shows the offline banner when connectivity is unavailable',
        (tester) async {
      final client = _makeReadyClient();

      await tester.pumpWidget(
        _wrap(
          PreCaptureScreen(
            workflow: ReferenceWorkflow.documentOnly,
            clientOverride: client,
            connectivityChecker: () async => false,
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.textContaining("You're offline"), findsOneWidget);
      // startKyc must never be called while offline (no
      // "attempted a request while offline" misattribution).
      verifyNever(() => client.startKyc(
            documentType: any(named: 'documentType'),
            referenceId: any(named: 'referenceId'),
            workflow: any(named: 'workflow'),
          ));
    });

    // ── _onSdkError ───────────────────────────────────────────
    //
    // A `precondition` error for a retake-class refusal means the SDK has
    // already reopened its own capture screen for the same side — the
    // reference app must do nothing.

    /// Drives [PreCaptureScreen] from mount through to the `capturing`
    /// state (document_only → BawariiDocumentCaptureView) and returns the
    /// mounted capture view so a test can invoke its `onError` directly.
    Future<BawariiDocumentCaptureView> pumpToCapturing(
      WidgetTester tester,
    ) async {
      final client = _makeReadyClient();

      await tester.pumpWidget(
        _wrap(
          PreCaptureScreen(
            workflow: ReferenceWorkflow.documentOnly,
            clientOverride: client,
            connectivityChecker: () async => true,
            permissionChecker: () async => true,
            camerasOverride: const [_fakeBackCamera],
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Start'));
      await tester.pump();
      // Past the 400ms minimum arming delay.
      await tester.pump(const Duration(milliseconds: 450));

      expect(find.byType(BawariiDocumentCaptureView), findsOneWidget);
      return tester.widget<BawariiDocumentCaptureView>(
        find.byType(BawariiDocumentCaptureView),
      );
    }

    testWidgets(
        'precondition error.mrz_viz_mismatch leaves the capture flow in '
        'place — no ErrorScreen, same repo', (tester) async {
      final captureView = await pumpToCapturing(tester);
      final repoBefore = captureView.repository;

      // Called twice — the SDK's own retake can re-arm and refuse again
      // before this screen's next frame; a second call must not crash or
      // dispose an already-live repo.
      captureView.onError!(const BawariiKycError(
        kind: BawariiKycErrorKind.precondition,
        message: 'error.mrz_viz_mismatch',
      ));
      captureView.onError!(const BawariiKycError(
        kind: BawariiKycErrorKind.precondition,
        message: 'error.mrz_viz_mismatch',
      ));
      // A single pump is not enough to prove this: pushReplacement's route
      // transition spans several frames, so "no ErrorScreen yet" would
      // pass even with the precondition branch deleted. Settling
      // fully is what actually exercises the mutation.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(ErrorScreen), findsNothing);
      final captureViewAfter = tester.widget<BawariiDocumentCaptureView>(
        find.byType(BawariiDocumentCaptureView),
      );
      expect(identical(captureViewAfter.repository, repoBefore), isTrue);

      // Unmount to cancel DocCaptureScreen's simulated-alignment timers.
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
        'precondition error.side_mismatch leaves the capture flow in place '
        '— no ErrorScreen, same repo', (tester) async {
      final captureView = await pumpToCapturing(tester);
      final repoBefore = captureView.repository;

      captureView.onError!(const BawariiKycError(
        kind: BawariiKycErrorKind.precondition,
        message: 'error.side_mismatch',
      ));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(ErrorScreen), findsNothing);
      final captureViewAfter = tester.widget<BawariiDocumentCaptureView>(
        find.byType(BawariiDocumentCaptureView),
      );
      expect(identical(captureViewAfter.repository, repoBefore), isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
        'a precondition error with another message still goes to the '
        'generic ErrorScreen, as today', (tester) async {
      final captureView = await pumpToCapturing(tester);

      captureView.onError!(const BawariiKycError(
        kind: BawariiKycErrorKind.precondition,
        message: 'error.workflow_step_not_permitted',
      ));
      // The route transition needs more than one frame to settle.
      await tester.pumpAndSettle();

      expect(find.byType(ErrorScreen), findsOneWidget);
      expect(find.byType(BawariiDocumentCaptureView), findsNothing);
    });

    testWidgets(
        'an unrelated error kind (sessionExpired) still maps to its own '
        'ErrorScreen code, unaffected by the precondition branch', (tester) async {
      final captureView = await pumpToCapturing(tester);

      captureView.onError!(const BawariiKycError(
        kind: BawariiKycErrorKind.sessionExpired,
        message: 'x',
      ));
      await tester.pumpAndSettle();

      final errorScreen = tester.widget<ErrorScreen>(find.byType(ErrorScreen));
      expect(errorScreen.errorCode, ReferenceErrorCode.sessionExpired);
    });
  });

  // ─── ResultScreen tests ─────────────────────────────────────────────────────

  group('ResultScreen', () {
    testWidgets('shows loading indicator initially', (tester) async {
      final mock = _MockReferenceBackendClient();
      // Completer that never resolves — lets us observe the loading state.
      final completer = Completer<ReferenceResult>();
      when(() => mock.getResult(any())).thenAnswer((_) => completer.future);

      await tester.pumpWidget(
        _wrap(
          ResultScreen(
            sessionId: 'test-session',
            clientOverride: mock,
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Resolve and let the catch block run (cancelling the elapsed-time
      // ticker) before the test ends, so no Timer is left pending.
      completer.completeError(Exception('dismissed'));
      await tester.pump();
    });

    testWidgets(
        'first frame is a structured skeleton, never a bare '
        'spinner on an empty scaffold', (tester) async {
      final mock = _MockReferenceBackendClient();
      final completer = Completer<ReferenceResult>();
      when(() => mock.getResult(any())).thenAnswer((_) => completer.future);

      await tester.pumpWidget(
        _wrap(ResultScreen(sessionId: 'test-session', clientOverride: mock)),
      );
      await tester.pump();

      expect(find.text('Verification Result'), findsOneWidget); // app bar
      expect(find.text('TEST ENVIRONMENT'), findsOneWidget); // strip
      expect(find.text('Analysing your submission…'), findsOneWidget);
      expect(
          find.text('Run another verification'), findsOneWidget); // sticky CTA

      completer.completeError(Exception('dismissed'));
      await tester.pump();
    });

    // A 503/OCR_BUSY on result fetch is a capacity signal, shown via
    // SystemBusyCallout, never generic connection-error copy.
    testWidgets('shows SystemBusyCallout (not a generic error) on 503',
        (tester) async {
      final mock = _MockReferenceBackendClient();
      when(() => mock.getResult(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/reference/result/x'),
          response: Response(
            requestOptions: RequestOptions(path: '/reference/result/x'),
            statusCode: 503,
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      await tester.pumpWidget(
        _wrap(ResultScreen(sessionId: 'test-session', clientOverride: mock)),
      );
      await tester.pump();

      expect(find.text('Our service is at capacity'), findsOneWidget);
      // Both the callout's own action and the sticky bar's secondary CTA
      // read "Try now".
      expect(find.text('Try now'), findsNWidgets(2));
      expect(find.textContaining('could not load'), findsNothing);

      // Unmount to cancel the pending retry timers before teardown.
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('honours Retry-After on a 429/503 result fetch',
        (tester) async {
      final mock = _MockReferenceBackendClient();
      when(() => mock.getResult(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/reference/result/x'),
          response: Response(
            requestOptions: RequestOptions(path: '/reference/result/x'),
            statusCode: 503,
            headers: Headers.fromMap({'retry-after': ['12']}),
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      await tester.pumpWidget(
        _wrap(ResultScreen(sessionId: 'test-session', clientOverride: mock)),
      );
      await tester.pump();

      expect(find.textContaining('Retrying in 12s'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    for (final status in [404, 410]) {
      testWidgets('maps a $status result fetch to the expired-session screen',
          (tester) async {
        final mock = _MockReferenceBackendClient();
        when(() => mock.getResult(any())).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/reference/result/x'),
            response: Response(
              requestOptions: RequestOptions(path: '/reference/result/x'),
              statusCode: status,
              data: {'detail': {'code': 'SESSION_GONE'}},
            ),
            type: DioExceptionType.badResponse,
          ),
        );

        await tester.pumpWidget(
          _wrap(ResultScreen(sessionId: 'test-session', clientOverride: mock)),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Your session expired'), findsOneWidget);
      });
    }

    testWidgets('a bare 404 without a session code is a fetch error',
        (tester) async {
      final mock = _MockReferenceBackendClient();
      when(() => mock.getResult(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/reference/result/x'),
          response: Response(
            requestOptions: RequestOptions(path: '/reference/result/x'),
            statusCode: 404,
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      await tester.pumpWidget(
        _wrap(ResultScreen(sessionId: 'test-session', clientOverride: mock)),
      );
      await tester.pump();

      expect(find.text('Your session expired'), findsNothing);
    });
  });
}
