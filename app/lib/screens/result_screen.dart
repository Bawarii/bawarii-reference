import 'dart:async';
import 'dart:convert';

import 'package:bawarii_ui/bawarii_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/extraction_quality_summary.dart';
import '../models/identity_field_row.dart';
import '../models/reference_result.dart';
import '../models/verdict.dart';
import '../reference_backend_client.dart';
import '../utils/backend_errors.dart';
import '../widgets/primitives/rb_sticky_bar.dart';
import 'error_screen.dart';
import '../widgets/primitives/test_environment_strip.dart';
import '../widgets/result/dev_info_panel.dart';
import '../widgets/result/document_sides_card.dart';
import '../widgets/result/extraction_quality_card.dart';
import '../widgets/result/field_detail_sheet.dart';
import '../widgets/result/identity_fields_card.dart';
import '../widgets/result/rejection_details.dart';
import '../widgets/result/system_busy_callout.dart';
import '../widgets/primitives/rb_skeleton.dart';
import '../widgets/result_loading_card.dart';
import '../widgets/stub_state_callout.dart';
import '../widgets/verdict_hero_card.dart';

enum _ResultMode { loading, verdict, fetchError, busy }

/// S4 — ResultScreen: the centrepiece. Verdict, extraction
/// quality, identity fields with confidence, document sides, and the
/// developer panel.
///
/// Poll strategy:
///   - [Verdict.processing] → 5-second interval, max 6 attempts (~30s).
///     Countdown shown between polls.
///   - [Verdict.manualReview] → NO auto-poll. Immediate terminal display.
///     A "Refresh result" button lets the user trigger a single re-fetch.
///   - Every other verdict (including the new [Verdict.approvePending] and
/// [Verdict.cancelled] —) is terminal: no polling, no refresh
///     affordance.
///
/// the first frame is the full scaffold with a structured
/// [ResultLoadingCard] + skeletons — never a bare spinner.
/// a 503/`OCR_BUSY` response to `GET /result` is a capacity signal,
/// shown via [SystemBusyCallout] with an 8s/15s/30s auto-retry — never
/// "check your connection".
///
/// NID masking: national_id is hidden by default; eye icon reveals it.
class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.sessionId,
    this.clientOverride,
  });

  final String sessionId;

  /// Injected for tests.
  final ReferenceBackendClient? clientOverride;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late final ReferenceBackendClient _client;
  final _identityFieldsKey = GlobalKey();

  ReferenceResult? _result;
  _ResultMode _mode = _ResultMode.loading;
  int _pollAttempts = 0;
  int _countdownSeconds = 0;
  bool _nidRevealed = false;
  bool _devExpanded = false;
  Timer? _pollTimer;
  Timer? _countdownTimer;

  // — capacity auto-retry: 8s, 15s, 30s, then stop.
  int _capacityAttempt = 0;
  int _capacitySecondsRemaining = 0;
  bool _capacityExhausted = false;
  Timer? _capacityCountdownTimer;
  Timer? _capacityFireTimer;

  // progressive loading honesty + client-measured elapsed.
  final Stopwatch _elapsedStopwatch = Stopwatch()..start();
  int _loadingElapsedSeconds = 0;
  Timer? _elapsedTicker;

  static const _maxPollAttempts = 6;
  static const _pollIntervalSeconds = 5;

  @override
  void initState() {
    super.initState();
    _client = widget.clientOverride ?? ReferenceBackendClient();
    _fetchResult();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    _capacityCountdownTimer?.cancel();
    _capacityFireTimer?.cancel();
    _elapsedTicker?.cancel();
    super.dispose();
  }

  /// The elapsed-seconds ticker only ever runs while genuinely awaiting the
  /// first result — started fresh on
  /// entry to [_ResultMode.loading] and explicitly cancelled the instant the
  /// request settles, rather than left running indefinitely and relying on
  /// its own callback to notice it's no longer needed.
  void _startElapsedTicker() {
    _elapsedTicker?.cancel();
    _elapsedTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _loadingElapsedSeconds = _elapsedStopwatch.elapsed.inSeconds);
    });
  }

  Future<void> _fetchResult() async {
    if (!mounted) return;
    final enteringLoading = _result == null;
    if (enteringLoading) {
      setState(() => _mode = _ResultMode.loading);
      _startElapsedTicker();
    }

    try {
      final result = await _client.getResult(widget.sessionId);
      if (!mounted) return;
      _elapsedTicker?.cancel();
      _cancelCapacityTimers();
      _capacityAttempt = 0;
      _capacityExhausted = false;
      setState(() {
        _result = result;
        _mode = _ResultMode.verdict;
      });
      _scheduleNextPollIfNeeded(result);
    } on DioException catch (e) {
      if (!mounted) return;
      _elapsedTicker?.cancel();
      if (isSessionGone(e)) {
        _cancelCapacityTimers();
        // Deferred: navigating is unsafe while the first build is in progress.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context).pushReplacement<void, void>(
            MaterialPageRoute<void>(
              builder: (_) => ErrorScreen(
                errorCode: ReferenceErrorCode.sessionExpired,
                sessionId: widget.sessionId,
              ),
            ),
          );
        });
      } else if (isCapacityBusy(e)) {
        setState(() => _mode = _ResultMode.busy);
        _startCapacityRetry(retryAfterSeconds: retryAfterSecondsOf(e));
      } else {
        setState(() => _mode = _ResultMode.fetchError);
      }
    } catch (_) {
      if (!mounted) return;
      _elapsedTicker?.cancel();
      setState(() => _mode = _ResultMode.fetchError);
    }
  }

  void _scheduleNextPollIfNeeded(ReferenceResult result) {
    // manualReview → no auto-poll.
    if (result.verdict == Verdict.manualReview) return;

    // Non-processing verdicts are terminal (this naturally also covers
    // the new approvePending/cancelled members — no special-casing needed).
    if (result.verdict != Verdict.processing) return;

    if (_pollAttempts >= _maxPollAttempts) return;

    _pollAttempts++;
    _startPollCountdown(_pollIntervalSeconds, onExpiry: _fetchResult);
  }

  void _startPollCountdown(int seconds, {required Future<void> Function() onExpiry}) {
    _countdownTimer?.cancel();
    _pollTimer?.cancel();

    setState(() => _countdownSeconds = seconds);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _countdownSeconds = (_countdownSeconds - 1).clamp(0, seconds);
      });
      if (_countdownSeconds == 0) t.cancel();
    });

    _pollTimer = Timer(Duration(seconds: seconds), () {
      if (mounted) onExpiry();
    });
  }

  void _onManualRefresh() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    _fetchResult();
  }

  void _cancelCapacityTimers() {
    _capacityCountdownTimer?.cancel();
    _capacityFireTimer?.cancel();
  }

  void _startCapacityRetry({int? retryAfterSeconds}) {
    if (_capacityAttempt >= capacityRetryDelaysSeconds.length) {
      setState(() => _capacityExhausted = true);
      return;
    }
    final delaySeconds =
        retryAfterSeconds ?? capacityRetryDelaysSeconds[_capacityAttempt];
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
      if (mounted) _fetchResult();
    });
  }

  void _onCapacityTryNow() {
    _cancelCapacityTimers();
    _fetchResult();
  }

  Future<void> _onShareResult() async {
    final json = _result?.rawJson;
    if (json == null) return;
    await Clipboard.setData(
      ClipboardData(text: const JsonEncoder.withIndent('  ').convert(json)),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Result payload copied'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _onTapField(IdentityFieldRow row) {
    FieldDetailSheet.show(context, row);
  }

  void _onViewFlagged() {
    final ctx = _identityFieldsKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification Result'),
        automaticallyImplyLeading: false,
        actions: [
          if (kDebugMode)
            SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                icon: const Icon(Icons.ios_share_outlined),
                onPressed: _result == null ? null : _onShareResult,
                tooltip: 'Copy result payload',
              ),
            ),
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              icon: const Icon(Icons.home_outlined),
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              tooltip: 'Return to home',
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildContent()),
            _buildStickyBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        const TestEnvironmentStrip(),
        const SizedBox(height: 12),
        switch (_mode) {
          _ResultMode.loading => _buildLoading(),
          _ResultMode.busy => SystemBusyCallout(
              secondsRemaining: _capacitySecondsRemaining,
              exhausted: _capacityExhausted,
              onTryNow: _onCapacityTryNow,
            ),
          _ResultMode.fetchError => _FetchErrorCard(
              sessionId: widget.sessionId,
              onRetry: _fetchResult,
            ),
          _ResultMode.verdict => _buildVerdict(_result!),
        },
      ],
    );
  }

  /// the very first frame — before any `ReferenceResult` has ever been
  /// received for this session — is this structured, staged card plus two
  /// skeleton blocks, never a bare spinner. Once any result arrives
  /// (including a `PROCESSING`/`APPROVE_PENDING` one), the screen moves to
  /// [_buildVerdict] and shows the real [VerdictHeroCard] instead (a
  /// `PROCESSING` result shows a verdict hero + poll countdown, not a
  /// loading card) — so the only reachable stage here is `none`.
  Widget _buildLoading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResultLoadingCard(
          stage: ResultLoadStage.none,
          secondsElapsed: _loadingElapsedSeconds,
        ),
        const SizedBox(height: 12),
        _SkeletonCard(),
        const SizedBox(height: 12),
        _SkeletonCard(),
      ],
    );
  }

  Widget _buildVerdict(ReferenceResult result) {
    final showFields = !const {
      Verdict.processing,
      Verdict.cancelled,
      Verdict.unknown,
    }.contains(result.verdict);

    final rows = showFields ? buildIdentityFieldRows(result) : const <IdentityFieldRow>[];
    final hasAnyFieldValue = [
      result.surnameLatin,
      result.givenNameLatin,
      result.fullName,
      result.nationalId,
      result.dateOfBirth,
      result.sex,
      result.dateOfExpiryGregorian,
    ].any((v) => (v ?? '').isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VerdictHeroCard(result: result),

        if (result.verdict == Verdict.processing) ...[
          const SizedBox(height: 8),
          _PollAffordance(seconds: _countdownSeconds),
        ],

        if (showFields && result.extractionMeta != null) ...[
          const SizedBox(height: 12),
          ExtractionQualityCard(
            summary: ExtractionQualitySummary.fromResult(result),
            onViewFlagged: _onViewFlagged,
          ),
        ],

        if (showFields && !hasAnyFieldValue) ...[
          const SizedBox(height: 12),
          const StubStateCallout(),
        ] else if (showFields && rows.isNotEmpty) ...[
          const SizedBox(height: 12),
          KeyedSubtree(
            key: _identityFieldsKey,
            child: IdentityFieldsCard(
              rows: rows,
              revealNationalId: _nidRevealed,
              onToggleRevealNationalId: () =>
                  setState(() => _nidRevealed = !_nidRevealed),
              onTapField: _onTapField,
            ),
          ),
        ],

        // zone order: DocumentSidesCard (always) precedes Rejection
        // details (REJECTED only).
        const SizedBox(height: 12),
        DocumentSidesCard(extractionMeta: result.extractionMeta),

        if (result.verdict == Verdict.rejected) ...[
          const SizedBox(height: 12),
          RejectionDetails(reasonCodes: result.rejectionReasons),
        ],

        const SizedBox(height: 12),
        DevInfoPanel(
          result: result,
          expanded: _devExpanded,
          onToggle: () => setState(() => _devExpanded = !_devExpanded),
          measuredElapsed: _elapsedStopwatch.elapsed,
        ),
      ],
    );
  }

  Widget _buildStickyBar() {
    final result = _result;
    return RbStickyBar(
      bordered: true,
      children: [
        if (result?.verdict == Verdict.manualReview && _mode == _ResultMode.verdict)
          OutlinedButton.icon(
            onPressed: _onManualRefresh,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Refresh result'),
            style: OutlinedButton.styleFrom(
              foregroundColor: BawariiColors.trust,
              side: const BorderSide(color: BawariiColors.trust),
            ),
          ),
        if (_mode == _ResultMode.busy)
          OutlinedButton(
            onPressed: _onCapacityTryNow,
            style: OutlinedButton.styleFrom(
              foregroundColor: BawariiColors.trust,
              side: const BorderSide(color: BawariiColors.trust),
            ),
            child: const Text('Try now'),
          ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
          child: const Text('Run another verification'),
        ),
      ],
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BawariiColors.paper,
        borderRadius: BorderRadius.circular(BawariiRadii.r20),
        border: Border.all(color: BawariiColors.hairline),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RbSkeleton(width: 120, height: 14),
          SizedBox(height: 10),
          RbSkeleton(width: 200, height: 14),
        ],
      ),
    );
  }
}

class _PollAffordance extends StatelessWidget {
  const _PollAffordance({required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(BawariiColors.trust),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              seconds > 0 ? 'Refreshing in ${seconds}s…' : 'Checking for update…',
              style: BawariiTextStyles.fine.copyWith(color: BawariiColors.ink70),
            ),
          ),
        ],
      ),
    );
  }
}

class _FetchErrorCard extends StatelessWidget {
  const _FetchErrorCard({required this.sessionId, required this.onRetry});

  final String sessionId;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: BawariiColors.paper,
        borderRadius: BorderRadius.circular(BawariiRadii.r20),
        border: Border.all(color: BawariiColors.hairline),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off, size: 40, color: BawariiColors.ink50),
          const SizedBox(height: 12),
          Text(
            'Could not load the verification result',
            textAlign: TextAlign.center,
            style: BawariiTextStyles.heading,
          ),
          const SizedBox(height: 8),
          Text(
            'The verification may still have completed. Check your '
            'connection and try again.',
            textAlign: TextAlign.center,
            style: BawariiTextStyles.bodySmall.copyWith(color: BawariiColors.ink70),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: BawariiColors.ink,
                side: const BorderSide(color: BawariiColors.ink, width: 1.5),
              ),
              child: const Text('Retry'),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Session', style: BawariiTextStyles.fine.copyWith(color: BawariiColors.ink70)),
              const SizedBox(width: 6),
              Expanded(
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    sessionId,
                    style: BawariiTextStyles.bodySmall.copyWith(color: BawariiColors.ink70),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              SizedBox(
                width: 44,
                height: 44,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.copy_outlined, size: 16, color: BawariiColors.ink50),
                  onPressed: () => Clipboard.setData(ClipboardData(text: sessionId)),
                  tooltip: 'Copy session ID',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
