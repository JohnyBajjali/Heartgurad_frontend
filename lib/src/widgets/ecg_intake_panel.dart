// lib/src/widgets/ecg_intake_panel.dart
import 'dart:io' show File, Platform;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../screens/manual_crop_screen.dart';
import '../services/ecg_upload_service.dart';
import 'action_card.dart';

enum EcgImageLayout { threeByFour, threeByFourPlusOne }
enum SignalType { xml, aecg }

class EcgIntakePanel extends StatefulWidget {
  final String patientId;
  final String patientName;

  final bool startWithScanner;
  final bool startWithUpload;

  final bool showClose;

  final VoidCallback onUploaded;
  final VoidCallback onClose;

  const EcgIntakePanel({
    super.key,
    required this.patientId,
    required this.patientName,
    this.startWithScanner = false,
    this.startWithUpload = false,
    this.showClose = true,
    required this.onUploaded,
    required this.onClose,
  });

  @override
  State<EcgIntakePanel> createState() => _EcgIntakePanelState();
}

class _EcgIntakePanelState extends State<EcgIntakePanel> {
  // IMAGE state
  Uint8List? _imageBytes;
  String? _imageFileName;
  String? _imagePath;
  EcgImageLayout? _imageLayout;

  // SIGNAL state
  Uint8List? _signalBytes;
  String? _signalFileName;
  SignalType? _signalType;

  bool _isUploading = false;
  bool _isAutoCropping = false;

  bool _didAutoStart = false;

  bool get busy => _isUploading || _isAutoCropping;

  @override
  void initState() {
    super.initState();
    _maybeAutoStart();
  }

  @override
  void didUpdateWidget(covariant EcgIntakePanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    final scannerBecameTrue =
        !oldWidget.startWithScanner && widget.startWithScanner;
    final uploadBecameTrue = !oldWidget.startWithUpload && widget.startWithUpload;

    if (scannerBecameTrue || uploadBecameTrue) {
      _didAutoStart = false;
      _maybeAutoStart();
    }
  }

  void _maybeAutoStart() {
    if (_didAutoStart) return;
    if (_imageBytes != null || _signalBytes != null) return;

    if (widget.startWithScanner) {
      _didAutoStart = true;
      Future.microtask(() async {
        if (!mounted) return;
        await _scanImage();
      });
    } else if (widget.startWithUpload) {
      _didAutoStart = true;
      Future.microtask(() async {
        if (!mounted) return;
        _openUploadChooser();
      });
    }
  }

  // ============================================================
  // Upload chooser (Signal / Image)
  // ============================================================
  void _openUploadChooser() {
    if (busy) return;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Upload Signal'),
                  subtitle: const Text('XML or aECG file'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openSignalTypeChooser();
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.image_outlined),
                  title: const Text('Upload Image'),
                  subtitle: const Text('3×4 or 3×4 + 1 image'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openImageLayoutChooser();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // 1) Signal type chooser (XML / aECG) -> pick file
  // ============================================================
  void _openSignalTypeChooser() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.code),
                  title: const Text('XML'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    _signalType = SignalType.xml;
                    await _pickSignalFile(allowedExt: const ['xml']);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.insert_drive_file_outlined),
                  title: const Text('aECG'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    _signalType = SignalType.aecg;
                    await _pickSignalFile(allowedExt: const ['aecg']);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickSignalFile({required List<String> allowedExt}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExt,
        withData: kIsWeb,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      Uint8List bytes;

      if (kIsWeb) {
        if (file.bytes == null) {
          _showSnack('Could not read file bytes on web.');
          return;
        }
        bytes = file.bytes!;
      } else {
        if (file.path == null) {
          _showSnack('Could not read file path.');
          return;
        }
        bytes = await File(file.path!).readAsBytes();
      }

      if (!mounted) return;

      setState(() {
        _signalBytes = bytes;
        _signalFileName = file.name;

        // clear image state
        _imageBytes = null;
        _imageFileName = null;
        _imagePath = null;
        _imageLayout = null;
      });
    } catch (e) {
      _showSnack('Signal pick failed: $e');
    }
  }

  // ============================================================
  // 2) Image layout chooser (3x4 / 3x4+1) -> pick image from device
  // ============================================================
  void _openImageLayoutChooser() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.grid_on_outlined),
                  title: const Text('3×4'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    setState(() => _imageLayout = EcgImageLayout.threeByFour);
                    await _pickImageFromDeviceOnly();
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.grid_view_outlined),
                  title: const Text('3×4 + 1'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    setState(() => _imageLayout = EcgImageLayout.threeByFourPlusOne);
                    await _pickImageFromDeviceOnly();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Upload Image = choose from device only (NO camera).
  Future<void> _pickImageFromDeviceOnly() async {
    // Desktop/Web: FilePicker is best
    if (kIsWeb || (!kIsWeb && !(Platform.isAndroid || Platform.isIOS))) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
        withData: kIsWeb,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      Uint8List bytes;

      if (kIsWeb) {
        if (file.bytes == null) {
          _showSnack('Could not read image bytes on web.');
          return;
        }
        bytes = file.bytes!;
      } else {
        if (file.path == null) return;
        bytes = await File(file.path!).readAsBytes();
      }

      if (!mounted) return;

      setState(() {
        _imageBytes = bytes;
        _imageFileName = file.name;
        _imagePath = file.path;

        // clear signal state
        _signalBytes = null;
        _signalFileName = null;
        _signalType = null;
      });

      return;
    }

    // Mobile: gallery picker
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 95);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;

    setState(() {
      _imageBytes = bytes;
      _imageFileName = p.basename(picked.path);
      _imagePath = picked.path;

      _signalBytes = null;
      _signalFileName = null;
      _signalType = null;
    });
  }

  // ============================================================
  // Scan/Camera (this is separate; you said it’s not the issue)
  // ============================================================
  Future<void> _scanImage() async {
    // WEB: browser camera
    if (kIsWeb) {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 95);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;

      setState(() {
        _imageBytes = bytes;
        _imageFileName = p.basename(picked.path);
        _imagePath = picked.path;
        _imageLayout ??= EcgImageLayout.threeByFour; // default if not chosen
        _signalBytes = null;
        _signalFileName = null;
        _signalType = null;
      });
      return;
    }

    final isMobile = Platform.isAndroid || Platform.isIOS;

    // DESKTOP: scanning is unreliable -> use file picker
    if (!isMobile) {
      _showSnack('On desktop, use Upload Image to pick from files.');
      return;
    }

    // ANDROID/iOS: MLKit document scanner
    final scanner = DocumentScanner(
      options: DocumentScannerOptions(
        documentFormat: DocumentFormat.jpeg,
        mode: ScannerMode.filter,
        pageLimit: 1,
        isGalleryImport: false,
      ),
    );

    try {
      final result = await scanner.scanDocument();
      if (!mounted) return;

      if (result.images.isNotEmpty) {
        final firstPath = result.images.first;
        final bytes = await File(firstPath).readAsBytes();
        if (!mounted) return;

        setState(() {
          _imageBytes = bytes;
          _imageFileName = p.basename(firstPath);
          _imagePath = firstPath;
          _imageLayout ??= EcgImageLayout.threeByFour;

          _signalBytes = null;
          _signalFileName = null;
          _signalType = null;
        });
      } else if (result.pdf != null) {
        _showSnack('Scanner returned PDF; configure scanner to return images.');
      }
    } catch (_) {
      if (mounted) _showSnack('Scan cancelled or failed.');
    } finally {
      await scanner.close();
    }
  }

  // ============================================================
  // Crop (image only)
  // ============================================================
  void _openCropMenu() {
    if (_imageBytes == null) return;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.auto_fix_high),
                  title: const Text('Automatic crop'),
                  subtitle: const Text('Remove borders & titles automatically'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _autoCropEcgRoi();
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.crop),
                  title: const Text('Manual crop'),
                  subtitle: const Text('Crop the ECG area yourself'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _manualCrop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _manualCrop() async {
    if (_imageBytes == null) return;

    final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

    if (!isMobile) {
      final croppedBytes = await Navigator.of(context).push<Uint8List>(
        MaterialPageRoute(builder: (_) => ManualCropScreen(imageBytes: _imageBytes!)),
      );
      if (croppedBytes == null) return;

      setState(() {
        _imageBytes = croppedBytes;
        _imageFileName = _imageFileName ?? 'ecg.jpg';
      });
      return;
    }

    final temp = await _bytesToTempFile(_imageBytes!, fileName: _imageFileName ?? 'ecg.jpg');

    final cropped = await ImageCropper().cropImage(
      sourcePath: temp.path,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 95,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop ECG Area',
          hideBottomControls: false,
          lockAspectRatio: false,
          showCropGrid: true,
        ),
        IOSUiSettings(title: 'Crop ECG Area'),
      ],
    );

    if (cropped == null) return;

    final bytes = await cropped.readAsBytes();
    if (!mounted) return;

    setState(() {
      _imageBytes = bytes;
      _imageFileName = p.basename(cropped.path);
      _imagePath = cropped.path;
    });
  }

  Future<void> _autoCropEcgRoi() async {
    if (_imageBytes == null) return;

    setState(() => _isAutoCropping = true);
    try {
      final cropped = await EcgUploadService.autoCropEcg(
        imageBytes: _imageBytes!,
        fileName: _imageFileName ?? 'ecg.jpg',
      );

      if (!mounted) return;
      setState(() {
        _imageBytes = cropped;
        _imageFileName = 'cropped_${_imageFileName ?? 'ecg.jpg'}';
      });

      _showSnack('✅ Auto crop done');
    } catch (e) {
      if (!mounted) return;
      _showSnack('❌ Auto crop failed: $e');
    } finally {
      if (mounted) setState(() => _isAutoCropping = false);
    }
  }

  // ============================================================
  // Upload to backend
  // ============================================================
  Future<void> _uploadImageToServer() async {
    if (_imageBytes == null) {
      _showSnack('Please choose an ECG image first.');
      return;
    }

    setState(() => _isUploading = true);

    try {
      final fileName = _imageFileName ?? 'ecg.jpg';

      final streamedResp = await EcgUploadService.uploadEcg(
        imageBytes: _imageBytes!,
        fileName: fileName,
        patientName: widget.patientName,
        patientId: widget.patientId,
      );

      final body = await streamedResp.stream.bytesToString();
      final ok = streamedResp.statusCode >= 200 && streamedResp.statusCode < 300;
      if (!mounted) return;

      if (ok) {
        _showSnack('✅ Image uploaded!');
        widget.onUploaded();
        setState(() {
          _imageBytes = null;
          _imageFileName = null;
          _imagePath = null;
          _imageLayout = null;
        });
      } else {
        _showSnack('❌ Upload failed [${streamedResp.statusCode}]: $body');
      }
    } catch (e) {
      if (mounted) _showSnack('Error uploading image: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _uploadSignalToServer() async {
    if (_signalBytes == null) {
      _showSnack('Please choose a signal file first.');
      return;
    }

    setState(() => _isUploading = true);

    try {
      final fileName = _signalFileName ?? 'signal.xml';

      final streamedResp = await EcgUploadService.uploadSignal(
        fileBytes: _signalBytes!,
        fileName: fileName,
        patientName: widget.patientName,
        patientId: widget.patientId,
      );

      final body = await streamedResp.stream.bytesToString();
      final ok = streamedResp.statusCode >= 200 && streamedResp.statusCode < 300;
      if (!mounted) return;

      if (ok) {
        _showSnack('✅ Signal uploaded!');
        widget.onUploaded();
        setState(() {
          _signalBytes = null;
          _signalFileName = null;
          _signalType = null;
        });
      } else {
        _showSnack('❌ Signal upload failed [${streamedResp.statusCode}]: $body');
      }
    } catch (e) {
      if (mounted) _showSnack('Error uploading signal: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ============================================================
  // UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final hasImage = _imageBytes != null;
    final hasSignal = _signalBytes != null;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'ECG Intake',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  if (widget.showClose)
                    IconButton(
                      tooltip: 'Close',
                      onPressed: widget.onClose,
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: ActionCard(
                      title: 'Scan / Camera',
                      subtitle: 'Use scanner/camera (image capture)',
                      icon: Icons.camera_alt_rounded,
                      color: const Color(0xFF1C7C80),
                      onTap: busy ? null : _scanTap,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ActionCard(
                      title: 'Upload',
                      subtitle: 'Pick Signal or Image from device',
                      icon: Icons.folder_open_rounded,
                      color: const Color(0xFF0E6B6F),
                      onTap: busy ? null : _uploadTap,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              if (hasImage) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: Container(
                      width: double.infinity,
                      color: Colors.black12,
                      child: Image.memory(_imageBytes!, fit: BoxFit.contain),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: _isAutoCropping
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.crop_rounded),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Crop', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                    onPressed: _isAutoCropping ? null : _openCropMenu,
                  ),
                ),

                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: _isUploading
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.cloud_upload_rounded),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Upload Image to Server',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                    onPressed: _isUploading ? null : _uploadImageToServer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0E6B6F),
                      disabledBackgroundColor: const Color(0xFF9FB9BC),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ] else if (hasSignal) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black.withOpacity(0.06)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.description_outlined),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _signalFileName ?? 'Signal file selected',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: _isUploading
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.cloud_upload_rounded),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Upload Signal to Server',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                    onPressed: _isUploading ? null : _uploadSignalToServer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0E6B6F),
                      disabledBackgroundColor: const Color(0xFF9FB9BC),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ] else ...[
                Text(
                  'Upload → choose Signal or Image. If Image → choose 3×4 or 3×4+1 → pick from device.',
                  style: TextStyle(color: Colors.black.withOpacity(0.70)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ---- VOID wrappers (VoidCallback requires void) ----
  void _scanTap() => _scanImage();
  void _uploadTap() => _openUploadChooser();

  Future<File> _bytesToTempFile(Uint8List bytes, {required String fileName}) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, 'ecg_${DateTime.now().millisecondsSinceEpoch}_$fileName'));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}