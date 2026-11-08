import 'package:dio/dio.dart';

import 'env.dart';
import 'models/reference_result.dart';

/// Response model for a newly created KYC session.
class StartKycResponse {
  const StartKycResponse({
    required this.sessionId,
    required this.uploadToken,
    required this.uploadBaseUrl,
    required this.expiresAt,
    required this.workflow,
  });

  factory StartKycResponse.fromJson(Map<String, dynamic> json) {
    return StartKycResponse(
      sessionId: json['session_id'] as String,
      uploadToken: json['upload_token'] as String,
      uploadBaseUrl: json['upload_base_url'] as String,
      expiresAt: json['expires_at'] as String,
      workflow: json['workflow'] as String,
    );
  }

  final String sessionId;
  final String uploadToken;

  /// Base URL the SDK must use for document and biometric uploads.
  /// Proxied through the reference backend to the Bawarii platform.
  final String uploadBaseUrl;
  final String expiresAt;
  final String workflow;
}

/// Thin Dio wrapper for the reference tenant backend.
///
/// The reference backend holds the Bawarii API key — the Flutter app never
/// sees it.  All KYC orchestration flows through this client.
class ReferenceBackendClient {
  ReferenceBackendClient({Dio? dio})
      : _dio =
            dio ??
            Dio(
              BaseOptions(baseUrl: Env.referenceBackendUrl),
            );

  final Dio _dio;

  /// Create a new KYC session via the reference backend.
  ///
  /// Returns a [StartKycResponse] containing the session ID and upload token
  /// that the SDK needs to upload biometric data directly to Bawarii.
  Future<StartKycResponse> startKyc({
    required String documentType,
    required String referenceId,
    String workflow = 'document_and_liveness',
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/reference/start_kyc',
      data: {
        'document_type': documentType,
        'reference_id': referenceId,
        'workflow': workflow,
      },
    );
    return StartKycResponse.fromJson(response.data!);
  }

  /// Fetch the typed result for a completed session.
  ///
  /// Returns a [ReferenceResult] parsed from the reference backend's verbatim
  /// proxy of the Bawarii platform result (including PII fields under `fields`).
  Future<ReferenceResult> getResult(String sessionId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/reference/result/$sessionId',
    );
    return ReferenceResult.fromJson(response.data!);
  }
}
