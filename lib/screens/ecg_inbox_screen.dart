// lib/screens/ecg_inbox_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api/api_service.dart';
import '../models/ecg_exam.dart';
import 'ecg_detail_screen.dart';

class EcgInboxScreen extends StatefulWidget {
  const EcgInboxScreen({super.key});

  @override
  State<EcgInboxScreen> createState() => _EcgInboxScreenState();
}

class _EcgInboxScreenState extends State<EcgInboxScreen> {
  late Future<List<EcgExam>> _future;
  Timer? _poller;
  String _filter = 'ALL'; // ALL | PENDING | PROCESSING | READY | FAILED

  @override
  void initState() {
    super.initState();
    _future = ApiService().getEcgExams();
    // Simple polling every 5s (can switch to WebSockets later)
    _poller = Timer.periodic(const Duration(seconds: 5), (_) {
      _refresh(silent: true);
    });
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  void _refresh({bool silent = false}) {
    setState(() {
      _future = ApiService()
          .getEcgExams(status: _filter == 'ALL' ? null : _filter);
    });
    if (!silent) {
      // optional: show a brief feedback
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Refreshing ECGs...'), duration: Duration(milliseconds: 600)),
      );
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    return DateFormat('yyyy-MM-dd HH:mm').format(dt);
    // Option: add timezone if desired
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ECG Inbox'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
          PopupMenuButton<String>(
            initialValue: _filter,
            onSelected: (v) {
              setState(() => _filter = v);
              _refresh();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'ALL', child: Text('All')),
              PopupMenuItem(value: 'PENDING', child: Text('Pending')),
              PopupMenuItem(value: 'PROCESSING', child: Text('Processing')),
              PopupMenuItem(value: 'READY', child: Text('Ready')),
              PopupMenuItem(value: 'FAILED', child: Text('Failed')),
            ],
          )
        ],
      ),
      body: FutureBuilder<List<EcgExam>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final exams = snapshot.data ?? [];
          if (exams.isEmpty) {
            return const Center(child: Text('No ECG exams yet.'));
          }

          return ListView.separated(
            itemCount: exams.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final e = exams[i];
              final patientName = e.patient != null
                  ? '${e.patient!.firstName} ${e.patient!.lastName}'
                  : 'Unknown patient';
              final status = _statusText(e.status);

              // Build a 1-line preview of top predictions if any
              final preds = e.topPredictions.take(3).map((p) {
                final pct = (p.prob * 100).toStringAsFixed(0);
                return '${p.label} $pct%';
              }).join(' · ');

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: _statusColor(e.status).withOpacity(0.15),
                  child: Icon(Icons.monitor_heart, color: _statusColor(e.status)),
                ),
                title: Text(patientName, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '${_formatDate(e.createdAt)}  •  $status'
                  '${preds.isNotEmpty ? '  •  $preds' : ''}',
                  maxLines: 2,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => EcgDetailScreen(examId: e.id)),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
