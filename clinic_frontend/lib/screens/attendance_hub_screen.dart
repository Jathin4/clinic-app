import 'package:flutter/material.dart';
import 'upload_doctor_face_screen.dart';
import 'scan_face_screen.dart';
import 'attendance_logs_screen.dart';

/// Drop this widget anywhere in your app.
/// Pass the clinic_id of the logged-in user.
class AttendanceHubScreen extends StatelessWidget {
  final int clinicId;
  const AttendanceHubScreen({super.key, required this.clinicId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        backgroundColor: Colors.blueGrey.shade800,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            _HubCard(
              icon: Icons.how_to_reg,
              title: 'Register Doctor Face',
              subtitle: 'Admin: upload a doctor\'s face photo once',
              color: Colors.teal,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      UploadDoctorFaceScreen(clinicId: clinicId),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _HubCard(
              icon: Icons.face_retouching_natural,
              title: 'Doctor Check-In',
              subtitle: 'Scan face to mark attendance',
              color: Colors.indigo,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ScanFaceScreen(clinicId: clinicId),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _HubCard(
              icon: Icons.list_alt,
              title: 'Attendance Logs',
              subtitle: 'Admin: view daily check-in records',
              color: Colors.deepPurple,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      AttendanceLogsScreen(clinicId: clinicId),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _HubCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.75)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white.withOpacity(0.2),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                color: Colors.white70, size: 18),
          ],
        ),
      ),
    );
  }
}
