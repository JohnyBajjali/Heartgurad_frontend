import 'package:flutter/material.dart';

import '../services/patient_service.dart';
import '../widgets/app_router.dart';

class PatientPickUploadScreen extends StatefulWidget {
  const PatientPickUploadScreen({super.key});

  @override
  State<PatientPickUploadScreen> createState() => _PatientPickUploadScreenState();
}

class _PatientPickUploadScreenState extends State<PatientPickUploadScreen> {
  bool _loading = true;
  String _query = '';
  List<Map<String, dynamic>> _patients = [];

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    setState(() => _loading = true);
    try {
      final list = await PatientService.fetchPatientsRaw();
      if (!mounted) return;
      setState(() {
        _patients = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showSnack('Failed to fetch patients: $e');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _nameOf(Map<String, dynamic> p) =>
      (p['name'] ?? p['full_name'] ?? '').toString().trim();

  String _idOf(Map<String, dynamic> p) =>
      (p['patient_id'] ?? p['id'] ?? '').toString().trim();

  List<Map<String, dynamic>> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _patients;

    return _patients.where((p) {
      final id = _idOf(p).toLowerCase();
      final name = _nameOf(p).toLowerCase();
      return id.contains(q) || name.contains(q);
    }).toList();
  }

  // ✅ IMPORTANT: open PatientDetailScreen (image 4) instead of CaptureUploadScreen (image 2)
  Future<void> _openPatientDetail(String patientId, String patientName) async {
    await Navigator.of(context).pushNamed(
      AppRouter.patient,
      arguments: {
        'patient_id': patientId,
        'name': patientName,
      },
    );
  }

  Future<void> _addNewPatientDialog() async {
    final nameCtrl = TextEditingController();
    final idCtrl = TextEditingController();
    bool saving = false;
    String? errorText;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            Future<void> submit() async {
              final name = nameCtrl.text.trim();
              final id = idCtrl.text.trim();

              setLocal(() => errorText = null);

              if (name.isEmpty || id.isEmpty) {
                setLocal(() => errorText = 'Please enter Patient Name and Patient ID.');
                return;
              }

              setLocal(() => saving = true);

              try {
                final p = await PatientService.loginOrCreate(
                  patientId: id,
                  name: name,
                );

                if (!mounted) return;

                Navigator.of(ctx).pop(); // close dialog
                await _loadPatients();

                // ✅ go to PatientDetailScreen
                await _openPatientDetail(p.id, p.name);
              } catch (e) {
                final msg = e.toString().replaceAll('Exception:', '').trim();
                setLocal(() {
                  saving = false;
                  errorText = msg.isEmpty ? 'Create failed' : msg;
                });
              }
            }

            return AlertDialog(
              title: const Text('Add New Patient'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Patient Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: idCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Patient ID',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          errorText!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving ? null : submit,
                  child: saving
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text('Create & Continue'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ECG Upload'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadPatients,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.black.withOpacity(0.06)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: cs.primary.withOpacity(0.12),
                        ),
                        child: Icon(Icons.upload_file, color: cs.primary),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Choose a patient',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Upload ECG to an existing patient, or create a new one.',
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _addNewPatientDialog,
                        icon: const Icon(Icons.person_add),
                        label: const Text('New Patient'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search by patient name or ID...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.black.withOpacity(0.06)),
                    ),
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : RefreshIndicator(
                      onRefresh: _loadPatients,
                      child: _filtered.isEmpty
                          ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 50),
                          Center(child: Text('No patients found.')),
                          SizedBox(height: 8),
                          Center(child: Text('Try a different search or add a new patient.')),
                          SizedBox(height: 50),
                        ],
                      )
                          : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: Colors.black.withOpacity(0.06),
                        ),
                        itemBuilder: (context, i) {
                          final p = _filtered[i];
                          final id = _idOf(p);
                          final name = _nameOf(p);

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: cs.primary.withOpacity(0.12),
                              child: Icon(Icons.person, color: cs.primary),
                            ),
                            title: Text(
                              name.isEmpty ? '(No name)' : name,
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: Text('ID: $id'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _openPatientDetail(id, name),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}