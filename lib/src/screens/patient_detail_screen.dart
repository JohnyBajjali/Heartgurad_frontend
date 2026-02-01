import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../services/ecg_upload_service.dart';

class PatientDetailScreen extends StatefulWidget {
  final String patientId;
  final String patientName;
  final String? gender;

  const PatientDetailScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    this.gender,
  });

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  bool loading = true;
  String? error;

  List<Map<String, dynamic>> ecgs = [];
  final notesCtrl = TextEditingController();

  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _loadEcgs();
  }

  @override
  void dispose() {
    notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEcgs() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final base = EcgUploadService.backendBaseUrl();
      final uri = Uri.parse('$base/api/ecg/list/?patient_id=${widget.patientId}');
      final res = await http.get(uri);

      if (res.statusCode != 200) {
        throw Exception('Failed to load ECGs (${res.statusCode})');
      }

      final decoded = jsonDecode(res.body);
      final list = (decoded as List).cast<dynamic>();

      setState(() {
        ecgs = list.map((e) => (e as Map).cast<String, dynamic>()).toList();
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  // -------------------- PICK IMAGE (UPLOAD only, no camera) --------------------
  Future<void> _pickAndUploadImage({required String layoutType}) async {
    // layoutType: "3x4" OR "3x4+1" (we keep it for later if you want backend validation)
    final picker = ImagePicker();

    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 95);
    if (picked == null) return;

    final Uint8List bytes = await picked.readAsBytes();
    final String fileName = p.basename(picked.path);

    if (!mounted) return;

    setState(() => _isUploadingImage = true);

    try {
      final streamedResp = await EcgUploadService.uploadEcg(
        imageBytes: bytes,
        fileName: fileName,
        patientName: widget.patientName,
        patientId: widget.patientId,
      );

      final body = await streamedResp.stream.bytesToString();
      final ok = streamedResp.statusCode >= 200 && streamedResp.statusCode < 300;

      if (!mounted) return;

      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Image uploaded ($layoutType)!')),
        );
        await _loadEcgs();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Upload failed [${streamedResp.statusCode}]: $body')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  // -------------------- SECOND BOTTOM SHEET (3x4 vs 3x4+1) --------------------
  Future<void> _showImageLayoutPicker() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              const ListTile(
                title: Text(
                  "Upload Image",
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text("Choose ECG image layout"),
              ),
              ListTile(
                leading: const Icon(Icons.grid_view_rounded),
                title: const Text("3×4 Image"),
                subtitle: const Text("Standard 12-lead (3×4)"),
                onTap: () => Navigator.pop(ctx, "3x4"),
              ),
              ListTile(
                leading: const Icon(Icons.grid_on_rounded),
                title: const Text("3×4 + 1 Image"),
                subtitle: const Text("3×4 plus rhythm strip"),
                onTap: () => Navigator.pop(ctx, "3x4+1"),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (!mounted) return;
    if (choice == null) return;

    await _pickAndUploadImage(layoutType: choice);
  }

  // -------------------- FIRST BOTTOM SHEET (Signal vs Image) --------------------
  Future<void> _showUploadTypePicker() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              const ListTile(
                title: Text(
                  "Upload ECG",
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text("Choose what you want to upload"),
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file_outlined),
                title: const Text("Upload Signal"),
                subtitle: const Text("XML or aECG file"),
                onTap: () => Navigator.pop(ctx, "signal"),
              ),
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text("Upload Image"),
                subtitle: const Text("3×4 or 3×4 + 1 image"),
                onTap: () => Navigator.pop(ctx, "image"),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (!mounted) return;
    if (choice == null) return;

    if (choice == "image") {
      // ✅ NO second screen navigation anymore
      await _showImageLayoutPicker();
      return;
    }

    if (choice == "signal") {
      // TODO: implement FilePicker for XML/aECG + call EcgUploadService.uploadSignal(...)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Signal upload (XML/aECG) will be implemented in the next step.'),
        ),
      );
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.patientName} (ID: ${widget.patientId})'),
        actions: [
          IconButton(onPressed: _loadEcgs, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildIntakeCard(
                    context,
                    onScan: () {
                      // Keep Scan/Camera as-is (if you want to later)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Scan/Camera flow is separate.')),
                      );
                    },
                    onUpload: _isUploadingImage ? null : _showUploadTypePicker,
                  ),

                  const SizedBox(height: 16),

                  Text('Doctor Notes', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesCtrl,
                    minLines: 3,
                    maxLines: 6,
                    decoration: InputDecoration(
                      hintText: 'Write notes for this patient...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),

                  const SizedBox(height: 16),
                  Text('Previous ECGs', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),

                  if (loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text(error!, textAlign: TextAlign.center)),
                    )
                  else if (ecgs.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'No ECGs uploaded for this patient yet.',
                            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: ecgs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final e = ecgs[i];
                          final id = e['id']?.toString() ?? '';
                          final created = e['uploaded_at']?.toString() ?? '';
                          final fileUrl = e['url']?.toString() ?? '';

                          return Card(
                            child: ListTile(
                              title: Text('ECG #$id'),
                              subtitle: Text(created.isEmpty ? 'Uploaded' : created),
                              trailing: const Icon(Icons.open_in_new),
                              onTap: fileUrl.isEmpty
                                  ? null
                                  : () {
                                showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('ECG URL'),
                                    content: SelectableText(fileUrl),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Close'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildIntakeCard(
      BuildContext context, {
        required VoidCallback onScan,
        required VoidCallback? onUpload,
      }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ECG Intake',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Scan or upload Signal (XML/aECG) or Image (3×4 / 3×4+1)',
            style: TextStyle(color: Colors.black.withValues(alpha: 0.65)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onScan,
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Scan / Camera'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onUpload,
                  icon: _isUploadingImage
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.cloud_upload_rounded),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Upload'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0E6B6F),
                    disabledBackgroundColor: const Color(0xFF9FB9BC),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}