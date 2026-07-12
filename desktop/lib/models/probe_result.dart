class CertInfo {
  final String subject;
  final String issuer;
  final String notBefore;
  final String notAfter;
  final String fingerprint;
  final bool verified;

  CertInfo({
    required this.subject,
    required this.issuer,
    required this.notBefore,
    required this.notAfter,
    required this.fingerprint,
    required this.verified,
  });
}

class SingleProbeResult {
  final String target;
  final bool success;
  final int? statusCode;
  final int? rttMs;
  final int? dnsLookupMs;
  final int? connectMs;
  final String? error;
  final String? protocol;
  final int? localPort;
  final CertInfo? cert;

  SingleProbeResult({
    required this.target,
    required this.success,
    this.statusCode,
    this.rttMs,
    this.dnsLookupMs,
    this.connectMs,
    this.error,
    this.protocol,
    this.localPort,
    this.cert,
  });

  static int? _toIntMs(dynamic val) {
    if (val == null) return null;
    if (val is int) return val;
    if (val is double) return val.round();
    return null;
  }

  factory SingleProbeResult.fromJson(Map<String, dynamic> json) {
    final status = json['status'] as int? ?? -1;
    final certSubject = json['cert_subject'] as String?;
    return SingleProbeResult(
      target: json['ip'] as String? ?? json['target'] as String? ?? '',
      success: status == 0,
      statusCode: json['status_code'] as int?,
      rttMs: _toIntMs(json['first_packet_cost_ms']),
      dnsLookupMs: _toIntMs(json['dns_cost_ms']),
      connectMs: _toIntMs(json['connect_cost_ms']),
      error: json['error_message'] as String? ?? json['details'] as String?,
      protocol: json['protocol'] as String?,
      localPort: json['local_port'] as int?,
      cert: (certSubject != null && certSubject.isNotEmpty)
          ? CertInfo(
              subject: certSubject,
              issuer: json['cert_issuer'] as String? ?? '',
              notBefore: json['cert_not_before'] as String? ?? '',
              notAfter: json['cert_not_after'] as String? ?? '',
              fingerprint: json['cert_fingerprint'] as String? ?? '',
              verified: json['cert_verified'] as bool? ?? false,
            )
          : null,
    );
  }
}

class ProbeResult {
  final int itemId;
  final String address;
  final String protocol;
  final String probeType;
  final int totalTargets;
  final int successCount;
  final List<SingleProbeResult> results;
  final DateTime detectedAt;

  ProbeResult({
    required this.itemId,
    required this.address,
    required this.protocol,
    required this.probeType,
    required this.totalTargets,
    required this.successCount,
    required this.results,
    required this.detectedAt,
  });

  factory ProbeResult.fromJson(Map<String, dynamic> json) {
    final resultsList = (json['results'] as List<dynamic>?)
            ?.map((e) => SingleProbeResult.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return ProbeResult(
      itemId: json['item_id'] as int,
      address: json['address'] as String? ?? '',
      protocol: json['protocol'] as String? ?? '',
      probeType: json['probe_type'] as String? ?? '',
      totalTargets: resultsList.length,
      successCount: resultsList.where((r) => r.success).length,
      results: resultsList,
      detectedAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}
