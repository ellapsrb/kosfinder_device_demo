import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../cloud_config.dart';
import '../services/device_location_service.dart';
import '../services/draft_repository.dart';
import '../services/photo_upload_service.dart';
import 'sensor_demo_page.dart';

class DeviceDemoPage extends StatefulWidget {
  const DeviceDemoPage({super.key});

  @override
  State<DeviceDemoPage> createState() => _DeviceDemoPageState();
}

class _DeviceDemoPageState extends State<DeviceDemoPage> {
  final _nameController = TextEditingController();
  final _picker = ImagePicker();
  final _draftRepository = DraftRepository();
  final _locationService = DeviceLocationService();
  final _uploadService = PhotoUploadService();

  String? _photoPath;
  double? _latitude;
  double? _longitude;

  bool _loading = true;
  bool _saving = false;
  bool _gettingLocation = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadDraft() async {
    try {
      final draft = await _draftRepository.load();

      if (!mounted) return;

      final savedPhoto = draft['photoPath'] as String?;

      setState(() {
        _nameController.text = draft['name'] as String? ?? '';

        if (savedPhoto != null && File(savedPhoto).existsSync()) {
          _photoPath = savedPhoto;
        }

        _latitude = (draft['latitude'] as num?)?.toDouble();
        _longitude = (draft['longitude'] as num?)?.toDouble();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage('Gagal memuat draft: $e');
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final selected = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );

      // Pengguna membatalkan pemilihan foto.
      if (selected == null) return;

      final savedPath = await _draftRepository.savePermanentPhoto(selected);

      if (!mounted) return;

      setState(() {
        _photoPath = savedPath;
      });

      _showMessage('Foto berhasil dipilih dan disimpan di perangkat.');
    } catch (e) {
      _showMessage('Gagal mengambil foto: $e');
    }
  }

  Future<void> _getLocation() async {
    setState(() => _gettingLocation = true);

    try {
      final position = await _locationService.getPosition();

      if (!mounted) return;

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });

      _showMessage('Lokasi berhasil diperoleh.');
    } on LocationFailure catch (e) {
      if (!mounted) return;

      _showMessage(e.message);

      if (e.type == LocationFailureType.deniedForever) {
        await Geolocator.openAppSettings();
      } else if (e.type == LocationFailureType.serviceDisabled) {
        await Geolocator.openLocationSettings();
      }
    } catch (e) {
      _showMessage('Gagal mendapatkan lokasi: $e');
    } finally {
      if (mounted) {
        setState(() => _gettingLocation = false);
      }
    }
  }

  Future<void> _saveDraft() async {
    setState(() => _saving = true);

    try {
      await _draftRepository.save({
        'name': _nameController.text.trim(),
        'photoPath': _photoPath,
        'latitude': _latitude,
        'longitude': _longitude,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      _showMessage('Draft berhasil disimpan di perangkat.');
    } catch (e) {
      _showMessage('Gagal menyimpan draft: $e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _uploadPhoto() async {
    if (_photoPath == null) {
      _showMessage('Pilih foto terlebih dahulu.');
      return;
    }

    setState(() => _uploading = true);

    try {
      final result = await _uploadService.upload(File(_photoPath!));

      _showMessage('Upload berhasil: ${result.storagePath}');
    } catch (e) {
      _showMessage('Upload gagal: $e');
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('KosFinder Device Demo'),
        actions: [
          IconButton(
            tooltip: 'Demo Sensor',
            icon: const Icon(Icons.sensors),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SensorDemoPage()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Data Kos',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Isi nama kos, pilih foto, dan ambil lokasi perangkat.'),
            const SizedBox(height: 20),

            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nama kos',
                hintText: 'Contoh: Kos Melati',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.home),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Foto Kos',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal),
              ),
              child: _photoPath != null && File(_photoPath!).existsSync()
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(_photoPath!),
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image, size: 55, color: Colors.teal),
                        SizedBox(height: 8),
                        Text('Belum ada foto'),
                      ],
                    ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickPhoto(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Kamera'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickPhoto(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Galeri'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            const Text(
              'Lokasi Perangkat',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _latitude != null && _longitude != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Latitude: $_latitude'),
                        Text('Longitude: $_longitude'),
                      ],
                    )
                  : const Text('Lokasi belum diambil.'),
            ),

            const SizedBox(height: 10),

            OutlinedButton.icon(
              onPressed: _gettingLocation ? null : _getLocation,
              icon: _gettingLocation
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.location_on),
              label: Text(
                _gettingLocation ? 'Mengambil lokasi...' : 'Ambil Lokasi GPS',
              ),
            ),

            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: _saving ? null : _saveDraft,
              icon: const Icon(Icons.save),
              label: Text(_saving ? 'Menyimpan...' : 'Simpan Draft Lokal'),
            ),

            if (CloudConfig.enabled) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _uploading ? null : _uploadPhoto,
                icon: const Icon(Icons.cloud_upload),
                label: Text(
                  _uploading ? 'Mengunggah...' : 'Upload Foto ke Supabase',
                ),
              ),
            ],

            const SizedBox(height: 16),

            const Text(
              'Draft disimpan di perangkat. Izin GPS bersifat opsional '
              'dan tidak menghalangi penggunaan kamera maupun galeri.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
