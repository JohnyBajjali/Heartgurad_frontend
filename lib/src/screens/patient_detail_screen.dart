import 'dart:convert';
import 'dart:typed_data';
import 'dart:io' show File;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;

import '../services/ecg_upload_service.dart';
import '../services/doctor_notes_service.dart';
import '../screens/manual_crop_screen.dart'; // adjust path if different


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

  // Notes
  final notesCtrl = TextEditingController();
  List<Map<String, dynamic>> notes = [];
  bool notesLoading = true;
  bool savingNote = false;

  bool _isUploadingImage = false;
  bool _isUploadingSignal = false;

  // ============================
  // ✅ PTB-XL Diagnostic 5 classes
  // ============================
  static const List<_DiagBucket> _diagBuckets = [
    _DiagBucket(key: 'NORM', title: 'NORM — Normal'),
    _DiagBucket(key: 'MI', title: 'MI — Myocardial Infarction'),
    _DiagBucket(key: 'STTC', title: 'STTC — ST/T Change (Ischemia / ST–T)'),
    _DiagBucket(key: 'CD', title: 'CD — Conduction Disturbance'),
    _DiagBucket(key: 'HYP', title: 'HYP — Hypertrophy'),
  ];

  // Threshold for showing “none above threshold”
  // You can adjust this if you want (0.50 means 50%)
  static const double _diagThreshold = 0.50;

  // CSV lookup: scp_code -> row map
  Map<String, Map<String, String>> _scpMap = {};
  bool _scpReady = false;

  // ============================
  // ✅ Group detailed labels under superclasses
  // ============================
  // Some rhythm/device labels might not exist in "diagnostic_class" mapping.
  // We still want them under one of the 5 superclasses to keep the UI consistent.
  // Best default bucket for rhythm/device: CD.
  static const Set<String> _fallbackToCD = {
    // Arrhythmia examples (PTB-XL style codes vary; keep what you see in your outputs)
    'AFIB',
    'AFLT',
    'SVTAC',
    'PSVT',
    'STACH',
    'SBRAD',
    'PAC',
    'PVC',
    'BIGU',
    'TRIGU',

    // Pacemaker/device
    'PACE',
  };

  String? _fallbackDiagClass(String code) {
    if (_fallbackToCD.contains(code)) return 'CD';
    return null;
  }

  String _labelDescription(String code) {
    final row = _scpMap[code];
    if (row == null) return code;

    // Try common columns across CSV variants
    final d1 = (row['description'] ?? '').trim();
    if (d1.isNotEmpty) return d1;

    final d2 = (row['statement_description'] ?? '').trim();
    if (d2.isNotEmpty) return d2;

    final d3 = (row['label'] ?? '').trim();
    if (d3.isNotEmpty) return d3;

    // Sometimes the original scp_statements uses "diagnostic" columns; keep fallback:
    return code;
  }

  Map<String, List<Map<String, dynamic>>> _groupTopkBySuperclass(List<Map<String, dynamic>> topk) {
    final grouped = <String, List<Map<String, dynamic>>>{
      for (final b in _diagBuckets) b.key: <Map<String, dynamic>>[],
    };

    for (final item in topk) {
      final code = (item['label'] ?? '').toString().trim();
      if (code.isEmpty) continue;

      final p = (item['p'] is num) ? (item['p'] as num).toDouble() : 0.0;

      // Only show detailed labels that are above threshold, to avoid noise
      if (p < _diagThreshold) continue;

      final dc = _diagClassOf(code) ?? _fallbackDiagClass(code);

      if (dc == null || !grouped.containsKey(dc)) continue;

      grouped[dc]!.add({
        'code': code,
        'name': _labelDescription(code),
        'p': p,
      });
    }

    // Sort each group by probability desc
    for (final k in grouped.keys) {
      grouped[k]!.sort((a, b) => (b['p'] as double).compareTo(a['p'] as double));
    }

    return grouped;
  }

  @override
  void initState() {
    super.initState();
    _loadScpCsv(); // ✅ load CSV first (async)
    _loadEcgs();
    _loadNotes();
  }

  @override
  void dispose() {
    notesCtrl.dispose();
    super.dispose();
  }

  // ----------------------------
  // ✅ Load SCP CSV mapping
  // ----------------------------
  Future<void> _loadScpCsv() async {
    try {
      final csv = await rootBundle.loadString('assets/data/scp_statementsRegrouped2.csv');
      final rows = _parseCsvToMaps(csv);

      final map = <String, Map<String, String>>{};

      for (final r in rows) {
        // SCP code column (after fixing CSV header)
        final code = (r['scp_code'] ?? '').replaceAll('\uFEFF', '').trim();
        if (code.isEmpty) continue;

        map[code] = r;
      }

      if (!mounted) return;
      setState(() {
        _scpMap = map;
        _scpReady = map.isNotEmpty;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _scpMap = {};
        _scpReady = false;
      });
    }
  }

  // Returns the diagnostic_class for a code (MI/STTC/CD/HYP/NORM), or null if not diagnostic
  String? _diagClassOf(String scpCode) {
    final row = _scpMap[scpCode];
    if (row == null) return null;

    // In your CSV, "diagnostic_class" contains MI / STTC / CD / HYP / NORM for diagnostic codes.
    final dc = (row['diagnostic_class'] ?? '').trim();
    if (dc.isNotEmpty) return dc;

    // Fallbacks (just in case your CSV format changes)
    final ds = (row['diagnostic_superclass'] ?? '').trim();
    if (ds.isNotEmpty) return ds;

    return null;
  }

  // Aggregate topk -> 5 diagnostic scores using max() per class
  Map<String, _DiagScore> _aggregateDiag5(List<Map<String, dynamic>> topk) {
    final scores = <String, _DiagScore>{
      for (final b in _diagBuckets) b.key: _DiagScore(label: b.key, p: 0.0, bestCode: null),
    };

    for (final item in topk) {
      final code = (item['label'] ?? '').toString().trim();
      if (code.isEmpty) continue;

      final p = (item['p'] is num) ? (item['p'] as num).toDouble() : 0.0;

      final dc = _diagClassOf(code) ?? _fallbackDiagClass(code);
      if (dc == null) continue;

      if (scores.containsKey(dc)) {
        final prev = scores[dc]!;
        if (p > prev.p) {
          scores[dc] = _DiagScore(label: dc, p: p, bestCode: code);
        }
      }
    }

    return scores;
  }

  _DiagScore _bestDiagScore(Map<String, _DiagScore> scores) {
    final list = scores.values.toList()..sort((a, b) => b.p.compareTo(a.p));
    return list.first;
  }

  // ----------------------------
  // Notes
  // ----------------------------
  Future<void> _loadNotes() async {
    setState(() => notesLoading = true);
    try {
      final list = await DoctorNotesService.fetchNotes(widget.patientId);
      if (!mounted) return;
      setState(() {
        notes = list;
        notesLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => notesLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load notes: $e')),
      );
    }
  }

  Future<void> _saveNewNote() async {
    final text = notesCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write a note first.')),
      );
      return;
    }

    setState(() => savingNote = true);
    try {
      await DoctorNotesService.addNote(patientId: widget.patientId, text: text);
      if (!mounted) return;
      notesCtrl.clear();
      await _loadNotes();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Note saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => savingNote = false);
    }
  }

  Future<void> _editNote(Map<String, dynamic> note) async {
    final ctrl = TextEditingController(text: (note['text'] ?? '').toString());

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Note'),
        content: TextField(
          controller: ctrl,
          minLines: 3,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: 'Update note...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );

    if (ok != true) return;
    final newText = ctrl.text.trim();
    if (newText.isEmpty) return;

    final noteId = (note['id'] as num).toInt();
    try {
      await DoctorNotesService.updateNote(
        patientId: widget.patientId,
        noteId: noteId,
        text: newText,
      );
      if (!mounted) return;
      await _loadNotes();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Note updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Update failed: $e')),
      );
    }
  }

  Future<void> _deleteNote(Map<String, dynamic> note) async {
    final noteId = (note['id'] as num).toInt();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Note?'),
        content: const Text('This will permanently delete the note.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await DoctorNotesService.deleteNote(patientId: widget.patientId, noteId: noteId);
      if (!mounted) return;
      await _loadNotes();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Note deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Delete failed: $e')),
      );
    }
  }

  Future<Uint8List?> _openManualCrop(Uint8List bytes) async {
    final cropped = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => ManualCropScreen(imageBytes: bytes),
      ),
    );
    return cropped; // null if user cancelled
  }

  // ----------------------------
  // ECG list
  // ----------------------------
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
        throw Exception('Failed to load ECGs (${res.statusCode}): ${res.body}');
      }

      final decoded = jsonDecode(res.body);
      final list = (decoded as List).cast<dynamic>();

      if (!mounted) return;
      setState(() {
        ecgs = list.map((e) => (e as Map).cast<String, dynamic>()).toList();
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<void> _deleteEcg(Map<String, dynamic> e) async {
    final id = e['id'];
    if (id == null) return;

    final created = _fmtDate((e['uploaded_at'] ?? '').toString());
    final titleLabel = created.isEmpty ? 'ECG' : 'ECG • $created';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete ECG?'),
        content: Text('Delete $titleLabel from this patient history?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final base = EcgUploadService.backendBaseUrl();
      final uri = Uri.parse('$base/api/ecg/delete/');

      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'patient_id': int.parse(widget.patientId),
          'ecg_id': int.parse(id.toString()),
        }),
      );

      if (res.statusCode != 200) {
        throw Exception('Delete failed (${res.statusCode}): ${res.body}');
      }

      await _loadEcgs();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ ECG deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Delete failed: $e')),
      );
    }
  }

  Future<void> _openEcg(Map<String, dynamic> e) async {
    final created = _fmtDate((e['uploaded_at'] ?? '').toString());
    final titleLabel = created.isEmpty ? 'ECG' : 'ECG • $created';

    final fileUrl = e['url']?.toString() ?? '';

    if (e['prediction_topk'] is List) {
      final data = <String, dynamic>{
        "topk": e['prediction_topk'],
        "preview_image_url": e['preview_image_url'],
        "original_image_url": e['url'],
        "source_type": e['source_type'],
      };
      await _showPredictionDialogFromJson(title: '$titleLabel Result', data: data);
      return;
    }

    if (fileUrl.isEmpty) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(titleLabel),
        content: SelectableText(fileUrl),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ----------------------------
  // Upload IMAGE: upload -> predict (with ecg_id)
  // ----------------------------
  Future<void> _pickAndUploadImage({required String layoutType}) async {
    final picker = ImagePicker();

    // 1) Pick from gallery
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
    );
    if (picked == null) return;

    // 2) Read original bytes
    final originalBytes = await picked.readAsBytes();

    // 3) Manual crop (same UI used for camera)
    if (!mounted) return;
    final Uint8List? croppedBytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => ManualCropScreen(imageBytes: originalBytes),
      ),
    );

    // If user cancelled crop
    if (croppedBytes == null) return;

    // Use cropped bytes for upload + predict
    final bytes = croppedBytes;

    // Safe filename (on web picked.path can be weird/empty)
    final fileName = (picked.name.isNotEmpty)
        ? picked.name
        : 'upload_${DateTime.now().millisecondsSinceEpoch}.jpg';

    if (!mounted) return;
    setState(() => _isUploadingImage = true);

    try {
      // 4) Upload (store in history)
      final uploadJson = await EcgUploadService.uploadEcgAndGetJson(
        fileBytes: bytes,
        fileName: fileName,
        patientName: widget.patientName,
        patientId: widget.patientId,
      );
      final ecgId = (uploadJson['ecg_id'] as num).toInt();

      // 5) Predict and save in same row
      final predResp = await EcgUploadService.predictUnified(
        fileBytes: bytes,
        fileName: fileName,
        patientName: widget.patientName,
        patientId: widget.patientId,
        ecgId: ecgId,
        layout: layoutType,
      );

      final predBody = await predResp.stream.bytesToString();
      final ok = predResp.statusCode >= 200 && predResp.statusCode < 300;

      if (!mounted) return;

      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Cropped + uploaded + predicted ($layoutType)!')),
        );
        await _showBackendResponseDialog(
          title: 'Image Result ($layoutType)',
          body: predBody,
        );
        await _loadEcgs();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Predict failed [${predResp.statusCode}]: $predBody')),
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

  Future<void> _showImageLayoutPicker() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            const ListTile(
              title: Text("Upload Image", style: TextStyle(fontWeight: FontWeight.w700)),
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
      ),
    );

    if (!mounted) return;
    if (choice == null) return;

    await _pickAndUploadImage(layoutType: choice);
  }

  Future<void> _captureAndUploadImage({required String layoutType}) async {
    final picker = ImagePicker();

    // 1) Capture image from camera
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 95,
    );
    if (picked == null) return;

    // 2) Read bytes (original captured)
    final originalBytes = await picked.readAsBytes();

    // 3) Manual crop screen (returns Uint8List or null if cancelled)
    if (!mounted) return;
    final Uint8List? croppedBytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => ManualCropScreen(imageBytes: originalBytes),
      ),
    );

    // If user cancelled crop, stop
    if (croppedBytes == null) return;

    final fileName = 'camera_${DateTime.now().millisecondsSinceEpoch}.jpg';

    if (!mounted) return;
    setState(() => _isUploadingImage = true);

    try {
      // 4) Upload cropped image (store in history)
      final uploadJson = await EcgUploadService.uploadEcgAndGetJson(
        fileBytes: croppedBytes,
        fileName: fileName,
        patientName: widget.patientName,
        patientId: widget.patientId,
      );

      final ecgId = (uploadJson['ecg_id'] as num).toInt();

      // 5) Predict using the same cropped image + save result in same row
      final predResp = await EcgUploadService.predictUnified(
        fileBytes: croppedBytes,
        fileName: fileName,
        patientName: widget.patientName,
        patientId: widget.patientId,
        ecgId: ecgId,
        layout: layoutType,
      );

      final predBody = await predResp.stream.bytesToString();
      final ok = predResp.statusCode >= 200 && predResp.statusCode < 300;

      if (!mounted) return;

      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Cropped + uploaded + predicted ($layoutType)!')),
        );

        await _showBackendResponseDialog(
          title: 'Camera Result ($layoutType)',
          body: predBody,
        );

        await _loadEcgs();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Predict failed [${predResp.statusCode}]: $predBody')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Camera upload failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _showCameraLayoutPicker() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            const ListTile(
              title: Text("Scan / Camera", style: TextStyle(fontWeight: FontWeight.w700)),
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
      ),
    );

    if (!mounted) return;
    if (choice == null) return;

    await _captureAndUploadImage(layoutType: choice);
  }

  // ----------------------------
  // Upload SIGNAL: upload -> predict (saved)
  // ----------------------------
  Future<void> _showSignalTypePicker() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            const ListTile(
              title: Text("Upload Signal", style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text("Choose signal type"),
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text("XML"),
              subtitle: const Text("Upload a Philips XML ECG"),
              onTap: () => Navigator.pop(ctx, "xml"),
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: const Text("aECG"),
              subtitle: const Text("Upload an aECG file"),
              onTap: () => Navigator.pop(ctx, "aecg"),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!mounted) return;
    if (choice == null) return;

    if (choice == "xml") {
      await _pickAndUploadSignal(allowedExt: const ["xml"]);
    } else if (choice == "aecg") {
      await _pickAndUploadSignal(allowedExt: const ["aecg"]);
    }
  }

  Future<void> _pickAndUploadSignal({required List<String> allowedExt}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExt,
      withData: kIsWeb,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final fileName = file.name;

    Uint8List bytes;
    if (kIsWeb) {
      if (file.bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read file bytes on web.')),
        );
        return;
      }
      bytes = file.bytes!;
    } else {
      if (file.path == null) return;
      bytes = await File(file.path!).readAsBytes();
    }

    if (!mounted) return;
    setState(() => _isUploadingSignal = true);

    try {
      final result = await EcgUploadService.uploadSignalAndPredict(
        fileBytes: bytes,
        fileName: fileName,
        patientName: widget.patientName,
        patientId: widget.patientId,
      );

      final predResp = result["predictResponse"] as http.StreamedResponse;
      final body = await predResp.stream.bytesToString();
      final ok = predResp.statusCode >= 200 && predResp.statusCode < 300;

      if (!mounted) return;

      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Signal uploaded + predicted ($fileName)')),
        );
        await _showBackendResponseDialog(title: 'Signal Result', body: body);
        await _loadEcgs();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Signal predict failed [${predResp.statusCode}]: $body')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading signal: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUploadingSignal = false);
    }
  }

  // ----------------------------
  // Upload type picker
  // ----------------------------
  Future<void> _showUploadTypePicker() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            const ListTile(
              title: Text("Upload ECG", style: TextStyle(fontWeight: FontWeight.w700)),
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
      ),
    );

    if (!mounted) return;
    if (choice == null) return;

    if (choice == "image") {
      await _showImageLayoutPicker();
      return;
    }
    if (choice == "signal") {
      await _showSignalTypePicker();
      return;
    }
  }

  // ----------------------------
  // Result dialog (pretty)
  // ----------------------------
  Future<void> _showBackendResponseDialog({required String title, required String body}) async {
    if (!mounted) return;

    Map<String, dynamic>? data;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) data = decoded;
    } catch (_) {}

    if (data == null) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(child: SelectableText(body)),
            ),
          ),
        ),
      );
      return;
    }

    await _showPredictionDialogFromJson(title: title, data: data);
  }

  Future<void> _showPredictionDialogFromJson({
    required String title,
    required Map<String, dynamic> data,
  }) async {
    // ----------------------------
    // ✅ Read URLs (preview / original / digitized)
    // ----------------------------
    String? previewUrl =
    (data['preview_image_url'] ??
        data['previewUrl'] ??
        data['preview_url'] ??
        ((data['meta'] is Map) ? (data['meta']['preview_url']) : null))
        ?.toString();

    String? originalUrl =
    (data['original_image_url'] ??
        data['originalUrl'] ??
        data['original_url'] ??
        ((data['meta'] is Map) ? (data['meta']['original_url']) : null))
        ?.toString();

    String? digitizedUrl =
    (data['digitized_image_url'] ??
        data['digitizedUrl'] ??
        data['digitized_url'] ??
        ((data['meta'] is Map) ? (data['meta']['digitized_url']) : null))
        ?.toString();

    // If backend returns /media/... make them absolute
    final base = EcgUploadService.backendBaseUrl();

    if (previewUrl != null && previewUrl.isNotEmpty && !previewUrl.startsWith('http')) {
      previewUrl = '$base$previewUrl';
    }
    if (originalUrl != null && originalUrl.isNotEmpty && !originalUrl.startsWith('http')) {
      originalUrl = '$base$originalUrl';
    }
    if (digitizedUrl != null && digitizedUrl.isNotEmpty && !digitizedUrl.startsWith('http')) {
      digitizedUrl = '$base$digitizedUrl';
    }

    debugPrint('previewUrl=$previewUrl');
    debugPrint('originalUrl=$originalUrl');
    debugPrint('digitizedUrl=$digitizedUrl');

    // ----------------------------
    // ✅ Parse & sort topk
    // ----------------------------
    final topkRaw = data['topk'] ?? data['prediction_topk'];
    final List<Map<String, dynamic>> topk = (topkRaw is List)
        ? topkRaw.map((e) => (e as Map).cast<String, dynamic>()).toList()
        : <Map<String, dynamic>>[];

    topk.sort((a, b) {
      final pa = (a['p'] is num) ? (a['p'] as num).toDouble() : 0.0;
      final pb = (b['p'] is num) ? (b['p'] as num).toDouble() : 0.0;
      return pb.compareTo(pa);
    });

    // ✅ Aggregate into 5 diagnostic classes if CSV is ready
    final diagScores = _scpReady ? _aggregateDiag5(topk) : null;
    final bestDiag = (diagScores != null) ? _bestDiagScore(diagScores) : null;

    // ✅ Group detailed ProtoECGNet labels under superclasses
    final grouped = (_scpReady) ? _groupTopkBySuperclass(topk) : null;

    // ----------------------------
    // ✅ Show dialog
    // ----------------------------
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final screen = MediaQuery.of(ctx).size;
        final w = (screen.width * 0.92).clamp(520.0, 1100.0);
        final h = (screen.height * 0.92).clamp(520.0, 900.0);

        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: SizedBox(
            width: w,
            height: h,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ✅ 1) ORIGINAL UPLOADED IMAGE
                        if (originalUrl != null && originalUrl.isNotEmpty) ...[
                          const _SectionTitle(title: 'ORIGINAL UPLOADED IMAGE'),
                          const SizedBox(height: 8),
                          _PreviewBox(url: originalUrl),
                          const SizedBox(height: 16),
                        ],

                        // ✅ 2) DIGITIZED-LIKE-ORIGINAL IMAGE
                        if (digitizedUrl != null && digitizedUrl.isNotEmpty) ...[
                          const _SectionTitle(title: 'DIGITIZED (LIKE ORIGINAL) — 3×4'),
                          const SizedBox(height: 8),
                          _PreviewBox(url: digitizedUrl),
                          const SizedBox(height: 16),
                        ],

                        // ✅ 3) PREVIEW/CROPPED USED FOR MODEL (optional)
                        if (previewUrl != null && previewUrl.isNotEmpty) ...[
                          const _SectionTitle(title: 'PREVIEW / CROPPED USED FOR MODEL'),
                          const SizedBox(height: 8),
                          _PreviewBox(url: previewUrl),
                          const SizedBox(height: 16),
                        ],

                        // Fallback if CSV not loaded
                        if (!_scpReady && topk.isNotEmpty) ...[
                          _TopResultCard(item: topk.first),
                          const SizedBox(height: 16),
                        ],

                        // ✅ Top superclass summary
                        if (_scpReady && bestDiag != null) ...[
                          _TopDiagCard(score: bestDiag),
                          const SizedBox(height: 16),
                        ],

                        _SectionTitle(title: 'DIAGNOSTIC CLASS (PTB-XL 5-way)'),
                        const SizedBox(height: 8),

                        if (!_scpReady)
                          Text(
                            'CSV mapping not loaded yet. Please ensure scp_statementsRegrouped2.csv is in assets.',
                            style: TextStyle(
                              color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.70),
                            ),
                          )
                        else ...[
                          for (final b in _diagBuckets) ...[
                            _DiagRow(
                              title: b.title,
                              score: diagScores![b.key]!,
                              threshold: _diagThreshold,
                            ),
                            const SizedBox(height: 8),
                          ],

                          const SizedBox(height: 6),
                          Text(
                            'Threshold: ${(100 * _diagThreshold).toStringAsFixed(0)}% '
                                '(classes below threshold are shown as “none above threshold”, '
                                'and detailed labels below threshold are hidden).',
                            style: TextStyle(
                              color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.60),
                              fontSize: 12,
                            ),
                          ),

                          const SizedBox(height: 18),
                          const _SectionTitle(
                            title: 'DETAILED LABELS (ProtoECGNet) — grouped by superclass',
                          ),
                          const SizedBox(height: 8),

                          for (final b in _diagBuckets) ...[
                            _DiagGroupTile(
                              bucket: b,
                              diagScore: diagScores![b.key]!,
                              items: grouped![b.key] ?? const [],
                            ),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _fmtDate(String iso) {
    if (iso.trim().isEmpty) return '';

    try {
      final dt = DateTime.parse(iso).toLocal(); // convert from +00:00 to your local time
      String two(int n) => n.toString().padLeft(2, '0');

      return '${dt.year}-${two(dt.month)}-${two(dt.day)}  ${two(dt.hour)}:${two(dt.minute)}';
    } catch (_) {
      // fallback if parse fails
      return iso.replaceFirst('T', ' ').split('.').first;
    }
  }

  // ----------------------------
  // UI
  // ----------------------------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final busyUpload = _isUploadingImage || _isUploadingSignal;

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
                    onScan: busyUpload ? () {} : _showCameraLayoutPicker,
                    onUpload: busyUpload ? null : _showUploadTypePicker,
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
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: savingNote ? null : _saveNewNote,
                        icon: savingNote
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                            : const Icon(Icons.save),
                        label: Text(savingNote ? 'Saving...' : 'Save Note'),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: _loadNotes,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh Notes'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (notesLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (notes.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No notes yet.',
                        style: TextStyle(color: cs.onSurface.withValues(alpha: 0.65)),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: notes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final n = notes[i];
                        final text = (n['text'] ?? '').toString();
                        final created = _fmtDate((n['created_at'] ?? '').toString());
                        final updated = _fmtDate((n['updated_at'] ?? '').toString());

                        return Card(
                          child: ListTile(
                            title: Text(created.isEmpty ? 'Note' : 'Note • $created'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 6),
                                Text(text),
                                if (updated.isNotEmpty && updated != created) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Updated: $updated',
                                    style: TextStyle(
                                      color: cs.onSurface.withValues(alpha: 0.6),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            isThreeLine: true,
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'edit') _editNote(n);
                                if (v == 'delete') _deleteNote(n);
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'edit', child: Text('Edit')),
                                PopupMenuItem(value: 'delete', child: Text('Delete')),
                              ],
                            ),
                          ),
                        );
                      },
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

                          // Keep id for internal use only (dialog/data), not for user label
                          final id = e['id']?.toString() ?? '';

                          // Uploaded time formatted (your existing formatter)
                          final created = _fmtDate((e['uploaded_at'] ?? '').toString());

                          // ✅ Title shown to user = date/time (or fallback)
                          final titleLabel = created.isEmpty ? 'ECG' : 'ECG • $created';

                          final fileUrl = e['url']?.toString() ?? '';

                          // Upload type label
                          final sourceType = (e['source_type'] ?? '').toString();
                          String typeLabel;
                          switch (sourceType) {
                            case 'xml':
                              typeLabel = 'XML';
                              break;
                            case 'aecg':
                              typeLabel = 'aECG';
                              break;
                            case 'image_3x4+1':
                              typeLabel = 'Image (3×4 + 1)';
                              break;
                            case 'image_3x4':
                              typeLabel = 'Image (3×4)';
                              break;
                            default:
                              typeLabel = sourceType.isEmpty ? '' : sourceType;
                          }

                          // ✅ Determine if this is a SIGNAL upload (not an image)
                          final isSignal = sourceType == 'xml' || sourceType == 'aecg';

                          final predTopk =
                          (e['prediction_topk'] is List) ? (e['prediction_topk'] as List) : null;

                          String? predSummary;

                          if (predTopk != null && predTopk.isNotEmpty) {
                            if (_scpReady) {
                              final topk = predTopk
                                  .whereType<Map>()
                                  .map((m) => m.cast<String, dynamic>())
                                  .toList();

                              final scores = _aggregateDiag5(topk);
                              final best = _bestDiagScore(scores);

                              final percent = (best.p * 100).toStringAsFixed(2);
                              predSummary =
                              '${best.label} • $percent%${best.bestCode == null ? '' : ' (from ${best.bestCode})'}';
                            } else {
                              final first = predTopk.first;
                              if (first is Map && first['label'] != null) {
                                final p = (first['p'] is num)
                                    ? ((first['p'] as num).toDouble() * 100)
                                    : null;
                                predSummary =
                                '${first['label']}${p == null ? '' : ' • ${p.toStringAsFixed(2)}%'}';
                              }
                            }
                          }

                          return Card(
                            child: ListTile(
                              // ✅ show date label instead of DB id
                              title: Text(
                                titleLabel,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Type line
                                  if (typeLabel.isNotEmpty) ...[
                                    Text(
                                      'Type: $typeLabel',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: cs.onSurface.withValues(alpha: 0.75),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                  ],

                                  if (predSummary != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Prediction: $predSummary',
                                      style: TextStyle(
                                        color: cs.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (v) async {
                                  if (v == 'open') {
                                    await _openEcg(e);
                                  } else if (v == 'delete') {
                                    await _deleteEcg(e);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'open', child: Text('Open')),
                                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                                ],
                                child: const Icon(Icons.more_vert),
                              ),
                              onTap: () async {
                                if (e['prediction_topk'] is List) {
                                  final data = <String, dynamic>{
                                    "topk": e['prediction_topk'],

                                    // ✅ For XML/aECG: preview_image_url is the important PNG
                                    // ✅ For Images: preview_image_url may be digitized/cropped, keep it
                                    "preview_image_url": e['preview_image_url'],

                                    // ✅ IMPORTANT FIX:
                                    // For XML/aECG the "url" points to the XML/aECG file (not an image),
                                    // so DO NOT pass it as original_image_url.
                                    "original_image_url": isSignal ? null : e['url'],

                                    "source_type": e['source_type'],
                                  };

                                  await _showPredictionDialogFromJson(
                                    title: '$titleLabel Result',
                                    data: data,
                                  );
                                  return;
                                }

                                if (fileUrl.isEmpty) return;
                                showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: Text(titleLabel),
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
    final cs = Theme.of(context).colorScheme;
    final busy = _isUploadingImage || _isUploadingSignal;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ECG Intake',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Scan or upload Signal (XML/aECG) or Image (3×4 / 3×4+1)',
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.70)),
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
                  icon: busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.cloud_upload_rounded),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(busy ? 'Uploading...' : 'Upload'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    disabledBackgroundColor: Colors.lightBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ----------------------------
  // ✅ Minimal CSV parser (no package)
  // ----------------------------
  List<Map<String, String>> _parseCsvToMaps(String csv) {
    final lines = const LineSplitter().convert(csv).where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return [];

    final headers = _parseCsvLine(lines.first).map((h) => h.trim()).toList();
    final out = <Map<String, String>>[];

    for (var i = 1; i < lines.length; i++) {
      final vals = _parseCsvLine(lines[i]);
      if (vals.isEmpty) continue;

      final row = <String, String>{};
      for (var c = 0; c < headers.length; c++) {
        final key = headers[c];
        final v = (c < vals.length) ? vals[c] : '';
        row[key] = v;
      }
      out.add(row);
    }
    return out;
  }

  // Parses one CSV line, supports quoted commas.
  List<String> _parseCsvLine(String line) {
    final out = <String>[];
    final sb = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final ch = line[i];

      if (ch == '"') {
        // handle escaped quotes ""
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          sb.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
        continue;
      }

      if (ch == ',' && !inQuotes) {
        out.add(sb.toString());
        sb.clear();
        continue;
      }

      sb.write(ch);
    }

    out.add(sb.toString());
    return out;
  }
}

// ----------------------------
// UI Widgets
// ----------------------------

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.2));
  }
}

class _PreviewBox extends StatelessWidget {
  final String url;
  const _PreviewBox({required this.url});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (ctx) => Dialog(
            insetPadding: const EdgeInsets.all(12),
            child: Container(
              color: Colors.black,
              child: InteractiveViewer(
                minScale: 0.6,
                maxScale: 6.0,
                child: Center(child: Image.network(url, fit: BoxFit.contain)),
              ),
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            color: Colors.black.withValues(alpha: 0.04),
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Center(child: Text('Could not load preview image')),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopResultCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _TopResultCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final label = (item['label'] ?? '').toString();
    final p = (item['p'] is num) ? (item['p'] as num).toDouble() : 0.0;
    final percent = (p * 100).toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Text('$percent%', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _TopDiagCard extends StatelessWidget {
  final _DiagScore score;
  const _TopDiagCard({required this.score});

  @override
  Widget build(BuildContext context) {
    final percent = (score.p * 100).toStringAsFixed(2);
    final sub = (score.bestCode == null) ? '' : ' • from ${score.bestCode}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              score.label,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Text('$percent%$sub', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _DiagRow extends StatelessWidget {
  final String title;
  final _DiagScore score;
  final double threshold;

  const _DiagRow({
    required this.title,
    required this.score,
    required this.threshold,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = score.p;
    final above = p >= threshold;
    final percent = (p * 100).toStringAsFixed(2);

    return Row(
      children: [
        SizedBox(
          width: 84,
          child: Text(
            above ? '$percent%' : '',
            style: TextStyle(fontWeight: FontWeight.w800, color: cs.primary),
          ),
        ),
        Expanded(
          child: Text(
            above ? title : '$title (none above threshold)',
            style: TextStyle(color: above ? cs.onSurface : cs.onSurface.withValues(alpha: 0.65)),
          ),
        ),
      ],
    );
  }
}

class _DiagGroupTile extends StatelessWidget {
  final _DiagBucket bucket;
  final _DiagScore diagScore;
  final List<Map<String, dynamic>> items;

  const _DiagGroupTile({
    required this.bucket,
    required this.diagScore,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final percent = (diagScore.p * 100).toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (Superclass + percentage)
          Row(
            children: [
              Expanded(
                child: Text(
                  bucket.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                '$percent%',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: cs.primary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Body (labels)
          if (items.isEmpty)
            Text(
              'No labels above ${(100 * _PatientDetailScreenState._diagThreshold).toStringAsFixed(0)}%.',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.65),
              ),
            )
          else
            ...items.map((it) {
              final p = (it['p'] as double) * 100;
              final code = (it['code'] ?? '').toString();
              final name = (it['name'] ?? '').toString();

              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 72,
                      child: Text(
                        '${p.toStringAsFixed(2)}%',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: cs.primary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '$code — $name',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ----------------------------
// Helper models
// ----------------------------

class _DiagBucket {
  final String key; // NORM / MI / STTC / CD / HYP
  final String title; // display name
  const _DiagBucket({required this.key, required this.title});
}

class _DiagScore {
  final String label; // NORM / MI / STTC / CD / HYP
  final double p; // probability
  final String? bestCode; // best contributing SCP code (e.g., ISC_)
  const _DiagScore({required this.label, required this.p, required this.bestCode});
}