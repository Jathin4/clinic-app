import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../widgets/app_widgets.dart';
import '../widgets/encounter_workflow.dart';

Color _statusColor(String? s) => switch (s) {
  'Booked'    => AppColors.statusBlue,
  'CheckedIn' => AppColors.statusPurple,
  'Completed' => AppColors.statusGreen,
  'Cancelled' => AppColors.statusRed,
  _           => AppColors.statusGray,
};
Color _statusBg(String? s) => switch (s) {
  'Booked'    => AppColors.statusBlueBg,
  'CheckedIn' => AppColors.statusPurpleBg,
  'Completed' => AppColors.statusGreenBg,
  'Cancelled' => AppColors.statusRedBg,
  _           => AppColors.statusGrayBg,
};

// Business hours: 07:00 – 21:00
const _businessHourStart = 7;
const _businessHourEnd   = 21;

// Notes max length
const _maxNotesLength = 500;

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});
  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  List<Map<String, dynamic>> _apts = [], _patients = [], _doctors = [];
  bool _loading = true;
  String _search = '';

  int get _clinicId => context.read<AppProvider>().user?['clinic_id'] ?? 1;

  @override
  void initState() { super.initState(); _fetch(); }

  List<Map<String, dynamic>> _decodeList(String body) {
    final d = jsonDecode(body);
    return d is List ? List<Map<String, dynamic>>.from(d) : [];
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        http.get(Uri.parse('${ApiClient.baseUrl}/appointmentsread?clinic_id=$_clinicId')),
        http.get(Uri.parse('${ApiClient.baseUrl}/patient_read?clinic_id=$_clinicId')),
        http.get(Uri.parse('${ApiClient.baseUrl}/doctorsread')),
      ]);
      setState(() {
        _apts     = _decodeList(results[0].body);
        _patients = _decodeList(results[1].body);
        _doctors  = _decodeList(results[2].body);
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  String _patientName(dynamic id) {
    final p = _patients.firstWhere((x) => x['id'].toString() == id.toString(), orElse: () => {});
    return p.isEmpty ? 'Patient #$id' : '${p['first_name']} ${p['last_name']}'.trim();
  }

  String _doctorName(dynamic id) {
    final d = _doctors.firstWhere((x) => x['id'].toString() == id.toString(), orElse: () => {});
    return d.isEmpty ? 'Dr. #$id' : (d['name'] ?? d['full_name'] ?? 'Dr. #$id');
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _apts;
    return _apts.where((a) =>
        _patientName(a['patient_id']).toLowerCase().contains(q) ||
        _doctorName(a['doctor_id']).toLowerCase().contains(q) ||
        (a['status'] ?? '').toLowerCase().contains(q)).toList();
  }

  Future<void> _deleteApt(Map<String, dynamic> apt) async {
    if (!await confirmDelete(context, title: 'Delete Appointment')) return;
    try {
      final req = http.Request('DELETE', Uri.parse('${ApiClient.baseUrl}/appointment_delete'))
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode({'id': apt['id'], 'modified_by': 'admin'});
      await req.send();
      _fetch();
    } catch (_) {}
  }

  Future<void> _checkIn(Map<String, dynamic> apt) async {
    // VALIDATION: Re-open guard — only 'Booked' can be checked in
    if (apt['status'] != 'Booked') {
      showSnack(context, 'Only Booked appointments can be checked in', isError: true);
      return;
    }
    try {
      await http.post(
        Uri.parse('${ApiClient.baseUrl}/appointment_create_update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({...apt, 'status': 'CheckedIn', 'user': 'admin'}),
      );
      _fetch();
    } catch (_) {}
  }

  Future<void> _startEncounter(Map<String, dynamic> apt) async {
    // VALIDATION: Start Encounter only for CheckedIn status
    if (apt['status'] != 'CheckedIn') {
      showSnack(context, 'Patient must be checked in to start an encounter', isError: true);
      return;
    }
    // Launch EncounterWorkflow bottom sheet
    await showEncounterWorkflow(
      context,
      appointment: apt,
      onComplete: _fetch, // refresh appointments list after encounter saved
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(children: [
        AppPageHeader(title: 'Appointments', subtitle: 'Manage appointment slots', actionLabel: 'Book', actionIcon: Icons.add, onAction: _showBookForm),
        AppStatsRow(stats: [
          AppStatData('Pending',    _apts.where((a) => a['status'] == 'Booked').length,    AppColors.statusBlue,   AppColors.statusBlueBg,   Icons.person_outline),
          AppStatData('Completed',  _apts.where((a) => a['status'] == 'Completed').length, AppColors.statusGreen,  AppColors.statusGreenBg,  Icons.check_circle_outline),
          AppStatData('Checked In', _apts.where((a) => a['status'] == 'CheckedIn').length, AppColors.statusPurple, AppColors.statusPurpleBg, Icons.edit_note_outlined),
        ]),
        AppSearchBar(hint: 'Search patient, doctor, status…', onChanged: (v) => setState(() => _search = v)),
        Expanded(
          child: _loading ? const AppLoadingView()
              : _filtered.isEmpty ? const AppEmptyView(message: 'No appointments found')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final apt = _filtered[i];
                    return _AptCard(
                      apt: apt,
                      patientName: _patientName(apt['patient_id']),
                      doctorName: _doctorName(apt['doctor_id']),
                      onDelete: () => _deleteApt(apt),
                      onCheckIn: () => _checkIn(apt),
                      onStartEncounter: () => _startEncounter(apt),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  void _showBookForm() => showModalBottomSheet(
    context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => _BookForm(clinicId: _clinicId, patients: _patients, doctors: _doctors, existingApts: _apts, onSaved: _fetch),
  );

  void _showEditForm(Map<String, dynamic> apt) => showModalBottomSheet(
    context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => _BookForm(
      clinicId: _clinicId, patients: _patients, doctors: _doctors,
      existingApts: _apts, existingApt: apt, onSaved: _fetch),
  );
}

class _AptCard extends StatelessWidget {
  final Map<String, dynamic> apt;
  final String patientName, doctorName;
  final VoidCallback onDelete, onCheckIn, onStartEncounter;
  const _AptCard({
    required this.apt, required this.patientName, required this.doctorName,
    required this.onDelete, required this.onCheckIn, required this.onStartEncounter,
  });

  @override
  Widget build(BuildContext context) {
    final status = apt['status'] ?? 'Booked';
    final tokenColors = [AppColors.statusBlue, AppColors.statusPurple, AppColors.statusGreen, AppColors.statusOrange, AppColors.statusRed, AppColors.teal];
    final tokenColor = tokenColors[(apt['token_number'] ?? 0) % tokenColors.length];
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(color: tokenColor, shape: BoxShape.circle),
            child: Center(child: Text(apt['token_number']?.toString() ?? '?',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(patientName, style: AppTextStyles.cardTitle),
            const SizedBox(height: 3),
            Text('Dr. $doctorName · ${fmtDate(apt['appointment_date'])}', style: AppTextStyles.bodySmall),
            Text(fmtTime(apt['slot_time']), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            AppStatusBadge(label: status, color: _statusColor(status), bg: _statusBg(status)),
            const SizedBox(height: 8),
            GestureDetector(onTap: onDelete, child: const Icon(Icons.delete_outline, size: 16, color: AppColors.textMuted)),
          ]),
        ]),

        // VALIDATION: Check In only shown for Booked status
        // VALIDATION: Start Encounter only shown for CheckedIn status
        if (status == 'Booked' || status == 'CheckedIn') ...[
          const SizedBox(height: 10),
          Row(children: [
            if (status == 'Booked')
              Expanded(child: OutlinedButton.icon(
                onPressed: onCheckIn,
                icon: const Icon(Icons.login, size: 14),
                label: const Text('Check In', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.statusPurple,
                  side: const BorderSide(color: AppColors.statusPurple),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              )),
            if (status == 'CheckedIn')
              Expanded(child: ElevatedButton.icon(
                onPressed: onStartEncounter,
                icon: const Icon(Icons.medical_services_outlined, size: 14),
                label: const Text('Start Encounter', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              )),
          ]),
        ],
      ]),
    );
  }
}

class _BookForm extends StatefulWidget {
  final int clinicId;
  final List<Map<String, dynamic>> patients, doctors, existingApts;
  final Map<String, dynamic>? existingApt; // non-null when editing
  final VoidCallback onSaved;
  const _BookForm({
    required this.clinicId,
    required this.patients,
    required this.doctors,
    required this.existingApts,
    this.existingApt,
    required this.onSaved,
  });
  @override
  State<_BookForm> createState() => _BookFormState();
}

class _BookFormState extends State<_BookForm> {
  int? _patientId, _doctorId;
  final _dateCtrl  = TextEditingController();
  final _timeCtrl  = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _saving = false;
  Map<String, String> _errors = {};
  bool _pastDateWarning = false;

  bool get _isEditing => widget.existingApt != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final apt = widget.existingApt!;
      _patientId = apt['patient_id'];
      _doctorId  = apt['doctor_id'];
      _dateCtrl.text  = apt['appointment_date']?.toString().substring(0, 10) ?? '';
      // Strip seconds from HH:MM:SS
      final rawTime = apt['slot_time']?.toString() ?? '';
      _timeCtrl.text = rawTime.length >= 5 ? rawTime.substring(0, 5) : rawTime;
      _notesCtrl.text = apt['notes'] ?? '';
    }
    _notesCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _dateCtrl.dispose(); _timeCtrl.dispose(); _notesCtrl.dispose();
    super.dispose();
  }

  /// Parses "HH:MM" into TimeOfDay; returns null on failure.
  TimeOfDay? _parseTime(String t) {
    final parts = t.trim().split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  bool _validate() {
    final e = <String, String>{};
    _pastDateWarning = false;

    // VALIDATION: patient required
    if (_patientId == null) e['patient'] = 'Required';

    // VALIDATION: doctor required
    if (_doctorId == null) e['doctor'] = 'Required';

    // VALIDATION: appointment_date required (min today for new; warn if past date for edit)
    if (_dateCtrl.text.isEmpty) {
      e['date'] = 'Required';
    } else {
      try {
        final aptDate = DateTime.parse(_dateCtrl.text.substring(0, 10));
        final today   = DateTime.now();
        final todayOnly = DateTime(today.year, today.month, today.day);
        if (!_isEditing && aptDate.isBefore(todayOnly)) {
          e['date'] = 'Appointment date cannot be in the past';
        } else if (_isEditing && aptDate.isBefore(todayOnly)) {
          // VALIDATION: Past date warning when editing
          _pastDateWarning = true;
        }
      } catch (_) {
        e['date'] = 'Invalid date format';
      }
    }

    // VALIDATION: slot_time required + business hours + format
    if (_timeCtrl.text.trim().isEmpty) {
      e['time'] = 'Required';
    } else {
      final tod = _parseTime(_timeCtrl.text.trim());
      if (tod == null) {
        e['time'] = 'Invalid time format (use HH:MM)';
      } else {
        // VALIDATION: enforce business hours 07:00–21:00
        if (tod.hour < _businessHourStart || tod.hour >= _businessHourEnd ||
            (tod.hour == _businessHourEnd - 1 && tod.minute > 0)) {
          e['time'] = 'Slot must be between ${_businessHourStart.toString().padLeft(2, '0')}:00 and ${_businessHourEnd.toString().padLeft(2, '0')}:00';
        } else {
          // VALIDATION: duplicate booking — same patient + doctor + date + time
          if (_patientId != null && _doctorId != null && _dateCtrl.text.isNotEmpty) {
            final isDuplicate = widget.existingApts.any((a) {
              if (_isEditing && a['id']?.toString() == widget.existingApt!['id']?.toString()) return false;
              final samePatient = a['patient_id']?.toString() == _patientId.toString();
              final sameDoctor  = a['doctor_id']?.toString()  == _doctorId.toString();
              final sameDate    = (a['appointment_date']?.toString().substring(0, 10) ?? '') == _dateCtrl.text.substring(0, 10);
              final rawExisting = a['slot_time']?.toString() ?? '';
              final existingSlot = rawExisting.length >= 5 ? rawExisting.substring(0, 5) : rawExisting;
              final sameSlot    = existingSlot == _timeCtrl.text.trim().substring(0, 5 < _timeCtrl.text.trim().length ? 5 : _timeCtrl.text.trim().length);
              return samePatient && sameDoctor && sameDate && sameSlot;
            });
            if (isDuplicate) {
              e['time'] = 'This patient already has an appointment with this doctor at the same time';
            }
          }
        }
      }
    }

    // VALIDATION: notes max 500 chars
    if (_notesCtrl.text.length > _maxNotesLength) {
      e['notes'] = 'Notes cannot exceed $_maxNotesLength characters';
    }

    setState(() => _errors = e);
    return e.isEmpty;
  }

  Future<void> _save() async {
    if (!_validate()) return;

    // VALIDATION: Past date warning when editing — show confirmation dialog
    if (_pastDateWarning) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Past Date Selected'),
          content: const Text('You are setting the appointment to a past date. Are you sure you want to continue?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.statusOrange),
              child: const Text('Yes, Continue', style: TextStyle(color: Colors.white))),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() => _saving = true);
    try {
      final t = _timeCtrl.text.trim();
      final res = await http.post(
        Uri.parse('${ApiClient.baseUrl}/appointment_create_update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': widget.existingApt?['id'], 'clinic_id': widget.clinicId,
          'patient_id': _patientId, 'doctor_id': _doctorId,
          'appointment_date': _dateCtrl.text,
          'slot_time': t.isEmpty ? '00:00:00' : (t.split(':').length == 2 ? '$t:00' : t),
          'status': _isEditing ? widget.existingApt!['status'] : 'Booked',
          'token_number': widget.existingApt?['token_number'] ?? 1,
          'notes': _notesCtrl.text.trim(), 'is_active': true, 'user': 'admin',
        }),
      );
      if (res.statusCode == 200 || res.statusCode == 201) { Navigator.pop(context); widget.onSaved(); }
    } catch (_) {}
    setState(() => _saving = false);
  }

  Widget _errText(String t) => Padding(padding: const EdgeInsets.only(top: 4),
    child: Text(t, style: const TextStyle(fontSize: 11, color: AppColors.statusRed)));

  @override
  Widget build(BuildContext context) => Container(
    height: MediaQuery.of(context).size.height * 0.82,
    decoration: const BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    child: Column(children: [
      AppSheetHeader(title: _isEditing ? 'Edit Appointment' : 'Book Appointment'),
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // VALIDATION: patient required
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AppDropdownField<int>(
              label: 'Patient *', value: _patientId,
              items: widget.patients.map((p) => DropdownMenuItem(value: p['id'] as int,
                  child: Text('${p['first_name']} ${p['last_name']}'.trim(), style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) => setState(() { _patientId = v; _errors.remove('patient'); }),
            ),
            if (_errors['patient'] != null) _errText(_errors['patient']!),
          ]),
          const SizedBox(height: 14),

          // VALIDATION: doctor required
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AppDropdownField<int>(
              label: 'Doctor *', value: _doctorId,
              items: widget.doctors.map((d) => DropdownMenuItem(value: d['id'] as int,
                  child: Text(d['name'] ?? d['full_name'] ?? '', style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) => setState(() { _doctorId = v; _errors.remove('doctor'); }),
            ),
            if (_errors['doctor'] != null) _errText(_errors['doctor']!),
          ]),
          const SizedBox(height: 14),

          // VALIDATION: date required, min today for new, warn if past when editing
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Appointment Date *', style: AppTextStyles.label),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _isEditing
                      ? (DateTime.tryParse(_dateCtrl.text) ?? DateTime.now())
                      : DateTime.now(),
                  firstDate: _isEditing ? DateTime(2020) : DateTime.now(),
                  lastDate: DateTime(2030),
                  builder: (c, child) => Theme(data: Theme.of(c).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.teal)), child: child!),
                );
                if (d != null) setState(() { _dateCtrl.text = d.toIso8601String().substring(0, 10); _errors.remove('date'); });
              },
              child: AbsorbPointer(child: TextField(controller: _dateCtrl, decoration: AppInput.deco('YYYY-MM-DD', icon: Icons.calendar_today_outlined))),
            ),
            if (_errors['date'] != null) _errText(_errors['date']!),
          ]),
          const SizedBox(height: 14),

          // VALIDATION: slot_time required + business hours (07:00–21:00) + duplicate check
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Slot Time * (${_businessHourStart.toString().padLeft(2,'0')}:00–${_businessHourEnd.toString().padLeft(2,'0')}:00)', style: AppTextStyles.label),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () async {
                final now = TimeOfDay.now();
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _parseTime(_timeCtrl.text) ?? TimeOfDay(hour: now.hour < _businessHourStart ? _businessHourStart : now.hour, minute: 0),
                  builder: (c, child) => Theme(data: Theme.of(c).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.teal)), child: child!),
                );
                if (picked != null) {
                  setState(() {
                    _timeCtrl.text = '${picked.hour.toString().padLeft(2,'0')}:${picked.minute.toString().padLeft(2,'0')}';
                    _errors.remove('time');
                  });
                }
              },
              child: AbsorbPointer(child: TextField(controller: _timeCtrl, decoration: AppInput.deco('HH:MM', icon: Icons.access_time_outlined))),
            ),
            if (_errors['time'] != null) _errText(_errors['time']!),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Business hours: ${_businessHourStart.toString().padLeft(2,'0')}:00 – ${_businessHourEnd.toString().padLeft(2,'0')}:00',
                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
            ),
          ]),
          const SizedBox(height: 14),

          // VALIDATION: notes max 500 chars with live counter
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('Notes', style: AppTextStyles.label)),
              Text('${_notesCtrl.text.length}/$_maxNotesLength',
                  style: TextStyle(fontSize: 10,
                      color: _notesCtrl.text.length > _maxNotesLength ? AppColors.statusRed : AppColors.textMuted)),
            ]),
            const SizedBox(height: 6),
            TextField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: AppInput.deco('Reason for visit…'),
            ),
            if (_errors['notes'] != null) _errText(_errors['notes']!),
          ]),
        ]),
      )),
      AppFormButtons(saving: _saving, onCancel: () => Navigator.pop(context), onSave: _save,
          saveLabel: _isEditing ? 'Update Appointment' : 'Book Appointment'),
    ]),
  );
}