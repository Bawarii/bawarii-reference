import 'package:dio/dio.dart';

/// True when [e] is the platform's capacity/`OCR_BUSY` response (`HTTP 503`). Distinguishing this from a generic network
/// failure matters: a 503 means the service was reached and answered, which
/// is a materially different message from "could not reach the service".
bool isCapacityBusy(DioException e) => e.response?.statusCode == 503;

/// True when the session no longer exists on the platform: 410, or a 404 whose
/// error `code` is `SESSION_GONE` / `SESSION_NOT_FOUND`. A bare 404 (for
/// example a wrong URL) is not a session expiry. The app treats it as an
/// expired session.
bool isSessionGone(DioException e) {
  final status = e.response?.statusCode;
  if (status == 410) return true;
  if (status != 404) return false;
  final data = e.response?.data;
  final detail = data is Map ? data['detail'] : null;
  final code = (detail is Map ? detail['code'] : data is Map ? data['code'] : null);
  return code == 'SESSION_GONE' || code == 'SESSION_NOT_FOUND';
}

/// The integer-seconds `Retry-After` the platform supplied, or null when it is
/// missing or not a positive integer. Capped so a bad header cannot stall the
/// screen.
int? retryAfterSecondsOf(DioException e, {int cap = 60}) {
  final raw = e.response?.headers.value('retry-after')?.trim();
  final seconds = raw == null ? null : int.tryParse(raw);
  if (seconds == null || seconds <= 0) return null;
  return seconds > cap ? cap : seconds;
}

/// True when [e] is an authentication/authorisation failure (403).
bool isUnauthorised(DioException e) => e.response?.statusCode == 403;

/// The `SystemBusyCallout` auto-retry schedule: three
/// attempts at 8s, 15s, 30s, then stop and require a manual "Try now".
const List<int> capacityRetryDelaysSeconds = [8, 15, 30];
