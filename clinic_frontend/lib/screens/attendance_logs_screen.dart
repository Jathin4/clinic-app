import 'package:flutter/material.dart';
import 'package:clinic_frontend/services/attendance_service.dart';

class AttendanceLogsScreen extends StatefulWidget {
  final int clinicId;
  const AttendanceLogsScreen({super.key, required this.clinicId});

  @override
  State<AttendanceLogsScreen> createState() => _AttendanceLogsScreenState();
}

class _AttendanceLogsScreenState extends State<AttendanceLogsScreen> {
  List<dynamic> _logs = [];
  bool _isLoading = false;
  DateTime _selectedDate = DateTime.now();
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  String get _formattedDate {
    final d = _selectedDate;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final logs = await AttendanceService.getAttendanceLogs(
        clinicId: widget.clinicId,
        date: _formattedDate,
      );
      setState(() => _logs = logs);
    } catch (e) {
      setState(() => _error = 'Failed to load logs: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Colors.deepPurple),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadLogs();
    }
  }

  String _formatTime(String? isoTime) {
    if (isoTime == null) return '-';
    try {
      final dt = DateTime.parse(isoTime).toLocal();
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$h:$m $ampm';
    } catch (_) {
      return isoTime;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Logs'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadLogs,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Date picker bar ──────────────────────────────
          Container(
            color: Colors.deepPurple.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.calendar_today,
                    color: Colors.deepPurple, size: 20),
                const SizedBox(width: 8),
                Text(
                  _formattedDate,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.deepPurple,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _pickDate,
                  child: const Text('Change Date'),
                ),
              ],
            ),
          ),

          // ── Summary bar ───────────────────────────────────
          if (!_isLoading && _logs.isNotEmpty)
            Container(
              color: Colors.deepPurple,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.people, color: Colors.white70, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '${_logs.length} doctor${_logs.length > 1 ? 's' : ''} checked in',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),

          // ── Content ───────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Colors.deepPurple))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.red, size: 48),
                            const SizedBox(height: 12),
                            Text(_error!,
                                style:
                                    const TextStyle(color: Colors.red)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadLogs,
                              child: const Text('Retry'),
                            )
                          ],
                        ),
                      )
                    : _logs.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.event_busy,
                                    size: 64,
                                    color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  'No attendance records\nfor $_formattedDate',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 16),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _logs.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final log = _logs[index];
                              final confidence =
                                  (log['matched_confidence'] ?? 0) * 100;
                              return Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 10),
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        Colors.deepPurple.shade100,
                                    child: Text(
                                      (log['full_name'] ?? '?')[0]
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.deepPurple,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    'Dr. ${log['full_name'] ?? '-'}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.access_time,
                                              size: 14, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text(
                                            _formatTime(
                                                log['check_in_time']),
                                            style: const TextStyle(
                                                fontSize: 13),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          const Icon(Icons.verified,
                                              size: 14, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Match: ${confidence.toStringAsFixed(1)}%',
                                            style: const TextStyle(
                                                fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius:
                                          BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      log['status'] ?? 'present',
                                      style: TextStyle(
                                        color: Colors.green.shade800,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
