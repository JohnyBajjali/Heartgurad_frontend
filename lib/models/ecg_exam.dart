// lib/models/ecg_exam.dart
import '../models/patient.dart';
import 'ecg_prediction.dart';

enum EcgStatus { pending, processing, ready, failed, unknown }

EcgStatus ecgStatusFromString(String? s) {
  switch ((s ?? '').toUpperCase()) {
    case 'PENDING': return EcgStatus.pending;
    case 'PROCESSING': return EcgStatus.processing;
    case 'READY': return EcgStatus.ready;
    case 'FAILED': return EcgStatus.failed;
    default: return EcgStatus.unknown;
  }
}

class EcgExam {
  final int id;
  final EcgStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Minimal patient info; can be null if backend omits it in list views
  final Patient? patient;

  /// Top predictions for quick view (ready state)
  final List<EcgPrediction> topPredictions;

  /// Optional URLs (PDF/HTML report, image preview)
  final String? reportUrl;
  final String? previewUrl;

  EcgExam({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.patient,
    required this.topPredictions,
    this.reportUrl,
    this.previewUrl,
  });

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    try {
      return DateTime.tryParse(s)?.toLocal();
    } catch (_) {
      return null;
    }
  }

  factory EcgExam.fromJson(Map<String, dynamic> json) {
    // patient may be nested or just id/name parts
    Patient? pt;
    final pj = json['patient'];
    if (pj is Map<String, dynamic>) {
      pt = Patient.fromJson({
        // tolerate either nested object or a slim object
        'id': pj['id'] ?? json['patient_id'],
        'first_name': pj['first_name'] ?? pj['firstName'] ?? json['patient_first_name'] ?? '',
        'last_name': pj['last_name'] ?? pj['lastName'] ?? json['patient_last_name'] ?? '',
        'date_of_birth': pj['date_of_birth'] ?? pj['dob'] ?? '',
        'gender': pj['gender'] ?? '',
        'hospital': pj['hospital'],
        'attending_doctor': pj['attending_doctor'],
      });
    }

    // predictions can be under different keys
    final predsRaw = (json['top_predictions'] ??
        json['predictions'] ?? json['result'] ?? []) as dynamic;

    final List<EcgPrediction> preds = (predsRaw is List
            ? predsRaw
            : (predsRaw is Map ? predsRaw['labels'] : [])) is List
        ? List<Map<String, dynamic>>.from((predsRaw is List)
                ? predsRaw
                : (predsRaw as Map)['labels'] as List)
            .map(EcgPrediction.fromJson)
            .toList()
        : <EcgPrediction>[];

    return EcgExam(
      id: (json['id'] ?? json['exam_id'] ?? -1) is int
          ? (json['id'] ?? json['exam_id'] ?? -1) as int
          : int.tryParse((json['id'] ?? json['exam_id'] ?? '-1').toString()) ?? -1,
      status: ecgStatusFromString(json['status']?.toString()),
      createdAt: _parseDate(json['created_at'] ?? json['createdAt']),
      updatedAt: _parseDate(json['updated_at'] ?? json['updatedAt']),
      patient: pt,
      topPredictions: preds,
      reportUrl: json['report_url']?.toString(),
      previewUrl: json['preview_url']?.toString(),
    );
  }
}
