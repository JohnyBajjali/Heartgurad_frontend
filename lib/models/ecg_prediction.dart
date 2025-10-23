// lib/models/ecg_prediction.dart
class EcgPrediction {
  final String label;
  final double prob; // 0..1

  EcgPrediction({required this.label, required this.prob});

  factory EcgPrediction.fromJson(Map<String, dynamic> json) {
    final rawProb = json['prob'] ?? json['score'] ?? json['confidence'] ?? 0.0;
    double p;
    if (rawProb is num) {
      p = rawProb.toDouble();
      if (p > 1.0) p = p / 100.0; // tolerate 0..100 inputs
    } else {
      p = double.tryParse(rawProb.toString()) ?? 0.0;
      if (p > 1.0) p = p / 100.0;
    }
    return EcgPrediction(
      label: (json['label'] ?? json['name'] ?? 'Unknown').toString(),
      prob: p.clamp(0.0, 1.0),
    );
  }
}
