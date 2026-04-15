import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:clinic_frontend/services/attendance_service.dart';
import 'package:clinic_frontend/services/session.dart';
import 'package:clinic_frontend/widgets/app_widgets.dart'; // ✅ DESIGN SYSTEM

class ScanFaceScreen extends StatefulWidget {
  final int clinicId;
  const ScanFaceScreen({super.key, required this.clinicId});

  @override
  State<ScanFaceScreen> createState() => _ScanFaceScreenState();
}

class _ScanFaceScreenState extends State<ScanFaceScreen> {
  File? _capturedImage;
  bool _isLoading = false;
  Map<String, dynamic>? _result;
  final ImagePicker _picker = ImagePicker();

  Future<void> _captureAndScan() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.front,
    );
    if (photo == null) return;

    if (Session.userId == null) {
      setState(() {
        _result = {
          'success': false,
          'detail': 'Session expired. Please log in again.'
        };
      });
      return;
    }

    setState(() {
      _capturedImage = File(photo.path);
      _isLoading = true;
      _result = null;
    });

    try {
      final result = await AttendanceService.scanFace(
        clinicId: widget.clinicId,
        userId: Session.userId!,
        imageFile: _capturedImage!,
      );
      setState(() => _result = result);
    } catch (e) {
      setState(() => _result = {'success': false, 'detail': 'Error: $e'});
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _reset() {
    setState(() {
      _capturedImage = null;
      _result = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool? success = _result?['success'];
    final bool alreadyCheckedIn = _result?['already_checked_in'] == true;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Doctor Check-In'),
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            /// 🔷 HEADER
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.tealDark, AppColors.teal2],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Icon(Icons.face, size: 48, color: Colors.white),
                  const SizedBox(height: 8),
                  const Text(
                    'Face Recognition Check-In',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Clinic ID: ${widget.clinicId}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            /// 🖼 IMAGE PREVIEW
            if (_capturedImage != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.file(
                  _capturedImage!,
                  height: 260,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
            ],

            /// ⏳ LOADING
            if (_isLoading)
              const Column(
                children: [
                  AppLoadingView(),
                  SizedBox(height: 10),
                  Text('Scanning face...',
                      style: TextStyle(color: AppColors.teal)),
                ],
              ),

            /// ✅ RESULT
            if (_result != null && !_isLoading) ...[
              _buildResultCard(success, alreadyCheckedIn),
              const SizedBox(height: 16),

              OutlinedButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.refresh),
                label: const Text('Scan Again'),
                style: AppButtonStyle.outlined(),
              ),
            ],

            /// 📷 SCAN BUTTON
            if (_result == null && !_isLoading) ...[
              AppPrimaryButton(
                label: 'Open Camera & Scan',
                onPressed: _captureAndScan,
              ),
              const SizedBox(height: 16),
              const Text(
                'Position your face clearly in front of the camera',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 🎯 RESULT CARD
  Widget _buildResultCard(bool? success, bool alreadyCheckedIn) {
    if (success == true) {
      final color =
          alreadyCheckedIn ? AppColors.statusOrange : AppColors.statusGreen;
      final bg =
          alreadyCheckedIn ? AppColors.statusOrangeBg : AppColors.statusGreenBg;

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(
              alreadyCheckedIn ? Icons.info_outline : Icons.check_circle,
              color: color,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              _result!['message'] ?? '',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            _infoRow(Icons.person, 'Doctor', _result!['full_name'] ?? ''),
            if (_result!['check_in_time'] != null)
              _infoRow(Icons.access_time, 'Time',
                  fmtTime(_result!['check_in_time'])),
            _infoRow(
              Icons.bar_chart,
              'Confidence',
              '${((_result!['confidence'] ?? 0) * 100).toStringAsFixed(1)}%',
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.statusRedBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            const Icon(Icons.face_retouching_off,
                color: AppColors.statusRed, size: 48),
            const SizedBox(height: 12),
            Text(
              _result!['detail'] ?? 'Face not recognized',
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.statusRed,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
  }

  /// 📄 INFO ROW
  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Text('$label: ',
              style: const TextStyle(color: AppColors.textMuted)),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}