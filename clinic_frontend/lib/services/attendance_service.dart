import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

const String baseUrl = 'http://10.11.1.128:5020';

class AttendanceService {
  // ── Upload Doctor Face ─────────────────────────────────────
  static Future<Map<String, dynamic>> uploadDoctorFace({
    required int userId,
    required int clinicId,
    required File imageFile,
  }) async {
    final uri = Uri.parse('$baseUrl/upload_doctor_face');
    final request = http.MultipartRequest('POST', uri);

    request.fields['user_id'] = userId.toString();
    request.fields['clinic_id'] = clinicId.toString();
    request.files.add(await http.MultipartFile.fromPath(
      'file',
      imageFile.path,
      // contentType: MediaType('image', 'jpeg'), // optional
    ));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return jsonDecode(response.body);
  }

  // ── Scan Face ──────────────────────────────────────────────
  static Future<Map<String, dynamic>> scanFace({
    required int clinicId,
    required int userId,
    required File imageFile,
  }) async {
    final uri = Uri.parse('$baseUrl/scan_face');
    final request = http.MultipartRequest('POST', uri);

    request.fields['clinic_id'] = clinicId.toString();
    request.fields['user_id'] = userId.toString();
    request.files.add(await http.MultipartFile.fromPath(
      'file',
      imageFile.path,
    ));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return jsonDecode(response.body);
  }

  // ── Attendance Logs ────────────────────────────────────────
  static Future<List<dynamic>> getAttendanceLogs({
    required int clinicId,
    String? date, // format: YYYY-MM-DD
  }) async {
    final queryParams = {
      'clinic_id': clinicId.toString(),
      if (date != null) 'date': date,
    };
    final uri = Uri.parse('$baseUrl/attendance_logs')
        .replace(queryParameters: queryParams);

    final response = await http.get(uri);
    return jsonDecode(response.body);
  }
}
