import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:clinic_frontend/services/attendance_service.dart';

class UploadDoctorFaceScreen extends StatefulWidget {
  final int clinicId;
  const UploadDoctorFaceScreen({super.key, required this.clinicId});

  @override
  State<UploadDoctorFaceScreen> createState() => _UploadDoctorFaceScreenState();
}

class _UploadDoctorFaceScreenState extends State<UploadDoctorFaceScreen> {
  final _userIdController = TextEditingController();
  File? _selectedImage;
  bool _isLoading = false;
  String? _resultMessage;
  bool _isSuccess = false;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (photo != null) {
      setState(() {
        _selectedImage = File(photo.path);
        _resultMessage = null;
      });
    }
  }

  Future<void> _upload() async {
    if (_userIdController.text.isEmpty) {
      _showSnack('Please enter a User ID');
      return;
    }
    if (_selectedImage == null) {
      _showSnack('Please capture a face photo first');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await AttendanceService.uploadDoctorFace(
        userId: int.parse(_userIdController.text),
        clinicId: widget.clinicId,
        imageFile: _selectedImage!,
      );

      setState(() {
        _isSuccess = result['success'] == true;
        _resultMessage = result['message'] ?? result['detail'] ?? 'Unknown response';
      });
    } catch (e) {
      setState(() {
        _isSuccess = false;
        _resultMessage = 'Error: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register Doctor Face'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── User ID input ──────────────────────────────
            TextField(
              controller: _userIdController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Doctor User ID',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 24),

            // ── Camera capture ─────────────────────────────
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 280,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  border: Border.all(color: Colors.teal, width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _selectedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(_selectedImage!, fit: BoxFit.cover),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.camera_alt, size: 60, color: Colors.teal),
                          SizedBox(height: 12),
                          Text('Tap to capture face photo',
                              style: TextStyle(color: Colors.teal, fontSize: 16)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),

            if (_selectedImage != null)
              TextButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.refresh),
                label: const Text('Retake Photo'),
              ),

            const SizedBox(height: 24),

            // ── Upload button ──────────────────────────────
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _upload,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.cloud_upload),
              label: Text(_isLoading ? 'Uploading...' : 'Register Face'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Result ─────────────────────────────────────
            if (_resultMessage != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isSuccess
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isSuccess ? Colors.green : Colors.red,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isSuccess ? Icons.check_circle : Icons.error,
                      color: _isSuccess ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _resultMessage!,
                        style: TextStyle(
                          color: _isSuccess
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
