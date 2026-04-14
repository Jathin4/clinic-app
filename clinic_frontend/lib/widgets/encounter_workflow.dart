import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/api_client.dart';
import 'app_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Constants
// ─────────────────────────────────────────────────────────────────────────────
const _frequencies = [
  'Once a day (OD)',
  'Twice a day (BID)',
  'Three times a day (TID)',
  'Four times a day (QID)',
  'As needed (SOS)',
  'Before sleep (HS)',
];

const _tabs = ['encounter', 'diagnoses', 'prescriptions'];

// ─────────────────────────────────────────────────────────────────────────────
//  Data models
// ─────────────────────────────────────────────────────────────────────────────
class _Diagnosis {
  final int id;
  String icdCode;
  String description;
  _Diagnosis({required this.id, required this.icdCode, this.description = ''});
}

class _Prescription {
  final int id;
  String medicineName;
  String dosage;
  String frequency;
  String duration;
  String instructions;
  _Prescription({
    required this.id,
    required this.medicineName,
    this.dosage = '',
    required this.frequency,
    this.duration = '',
    this.instructions = '',
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  Entry point — call this to open the workflow
// ─────────────────────────────────────────────────────────────────────────────
Future<void> showEncounterWorkflow(
  BuildContext context, {
  required Map<String, dynamic> appointment,
  VoidCallback? onComplete,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    enableDrag: false,
    builder: (_) => EncounterWorkflow(
      appointment: appointment,
      onComplete: onComplete,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Main EncounterWorkflow widget
// ─────────────────────────────────────────────────────────────────────────────
class EncounterWorkflow extends StatefulWidget {
  final Map<String, dynamic> appointment;
  final VoidCallback? onComplete;
  const EncounterWorkflow(
      {super.key, required this.appointment, this.onComplete});

  @override
  State<EncounterWorkflow> createState() => _EncounterWorkflowState();
}

class _EncounterWorkflowState extends State<EncounterWorkflow>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  bool _saving = false;

  // Remote data
  List<Map<String, dynamic>> _patients = [];
  List<Map<String, dynamic>> _doctors = [];
  List<String> _icdCodes = [];
  List<Map<String, dynamic>> _inventory = [];
  bool _loadingData = true;

  // Selections
  int? _selectedPatientId;
  int? _selectedDoctorId;

  // Encounter form
  final _complaintCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _followUpCtrl = TextEditingController();

  // Diagnoses
  List<_Diagnosis> _diagnoses = [];
  final _dxDescCtrl = TextEditingController();
  String? _selectedIcd;

  // Prescriptions
  List<_Prescription> _prescriptions = [];
  final _rxNameCtrl = TextEditingController();
  final _rxDosageCtrl = TextEditingController();
  String _rxFrequency = _frequencies[0];
  final _rxDurationCtrl = TextEditingController();
  final _rxInstructionsCtrl = TextEditingController();

  // Medicine search
  List<Map<String, dynamic>> _filteredMedicines = [];
  List<Map<String, dynamic>> _allMedicines = [];
  bool _showMedicineDrop = false;

  int get _clinicId => context.read<AppProvider>().user?['clinic_id'] ?? 1;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _selectedPatientId = widget.appointment['patient_id'] is int
        ? widget.appointment['patient_id']
        : int.tryParse(widget.appointment['patient_id']?.toString() ?? '');
    _selectedDoctorId = widget.appointment['doctor_id'] is int
        ? widget.appointment['doctor_id']
        : int.tryParse(widget.appointment['doctor_id']?.toString() ?? '');
    _complaintCtrl.text = widget.appointment['notes'] ?? '';
    _fetchAll();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _complaintCtrl.dispose();
    _notesCtrl.dispose();
    _followUpCtrl.dispose();
    _dxDescCtrl.dispose();
    _rxNameCtrl.dispose();
    _rxDosageCtrl.dispose();
    _rxDurationCtrl.dispose();
    _rxInstructionsCtrl.dispose();
    super.dispose();
  }

  // ── Data fetching ────────────────────────────────────────────────────────
  Future<void> _fetchAll() async {
    setState(() => _loadingData = true);
    try {
      final results = await Future.wait([
        http.get(Uri.parse(
            '${ApiClient.baseUrl}/patient_read?clinic_id=$_clinicId')),
        http.get(Uri.parse('${ApiClient.baseUrl}/doctorsread')),
        http.get(Uri.parse('${ApiClient.baseUrl}/icd_codes_read')),
        http.get(Uri.parse(
            '${ApiClient.baseUrl}/inventory_transactions_read?clinic_id=$_clinicId')),
      ]);

      final patients = _decode(results[0].body);
      final doctors = _decode(results[1].body);
      final icdRaw = _decode(results[2].body);
      final inventory = _decode(results[3].body);

      final today = DateTime.now();
      final seen = <String>{};
      final uniqueMedicines = inventory.where((m) {
        final expiry = m['expiry_date']?.toString();
        if (expiry != null) {
          try {
            if (DateTime.parse(expiry.substring(0, 10)).isBefore(today)) {
              return false;
            }
          } catch (_) {}
        }
        final key =
            '${(m['medicine_name'] ?? '').toLowerCase()}_${(m['dosage'] ?? '').toLowerCase()}';
        return seen.add(key);
      }).toList();

      setState(() {
        _patients = patients;
        _doctors = doctors;
        _icdCodes = icdRaw
            .map((i) => i['icd_code']?.toString() ?? '')
            .where((c) => c.isNotEmpty)
            .toList();
        _inventory = uniqueMedicines;
        _allMedicines = uniqueMedicines;
      });
    } catch (_) {}
    setState(() => _loadingData = false);
  }

  List<Map<String, dynamic>> _decode(String body) {
    final d = jsonDecode(body);
    return d is List ? List<Map<String, dynamic>>.from(d) : [];
  }

  Future<void> _reloadIcd() async {
    try {
      final res =
          await http.get(Uri.parse('${ApiClient.baseUrl}/icd_codes_read'));
      final data = _decode(res.body);
      setState(() => _icdCodes = data
          .map((i) => i['icd_code']?.toString() ?? '')
          .where((c) => c.isNotEmpty)
          .toList());
    } catch (_) {}
  }

  // ── Medicine search ──────────────────────────────────────────────────────
  void _onMedicineSearch(String query) {
    setState(() {
      _showMedicineDrop = query.trim().isNotEmpty;
      _filteredMedicines = query.trim().isEmpty
          ? []
          : _allMedicines
              .where((m) => (m['medicine_name'] ?? '')
                  .toLowerCase()
                  .contains(query.toLowerCase()))
              .toList();
    });
  }

  void _pickMedicine(Map<String, dynamic> medicine) {
    final name = medicine['medicine_name'] ?? medicine['name'] ?? '';
    setState(() {
      _rxNameCtrl.text = name;
      _rxDosageCtrl.text = medicine['dosage'] ?? _rxDosageCtrl.text;
      _showMedicineDrop = false;
      _filteredMedicines = [];
    });
  }

  // ── Diagnoses ────────────────────────────────────────────────────────────
  void _addDiagnosis() {
    if (_selectedIcd == null || _selectedIcd!.isEmpty) {
      showSnack(context,'ICD Code is required', isError: true);
      return;
    }
    setState(() {
      _diagnoses.add(_Diagnosis(
        id: DateTime.now().millisecondsSinceEpoch,
        icdCode: _selectedIcd!,
        description: _dxDescCtrl.text.trim(),
      ));
      _selectedIcd = null;
      _dxDescCtrl.clear();
    });
  }

  // ── Prescriptions ────────────────────────────────────────────────────────
  void _addPrescription() {
    if (_rxNameCtrl.text.trim().isEmpty) {
      showSnack(context,'Medicine name is required', isError: true);
      return;
    }
    setState(() {
      _prescriptions.add(_Prescription(
        id: DateTime.now().millisecondsSinceEpoch,
        medicineName: _rxNameCtrl.text.trim(),
        dosage: _rxDosageCtrl.text.trim(),
        frequency: _rxFrequency,
        duration: _rxDurationCtrl.text.trim(),
        instructions: _rxInstructionsCtrl.text.trim(),
      ));
      _rxNameCtrl.clear();
      _rxDosageCtrl.clear();
      _rxDurationCtrl.clear();
      _rxInstructionsCtrl.clear();
      _rxFrequency = _frequencies[0];
      _showMedicineDrop = false;
    });
  }

  // ── Complete / validate ──────────────────────────────────────────────────
  void _handleCompleteClick() {
    if (_complaintCtrl.text.trim().isEmpty) {
      _tabCtrl.animateTo(0);
      showSnack(context,'Chief complaint is required', isError: true);
      return;
    }
    _showSummary();
  }

  // ── Save encounter ───────────────────────────────────────────────────────
  Future<void> _confirmSave() async {
  setState(() => _saving = true);
  try {
    final payload = {
      'id': null,
      'clinic_id': _clinicId,
      'patient_id': _selectedPatientId,
      'doctor_id': _selectedDoctorId,
      'appointment_id': widget.appointment['id'],
      'visit_date': DateTime.now().toIso8601String(),
      'chief_complaint': _complaintCtrl.text.trim(),
      'notes': _notesCtrl.text.trim(),
      'follow_up_date': _followUpCtrl.text.isEmpty ? null : _followUpCtrl.text,
      'created_by': 'admin',
      'diagnoses': _diagnoses
          .map((d) => {'icd_code': d.icdCode, 'description': d.description})
          .toList(),
      'prescriptions': _prescriptions
          .map((p) => {
                'medicine_name': p.medicineName,
                'dosage': p.dosage,
                'frequency': p.frequency,
                'duration': p.duration,
                'instructions': p.instructions,
              })
          .toList(),
    };

    // Step 1: Save the encounter
    final res = await http.post(
      Uri.parse('${ApiClient.baseUrl}/save_encounter_with_details'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    debugPrint('Encounter save: ${res.statusCode} → ${res.body}');

    if (res.statusCode == 200 || res.statusCode == 201) {

      // ── Step 2: Update appointment status to Completed ──────────
      final apt = widget.appointment;
      final apptPayload = {
        'id':               apt['id'],
        'clinic_id':        apt['clinic_id'] ?? _clinicId,
        'patient_id':       apt['patient_id'],
        'doctor_id':        apt['doctor_id'],
        'appointment_date': apt['appointment_date'],
        'slot_time':        apt['slot_time'],
        'notes':            apt['notes'] ?? '',
        'token_number':     apt['token_number'] ?? 1,
        'is_active':        true,
        'user':             'admin',
        'status':           'Completed',   // ← capital C to match your switch()
      };

      debugPrint('Updating appointment: $apptPayload');

      final apptRes = await http.post(
        Uri.parse('${ApiClient.baseUrl}/appointment_create_update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(apptPayload),
      );

      debugPrint('Appointment update: ${apptRes.statusCode} → ${apptRes.body}');

      showSnack(context,'Encounter saved successfully');
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        Navigator.pop(context); // close summary dialog
        Navigator.pop(context); // close workflow sheet
        widget.onComplete?.call(); // triggers _fetch() in appointments screen
      }
    } else {
      debugPrint('Encounter FAILED: ${res.statusCode} → ${res.body}');
      showSnack(context,'Failed to save encounter', isError: true);
    }
  } catch (e) {
    debugPrint('Exception: $e');
    showSnack(context,'Failed to save encounter', isError: true);
  }
  if (mounted) setState(() => _saving = false);
}
  // ── Helper names ─────────────────────────────────────────────────────────
  String get _patientName {
    final p = _patients.firstWhere(
        (x) => x['id']?.toString() == _selectedPatientId?.toString(),
        orElse: () => {});
    return p.isEmpty ? '' : '${p['first_name']} ${p['last_name'] ?? ''}'.trim();
  }

  String get _doctorName {
    final d = _doctors.firstWhere(
        (x) => x['id']?.toString() == _selectedDoctorId?.toString(),
        orElse: () => {});
    return d.isEmpty ? '' : (d['name'] ?? d['full_name'] ?? '');
  }

  // ── Summary popup ─────────────────────────────────────────────────────────
  void _showSummary() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EncounterSummaryDialog(
        patientName: _patientName,
        doctorName: _doctorName,
        encounter: {
          'chief_complaint': _complaintCtrl.text.trim(),
          'notes': _notesCtrl.text.trim(),
          'follow_up_date': _followUpCtrl.text,
        },
        diagnoses: _diagnoses,
        prescriptions: _prescriptions,
        saving: _saving,
        onEdit: () => Navigator.pop(context),
        onConfirm: _confirmSave,
      ),
    );
  }

  // ── ICD popup ─────────────────────────────────────────────────────────────
  void _showIcdPopup() {
    showDialog(
      context: context,
      builder: (_) => _AddIcdDialog(
        onAdded: (newCode) async {
          await _reloadIcd();
          setState(() => _selectedIcd = newCode);
          showSnack(context,'ICD code $newCode added');
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return Container(
      height: h * 0.95,
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        _buildHeader(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppColors.teal.withOpacity(0.08),
              Colors.blue.withOpacity(0.05)
            ]),
            border: const Border(bottom: BorderSide(color: AppColors.divider)),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline, size: 14, color: AppColors.teal),
            const SizedBox(width: 8),
            const Text(
                'Fill in the details to register a new patient encounter',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ]),
        ),
        _buildTabBar(),
        Expanded(
          child: _loadingData
              ? const AppLoadingView()
              : TabBarView(
                  controller: _tabCtrl,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _EncounterTab(this),
                    _DiagnosesTab(this),
                    _PrescriptionsTab(this),
                  ],
                ),
        ),
        _buildFooter(),
      ]),
    );
  }

  Widget _buildHeader() => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.divider))),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: AppColors.teal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.medical_services_outlined,
                color: AppColors.teal, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Patient Encounter',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                Text('New encounter registration',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ])),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.close, color: AppColors.textMuted),
          ),
        ]),
      );

  Widget _buildTabBar() {
    const icons = [
      Icons.assignment_outlined,
      Icons.local_hospital_outlined,
      Icons.medication_outlined
    ];
    return Container(
      color: AppColors.white,
      child: TabBar(
        controller: _tabCtrl,
        labelColor: AppColors.teal,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.teal,
        indicatorWeight: 2,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        tabs: List.generate(
            _tabs.length,
            (i) => Tab(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icons[i], size: 15),
                    const SizedBox(width: 5),
                    Text(_tabs[i][0].toUpperCase() + _tabs[i].substring(1)),
                  ]),
                )),
      ),
    );
  }

  Widget _buildFooter() {
    final idx = _tabCtrl.index;
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).padding.bottom + 16),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(children: [
        if (idx > 0)
          Expanded(
              child: OutlinedButton(
            onPressed: () => _tabCtrl.animateTo(idx - 1),
            style: AppButtonStyle.outlined(),
            child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 13),
                child: Text('Back',
                    style: TextStyle(color: AppColors.textSecondary))),
          )),
        if (idx > 0) const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: idx < _tabs.length - 1
              ? ElevatedButton(
                  onPressed: () => _tabCtrl.animateTo(idx + 1),
                  style: AppButtonStyle.primary(),
                  child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 13),
                      child: Text('Next',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600))),
                )
              : ElevatedButton(
                  onPressed: _saving ? null : _handleCompleteClick,
                  style: AppButtonStyle.primary(),
                  child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                  Icon(Icons.check_circle_outline,
                                      size: 16, color: Colors.white),
                                  SizedBox(width: 6),
                                  Text('Complete Encounter',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600)),
                                ])),
                ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Tab 1 — Encounter
// ─────────────────────────────────────────────────────────────────────────────
class _EncounterTab extends StatefulWidget {
  final _EncounterWorkflowState s;
  const _EncounterTab(this.s);
  @override
  State<_EncounterTab> createState() => _EncounterTabState();
}

class _EncounterTabState extends State<_EncounterTab> {
  _EncounterWorkflowState get s => widget.s;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: _SearchableDropdown<int>(
            label: 'Patient',
            value: s._selectedPatientId,
            options: s._patients
                .map((p) => _DropOption(
                      value: p['id'] as int,
                      label:
                          '${p['first_name']} ${p['last_name'] ?? ''}'.trim(),
                    ))
                .toList(),
            placeholder: 'Select patient...',
            onChanged: (v) => s.setState(() => s._selectedPatientId = v),
          )),
          const SizedBox(width: 12),
          Expanded(
              child: _SearchableDropdown<int>(
            label: 'Doctor',
            value: s._selectedDoctorId,
            options: s._doctors
                .map((d) => _DropOption(
                      value: d['id'] as int,
                      label: d['name'] ?? d['full_name'] ?? '',
                    ))
                .toList(),
            placeholder: 'Select doctor...',
            onChanged: (v) => s.setState(() => s._selectedDoctorId = v),
          )),
        ]),
        const SizedBox(height: 16),
        _fieldLabel('Chief Complaint *'),
        const SizedBox(height: 6),
        TextField(
          controller: s._complaintCtrl,
          maxLines: 2,
          decoration: AppInput.deco('Enter chief complaint…'),
        ),
        const SizedBox(height: 16),
        _fieldLabel('Clinical Notes'),
        const SizedBox(height: 6),
        TextField(
          controller: s._notesCtrl,
          maxLines: 4,
          decoration: AppInput.deco('Additional clinical notes…'),
        ),
        const SizedBox(height: 16),
        _fieldLabel('Follow-up Date'),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: DateTime.now().add(const Duration(days: 7)),
              firstDate: DateTime.now(),
              lastDate: DateTime(2035),
              builder: (c, child) => Theme(
                data: Theme.of(c).copyWith(
                    colorScheme:
                        const ColorScheme.light(primary: AppColors.teal)),
                child: child!,
              ),
            );
            if (d != null) {
              s.setState(() =>
                  s._followUpCtrl.text = d.toIso8601String().substring(0, 10));
            }
          },
          child: AbsorbPointer(
              child: TextField(
            controller: s._followUpCtrl,
            decoration: AppInput.deco('YYYY-MM-DD',
                icon: Icons.calendar_today_outlined),
          )),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Tab 2 — Diagnoses
// ─────────────────────────────────────────────────────────────────────────────
class _DiagnosesTab extends StatefulWidget {
  final _EncounterWorkflowState s;
  const _DiagnosesTab(this.s);
  @override
  State<_DiagnosesTab> createState() => _DiagnosesTabState();
}

class _DiagnosesTabState extends State<_DiagnosesTab> {
  _EncounterWorkflowState get s => widget.s;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: _IcdDropdown(
            value: s._selectedIcd,
            codes: s._icdCodes,
            onChanged: (v) {
              if (v == '__other__') {
                s._showIcdPopup();
                return;
              }
              s.setState(() => s._selectedIcd = v);
            },
          )),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _fieldLabel('Description'),
                const SizedBox(height: 6),
                TextField(
                    controller: s._dxDescCtrl,
                    decoration: AppInput.deco('Optional description…')),
              ])),
        ]),
        const SizedBox(height: 12),
        SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: s._addDiagnosis,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Diagnosis'),
              style: AppButtonStyle.primary(),
            )),
        const SizedBox(height: 16),
        if (s._diagnoses.isEmpty)
          _emptyHint('No diagnoses added yet')
        else
          ...s._diagnoses.map((d) => _DiagnosisChip(
                diagnosis: d,
                onRemove: () => s.setState(
                    () => s._diagnoses.removeWhere((x) => x.id == d.id)),
              )),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Tab 3 — Prescriptions
// ─────────────────────────────────────────────────────────────────────────────
class _PrescriptionsTab extends StatefulWidget {
  final _EncounterWorkflowState s;
  const _PrescriptionsTab(this.s);
  @override
  State<_PrescriptionsTab> createState() => _PrescriptionsTabState();
}

class _PrescriptionsTabState extends State<_PrescriptionsTab> {
  _EncounterWorkflowState get s => widget.s;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: _MedicineSearchField(
            controller: s._rxNameCtrl,
            medicines: s._filteredMedicines,
            showDrop: s._showMedicineDrop,
            onSearch: s._onMedicineSearch,
            onPick: s._pickMedicine,
          )),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _fieldLabel('Dosage'),
                const SizedBox(height: 6),
                TextField(
                    controller: s._rxDosageCtrl,
                    decoration: AppInput.deco('e.g. 1 tablet 500mg')),
              ])),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _fieldLabel('Frequency'),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: s._rxFrequency,
                  isExpanded: true, // ← ADD THIS, prevents overflow
                  decoration: AppInput.deco(''),
                  onChanged: (v) => s.setState(() => s._rxFrequency = v!),
                  items: _frequencies
                      .map((f) => DropdownMenuItem(
                          value: f,
                          child: Text(
                            f,
                            style: const TextStyle(
                                fontSize: 11), // ← slightly smaller
                            overflow:
                                TextOverflow.ellipsis, // ← clips if needed
                          )))
                      .toList(),
                ),
              ])),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _fieldLabel('Duration'),
                const SizedBox(height: 6),
                TextField(
                    controller: s._rxDurationCtrl,
                    decoration: AppInput.deco('e.g. 5 days')),
              ])),
        ]),
        const SizedBox(height: 12),
        _fieldLabel('Instructions'),
        const SizedBox(height: 6),
        TextField(
            controller: s._rxInstructionsCtrl,
            decoration: AppInput.deco('e.g. After meals')),
        const SizedBox(height: 12),
        SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: s._addPrescription,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Medicine'),
              style: AppButtonStyle.primary(),
            )),
        const SizedBox(height: 16),
        if (s._prescriptions.isEmpty)
          _emptyHint('No medicines added yet')
        else
          ...s._prescriptions.map((p) => _PrescriptionChip(
                prescription: p,
                onRemove: () => s.setState(
                    () => s._prescriptions.removeWhere((x) => x.id == p.id)),
              )),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Searchable Dropdown (Patient / Doctor)
// ─────────────────────────────────────────────────────────────────────────────
class _DropOption<T> {
  final T value;
  final String label;
  const _DropOption({required this.value, required this.label});
}

class _SearchableDropdown<T> extends StatefulWidget {
  final String label;
  final T? value;
  final List<_DropOption<T>> options;
  final String placeholder;
  final ValueChanged<T?> onChanged;
  const _SearchableDropdown({
    required this.label,
    this.value,
    required this.options,
    required this.placeholder,
    required this.onChanged,
  });
  @override
  State<_SearchableDropdown<T>> createState() => _SearchableDropdownState<T>();
}

class _SearchableDropdownState<T> extends State<_SearchableDropdown<T>> {
  bool _open = false;
  final _searchCtrl = TextEditingController();
  List<_DropOption<T>> get _filtered => widget.options
      .where(
          (o) => o.label.toLowerCase().contains(_searchCtrl.text.toLowerCase()))
      .toList();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected =
        widget.options.where((o) => o.value == widget.value).firstOrNull;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _fieldLabel(widget.label),
      const SizedBox(height: 6),
      GestureDetector(
        onTap: () => setState(() => _open = !_open),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            border:
                Border.all(color: _open ? AppColors.teal : AppColors.border),
            borderRadius: BorderRadius.circular(10),
            color: AppColors.white,
          ),
          child: Row(children: [
            Expanded(
                child: Text(
              selected?.label ?? widget.placeholder,
              style: TextStyle(
                  fontSize: 13,
                  color: selected != null
                      ? AppColors.textPrimary
                      : AppColors.textMuted),
            )),
            Icon(Icons.keyboard_arrow_down,
                size: 18, color: _open ? AppColors.teal : AppColors.textMuted),
          ]),
        ),
      ),
      if (_open)
        Container(
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: AppInput.deco('Search…', icon: Icons.search),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView(
                  shrinkWrap: true,
                  children: _filtered.isEmpty
                      ? [
                          const Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('No results',
                                  style: TextStyle(
                                      fontSize: 12, color: AppColors.textMuted),
                                  textAlign: TextAlign.center))
                        ]
                      : _filtered
                          .map((o) => InkWell(
                                onTap: () {
                                  widget.onChanged(o.value);
                                  setState(() {
                                    _open = false;
                                    _searchCtrl.clear();
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 11),
                                  color: o.value == widget.value
                                      ? AppColors.teal.withOpacity(0.06)
                                      : Colors.transparent,
                                  child: Text(o.label,
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: o.value == widget.value
                                              ? AppColors.teal
                                              : AppColors.textPrimary,
                                          fontWeight: o.value == widget.value
                                              ? FontWeight.w600
                                              : FontWeight.normal)),
                                ),
                              ))
                          .toList()),
            ),
          ]),
        ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ICD Dropdown
// ─────────────────────────────────────────────────────────────────────────────
class _IcdDropdown extends StatefulWidget {
  final String? value;
  final List<String> codes;
  final ValueChanged<String?> onChanged;
  const _IcdDropdown(
      {this.value, required this.codes, required this.onChanged});
  @override
  State<_IcdDropdown> createState() => _IcdDropdownState();
}

class _IcdDropdownState extends State<_IcdDropdown> {
  bool _open = false;
  final _searchCtrl = TextEditingController();
  List<String> get _filtered => widget.codes
      .where((c) => c.toLowerCase().contains(_searchCtrl.text.toLowerCase()))
      .toList();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _fieldLabel('ICD Code'),
      const SizedBox(height: 6),
      GestureDetector(
        onTap: () => setState(() => _open = !_open),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            border:
                Border.all(color: _open ? AppColors.teal : AppColors.border),
            borderRadius: BorderRadius.circular(10),
            color: AppColors.white,
          ),
          child: Row(children: [
            Expanded(
                child: Text(widget.value ?? 'Select ICD code...',
                    style: TextStyle(
                        fontSize: 13,
                        color: widget.value != null
                            ? AppColors.teal
                            : AppColors.textMuted,
                        fontWeight: widget.value != null
                            ? FontWeight.w600
                            : FontWeight.normal))),
            Icon(Icons.keyboard_arrow_down,
                size: 18, color: _open ? AppColors.teal : AppColors.textMuted),
          ]),
        ),
      ),
      if (_open)
        Container(
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  decoration:
                      AppInput.deco('Search ICD codes…', icon: Icons.search)),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 160),
              child: ListView(shrinkWrap: true, children: [
                ..._filtered.isEmpty
                    ? [
                        const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('No matching codes',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.textMuted),
                                textAlign: TextAlign.center))
                      ]
                    : _filtered
                        .map((c) => InkWell(
                              onTap: () {
                                widget.onChanged(c);
                                setState(() {
                                  _open = false;
                                  _searchCtrl.clear();
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                color: c == widget.value
                                    ? AppColors.teal.withOpacity(0.06)
                                    : Colors.transparent,
                                child: Text(c,
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: c == widget.value
                                            ? AppColors.teal
                                            : AppColors.textPrimary,
                                        fontWeight: c == widget.value
                                            ? FontWeight.w600
                                            : FontWeight.normal)),
                              ),
                            ))
                        .toList(),
                InkWell(
                  onTap: () {
                    widget.onChanged('__other__');
                    setState(() {
                      _open = false;
                      _searchCtrl.clear();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: const BoxDecoration(
                        border:
                            Border(top: BorderSide(color: AppColors.divider))),
                    child: Row(children: [
                      const Icon(Icons.add_circle_outline,
                          size: 15, color: AppColors.teal),
                      const SizedBox(width: 8),
                      const Text('Other (Add new ICD code)',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.teal,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ]),
            ),
          ]),
        ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Medicine Search Field
// ─────────────────────────────────────────────────────────────────────────────
class _MedicineSearchField extends StatelessWidget {
  final TextEditingController controller;
  final List<Map<String, dynamic>> medicines;
  final bool showDrop;
  final ValueChanged<String> onSearch;
  final ValueChanged<Map<String, dynamic>> onPick;
  const _MedicineSearchField({
    required this.controller,
    required this.medicines,
    required this.showDrop,
    required this.onSearch,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _fieldLabel('Medicine Name'),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        onChanged: onSearch,
        decoration: AppInput.deco('Search from inventory…', icon: Icons.search),
      ),
      if (showDrop && medicines.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(top: 4),
          constraints: const BoxConstraints(maxHeight: 180),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 4))
            ],
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: medicines.length,
            itemBuilder: (_, i) {
              final m = medicines[i];
              final name = m['medicine_name'] ?? m['name'] ?? '';
              final dosage = m['dosage'] ?? '';
              return InkWell(
                onTap: () => onPick(m),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(children: [
                    Expanded(
                        child: Text(name,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary))),
                    if (dosage.isNotEmpty)
                      Text(dosage,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textMuted)),
                  ]),
                ),
              );
            },
          ),
        ),
      if (showDrop && medicines.isEmpty)
        Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border)),
          child: const Text('No medicines found in inventory',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              textAlign: TextAlign.center),
        ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Diagnosis chip row
// ─────────────────────────────────────────────────────────────────────────────
class _DiagnosisChip extends StatelessWidget {
  final _Diagnosis diagnosis;
  final VoidCallback onRemove;
  const _DiagnosisChip({required this.diagnosis, required this.onRemove});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: AppColors.teal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6)),
            child: Text(diagnosis.icdCode,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.teal)),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text(
                  diagnosis.description.isNotEmpty
                      ? diagnosis.description
                      : '—',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary))),
          GestureDetector(
              onTap: onRemove,
              child: const Icon(Icons.delete_outline,
                  size: 16, color: AppColors.statusRed)),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Prescription chip row
// ─────────────────────────────────────────────────────────────────────────────
class _PrescriptionChip extends StatelessWidget {
  final _Prescription prescription;
  final VoidCallback onRemove;
  const _PrescriptionChip({required this.prescription, required this.onRemove});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(prescription.medicineName,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.teal)),
                const SizedBox(height: 3),
                Text(
                  [
                    prescription.dosage,
                    prescription.frequency,
                    prescription.duration
                  ].where((s) => s.isNotEmpty).join(' · '),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
                if (prescription.instructions.isNotEmpty)
                  Text(prescription.instructions,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textMuted)),
              ])),
          GestureDetector(
              onTap: onRemove,
              child: const Icon(Icons.delete_outline,
                  size: 16, color: AppColors.statusRed)),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Add ICD Code Dialog
// ─────────────────────────────────────────────────────────────────────────────
class _AddIcdDialog extends StatefulWidget {
  final ValueChanged<String> onAdded;
  const _AddIcdDialog({required this.onAdded});
  @override
  State<_AddIcdDialog> createState() => _AddIcdDialogState();
}

class _AddIcdDialogState extends State<_AddIcdDialog> {
  final _codeCtrl = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_codeCtrl.text.trim().isEmpty) {
      setState(() => _error = 'ICD code is required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final res = await http.post(
        Uri.parse('${ApiClient.baseUrl}/icd_codes_create'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'icd_code': _codeCtrl.text.trim().toUpperCase(),
          'created_by': 'admin'
        }),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 || res.statusCode == 201) {
        final code =
            data['data']?['icd_code'] ?? _codeCtrl.text.trim().toUpperCase();
        Navigator.pop(context);
        widget.onAdded(code);
      } else {
        setState(() => _error = data['error'] ?? 'Failed to create ICD code');
      }
    } catch (_) {
      setState(() => _error = 'Network error. Please try again.');
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: AppColors.teal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.add_circle_outline,
                          color: AppColors.teal, size: 18)),
                  const SizedBox(width: 10),
                  const Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('Add New ICD Code',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary)),
                        Text('Saved to database immediately',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.textMuted)),
                      ])),
                  GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close,
                          color: AppColors.textMuted, size: 18)),
                ]),
                const SizedBox(height: 16),
                Text('ICD Code *', style: AppTextStyles.label),
                const SizedBox(height: 6),
                TextField(
                  controller: _codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: AppInput.deco('e.g. A01.0'),
                  onChanged: (_) => setState(() => _error = null),
                ),
                if (_error != null)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                        color: AppColors.statusRedBg,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(_error!,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.statusRed)),
                  ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                      child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: AppButtonStyle.outlined(),
                    child: const Text('Cancel',
                        style: TextStyle(color: AppColors.textSecondary)),
                  )),
                  const SizedBox(width: 10),
                  Expanded(
                      child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: AppButtonStyle.primary(),
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Add ICD Code',
                            style: TextStyle(color: Colors.white)),
                  )),
                ]),
              ]),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Encounter Summary / Review Dialog
// ─────────────────────────────────────────────────────────────────────────────
class _EncounterSummaryDialog extends StatelessWidget {
  final String patientName, doctorName;
  final Map<String, dynamic> encounter;
  final List<_Diagnosis> diagnoses;
  final List<_Prescription> prescriptions;
  final bool saving;
  final VoidCallback onEdit, onConfirm;

  const _EncounterSummaryDialog({
    required this.patientName,
    required this.doctorName,
    required this.encounter,
    required this.diagnoses,
    required this.prescriptions,
    required this.saving,
    required this.onEdit,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.divider))),
            child: Row(children: [
              Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: AppColors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.preview_outlined,
                      color: AppColors.teal, size: 18)),
              const SizedBox(width: 12),
              const Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Review Encounter',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                    Text('Please review all details before confirming',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textMuted)),
                  ])),
              GestureDetector(
                  onTap: onEdit,
                  child: const Icon(Icons.close, color: AppColors.textMuted)),
            ]),
          ),

          // Scrollable body
          Flexible(
              child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _summarySection('Basic Info',
                  child: Column(children: [
                    Row(children: [
                      Expanded(
                          child: _infoField('Patient',
                              patientName.isNotEmpty ? patientName : '—')),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _infoField('Doctor',
                              doctorName.isNotEmpty ? doctorName : '—')),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                          child: _infoField('Visit Date',
                              DateTime.now().toString().substring(0, 10))),
                      if ((encounter['follow_up_date'] ?? '').isNotEmpty)
                        Expanded(
                            child: _infoField(
                                'Follow-up', encounter['follow_up_date'])),
                    ]),
                  ])),
              const SizedBox(height: 12),
              _summarySection('Chief Complaint',
                  child: _bgText(encounter['chief_complaint'] ?? '—')),
              const SizedBox(height: 12),
              if ((encounter['notes'] ?? '').isNotEmpty) ...[
                _summarySection('Clinical Notes',
                    child: _bgText(encounter['notes'])),
                const SizedBox(height: 12),
              ],
              _summarySection('Diagnoses (${diagnoses.length})',
                  child: diagnoses.isEmpty
                      ? const Text('No diagnoses added',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textMuted,
                              fontStyle: FontStyle.italic))
                      : Column(
                          children: diagnoses
                              .map((d) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                            color:
                                                AppColors.teal.withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(6)),
                                        child: Text(d.icdCode,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.teal)),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                          child: Text(
                                              d.description.isNotEmpty
                                                  ? d.description
                                                  : '—',
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  color: AppColors
                                                      .textSecondary))),
                                    ]),
                                  ))
                              .toList())),
              const SizedBox(height: 12),
              _summarySection('Prescriptions (${prescriptions.length})',
                  child: prescriptions.isEmpty
                      ? const Text('No prescriptions added',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textMuted,
                              fontStyle: FontStyle.italic))
                      : Column(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(8)),
                            child: const Row(children: [
                              Expanded(
                                  flex: 2,
                                  child: Text('Medicine',
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textMuted))),
                              Expanded(
                                  child: Text('Dosage',
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textMuted))),
                              Expanded(
                                  child: Text('Frequency',
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textMuted))),
                            ]),
                          ),
                          ...prescriptions.map((p) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                decoration: const BoxDecoration(
                                    border: Border(
                                        bottom: BorderSide(
                                            color: AppColors.divider))),
                                child: Row(children: [
                                  Expanded(
                                      flex: 2,
                                      child: Text(p.medicineName,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.teal))),
                                  Expanded(
                                      child: Text(
                                          p.dosage.isNotEmpty ? p.dosage : '—',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary))),
                                  Expanded(
                                      child: Text(p.frequency,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textSecondary))),
                                ]),
                              )),
                        ])),
            ]),
          )),

          // Footer
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: const BoxDecoration(
              color: AppColors.background,
              border: Border(top: BorderSide(color: AppColors.divider)),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(children: [
              OutlinedButton(
                onPressed: onEdit,
                style: AppButtonStyle.outlined(),
                child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    child: Text('Edit',
                        style: TextStyle(color: AppColors.textSecondary))),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: ElevatedButton(
                onPressed: saving ? null : onConfirm,
                style: AppButtonStyle.primary(),
                child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    child: saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                                Icon(Icons.check_circle_outline,
                                    size: 16, color: Colors.white),
                                SizedBox(width: 6),
                                Text('Confirm & Save',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600)),
                              ])),
              )),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _summarySection(String title, {required Widget child}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title.toUpperCase(),
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: AppColors.textMuted)),
        const SizedBox(height: 4),
        const Divider(height: 1, color: AppColors.divider),
        const SizedBox(height: 10),
        child,
      ]);

  Widget _infoField(String label, String value) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
      ]);

  Widget _bgText(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8)),
        child: Text(text,
            style:
                const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Shared helpers
// ─────────────────────────────────────────────────────────────────────────────
Widget _fieldLabel(String text) => Text(text,
    style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary));

Widget _emptyHint(String msg) => Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.inbox_outlined,
              size: 36, color: AppColors.textMuted),
          const SizedBox(height: 8),
          Text(msg,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
        ]),
      ),
    );
