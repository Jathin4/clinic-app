import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../widgets/app_widgets.dart';
import '../widgets/encounter_workflow.dart';

class EncountersScreen extends StatefulWidget {
  const EncountersScreen({super.key});
  @override
  State<EncountersScreen> createState() => _EncountersScreenState();
}

class _EncountersScreenState extends State<EncountersScreen> {
  List<Map<String, dynamic>> _encounters = [];
  List<Map<String, dynamic>> _patients = [];
  List<Map<String, dynamic>> _doctors = [];
  bool _loading = true;
  String _search = '';

  // Pagination
  int _currentPage = 1;
  int _pageSize = 10;

  int get _clinicId =>
      context.read<AppProvider>().user?['clinic_id'] ?? 1;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  List<Map<String, dynamic>> _decodeList(String body) {
    final d = jsonDecode(body);
    return d is List ? List<Map<String, dynamic>>.from(d) : [];
  }

  Future<void> _fetchAll() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        http.get(Uri.parse(
            '${ApiClient.baseUrl}/encountersread?clinic_id=$_clinicId')),
        http.get(Uri.parse(
            '${ApiClient.baseUrl}/patient_read?clinic_id=$_clinicId')),
        http.get(Uri.parse('${ApiClient.baseUrl}/doctorsread')),
      ]);
      setState(() {
        _encounters = _decodeList(results[0].body);
        _patients = _decodeList(results[1].body);
        _doctors = _decodeList(results[2].body);
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  String _patientName(dynamic id) {
    final p = _patients.firstWhere(
        (x) => x['id']?.toString() == id?.toString(),
        orElse: () => {});
    return p.isEmpty
        ? '—'
        : '${p['first_name']} ${p['last_name'] ?? ''}'.trim();
  }

  String _doctorName(dynamic id) {
    final d = _doctors.firstWhere(
        (x) => x['id']?.toString() == id?.toString(),
        orElse: () => {});
    return d.isEmpty
        ? '—'
        : (d['name'] ?? d['full_name'] ?? '');
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _encounters;
    return _encounters.where((e) {
      final pName = _patientName(e['patient_id']).toLowerCase();
      final dName = _doctorName(e['doctor_id']).toLowerCase();
      final complaint =
          (e['chief_complaint'] ?? '').toLowerCase();
      return pName.contains(q) ||
          dName.contains(q) ||
          complaint.contains(q) ||
          e['id']?.toString().contains(q) == true;
    }).toList();
  }

  List<Map<String, dynamic>> get _paginated {
    final f = _filtered;
    final start = (_currentPage - 1) * _pageSize;
    final end =
        (start + _pageSize).clamp(0, f.length);
    return f.sublist(start, end);
  }

  int get _totalPages =>
      (_filtered.length / _pageSize).ceil().clamp(1, double.infinity).toInt();

  void _openNewEncounter() {
    showEncounterWorkflow(
      context,
      appointment: {
        'patient_id': null,
        'doctor_id': null,
        'notes': '',
      },
      onComplete: _fetchAll,
    );
  }

  void _openEditForm(Map<String, dynamic> enc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EncounterEditForm(
        encounter: enc,
        patients: _patients,
        doctors: _doctors,
        clinicId: _clinicId,
        onSaved: _fetchAll,
      ),
    );
  }

  Future<void> _delete(Map<String, dynamic> enc) async {
    if (!await confirmDelete(context,
        title: 'Delete Encounter')) return;
    try {
      await http.delete(
        Uri.parse('${ApiClient.baseUrl}/encounter_delete/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': enc['id']}),
      );
      _fetchAll();
    } catch (_) {}
  }

  String _fmtDate(dynamic v) {
    if (v == null) return '—';
    final s = v.toString();
    if (s.length < 10) return s;
    final parts = s.substring(0, 10).split('-');
    if (parts.length == 3) return '${parts[2]}-${parts[1]}-${parts[0]}';
    return s.substring(0, 10);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(children: [
        AppPageHeader(
          title: 'Encounters',
          subtitle: 'Clinical encounter records',
          actionLabel: 'New Encounter',
          actionIcon: Icons.add,
          onAction: _openNewEncounter,
        ),
        AppSearchBar(
          hint: 'Search patient, doctor, complaint…',
          onChanged: (v) => setState(() {
            _search = v;
            _currentPage = 1;
          }),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('${_filtered.length} encounters',
                style: AppTextStyles.bodySmall),
          ),
        ),
        Expanded(
          child: _loading
              ? const AppLoadingView()
              : _filtered.isEmpty
                  ? const AppEmptyView(
                      message: 'No encounters found')
                  : RefreshIndicator(
                      onRefresh: _fetchAll,
                      color: AppColors.teal,
                      child: Column(children: [
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(
                                16, 0, 16, 8),
                            itemCount: _paginated.length,
                            itemBuilder: (_, i) {
                              final enc = _paginated[i];
                              return _EncounterCard(
                                encounter: enc,
                                patientName: _patientName(
                                    enc['patient_id']),
                                doctorName:
                                    _doctorName(enc['doctor_id']),
                                fmtDate: _fmtDate,
                                onEdit: () => _openEditForm(enc),
                                onDelete: () => _delete(enc),
                              );
                            },
                          ),
                        ),
                        if (_totalPages > 1)
                          _PaginationBar(
                            currentPage: _currentPage,
                            totalPages: _totalPages,
                            pageSize: _pageSize,
                            totalItems: _filtered.length,
                            onPageChanged: (p) =>
                                setState(() => _currentPage = p),
                            onPageSizeChanged: (s) => setState(() {
                              _pageSize = s;
                              _currentPage = 1;
                            }),
                          ),
                      ]),
                    ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Encounter Card
// ─────────────────────────────────────────────────────────────────────────────
class _EncounterCard extends StatelessWidget {
  final Map<String, dynamic> encounter;
  final String patientName;
  final String doctorName;
  final String Function(dynamic) fmtDate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EncounterCard({
    required this.encounter,
    required this.patientName,
    required this.doctorName,
    required this.fmtDate,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => AppCard(
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: AppColors.statusGreenBg,
                borderRadius: BorderRadius.circular(10)),
            child: Center(
                child: Text('#${encounter['id'] ?? '—'}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.teal))),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                    patientName.isNotEmpty
                        ? patientName
                        : 'Unknown Patient',
                    style: AppTextStyles.cardTitle),
                const SizedBox(height: 3),
                Text(
                    'Dr. $doctorName · ${fmtDate(encounter['visit_date'])}',
                    style: AppTextStyles.bodySmall),
                const SizedBox(height: 4),
                if (encounter['chief_complaint'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: AppColors.statusGreenBg,
                        borderRadius:
                            BorderRadius.circular(6)),
                    child: Text(
                        encounter['chief_complaint'],
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.teal))),
              ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (encounter['follow_up_date'] != null)
              Text(
                  'Follow-up: ${fmtDate(encounter['follow_up_date'])}',
                  style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted)),
            const SizedBox(height: 8),
            Row(children: [
              GestureDetector(
                  onTap: onEdit,
                  child: const Icon(Icons.edit_outlined,
                      size: 16, color: AppColors.textMuted)),
              const SizedBox(width: 10),
              GestureDetector(
                  onTap: onDelete,
                  child: const Icon(Icons.delete_outline,
                      size: 16, color: AppColors.statusRed)),
            ]),
          ]),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Pagination Bar
// ─────────────────────────────────────────────────────────────────────────────
class _PaginationBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int pageSize;
  final int totalItems;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onPageSizeChanged;

  const _PaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.pageSize,
    required this.totalItems,
    required this.onPageChanged,
    required this.onPageSizeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
          color: AppColors.white,
          border:
              Border(top: BorderSide(color: AppColors.divider))),
      child: Row(children: [
        // Page size selector
        Text('Show:',
            style: const TextStyle(
                fontSize: 12, color: AppColors.textMuted)),
        const SizedBox(width: 6),
        DropdownButton<int>(
          value: pageSize,
          underline: const SizedBox(),
          style: const TextStyle(
              fontSize: 12, color: AppColors.textPrimary),
          items: [10, 20, 50].map((n) => DropdownMenuItem(
              value: n, child: Text('$n'))).toList(),
          onChanged: (v) => v != null ? onPageSizeChanged(v) : null,
        ),
        const Spacer(),
        Text(
          'Page $currentPage of $totalPages',
          style: const TextStyle(
              fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(width: 12),
        // Prev
        GestureDetector(
          onTap: currentPage > 1
              ? () => onPageChanged(currentPage - 1)
              : null,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: currentPage > 1
                  ? AppColors.teal.withOpacity(0.1)
                  : AppColors.border.withOpacity(0.3),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.chevron_left,
                size: 16,
                color: currentPage > 1
                    ? AppColors.teal
                    : AppColors.textMuted),
          ),
        ),
        const SizedBox(width: 6),
        // Next
        GestureDetector(
          onTap: currentPage < totalPages
              ? () => onPageChanged(currentPage + 1)
              : null,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: currentPage < totalPages
                  ? AppColors.teal.withOpacity(0.1)
                  : AppColors.border.withOpacity(0.3),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.chevron_right,
                size: 16,
                color: currentPage < totalPages
                    ? AppColors.teal
                    : AppColors.textMuted),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Encounter Edit Form (bottom sheet)
// ─────────────────────────────────────────────────────────────────────────────
class _EncounterEditForm extends StatefulWidget {
  final Map<String, dynamic> encounter;
  final List<Map<String, dynamic>> patients;
  final List<Map<String, dynamic>> doctors;
  final int clinicId;
  final VoidCallback onSaved;

  const _EncounterEditForm({
    required this.encounter,
    required this.patients,
    required this.doctors,
    required this.clinicId,
    required this.onSaved,
  });

  @override
  State<_EncounterEditForm> createState() =>
      _EncounterEditFormState();
}

class _EncounterEditFormState extends State<_EncounterEditForm> {
  int? _patientId;
  int? _doctorId;
  final _dateCtrl = TextEditingController();
  final _followUpCtrl = TextEditingController();
  final _complaintCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _saving = false;
  Map<String, String> _errors = {};

  @override
  void initState() {
    super.initState();
    final e = widget.encounter;
    _patientId = e['patient_id'] is int
        ? e['patient_id']
        : int.tryParse(e['patient_id']?.toString() ?? '');
    _doctorId = e['doctor_id'] is int
        ? e['doctor_id']
        : int.tryParse(e['doctor_id']?.toString() ?? '');
    _dateCtrl.text =
        e['visit_date']?.toString().substring(0, 10) ?? '';
    _followUpCtrl.text =
        e['follow_up_date']?.toString().substring(0, 10) ?? '';
    _complaintCtrl.text = e['chief_complaint'] ?? '';
    _notesCtrl.text = e['notes'] ?? '';
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _followUpCtrl.dispose();
    _complaintCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController ctrl,
      {DateTime? initial}) async {
    final d = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (c, child) => Theme(
        data: Theme.of(c).copyWith(
            colorScheme:
                const ColorScheme.light(primary: AppColors.teal)),
        child: child!,
      ),
    );
    if (d != null) {
      setState(() => ctrl.text = d.toIso8601String().substring(0, 10));
    }
  }

  bool _validate() {
    final e = <String, String>{};
    if (_patientId == null) e['patient'] = 'Required';
    if (_dateCtrl.text.isEmpty) e['date'] = 'Required';
    if (_complaintCtrl.text.trim().isEmpty)
      e['complaint'] = 'Required';
    setState(() => _errors = e);
    return e.isEmpty;
  }

  Future<void> _save() async {
    if (!_validate()) return;
    setState(() => _saving = true);
    try {
      final res = await http.post(
        Uri.parse(
            '${ApiClient.baseUrl}/save_encounter_with_details'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': widget.encounter['id'],
          'clinic_id': widget.clinicId,
          'patient_id': _patientId,
          'doctor_id': _doctorId,
          'appointment_id':
              widget.encounter['appointment_id'],
          'visit_date': _dateCtrl.text,
          'follow_up_date': _followUpCtrl.text.isEmpty
              ? null
              : _followUpCtrl.text,
          'chief_complaint': _complaintCtrl.text.trim(),
          'notes': _notesCtrl.text.trim(),
          'created_by': 'admin',
          'diagnoses': [],
          'prescriptions': [],
        }),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        Navigator.pop(context);
        widget.onSaved();
      } else {
        showSnack(context, 'Failed to update encounter',
            isError: true);
      }
    } catch (_) {
      showSnack(context, 'Failed to update encounter',
          isError: true);
    }
    if (mounted) setState(() => _saving = false);
  }

  Widget _errText(String t) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(t,
          style: const TextStyle(
              fontSize: 11, color: AppColors.statusRed)));

  @override
  Widget build(BuildContext context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(children: [
          AppSheetHeader(title: 'Edit Encounter'),
          Expanded(
              child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Patient
                  Text('Patient *', style: AppTextStyles.label),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    value: _patientId,
                    onChanged: (v) => setState(() {
                      _patientId = v;
                      _errors.remove('patient');
                    }),
                    hint: Text('Select patient',
                        style: AppTextStyles.hint),
                    items: widget.patients
                        .map((p) => DropdownMenuItem<int>(
                              value: p['id'] as int,
                              child: Text(
                                  '${p['first_name']} ${p['last_name'] ?? ''}'
                                      .trim(),
                                  style: const TextStyle(
                                      fontSize: 13)),
                            ))
                        .toList(),
                    decoration: AppInput.deco(''),
                  ),
                  if (_errors['patient'] != null)
                    _errText(_errors['patient']!),
                  const SizedBox(height: 14),

                  // Doctor
                  AppDropdownField<int>(
                    label: 'Doctor',
                    value: _doctorId,
                    items: widget.doctors
                        .map((d) => DropdownMenuItem<int>(
                              value: d['id'] as int,
                              child: Text(
                                  d['name'] ??
                                      d['full_name'] ??
                                      '',
                                  style: const TextStyle(
                                      fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _doctorId = v),
                  ),
                  const SizedBox(height: 14),

                  // Dates
                  Row(children: [
                    Expanded(
                        child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                          Text('Visit Date *',
                              style: AppTextStyles.label),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () async {
                              await _pickDate(_dateCtrl);
                              setState(() =>
                                  _errors.remove('date'));
                            },
                            child: AbsorbPointer(
                                child: TextField(
                              controller: _dateCtrl,
                              decoration: AppInput.deco(
                                  'YYYY-MM-DD',
                                  icon: Icons
                                      .calendar_today_outlined),
                            )),
                          ),
                          if (_errors['date'] != null)
                            _errText(_errors['date']!),
                        ])),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                          Text('Follow-up Date',
                              style: AppTextStyles.label),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () => _pickDate(
                                _followUpCtrl,
                                initial: DateTime.now()
                                    .add(const Duration(
                                        days: 7))),
                            child: AbsorbPointer(
                                child: TextField(
                              controller: _followUpCtrl,
                              decoration: AppInput.deco(
                                  'YYYY-MM-DD',
                                  icon: Icons.event_outlined),
                            )),
                          ),
                        ])),
                  ]),
                  const SizedBox(height: 14),

                  // Chief Complaint
                  Text('Chief Complaint *',
                      style: AppTextStyles.label),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _complaintCtrl,
                    onChanged: (_) => setState(
                        () => _errors.remove('complaint')),
                    decoration:
                        AppInput.deco('Reason for visit…'),
                  ),
                  if (_errors['complaint'] != null)
                    _errText(_errors['complaint']!),
                  const SizedBox(height: 14),

                  // Notes
                  AppFormField(
                    label: 'Notes',
                    controller: _notesCtrl,
                    hint: 'Additional clinical notes…',
                    maxLines: 3,
                  ),
                ]),
          )),
          AppFormButtons(
            saving: _saving,
            onCancel: () => Navigator.pop(context),
            onSave: _save,
            saveLabel: 'Update Encounter',
          ),
        ]),
      );
}