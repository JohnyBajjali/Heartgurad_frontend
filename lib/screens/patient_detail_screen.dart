// In lib/screens/patient_detail_screen.dart

import 'package:flutter/material.dart';
import '../api/api_service.dart';
import '../models/patient.dart';

class PatientDetailScreen extends StatefulWidget {
  final int patientId;

  const PatientDetailScreen({super.key, required this.patientId});

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  late Future<Patient> _patientFuture;

  @override
  void initState() {
    super.initState();
    // Fetch the specific patient's details when the screen loads
    _patientFuture = ApiService().getPatientById(widget.patientId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Details'),
        backgroundColor: Colors.teal,
      ),
      body: FutureBuilder<Patient>(
        future: _patientFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.hasData) {
            final patient = snapshot.data!;
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${patient.firstName} ${patient.lastName}',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const Divider(height: 24),
                      _buildDetailRow('Patient ID:', patient.id.toString()),
                      _buildDetailRow('Date of Birth:', patient.dateOfBirth),
                      _buildDetailRow('Gender:', patient.gender),
                      _buildDetailRow('Hospital:', patient.hospital?.name ?? 'N/A'),
                      _buildDetailRow('Attending Doctor:', patient.attendingDoctor?.username ?? 'N/A'),
                    ],
                  ),
                ),
              ),
            );
          }
          return const Center(child: Text('No patient data found.'));
        },
      ),
    );
  }

  // Helper widget to avoid repeating code
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }
}