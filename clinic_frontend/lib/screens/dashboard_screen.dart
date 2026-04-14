import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/app_widgets.dart';

const _apiBase = 'http://10.11.1.128:5020';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _kpis;
  List _todaysApts     = [];
  List _recentPayments = [];
  List _aptsPerDoctor  = [];
  List _paymentModes   = [];
  bool _loading        = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchAll());
  }

  Future<void> _fetchAll() async {
    final clinicId = context.read<AppProvider>().user?['clinic_id'];
    if (clinicId == null) return;
    setState(() => _loading = true);
    try {
      final res = await http.get(Uri.parse('$_apiBase/dashboard_kpis?clinic_id=$clinicId'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _kpis           = data;
          _todaysApts     = data['todays_apts']     ?? [];
          _recentPayments = data['recent_payments'] ?? [];
          _aptsPerDoctor  = data['apts_per_doctor'] ?? [];
          _paymentModes   = data['payment_modes']   ?? [];
        });
      }
    } catch (e) {
      debugPrint('Dashboard fetch error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmtTime(dynamic t) {
    if (t == null) return '—';
    return t.toString().substring(0, t.toString().length >= 5 ? 5 : t.toString().length);
  }

  String _fmtDate(dynamic dt) {
    if (dt == null) return '—';
    try {
      final d = DateTime.parse(dt.toString());
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) { return dt.toString(); }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppProvider>().user;
    final today = DateTime.now();
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final dateStr = '${today.day} ${months[today.month-1]} ${today.year}';

    return Scaffold(
  backgroundColor: AppColors.background,
  body: SafeArea(
    child: RefreshIndicator(
      onRefresh: _fetchAll,
      color: AppColors.teal,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Header ──────────────────────────────────────────
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Good ${_greeting()}!',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted, letterSpacing: 0.5)),
              const SizedBox(height: 2),
              Text(user?['full_name'] ?? 'Doctor',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
                      color: AppColors.onSurface, letterSpacing: -0.3)),
              Text(dateStr, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ])),
            GestureDetector(
              onTap: () => context.read<AppProvider>().setPage('appointments'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [AppColors.teal, AppColors.teal2],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add, size: 15, color: Colors.white),
                  SizedBox(width: 6),
                  Text('New Appointment',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 24),

          // ── KPI Grid ─────────────────────────────────────────
          _KpiGrid(kpis: _kpis, loading: _loading),
          const SizedBox(height: 20),

          // ── Charts row ───────────────────────────────────────
          LayoutBuilder(builder: (ctx, c) {
            final isWide = c.maxWidth > 700;
            return isWide
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: _AptsPerDoctorCard(data: _aptsPerDoctor, loading: _loading)),
                    const SizedBox(width: 16),
                    Expanded(child: _PaymentModesCard(data: _paymentModes, loading: _loading)),
                  ])
                : Column(children: [
                    _AptsPerDoctorCard(data: _aptsPerDoctor, loading: _loading),
                    const SizedBox(height: 16),
                    _PaymentModesCard(data: _paymentModes, loading: _loading),
                  ]);
          }),
          const SizedBox(height: 20),

          // ── Bottom lists ─────────────────────────────────────
          LayoutBuilder(builder: (ctx, c) {
            final isWide = c.maxWidth > 700;
            return isWide
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: _TodaysAptsList(apts: _todaysApts, loading: _loading, fmtTime: _fmtTime)),
                    const SizedBox(width: 16),
                    Expanded(child: _RecentPaymentsList(payments: _recentPayments, loading: _loading, fmtDate: _fmtDate)),
                  ])
                : Column(children: [
                    _TodaysAptsList(apts: _todaysApts, loading: _loading, fmtTime: _fmtTime),
                    const SizedBox(height: 16),
                    _RecentPaymentsList(payments: _recentPayments, loading: _loading, fmtDate: _fmtDate),
                  ]);
          }),
        ]),
      ),
    ),
  ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Morning';
    if (h < 17) return 'Afternoon';
    return 'Evening';
  }
}

// ── KPI Grid ─────────────────────────────────────────────────────
class _KpiGrid extends StatelessWidget {
  final Map? kpis;
  final bool loading;
  const _KpiGrid({required this.kpis, required this.loading});

  @override
  Widget build(BuildContext context) {
    final cards = [
      {'title': 'Total Patients',   'value': loading ? '...' : '${kpis?['total_patients'] ?? '—'}',      'icon': Icons.person_outline,          'color': AppColors.statusBlue,   'bg': AppColors.statusBlueBg},
      {'title': "Today's Apts",     'value': loading ? '...' : '${kpis?['todays_appointments'] ?? '—'}',  'icon': Icons.calendar_month_outlined,  'color': AppColors.statusOrange, 'bg': AppColors.statusOrangeBg},
      {'title': "Today's Revenue",  'value': loading ? '...' : fmtCurrency(kpis?['todays_revenue']),      'icon': Icons.attach_money_outlined,    'color': AppColors.statusGreen,  'bg': AppColors.statusGreenBg},
      {'title': 'Monthly Revenue',  'value': loading ? '...' : fmtCurrency(kpis?['monthly_revenue']),     'icon': Icons.trending_up_outlined,     'color': AppColors.teal,          'bg': AppColors.statusGreenBg},
      {'title': 'Monthly Expenses', 'value': loading ? '...' : fmtCurrency(kpis?['monthly_expenses']),    'icon': Icons.money_off_outlined,       'color': AppColors.statusRed,    'bg': AppColors.statusRedBg},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.35),
      itemCount: cards.length,
      itemBuilder: (_, i) => _KpiCard(data: cards[i]),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final Map data;
  const _KpiCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF001F26).withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 4))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: data['bg'] as Color,
              borderRadius: BorderRadius.circular(12)),
          child: Icon(data['icon'] as IconData,
              size: 18, color: data['color'] as Color),
        ),
        const Spacer(),
        Text(data['value'] as String,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: data['color'] as Color)),
        Text(data['title'] as String,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
      ]),
    );
  }
}

// ── Appointments per Doctor ───────────────────────────────────────
class _AptsPerDoctorCard extends StatelessWidget {
  final List data;
  final bool loading;
  const _AptsPerDoctorCard({required this.data, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: const Color(0xFF001F26).withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Appointments per Doctor',
            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.onSurface, fontSize: 14)),
        const Text('This month',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
        const SizedBox(height: 16),
        if (loading)
          const Center(child: CircularProgressIndicator(color: AppColors.teal))
        else if (data.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(24),
              child: Text('No data', style: TextStyle(color: AppColors.textMuted))))
        else
          ...data.map((d) {
            final name  = (d['name'] ?? d['doctor_name'] ?? '').toString();
            final count = (d['value'] ?? d['count'] ?? 0) as num;
            final max   = data.map((x) => (x['value'] ?? x['count'] ?? 0) as num).reduce((a, b) => a > b ? a : b);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Expanded(child: Text(name,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis)),
                  Text('$count',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                ]),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: max == 0 ? 0 : count / max,
                    backgroundColor: AppColors.surfaceLow,
                    valueColor: const AlwaysStoppedAnimation(AppColors.teal),
                    minHeight: 6,
                  ),
                ),
              ]),
            );
          }),
      ]),
    );
  }
}

// ── Payment modes ────────────────────────────────────────────────
class _PaymentModesCard extends StatelessWidget {
  final List data;
  final bool loading;
  const _PaymentModesCard({required this.data, required this.loading});

  @override
  Widget build(BuildContext context) {
    final colors = [AppColors.teal, AppColors.teal2, AppColors.statusBlue, AppColors.statusOrange, AppColors.statusRed];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: const Color(0xFF001F26).withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Payment Modes',
            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.onSurface, fontSize: 14)),
        const Text('Current month',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
        const SizedBox(height: 16),
        if (loading)
          const Center(child: CircularProgressIndicator(color: AppColors.teal))
        else if (data.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(24),
              child: Text('No data', style: TextStyle(color: AppColors.textMuted))))
        else
          ...data.asMap().entries.map((e) {
            final color = colors[e.key % colors.length];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                Container(width: 10, height: 10,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Expanded(child: Text('${e.value['name'] ?? ''}',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
                Text('${e.value['value'] ?? 0}%',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
              ]),
            );
          }),
      ]),
    );
  }
}

// ── Today's appointments ─────────────────────────────────────────
class _TodaysAptsList extends StatelessWidget {
  final List apts;
  final bool loading;
  final String Function(dynamic) fmtTime;
  const _TodaysAptsList({required this.apts, required this.loading, required this.fmtTime});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: const Color(0xFF001F26).withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 8, height: 8,
              decoration: const BoxDecoration(color: AppColors.statusBlue, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          const Text("Today's Appointments",
              style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.onSurface, fontSize: 14)),
        ]),
        const SizedBox(height: 16),
        if (loading)
          const Center(child: CircularProgressIndicator(color: AppColors.teal))
        else if (apts.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(24),
              child: Text('No appointments today', style: TextStyle(color: AppColors.textMuted))))
        else
          ...apts.asMap().entries.map((e) {
            final a = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                      color: AppColors.statusBlueBg,
                      borderRadius: BorderRadius.circular(10)),
                  child: Center(child: Text('${e.key + 1}',
                      style: const TextStyle(color: AppColors.statusBlue, fontSize: 13, fontWeight: FontWeight.w700))),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${a['patient_name'] ?? ''}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
                  Text('${fmtTime(a['slot_time'])} · ${a['doctor_name'] ?? ''}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ])),
                _DashStatusBadge(status: '${a['status'] ?? ''}'),
              ]),
            );
          }),
      ]),
    );
  }
}

class _DashStatusBadge extends StatelessWidget {
  final String status;
  const _DashStatusBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    final lower = status.toLowerCase();
    Color bg, fg;
    if (lower == 'completed')  { bg = AppColors.statusGreenBg;  fg = AppColors.statusGreen; }
    else if (lower == 'cancelled') { bg = AppColors.statusRedBg; fg = AppColors.statusRed; }
    else { bg = AppColors.statusBlueBg; fg = AppColors.statusBlue; }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9999)),
      child: Text(status, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Recent payments ──────────────────────────────────────────────
class _RecentPaymentsList extends StatelessWidget {
  final List payments;
  final bool loading;
  final String Function(dynamic) fmtDate;
  const _RecentPaymentsList({required this.payments, required this.loading, required this.fmtDate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: const Color(0xFF001F26).withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Recent Payments',
            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.onSurface, fontSize: 14)),
        const SizedBox(height: 16),
        if (loading)
          const Center(child: CircularProgressIndicator(color: AppColors.teal))
        else if (payments.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(24),
              child: Text('No payments found', style: TextStyle(color: AppColors.textMuted))))
        else
          ...payments.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    color: AppColors.statusGreenBg,
                    borderRadius: BorderRadius.circular(10)),
                child: const Center(child: Icon(Icons.payment_outlined,
                    color: AppColors.statusGreen, size: 16)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${p['patient_name'] ?? ''}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
                Text('${p['payment_mode'] ?? ''} · ${fmtDate(p['payment_date'])}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ])),
              Text('₹${p['amount_paid'] ?? 0}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.teal)),
            ]),
          )),
      ]),
    );
  }
}
