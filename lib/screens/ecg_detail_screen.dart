// lib/screens/ecg_detail_screen.dart
import 'package:flutter/material.dart';
import '../api/api_service.dart';
import '../models/ecg_exam.dart';
import '../models/ecg_prediction.dart';
import 'package:url_launcher/url_launcher.dart';

class EcgDetailScreen extends StatefulWidget {
  final int examId;
  const EcgDetailScreen({super.key, required this.examId});

  @override
  State<EcgDetailScreen> createState() => _EcgDetailScreenState();
}

class _EcgDetailScreenState extends State<EcgDetailScreen> {
  late Future<EcgExam> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService().getEcgExamById(widget.examId);
  }

  Color _statusColor(EcgStatus s) {
    switch (s) {
      case EcgStatus.pending: return Colors.grey;
      case EcgStatus.processing: return Colors.amber;
      case EcgStatus.ready: return Colors.teal;
      case EcgStatus.failed: return Colors.redAccent;
      case EcgStatus.unknown: return Colors.blueGrey;
    }
  }

  String _statusText(EcgStatus s) {
    switch (s) {
      case EcgStatus.pending: return 'PENDING';
      case EcgStatus.processing: return 'PROCESSING';
      case EcgStatus.ready: return 'READY';
      case EcgStatus.failed: return 'FAILED';
      case EcgStatus.unknown: return 'UNKNOWN';
    }
  }

  Widget _predictionRow(EcgPrediction p) {
    final pct = (p.prob * 100).toStringAsFixed(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${p.label}  •  $pct%', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: p.prob.clamp(0.0, 1.0),
            minHeight: 10,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot open URL')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ECG Details'), backgroundColor: Colors.teal),
      body: FutureBuilder<EcgExam>(
        future: _future,
        builder: (context, s) {
          if (s.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (s.hasError) {
            return Center(child: Text('Error: ${s.error}'));
          }
          if (!s.hasData) {
            return const Center(child: Text('No data'));
          }
          final e = s.data!;
          final patientName = e.patient != null
              ? '${e.patient!.firstName} ${e.patient!.lastName}'
              : 'Unknown patient';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header card
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: _statusColor(e.status).withOpacity(0.15),
                          child: Icon(Icons.monitor_heart, color: _statusColor(e.status)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(patientName,
                                  style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 4),
                              Text('Status: ${_statusText(e.status)}'),
                            ],
                          ),
                        ),
                        if (e.reportUrl != null && e.reportUrl!.isNotEmpty)
                          ElevatedButton.icon(
                            onPressed: () => _openUrl(e.reportUrl!),
                            icon: const Icon(Icons.picture_as_pdf),
                            label: const Text('Open Report'),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Predictions
                Text('Top Predictions',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (e.topPredictions.isEmpty)
                  const Text('Awaiting AI results...')
                else
                  Column(
                    children: e.topPredictions.map(_predictionRow).toList(),
                  ),

                // (Optional) waveform preview
                if (e.previewUrl != null && e.previewUrl!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Waveform Preview',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  // If preview requires auth headers, fetch via API in future.
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(e.previewUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox()),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
