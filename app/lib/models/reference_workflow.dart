/// Workflows supported by the reference app.
enum ReferenceWorkflow {
  documentOnly,
  documentAndLiveness;

  /// API value sent to the reference backend and SDK.
  String get apiValue {
    return switch (this) {
      ReferenceWorkflow.documentOnly => 'document_only',
      ReferenceWorkflow.documentAndLiveness => 'document_and_liveness',
    };
  }

  /// Human-readable display name shown in AppBar and workflow cards.
  String get displayName {
    return switch (this) {
      ReferenceWorkflow.documentOnly => 'Document Only',
      ReferenceWorkflow.documentAndLiveness => 'Document + Liveness',
    };
  }
}

/// Maps an API workflow string to a [ReferenceWorkflow].
ReferenceWorkflow workflowFromApi(String value) {
  return switch (value) {
    'document_only' => ReferenceWorkflow.documentOnly,
    _ => ReferenceWorkflow.documentAndLiveness,
  };
}
