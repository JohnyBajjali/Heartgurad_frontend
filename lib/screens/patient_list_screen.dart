// lib/screens/patient_list_screen.dart
import 'package:flutter/material.dart';
import '../api/api_service.dart';
import '../models/patient.dart';
import 'patient_detail_screen.dart';

class PatientListScreen extends StatefulWidget {
  const PatientListScreen({super.key});

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  late Future<List<Patient>> _patientsFuture;

  @override
  void initState() {
    super.initState();
    _patientsFuture = ApiService().getPatients();
  }

  void _refresh() {
    setState(() {
      _patientsFuture = ApiService().getPatients();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patients'),
        backgroundColor: Colors.teal,
      ),
      body: FutureBuilder<List<Patient>>(
        future: _patientsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            final patients = snapshot.data!;
            if (patients.isEmpty) {
              return const Center(
                child: Text('No patients found.\nAdd a patient in the Django admin panel.',
                    textAlign: TextAlign.center),
              );
            }
            return ListView.builder(
              itemCount: patients.length,
              itemBuilder: (context, index) {
                final p = patients[index];
                return ListTile(
                  leading: const Icon(Icons.person),
                  title: Text('${p.firstName} ${p.lastName}'),
                  subtitle: Text('DOB: ${p.dateOfBirth}'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => PatientDetailScreen(patientId: p.id)),
                    );
                  },
                );
              },
            );
          }
          return const Center(child: Text('Something went wrong.'));
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _refresh,
        tooltip: 'Refresh',
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
