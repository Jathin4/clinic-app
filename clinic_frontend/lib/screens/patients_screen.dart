import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../widgets/app_widgets.dart';

const _bloods  = ['A+','A-','B+','B-','AB+','AB-','O+','O-'];
const _genders = ['Male','Female','Other'];
const _refs    = ['Friend/Relative','Google','Social Media','Advertisement','Other'];

Color _gc(String? g) => g=='Male' ? const Color(0xFF1D4ED8) : g=='Female' ? const Color(0xFFBE185D) : Colors.grey;
Color _gb(String? g) => g=='Male' ? const Color(0xFFEFF6FF) : g=='Female' ? const Color(0xFFFDF2F8) : const Color(0xFFF9FAFB);

// ── PATIENTS SCREEN ────────────────────────────────────────────────────────
class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});
  @override State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  List<Map<String,dynamic>> _all=[], _list=[];
  bool _loading=true;
  String _q='';
  Map<String,dynamic>? _viewing;
  int get _cid => context.read<AppProvider>().user?['clinic_id'];

  @override void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final r = await http.get(Uri.parse('${ApiClient.baseUrl}/patient_read?clinic_id=$_cid'));
      final d = jsonDecode(r.body);
      if (d is List) setState(() { _all = List<Map<String,dynamic>>.from(d); _filter(); });
    } catch (_) {}
    setState(() => _loading = false);
  }

  void _filter() {
    final q = _q.trim().toLowerCase();
    _list = q.isEmpty ? List.from(_all) : _all.where((p) =>
        '${p['first_name']} ${p['last_name']} ${p['email']} ${p['phone']} ${p['gender']} ${p['blood_group']} ${p['dob']} ${p['pulse_rate']} ${p['bp']}'
            .toLowerCase().contains(q)).toList();
  }

  Future<void> _delete(int id) async {
    if (!await confirmDelete(context, title: 'Delete Patient', message: 'Are you sure you want to delete this patient?')) return;
    try {
      await http.delete(Uri.parse('${ApiClient.baseUrl}/patients_delete/'),
          headers: {'Content-Type': 'application/json'}, body: jsonEncode({'id': id, 'modified_by': 'admin'}));
      _fetch();
    } catch (_) {}
  }

  void _form({Map<String,dynamic>? p}) => showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _PatientForm(patient: p, clinicId: _cid, onSaved: _fetch, existingPatients: _all,));

  @override
  Widget build(BuildContext context) {
    if (_viewing != null) return _PatientDetail(patient: _viewing!,
        onBack: () => setState(() => _viewing = null),
        onEdit: () { _form(p: _viewing); setState(() => _viewing = null); });
    return Scaffold(backgroundColor: AppColors.background, body: Column(children: [
      AppPageHeader(title: 'Patients', subtitle: 'Manage patient records', actionLabel: 'Add Patient', actionIcon: Icons.add, onAction: () => _form()),
      AppSearchBar(hint: 'Search by name, phone, blood group…', onChanged: (v) => setState(() { _q = v; _filter(); })),
      Padding(padding: const EdgeInsets.fromLTRB(16,4,16,4), child: Align(alignment: Alignment.centerLeft, child: Text('${_list.length} patients registered', style: AppTextStyles.bodySmall))),
      Expanded(child: _loading ? const AppLoadingView() : _list.isEmpty ? const AppEmptyView(message: 'No patients found')
          : ListView.builder(padding: const EdgeInsets.fromLTRB(16,0,16,16), itemCount: _list.length,
              itemBuilder: (_, i) => _PatientCard(p: _list[i],
                onView: () => setState(() => _viewing = _list[i]),
                onEdit: () => _form(p: _list[i]),
                onDelete: () => _delete(_list[i]['id'])))),
    ]));
  }
}

// ── PATIENT CARD ───────────────────────────────────────────────────────────
class _PatientCard extends StatelessWidget {
  final Map<String,dynamic> p;
  final VoidCallback onView, onEdit, onDelete;
  const _PatientCard({required this.p, required this.onView, required this.onEdit, required this.onDelete});

  Widget _btn(IconData icon, Color c, VoidCallback fn) => GestureDetector(onTap: fn,
      child: Container(margin: const EdgeInsets.only(left: 4), padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: c.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: c)));

  @override
  Widget build(BuildContext context) {
    final name = '${p['first_name']??''} ${p['last_name']??''}'.trim();
    final ini  = '${(p['first_name']??'')[0]}${(p['last_name']??'')[0]}'.toUpperCase();
    return AppCard(child: Row(children: [
      Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(12)),
          child: Center(child: Text(ini, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)))),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name.isEmpty ? '—' : name, style: AppTextStyles.cardTitle),
        const SizedBox(height: 3),
        Row(children: [
          if (p['phone'] != null) Text(p['phone'], style: AppTextStyles.bodySmall),
          if (p['phone'] != null && p['gender'] != null) const Text(' · ', style: TextStyle(color: AppColors.textMuted)),
          if (p['gender'] != null) Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: _gb(p['gender']), borderRadius: BorderRadius.circular(6)),
              child: Text(p['gender'], style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _gc(p['gender'])))),
        ]),
        Text('DOB: ${fmtDate(p['dob'])}${p['blood_group'] != null ? ' · ${p['blood_group']}' : ''}',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
      ])),
      Row(mainAxisSize: MainAxisSize.min, children: [
        _btn(Icons.visibility_outlined, AppColors.teal,       onView),
        _btn(Icons.edit_outlined,       AppColors.statusBlue, onEdit),
        _btn(Icons.delete_outline,      AppColors.statusRed,  onDelete),
      ]),
    ]));
  }
}

// ── PATIENT DETAIL ─────────────────────────────────────────────────────────
class _PatientDetail extends StatelessWidget {
  final Map<String,dynamic> patient;
  final VoidCallback onBack, onEdit;
  const _PatientDetail({required this.patient, required this.onBack, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final p    = patient;
    final name = '${p['first_name']??''} ${p['last_name']??''}'.trim();
    final ini  = '${(p['first_name']??' ')[0]}${(p['last_name']??' ')[0]}'.toUpperCase();
    final rows = [
      ['UHID',        p['id'] != null ? 'HF-${p['id'].toString().padLeft(4,'0')}' : '—'],
      ['Gender',      p['gender']      ?? '—'], ['DOB',    fmtDate(p['dob'])],
      ['Phone',       p['phone']       ?? '—'], ['Email',  p['email']  ?? '—'],
      ['Blood Group', p['blood_group'] ?? '—'],
      ['Weight',      p['weight']    != null ? '${p['weight']} kg'  : '—'],
      ['BP',          p['bp']          ?? '—'],
      ['Pulse Rate',  p['pulse_rate'] != null ? '${p['pulse_rate']} bpm' : '—'],
      ['Address',     p['address']     ?? '—'],
    ];
    return Scaffold(backgroundColor: AppColors.background, body: Column(children: [
      Container(color: AppColors.white,
          padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 16, 12),
          child: Row(children: [
            GestureDetector(onTap: onBack, child: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.textSecondary)),
            const SizedBox(width: 8),
            const Text('Patient Detail', style: AppTextStyles.sectionTitle),
            const Spacer(),
            GestureDetector(onTap: onEdit, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(10)),
                child: const Row(children: [Icon(Icons.edit_outlined, size: 14, color: Colors.white), SizedBox(width: 4),
                  Text('Edit', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))]))),
          ])),
      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
        AppCard(padding: const EdgeInsets.all(16), child: Row(children: [
          Container(width: 56, height: 56, decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(14)),
              child: Center(child: Text(ini, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name.isEmpty ? '—' : name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.statusGreenBg, borderRadius: BorderRadius.circular(6)),
                child: const Text('Active', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.teal))),
          ])),
        ])),
        const SizedBox(height: 12),
        AppCard(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Personal Information', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 12),
          ...rows.map((f) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [
            SizedBox(width: 110, child: Text(f[0], style: const TextStyle(fontSize: 13, color: AppColors.textMuted))),
            Expanded(child: Text(f[1], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary))),
          ]))),
        ])),
      ]))),
    ]));
  }
}

// ── PATIENT FORM ───────────────────────────────────────────────────────────
class _PatientForm extends StatefulWidget {
  final Map<String,dynamic>? patient;
  final int clinicId;
  final VoidCallback onSaved;
  final List<Map<String,dynamic>> existingPatients; 
  const _PatientForm({this.patient, required this.clinicId, required this.onSaved, required this.existingPatients,});
  @override State<_PatientForm> createState() => _PatientFormState();
}

class _PatientFormState extends State<_PatientForm> {
  final _fc=TextEditingController(), _lc=TextEditingController(), _ec=TextEditingController(),
        _pc=TextEditingController(), _ac=TextEditingController(), _wc=TextEditingController(),
        _bc=TextEditingController(), _pu=TextEditingController();
  final _ff=FocusNode(), _lf=FocusNode(), _af=FocusNode(), _wf=FocusNode(),
        _bf=FocusNode(), _puf=FocusNode(), _ef=FocusNode(), _phf=FocusNode();
  final _sc = ScrollController();
  String _g='', _bl='', _ref='', _eF='', _eL='', _eD='', _eA='', _eG='',
         _eW='', _eB='', _eP='', _eBl='', _ePh='', _eE='', _se='';
  DateTime? _dob;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.patient;
    if (p != null) {
      _fc.text=p['first_name']??''; _lc.text=p['last_name']??''; _ec.text=p['email']??'';
      _pc.text=p['phone']??'';     _ac.text=p['age']?.toString()??'';
      _wc.text=p['weight']?.toString()??''; _bc.text=p['bp']??'';
      _pu.text=p['pulse_rate']?.toString()??'';
      _g=p['gender']??''; _bl=p['blood_group']??''; _ref=p['reference']??'';
      if (p['dob']!=null && p['dob'].toString().isNotEmpty) try { _dob=DateTime.parse(p['dob']); } catch (_) {}
    }
  }

  @override
  void dispose() {
    for (final c in [_fc,_lc,_ec,_pc,_ac,_wc,_bc,_pu]) c.dispose();
    for (final f in [_ff,_lf,_af,_wf,_bf,_puf,_ef,_phf]) f.dispose();
    _sc.dispose(); super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context,
        initialDate: _dob ?? DateTime(now.year-25),
        firstDate: DateTime(now.year-120), lastDate: now);
    if (d != null) {
      final age = now.year - d.year - ((now.month < d.month || (now.month == d.month && now.day < d.day)) ? 1 : 0);
      setState(() { _dob=d; _ac.text=age.toString(); _eD=''; _eA=''; });
    }
  }

  bool _validate() {
    final lr = RegExp(r"^[a-zA-Z\s'-]+$");
    final er = RegExp(r'^[\w.+-]+@[\w-]+\.[a-z]{2,}$', caseSensitive: false);
    setState(() {
      _eF  = _fc.text.trim().isEmpty ? 'First name is required' : !lr.hasMatch(_fc.text.trim()) ? 'Letters only' : '';
      _eL  = _lc.text.trim().isEmpty ? 'Last name is required'  : !lr.hasMatch(_lc.text.trim()) ? 'Letters only' : '';
      _eD  = _dob == null ? 'Date of birth is required' : '';
      _eA  = _ac.text.trim().isEmpty  ? 'Age is required'          : '';
      _eG  = _g.isEmpty               ? 'Gender is required'        : '';
      _eW  = _wc.text.trim().isEmpty  ? 'Weight is required'        : '';
      _eB  = _bc.text.trim().isEmpty  ? 'BP is required'            : '';
      _eP  = _pu.text.trim().isEmpty  ? 'Pulse rate is required'    : '';
      _eBl = _bl.isEmpty              ? 'Blood group is required'   : '';
      _ePh = _pc.text.trim().isEmpty  ? 'Phone is required' : _pc.text.trim().length != 10 ? 'Must be exactly 10 digits' : '';
      _eE  = _ec.text.trim().isNotEmpty && !er.hasMatch(_ec.text.trim()) ? 'Invalid email address' : '';
    });
    return [_eF,_eL,_eD,_eA,_eG,_eW,_eB,_eP,_eBl,_ePh,_eE].every((e) => e.isEmpty);
  }

  Future<void> _save() async {
  if (!_validate()) return;
  setState(() { _saving=true; _se=''; });

  // ── DUPLICATE CHECK ──────────────────────────────────────────
  final dobStr = _dob != null
      ? '${_dob!.year}-${_dob!.month.toString().padLeft(2,'0')}-${_dob!.day.toString().padLeft(2,'0')}'
      : '';

  final isDuplicate = widget.existingPatients.any((p) {
    // Skip the current patient when editing
    if (widget.patient != null && p['id'] == widget.patient!['id']) return false;

    final sameName  = '${p['first_name']??''}'.trim().toLowerCase() == _fc.text.trim().toLowerCase()
                   && '${p['last_name']??''}'.trim().toLowerCase()  == _lc.text.trim().toLowerCase();
    final samePhone = '${p['phone']??''}'.trim() == _pc.text.trim();
    final sameDob   = '${p['dob']??''}'.trim()   == dobStr;

    return sameName && samePhone && sameDob;  // all 3 must match
  });

  if (isDuplicate) {
    setState(() { 
      _se = 'Account already exists with same name, phone & date of birth.'; 
      _saving = false; 
    });
    return;   // ← stop here, don't call API
  }
  // ─────────────────────────────────────────────────────────────

  try {
    final r = await http.post(Uri.parse('${ApiClient.baseUrl}/patient_create_update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': widget.patient?['id'] ?? 0, 'clinic_id': widget.clinicId, 'created_by': 'admin',
          'first_name': _fc.text.trim(), 'last_name': _lc.text.trim(), 'email': _ec.text.trim(),
          'phone': _pc.text.trim(), 'dob': dobStr,
          'age': int.tryParse(_ac.text.trim()), 'gender': _g, 'blood_group': _bl,
          'weight': double.tryParse(_wc.text.trim()), 'bp': _bc.text.trim(),
          'pulse_rate': _pu.text.trim(), 'reference': _ref, 'address': '',
        }));
    if (r.statusCode == 200 || r.statusCode == 201) { Navigator.pop(context); widget.onSaved(); }
    else {
      final msg = jsonDecode(r.body)['detail'] ?? 'Server error. Please try again.';
      setState(() {
        if (msg.toString().toLowerCase().contains('phone') || msg.toString().toLowerCase().contains('duplicate')) _ePh = msg;
        else if (msg.toString().toLowerCase().contains('email')) _eE = msg;
        else _se = msg;
      });
    }
  } catch (e) { setState(() => _se = 'Network error: $e'); }
  if (mounted) setState(() => _saving = false);
}

  // ── UI helpers ─────────────────────────────────────────────────────────
  Widget _lbl(String t, {bool req=true}) => Padding(padding: const EdgeInsets.only(bottom: 4),
      child: RichText(text: TextSpan(text: t.toUpperCase(), style: AppTextStyles.label,
          children: req ? [const TextSpan(text: ' *', style: TextStyle(color: Colors.red, fontSize: 11))] : [])));

  Widget _err(String e) => e.isEmpty ? const SizedBox.shrink()
      : Padding(padding: const EdgeInsets.only(top: 4), child: Text(e, style: const TextStyle(color: Colors.red, fontSize: 11)));

  InputDecoration _deco(String hint, String err) => AppInput.deco(hint).copyWith(
      counterText: '',
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: err.isNotEmpty ? Colors.red : Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: err.isNotEmpty ? Colors.red : AppColors.teal, width: 1.5)));

  Widget _tf(String lbl, TextEditingController c, String err, {String hint='', TextInputType kt=TextInputType.text,
      List<TextInputFormatter> fmt=const[], bool req=true, int? ml, FocusNode? fn, FocusNode? nf, bool last=false}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _lbl(lbl, req: req),
        TextField(controller: c, keyboardType: kt, inputFormatters: fmt, maxLength: ml, focusNode: fn,
            textInputAction: last ? TextInputAction.done : TextInputAction.next,
            onSubmitted: (_) { if (nf != null) FocusScope.of(context).requestFocus(nf); else FocusScope.of(context).unfocus(); },
            onChanged: (_) => setState(() {}),
            decoration: _deco(hint, err)),
        _err(err),
      ]);

  Widget _dd(String lbl, List<String> opts, String val, ValueChanged<String?> fn, String err, {bool req=true}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _lbl(lbl, req: req),
        DropdownButtonFormField<String>(value: val.isEmpty ? null : val, isDense: true,
            decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                filled: true, fillColor: Colors.grey.shade100,
                border:        OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: err.isNotEmpty ? Colors.red : Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: err.isNotEmpty ? Colors.red : Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.teal, width: 1.5))),
            hint: Text('Select', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            items: opts.map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: (v) { fn(v); setState(() {}); }),
        _err(err),
      ]);

  @override
  Widget build(BuildContext context) {
    final bi = MediaQuery.of(context).viewInsets.bottom;
    final lf = FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s'-]"));
    return Container(
      height: MediaQuery.of(context).size.height * 0.92 + bi,
      decoration: const BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(children: [
        AppSheetHeader(title: widget.patient != null ? 'Edit Patient' : 'Add New Patient'),
        Expanded(child: SingleChildScrollView(controller: _sc, keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: bi + 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (_se.isNotEmpty) AppErrorBanner(message: _se),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _tf('First Name', _fc, _eF, fn: _ff, nf: _lf, fmt: [lf])),
                const SizedBox(width: 12),
                Expanded(child: _tf('Last Name',  _lc, _eL, fn: _lf, nf: _af, fmt: [lf])),
              ]),
              const SizedBox(height: 14),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _lbl('Date of Birth'),
                  GestureDetector(onTap: _pickDob, child: Container(height: 48, padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _eD.isNotEmpty ? Colors.red : Colors.grey.shade300)),
                      child: Row(children: [
                        const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textMuted),
                        const SizedBox(width: 8),
                        Text(_dob != null ? '${_dob!.day.toString().padLeft(2,'0')}/${_dob!.month.toString().padLeft(2,'0')}/${_dob!.year}' : 'DD/MM/YYYY',
                            style: TextStyle(fontSize: 13, color: _dob != null ? AppColors.textPrimary : AppColors.textMuted)),
                      ]))),
                  _err(_eD),
                ])),
                const SizedBox(width: 12),
                Expanded(child: _tf('Age', _ac, _eA, kt: TextInputType.number, fmt: [FilteringTextInputFormatter.digitsOnly], ml: 3, fn: _af, nf: _wf)),
              ]),
              const SizedBox(height: 14),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _dd('Gender',     _genders, _g,  (v) => setState(() { _g=v!;  _eG=''; }),  _eG)),
                const SizedBox(width: 12),
                Expanded(child: _tf('Weight (kg)', _wc, _eW, kt: const TextInputType.numberWithOptions(decimal: true),
                    fmt: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))], fn: _wf, nf: _bf)),
              ]),
              const SizedBox(height: 14),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _tf('BP (mmHg)',   _bc, _eB, hint: '120/80', fn: _bf,  nf: _puf)),
                const SizedBox(width: 12),
                Expanded(child: _tf('Pulse Rate',  _pu, _eP, kt: TextInputType.number, fmt: [FilteringTextInputFormatter.digitsOnly], fn: _puf, nf: _ef)),
              ]),
              const SizedBox(height: 14),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _dd('Blood Group', _bloods, _bl, (v) => setState(() { _bl=v!; _eBl=''; }), _eBl)),
                const SizedBox(width: 12),
                Expanded(child: _dd('Reference',   _refs, _ref, (v) => setState(() { _ref=v!; }), '', req: false)),
              ]),
              const SizedBox(height: 14),
              _tf('Email', _ec, _eE, kt: TextInputType.emailAddress, req: false, fn: _ef, nf: _phf),
              const SizedBox(height: 14),
              _tf('Phone', _pc, _ePh, kt: TextInputType.phone, fmt: [FilteringTextInputFormatter.digitsOnly], ml: 10, fn: _phf, last: true),
            ]))),
        AppFormButtons(saving: _saving, onCancel: () => Navigator.pop(context), onSave: _save,
            saveLabel: widget.patient != null ? 'Update Patient' : 'Save Patient'),
      ]),
    );
  }
}