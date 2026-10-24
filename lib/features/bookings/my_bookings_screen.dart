import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/lt_widgets.dart';
import '../../data/providers.dart';

/// A hotel or flight booking row (hotel_bookings / flight_bookings), normalised for display.
class MyBooking {
  MyBooking(this.kind, this.row);
  final String kind; // 'hotel' | 'flight'
  final Map<String, dynamic> row;

  String get id => row['id'] as String;
  String get status => (row['status'] ?? '') as String;
  bool get sandbox => row['sandbox'] == true;
  Map<String, dynamic> get raw => Map<String, dynamic>.from((row['raw'] as Map?) ?? const {});
  DateTime get created => DateTime.tryParse('${row['created_at']}') ?? DateTime.fromMillisecondsSinceEpoch(0);
  String? get code => (row['confirmation_code'] ?? row['booking_id']) as String?;

  List<Map<String, dynamic>> get _segs {
    final j = raw['journey'];
    final s = j is Map ? j['segments'] : null;
    return s is List ? s.map((e) => Map<String, dynamic>.from(e as Map)).toList() : const [];
  }

  String get title {
    if (kind == 'hotel') return (row['hotel_name'] ?? raw['hotel']?['name'] ?? 'מלון') as String;
    final out = _segs.where((s) => s['direction'] != 'INBOUND').toList();
    if (out.isEmpty) return 'טיסה';
    return '${out.first['originCode']} ⇄ ${out.last['destinationCode']}';
  }

  String get dates {
    String d(dynamic v) {
      final t = DateTime.tryParse('$v');
      return t == null ? '' : '${t.day}.${t.month}.${t.year}';
    }

    if (kind == 'hotel') return '${d(row['checkin'])} – ${d(row['checkout'])}';
    final out = _segs.where((s) => s['direction'] != 'INBOUND').toList();
    final back = _segs.where((s) => s['direction'] == 'INBOUND').toList();
    if (out.isEmpty) return '';
    return back.isEmpty
        ? d(out.first['departureTime'])
        : '${d(out.first['departureTime'])} – ${d(back.first['departureTime'])}';
  }

  String get price {
    final p = row['price'];
    if (p == null) return '';
    final n = (p as num);
    return '${n == n.roundToDouble() ? n.round() : n.toStringAsFixed(2)} ${row['currency'] ?? ''}'.trim();
  }

  bool get cancellable => row['booking_id'] != null && (status == 'confirmed' || status == 'pending_confirmation');
  bool get visible => status != 'prebooked';
}

final myBookingsProvider = FutureProvider.autoDispose<List<MyBooking>>((ref) async {
  ref.watch(authStateProvider);
  final c = ref.watch(supabaseProvider);
  if (c == null) return [];
  final hotels = await c.from('hotel_bookings').select().order('created_at', ascending: false);
  final flights = await c.from('flight_bookings').select().order('created_at', ascending: false);
  final all = <MyBooking>[
    for (final r in hotels) MyBooking('hotel', Map<String, dynamic>.from(r)),
    for (final r in flights) MyBooking('flight', Map<String, dynamic>.from(r)),
  ].where((b) => b.visible).toList()
    ..sort((a, b) => b.created.compareTo(a.created));
  return all;
});

({String label, Color color}) _statusStyle(String s) {
  switch (s) {
    case 'confirmed':
      return (label: 'אושרה', color: AppColors.success);
    case 'pending_confirmation':
      return (label: 'ממתינה לאישור', color: AppColors.warning);
    case 'cancelled':
      return (label: 'בוטלה', color: AppColors.danger);
    case 'failed':
      return (label: 'נכשלה', color: AppColors.danger);
    default:
      return (label: s, color: AppColors.textBody);
  }
}

class MyBookingsScreen extends ConsumerStatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  ConsumerState<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends ConsumerState<MyBookingsScreen> {
  bool _refreshing = false;

  Future<void> _refreshAll(List<MyBooking> items) async {
    final c = ref.read(supabaseProvider);
    if (c == null) return;
    setState(() => _refreshing = true);
    try {
      await c.auth.refreshSession();
      for (final b in items.where((b) => b.cancellable).take(8)) {
        await c.functions.invoke('booking-manage', body: {'action': 'refresh', 'kind': b.kind, 'id': b.id});
      }
    } catch (_) {
      // best effort; the list below still shows the last known state
    }
    ref.invalidate(myBookingsProvider);
    if (mounted) setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(myBookingsProvider);
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: const Text('ההזמנות שלי'),
        leading: LtIconCircle(icon: Icons.arrow_forward, onTap: () => context.pop()),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('לא הצלחנו לטעון הזמנות', style: GoogleFonts.notoSansHebrew())),
        data: (items) => RefreshIndicator(
          onRefresh: () => _refreshAll(items),
          child: items.isEmpty
              ? ListView(children: [
                  const SizedBox(height: 120),
                  const Icon(Icons.confirmation_number_outlined, size: 56, color: AppColors.textBody),
                  const SizedBox(height: 12),
                  Text('עדיין אין הזמנות',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.notoSansHebrew(fontSize: 18, fontWeight: FontWeight.w800)),
                  Text('טיסות ומלונות שתזמינו יופיעו כאן',
                      textAlign: TextAlign.center, style: GoogleFonts.notoSansHebrew(color: AppColors.textBody)),
                ])
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length + (_refreshing ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    if (i >= items.length) return const LinearProgressIndicator();
                    return _BookingCard(b: items[i], onTap: () => _openVoucher(items[i]));
                  },
                ),
        ),
      ),
    );
  }

  void _openVoucher(MyBooking b) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VoucherSheet(booking: b, onChanged: () => ref.invalidate(myBookingsProvider)),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.b, required this.onTap});
  final MyBooking b;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final st = _statusStyle(b.status);
    return RepaintBoundary(
      child: LtCard(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: AppColors.sectionTint, borderRadius: BorderRadius.circular(14)),
              child: Icon(b.kind == 'hotel' ? Icons.hotel_rounded : Icons.flight_takeoff_rounded, color: AppColors.primaryDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textDark)),
                  Text(b.dates, style: GoogleFonts.notoSansHebrew(fontSize: 12.5, color: AppColors.textBody)),
                  const SizedBox(height: 6),
                  Row(children: [
                    _Pill(st.label, st.color),
                    if (b.sandbox) ...[const SizedBox(width: 6), const _Pill('בדיקה', AppColors.textBody)],
                  ]),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(b.price, style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
                const Icon(Icons.chevron_left, color: AppColors.textBody),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.color);
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: .14), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: GoogleFonts.notoSansHebrew(fontSize: 11.5, fontWeight: FontWeight.w800, color: color)),
      );
}

class _VoucherSheet extends ConsumerStatefulWidget {
  const _VoucherSheet({required this.booking, required this.onChanged});
  final MyBooking booking;
  final VoidCallback onChanged;
  @override
  ConsumerState<_VoucherSheet> createState() => _VoucherSheetState();
}

class _VoucherSheetState extends ConsumerState<_VoucherSheet> {
  late MyBooking b = widget.booking;
  bool _busy = false;
  String? _msg;

  Future<Map<String, dynamic>?> _call(Map<String, dynamic> body) async {
    final c = ref.read(supabaseProvider);
    if (c == null) return null;
    await c.auth.refreshSession();
    final res = await c.functions.invoke('booking-manage', body: {...body, 'kind': b.kind, 'id': b.id});
    return res.data is Map ? Map<String, dynamic>.from(res.data as Map) : null;
  }

  Future<void> _run(Future<void> Function() fn) async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      await fn();
    } on FunctionException catch (e) {
      _msg = 'הפעולה נכשלה (${e.status})';
    } catch (_) {
      _msg = 'הפעולה נכשלה, נסו שוב';
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _reload() async {
    final c = ref.read(supabaseProvider)!;
    final t = b.kind == 'hotel' ? 'hotel_bookings' : 'flight_bookings';
    final r = await c.from(t).select().eq('id', b.id).single();
    b = MyBooking(b.kind, Map<String, dynamic>.from(r));
    widget.onChanged();
  }

  Future<void> _refresh() => _run(() async {
        await _call({'action': 'refresh'});
        await _reload();
        _msg = 'הסטטוס עודכן';
      });

  Future<void> _email() => _run(() async {
        final r = await _call({'action': 'resend_email'});
        final s = r?['status'];
        _msg = switch (s) {
          'sent' => 'נשלח אישור למייל',
          'skipped_no_resend_key' => 'שליחת מיילים עדיין לא הופעלה',
          'blocked_sandbox_recipient' => 'הזמנת בדיקה – אפשר לשלוח רק לכתובת הבדיקה',
          _ => 'לא נשלח ($s)',
        };
        await _reload();
      });

  Future<void> _cancel() async {
    String extra = '';
    if (b.kind == 'flight') {
      try {
        final q = await _call({'action': 'quote'});
        final qq = q?['quote'];
        if (qq is Map && qq['cancellation_fee'] != null) {
          extra = '\nדמי ביטול: ${qq['cancellation_fee']} ${qq['currency'] ?? ''}\nהחזר צפוי: ${qq['refund_amount'] ?? 0} ${qq['currency'] ?? ''}';
        }
      } catch (_) {}
    }
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('לבטל את ההזמנה?'),
        content: Text('הפעולה אינה הפיכה, ועלולים לחול דמי ביטול לפי תנאי ההזמנה.$extra'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('השאר')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('בטל הזמנה', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      final r = await _call({'action': 'cancel'});
      await _reload();
      _msg = r?['error'] != null ? 'הביטול נכשל' : (b.status == 'cancelled' ? 'ההזמנה בוטלה' : 'בקשת הביטול נשלחה, ממתינים לאישור');
    });
  }

  @override
  Widget build(BuildContext context) {
    final st = _statusStyle(b.status);
    final raw = b.raw;
    final lines = <(String, String)>[
      if (b.kind == 'hotel') ('מלון', b.title) else ('מסלול', b.title),
      ('תאריכים', b.dates),
      if (b.kind == 'hotel' && raw['adults'] != null) ('אורחים', '${raw['adults']} מבוגרים'),
      if (b.kind == 'hotel' && raw['holder'] is Map)
        ('על שם', '${raw['holder']['firstName'] ?? ''} ${raw['holder']['lastName'] ?? ''}'.trim()),
      if (b.kind == 'flight' && raw['contact'] is Map)
        ('על שם', '${raw['contact']['firstName'] ?? ''} ${raw['contact']['lastName'] ?? ''}'.trim()),
      ('סכום', b.price),
      ('קוד אישור', b.code ?? '—'),
    ];
    return DraggableScrollableSheet(
      initialChildSize: .78,
      maxChildSize: .95,
      minChildSize: .4,
      expand: false,
      builder: (_, scroll) => Container(
        decoration: const BoxDecoration(
            color: AppColors.bgLight, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(3)))),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: Text('שובר / אישור הזמנה', style: GoogleFonts.notoSansHebrew(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textDark))),
              _Pill(st.label, st.color),
            ]),
            if (b.sandbox)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('הזמנת בדיקה (Sandbox) – לא בוצע חיוב אמיתי',
                    style: GoogleFonts.notoSansHebrew(fontSize: 12.5, color: AppColors.warning, fontWeight: FontWeight.w700)),
              ),
            const SizedBox(height: 14),
            LtCard(
              child: Column(
                children: [
                  for (final l in lines.where((l) => l.$2.trim().isNotEmpty))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(children: [
                        Text(l.$1, style: GoogleFonts.notoSansHebrew(color: AppColors.textBody)),
                        const Spacer(),
                        Flexible(
                          child: SelectableText(l.$2,
                              textAlign: TextAlign.end,
                              style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w800, color: AppColors.textDark)),
                        ),
                      ]),
                    ),
                ],
              ),
            ),
            if (b.row['sync_error'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('סנכרון אחרון נכשל, ננסה שוב אוטומטית',
                    style: GoogleFonts.notoSansHebrew(fontSize: 12, color: AppColors.textBody)),
              ),
            const SizedBox(height: 16),
            LtPrimaryButton(label: _busy ? 'רגע...' : 'רענן סטטוס', icon: Icons.refresh, onPressed: _busy ? null : _refresh),
            const SizedBox(height: 10),
            LtSecondaryButton(label: 'שלח לי אישור במייל', icon: Icons.mail_outline, onPressed: _busy || b.status != 'confirmed' ? null : _email),
            if (b.cancellable) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _busy ? null : _cancel,
                icon: const Icon(Icons.cancel_outlined, color: AppColors.danger),
                label: Text('בטל הזמנה', style: GoogleFonts.notoSansHebrew(color: AppColors.danger, fontWeight: FontWeight.w800)),
              ),
            ],
            if (_msg != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_msg!, textAlign: TextAlign.center, style: GoogleFonts.notoSansHebrew(color: AppColors.primaryDark, fontWeight: FontWeight.w700)),
              ),
          ],
        ),
      ),
    );
  }
}
