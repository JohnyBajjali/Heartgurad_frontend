import 'package:flutter/material.dart';
import '../services/patient_service.dart';

enum Gender { male, female }

class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  final nameCtrl = TextEditingController();
  final idCtrl = TextEditingController();
  final ageCtrl = TextEditingController();
  Gender? gender;

  bool creating = false;

  List<Map<String, dynamic>> patients = [];
  bool loading = true;
  String? loadError;

  OutlineInputBorder _rounded() =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(14));

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    idCtrl.dispose();
    ageCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    final clean = msg.replaceAll('Exception:', '').trim();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(clean.isEmpty ? 'Something went wrong' : clean),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _loadPatients() async {
    setState(() {
      loading = true;
      loadError = null;
    });

    try {
      final items = await PatientService.fetchPatientsRaw();
      setState(() {
        patients = items;
        loading = false;
      });
    } catch (e) {
      setState(() {
        loadError = e.toString();
        loading = false;
      });
    }
  }

  String? _toBackendGender() {
    if (gender == null) return null;
    return gender == Gender.male ? 'M' : 'F';
  }

  String _genderLabel(String? g) {
    if (g == 'M') return 'Male';
    if (g == 'F') return 'Female';
    return '';
  }

  int? _parseAge(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  Future<void> createPatient() async {
    final name = nameCtrl.text.trim();
    final id = idCtrl.text.trim();
    final age = _parseAge(ageCtrl.text);

    if (name.isEmpty || id.isEmpty) {
      _snack('Enter patient name and ID');
      return;
    }

    // ✅ gender is mandatory
    if (gender == null) {
      _snack('Please select gender');
      return;
    }

    // ✅ age is mandatory
    if (age == null) {
      _snack('Enter a valid age');
      return;
    }
    if (age <= 0 || age > 130) {
      _snack('Age must be between 1 and 130');
      return;
    }

    // optional client-side check (backend is the real enforcement)
    final idExistsLocal =
    patients.any((p) => (p['patient_id']?.toString() ?? '') == id);
    if (idExistsLocal) {
      _snack('Patient ID already exists');
      return;
    }

    setState(() => creating = true);

    try {
      await PatientService.createPatient(
        patientId: id,
        fullName: name,
        age: age,
        gender: _toBackendGender(), // now always M/F (not null)
      );

      nameCtrl.clear();
      idCtrl.clear();
      ageCtrl.clear();
      setState(() => gender = null);

      await _loadPatients();
      if (mounted) _snack('Patient created successfully');
    } catch (e) {
      if (mounted) _snack(e.toString());
    } finally {
      if (mounted) setState(() => creating = false);
    }
  }

  Future<void> _confirmDelete(String patientId, String patientName) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete patient?'),
        content: Text(
          'Delete "$patientName" (ID: $patientId)?\nThis cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await PatientService.deletePatient(patientId);
      await _loadPatients();
      _snack('Patient deleted');
    } catch (e) {
      _snack(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // ✅ Disable Create until gender selected (mandatory)
    final canCreate = !creating && gender != null;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                'Patients',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _loadPatients,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Create Card
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create Patient',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Full Name + ID + Age
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: nameCtrl,
                          decoration: InputDecoration(
                            labelText: 'Full Name',
                            border: _rounded(),
                            enabledBorder: _rounded(),
                            focusedBorder: _rounded(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: idCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Patient ID (unique)',
                            border: _rounded(),
                            enabledBorder: _rounded(),
                            focusedBorder: _rounded(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: ageCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Age',
                            border: _rounded(),
                            enabledBorder: _rounded(),
                            focusedBorder: _rounded(),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Gender:',
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.75),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      ChoiceChip(
                        label: const Text('Male'),
                        selected: gender == Gender.male,
                        onSelected: creating
                            ? null
                            : (_) => setState(() => gender = Gender.male),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      ChoiceChip(
                        label: const Text('Female'),
                        selected: gender == Gender.female,
                        onSelected: creating
                            ? null
                            : (_) => setState(() => gender = Gender.female),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),

                      FilledButton.icon(
                        // ✅ disabled until gender selected
                        onPressed: canCreate ? createPatient : null,
                        icon: creating
                            ? const SizedBox(
                          width: 16,
                          height: 16,
                          child:
                          CircularProgressIndicator(strokeWidth: 2),
                        )
                            : const Icon(Icons.add),
                        label: Text(creating ? 'Creating...' : 'Create'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          Text(
            'Existing Patients',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),

          // List
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : loadError != null
                ? Center(
              child: Text(
                'Failed to load patients.\n$loadError',
                textAlign: TextAlign.center,
              ),
            )
                : patients.isEmpty
                ? const Center(
              child: Text('No patients yet. Create one above.'),
            )
                : ListView.separated(
              itemCount: patients.length,
              separatorBuilder: (_, __) =>
              const Divider(height: 1),
              itemBuilder: (_, i) {
                final p = patients[i];
                final name =
                (p['full_name'] ?? '').toString().trim();
                final id =
                (p['patient_id'] ?? '').toString().trim();
                final g = p['gender']?.toString();
                final ecgCount = (p['ecg_count'] ?? 0).toString();
                final age = p['age'];

                final gLabel = _genderLabel(g);

                final parts = <String>[
                  'ID: $id',
                  if (age != null && age.toString().isNotEmpty)
                    'Age: $age',
                  if (gLabel.isNotEmpty) gLabel,
                  'ECGs: $ecgCount',
                ];

                final subtitle = parts.join(' • ');
                final displayName =
                name.isEmpty ? '(No name)' : name;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: cs.primary.withOpacity(0.12),
                    child: Text(
                      displayName[0].toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: cs.primary,
                      ),
                    ),
                  ),
                  title: Text(displayName),
                  subtitle: Text(subtitle),
                  trailing: IconButton(
                    tooltip: 'Delete',
                    icon: Icon(Icons.delete_outline,
                        color: cs.error),
                    onPressed: () =>
                        _confirmDelete(id, displayName),
                  ),
                  onTap: () {
                    Navigator.of(context).pushNamed(
                      '/patient',
                      arguments: {
                        'patient_id': id,
                        'name': displayName,
                        'gender': g,
                        'age': age,
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}