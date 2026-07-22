class AttachmentCreateResult {
  final String attachmentId;
  final String uploadUrl;
  final DateTime? expiresAt;

  const AttachmentCreateResult({
    required this.attachmentId,
    required this.uploadUrl,
    this.expiresAt,
  });

  factory AttachmentCreateResult.fromJson(Map<String, dynamic> json) {
    DateTime? expires;
    if (json['expires_at'] is String) {
      expires = DateTime.tryParse(json['expires_at'] as String);
    }
    final att = json['attachment'];
    final attMap = att is Map ? Map<String, dynamic>.from(att) : json;
    return AttachmentCreateResult(
      attachmentId: attMap['id']?.toString() ?? '',
      uploadUrl: json['upload_url']?.toString() ?? '',
      expiresAt: expires,
    );
  }
}

class AttachmentConfirmResult {
  final String attachmentId;
  final String status;
  final int? sizeBytes;

  const AttachmentConfirmResult({
    required this.attachmentId,
    required this.status,
    this.sizeBytes,
  });

  factory AttachmentConfirmResult.fromJson(Map<String, dynamic> json) {
    return AttachmentConfirmResult(
      attachmentId: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'unknown',
      sizeBytes: json['size_bytes'] is int ? json['size_bytes'] as int : null,
    );
  }
}

/// Distinguishes failure types so the sync service can react appropriately.
enum AttachmentFailureType {
  /// Local file is missing or unreadable.
  local,

  /// Network failure — could not connect to server or RustFS.
  network,

  /// Server returned an error response (4xx/5xx).
  server,

  /// Generic catch-all.
  unknown,
}

class AttachmentException implements Exception {
  final String message;
  final AttachmentFailureType type;
  final int? statusCode;

  const AttachmentException(
    this.message, {
    required this.type,
    this.statusCode,
  });

  @override
  String toString() => '$type: $message';
}