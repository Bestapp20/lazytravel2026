import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/lt_widgets.dart';
import '../../data/providers.dart';

part 'flight_booking.dart';

TextStyle _t(double size, {FontWeight w = FontWeight.w500, Color c = AppColors.textDark}) =>
    GoogleFonts.notoSansHebrew(fontSize: size, fontWeight: w, color: c);

final _money = NumberFormat.decimalPattern('he');
String _price(num? v, String cur) => v == null ? '-' : '${_money.format(v.round())} ${cur == 'ILS' ? '₪' : cur}';
final _d = DateFormat('d.M.yy');

/// Gradient header used across finder screens (same look as Explore).
class _Header extends StatelessWidget {
  const _Header({required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppColors.primaryDark, Color(0xFF163F4A)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 20, 20),
          child: Row(
            children: [
              IconButton(
                onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
                icon: const Icon(Icons.arrow_forward, color: Colors.white),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: _t(22, w: FontWeight.w800, c: Colors.white)),
                    if (subtitle != null)
                      Text(subtitle!, style: _t(13, c: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Form ─────────────────────────
class FinderFormScreen extends ConsumerStatefulWidget {
  const FinderFormScreen({super.key});
  @override
  ConsumerState<FinderFormScreen> createState() => _FinderFormScreenState();
}

class _FinderFormScreenState extends ConsumerState<FinderFormScreen> {
  final _dest = TextEditingController();
  final _origin = TextEditingController(text: 'TLV');
  final _budget = TextEditingController();
  bool _anywhere = false;
  DateTimeRange? _range;
  String _dateMode = '3m'; // 1m | 3m | any | exact
  String _bagMode = 'none'; // none | checked | carryon

  /// Effective date window: chips give rolling windows from tomorrow; 'exact' uses the picker.
  DateTimeRange? get _window {
    if (_dateMode == 'exact') return _range;
    final start = DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 1));
    final days = switch (_dateMode) { '1m' => 30, 'any' => 180, _ => 90 };
    return DateTimeRange(start: start, end: start.add(Duration(days: days)));
  }
  RangeValues _nights = const RangeValues(4, 7);
  int _adults = 2;
  int _children = 0;
  bool _busy = false;

  @override
  void dispose() {
    _dest.dispose();
    _origin.dispose();
    _budget.dispose();
    super.dispose();
  }

  Future<void> _pickDates() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _range,
      helpText: 'חלון תאריכים גמיש',
    );
    if (r != null) setState(() { _range = r; _dateMode = 'exact'; });
  }

  Future<void> _submit() async {
    final client = ref.read(supabaseProvider);
    final win = _window;
    if (client == null || win == null) return;
    // No destination typed = anywhere (a budget-only search must work).
    final anywhere = _anywhere || _dest.text.trim().isEmpty;
    setState(() => _busy = true);
    try {
      final f = DateFormat('yyyy-MM-dd');
      final res = await client.functions.invoke('trip-search-start', body: {
        'origin': _origin.text.trim().isEmpty ? 'TLV' : _origin.text.trim(),
        'destination': anywhere ? null : _dest.text.trim(),
        'date_from': f.format(win.start),
        'date_to': f.format(win.end),
        'bag_mode': _bagMode,
        // Exact dates: the chosen range IS the trip.
        'nights_min': _dateMode == 'exact' && _range != null ? _range!.duration.inDays : _nights.start.round(),
        'nights_max': _dateMode == 'exact' && _range != null ? _range!.duration.inDays : _nights.end.round(),
        'adults': _adults,
        'children': _children,
        'budget': num.tryParse(_budget.text.trim()),
        'currency': 'ILS',
      });
      final id = (res.data as Map)['id'] as String?;
      if (id == null) throw Exception((res.data as Map)['error'] ?? 'error');
      if (mounted) context.push('/finder/$id');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('שגיאה: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 18),
        child: Text(s, style: _t(14, w: FontWeight.w700)),
      );

  InputDecoration _dec(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.accent),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border, width: 1.5)),
      );

  Widget _stepper(String label, int v, ValueChanged<int> on, {int min = 0}) => Row(
        children: [
          Expanded(child: Text(label, style: _t(14))),
          LtIconCircle(icon: Icons.remove, size: 34, onTap: v > min ? () => on(v - 1) : null),
          SizedBox(width: 36, child: Center(child: Text('$v', style: _t(16, w: FontWeight.w800)))),
          LtIconCircle(icon: Icons.add, size: 34, onTap: () => on(v + 1)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: Column(
        children: [
          const _Header(title: 'מצא לי טיול', subtitle: 'הטיסה והמלון הזולים ביותר בתאריכים הגמישים שלך'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
              children: [
                _label('לאן?'),
                Row(children: [
                  LtChip(label: 'יעד מסוים', selected: !_anywhere, onTap: () => setState(() => _anywhere = false)),
                  const SizedBox(width: 8),
                  LtChip(label: '🌍 לכל מקום', selected: _anywhere, onTap: () => setState(() => _anywhere = true)),
                ]),
                if (!_anywhere) ...[
                  const SizedBox(height: 10),
                  TextField(controller: _dest, decoration: _dec('למשל: Koh Samui, Rome (ריק = לכל מקום)', Icons.place_outlined)),
                ],
                _label('יוצאים מ'),
                TextField(controller: _origin, decoration: _dec('קוד שדה/עיר, למשל TLV', Icons.flight_takeoff)),
                _label('חלון תאריכים'),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  LtChip(label: 'החודש הקרוב', selected: _dateMode == '1m', onTap: () => setState(() => _dateMode = '1m')),
                  LtChip(label: '3 החודשים הקרובים', selected: _dateMode == '3m', onTap: () => setState(() => _dateMode = '3m')),
                  LtChip(label: 'לא משנה לי', selected: _dateMode == 'any', onTap: () => setState(() => _dateMode = 'any')),
                  LtChip(label: '📅 תאריכים מדויקים', selected: _dateMode == 'exact', onTap: _pickDates),
                ]),
                if (_window != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('${_d.format(_window!.start)} – ${_d.format(_window!.end)}', style: _t(12, c: AppColors.textBody)),
                  ),
                _label('כבודה'),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  LtChip(label: 'לא חשוב', selected: _bagMode == 'none', onTap: () => setState(() => _bagMode = 'none')),
                  LtChip(label: '🧳 כולל מזוודה', selected: _bagMode == 'checked', onTap: () => setState(() => _bagMode = 'checked')),
                  LtChip(label: '🎒 תיק עלייה בלבד', selected: _bagMode == 'carryon', onTap: () => setState(() => _bagMode = 'carryon')),
                ]),
                if (_bagMode != 'none')
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('נבדוק מחיר חי כולל כבודה לתאריכים הזולים (לוקח עוד כמה שניות)', style: _t(12, c: AppColors.textBody)),
                  ),
                if (_dateMode == 'exact' && _range != null)
                  _label('אורך הטיול: ${_range!.duration.inDays} לילות (לפי התאריכים שבחרת)')
                else ...[
                _label('אורך הטיול (לא חובה): ${_nights.start.round()}–${_nights.end.round()} לילות'),
                RangeSlider(
                  values: _nights,
                  min: 2,
                  max: 21,
                  divisions: 19,
                  activeColor: AppColors.accent,
                  onChanged: (v) => setState(() => _nights = v),
                ),
                ],
                _label('נוסעים'),
                LtCard(
                  child: Column(children: [
                    _stepper('מבוגרים', _adults, (v) => setState(() => _adults = v), min: 1),
                    const SizedBox(height: 10),
                    _stepper('ילדים', _children, (v) => setState(() => _children = v)),
                  ]),
                ),
                _label('תקציב כולל (₪, לא חובה)'),
                TextField(controller: _budget, keyboardType: TextInputType.number, decoration: _dec('למשל 12000', Icons.savings_outlined)),
                const SizedBox(height: 28),
                LtPrimaryButton(
                  label: _busy ? 'מחפש...' : 'חפש לי טיול',
                  icon: Icons.search,
                  onPressed: _busy || _window == null ? null : _submit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Progress + results ─────────────────────────
class FinderResultsScreen extends ConsumerStatefulWidget {
  const FinderResultsScreen({super.key, required this.searchId});
  final String searchId;
  @override
  ConsumerState<FinderResultsScreen> createState() => _FinderResultsScreenState();
}

class _FinderResultsScreenState extends ConsumerState<FinderResultsScreen> {
  Map<String, dynamic>? _search;
  List<Map<String, dynamic>> _offers = [];
  StreamSubscription? _sub;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    final client = ref.read(supabaseProvider)!;
    _sub = client.from('trip_searches').stream(primaryKey: ['id']).eq('id', widget.searchId).listen((rows) {
      if (rows.isNotEmpty) _onSearch(rows.first);
    });
    // Fallback polling in case realtime is slow.
    _poll = Timer.periodic(const Duration(seconds: 3), (_) async {
      final r = await client.from('trip_searches').select().eq('id', widget.searchId).maybeSingle();
      if (r != null) _onSearch(r);
    });
  }

  Future<void> _onSearch(Map<String, dynamic> s) async {
    if (!mounted) return;
    setState(() => _search = s);
    if (s['status'] == 'done' || s['status'] == 'error') {
      _poll?.cancel();
      if (_offers.isEmpty && s['status'] == 'done') {
        final o = await ref.read(supabaseProvider)!.from('trip_offers').select().eq('search_id', widget.searchId).order('rank', ascending: true);
        if (mounted) setState(() => _offers = List<Map<String, dynamic>>.from(o));
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  String _stage(String? st) => switch (st) {
        'discovering' => 'מחפש תאריכים ויעדים זולים...',
        'verifying' => 'בודק מחירי מלונות בזמן אמת...',
        'done' => 'מוכן',
        'error' => 'שגיאה',
        _ => 'בתור...',
      };

  @override
  Widget build(BuildContext context) {
    final s = _search;
    final status = s?['status'] as String?;
    final finished = status == 'done' || status == 'error';
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: Column(
        children: [
          _Header(
            title: 'הצעות בשבילך',
            subtitle: s == null ? null : '${s['destination'] ?? 'לכל מקום'} · ${s['adults']} מבוגרים${(s['children'] ?? 0) > 0 ? ' + ${s['children']} ילדים' : ''}',
          ),
          if (!finished)
            Padding(
              padding: const EdgeInsets.all(24),
              child: LtCard(
                child: Column(children: [
                  Text(_stage(status), style: _t(15, w: FontWeight.w700)),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: ((s?['progress'] ?? 0) as num) / 100,
                      minHeight: 10,
                      backgroundColor: AppColors.sectionTint,
                      color: AppColors.accent,
                    ),
                  ),
                ]),
              ),
            ),
          if (status == 'error' || (status == 'done' && _offers.isEmpty && s?['error'] != null))
            Padding(
              padding: const EdgeInsets.all(24),
              child: LtCard(child: Text('${s?['error'] ?? 'שגיאה'}', style: _t(14, c: AppColors.danger))),
            ),
          if (_offers.isNotEmpty)
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                itemCount: _offers.length,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (_, i) => _OfferCard(
                  offer: _offers[i],
                  onTap: () => context.push('/finder/${widget.searchId}/offer/${_offers[i]['id']}'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.offer, required this.onTap});
  final Map<String, dynamic> offer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cur = offer['currency'] as String? ?? 'ILS';
    final photo = offer['hotel_photo'] as String?;
    return LtCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
              child: photo == null
                  ? Container(height: 150, color: AppColors.sectionTint)
                  : Image.network(photo, height: 150, width: double.infinity, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(height: 150, color: AppColors.sectionTint)),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.primaryDark, borderRadius: BorderRadius.circular(20)),
                child: Text('#${offer['rank']}', style: _t(12, w: FontWeight.w800, c: Colors.white)),
              ),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(offer['hotel_name'] ?? '', style: _t(16, w: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  if (offer['hotel_stars'] != null) Text('${'★' * (offer['hotel_stars'] as num).round()}', style: _t(13, c: AppColors.warning)),
                ]),
                const SizedBox(height: 4),
                Text('${offer['destination']} · ${_d.format(DateTime.parse(offer['checkin']))} – ${_d.format(DateTime.parse(offer['checkout']))} · ${offer['nights']} לילות',
                    style: _t(12, c: AppColors.textBody)),
                const SizedBox(height: 6),
                if (offer['ai_reason'] != null) Text(offer['ai_reason'], style: _t(12, c: AppColors.textBody)),
                const SizedBox(height: 10),
                Row(children: [
                  if (offer['flight_price'] != null) ...[
                    const Icon(Icons.flight, size: 16, color: AppColors.accent),
                    Text(' ${_price(offer['flight_price'], cur)}  ', style: _t(12)),
                  ],
                  const Icon(Icons.hotel, size: 16, color: AppColors.accent),
                  Text(' ${_price(offer['hotel_price'], cur)}', style: _t(12)),
                  const Spacer(),
                  Text(_price(offer['total'], cur), style: _t(18, w: FontWeight.w800, c: AppColors.primaryDark)),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Offer detail + booking ─────────────────────────
class FinderOfferScreen extends ConsumerStatefulWidget {
  const FinderOfferScreen({super.key, required this.offerId});
  final String offerId;
  @override
  ConsumerState<FinderOfferScreen> createState() => _FinderOfferScreenState();
}

class _FinderOfferScreenState extends ConsumerState<FinderOfferScreen> {
  Map<String, dynamic>? _offer;
  Map<String, dynamic>? _search;
  bool _creating = false;
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  bool _busy = false;
  String? _confirmation;

  @override
  void initState() {
    super.initState();
    final client = ref.read(supabaseProvider)!;
    _email.text = client.auth.currentUser?.email ?? '';
    client.from('trip_offers').select().eq('id', widget.offerId).single().then((o) async {
      if (mounted) setState(() => _offer = o);
      final s = await client.from('trip_searches').select('adults,children').eq('id', o['search_id']).maybeSingle();
      if (mounted) setState(() => _search = s);
    });
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _book() async {
    if (_first.text.trim().isEmpty || _last.text.trim().isEmpty || !_email.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('מלא שם פרטי, שם משפחה ומייל (באנגלית)')));
      return;
    }
    final client = ref.read(supabaseProvider)!;
    setState(() => _busy = true);
    try {
      final pre = await client.functions.invoke('hotel-prebook', body: {'offer_id': widget.offerId});
      final p = Map<String, dynamic>.from(pre.data as Map);
      if (p['error'] != null) throw Exception(p['error']);
      if (!mounted) return;
      final paid = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => PaymentWebViewScreen(secretKey: p['secret_key'], sandbox: p['sandbox'] == true),
      ));
      if (paid != true) return;
      final res = await client.functions.invoke('hotel-book', body: {
        'booking_id': p['booking_id'],
        'first_name': _first.text.trim(),
        'last_name': _last.text.trim(),
        'email': _email.text.trim(),
      });
      final r = Map<String, dynamic>.from(res.data as Map);
      if (r['error'] != null) throw Exception(r['error']);
      setState(() => _confirmation = '${r['status']} · ${r['booking_id']}${r['confirmation'] != null ? ' · ${r['confirmation']}' : ''}');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('שגיאה: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createTrip() async {
    if (_creating || _busy) return;
    final o = _offer!;
    final repo = ref.read(tripsRepositoryProvider);
    if (repo == null) return;
    setState(() => _creating = true);
    try {
      final id = await repo.generateRoute({
        'destination': {'city': o['destination'], 'lat': o['dest_lat'], 'lng': o['dest_lng']},
        'start_date': o['checkin'],
        'end_date': o['checkout'],
        'adults': (_search?['adults'] as num?)?.toInt() ?? 2,
        'kids': (_search?['children'] as num?)?.toInt() ?? 0,
        'budget_total': o['total'],
        'currency': o['currency'] ?? 'ILS',
        'hotel': {'name': o['hotel_name'], 'address': o['hotel_address']},
        if ((o['flight'] as Map?)?['origin'] != null) 'origin_city': (o['flight'] as Map)['origin'],
      });
      ref.invalidate(tripsProvider);
      if (mounted) context.go('/trips/$id');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('שגיאה: $e')));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Widget _field(TextEditingController c, String hint) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final o = _offer;
    if (o == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final cur = o['currency'] as String? ?? 'ILS';
    final flight = o['flight'] as Map?;
    final link = flight?['link'] as String?;
    final live = flight?['live'] as Map?;
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: _Header(title: o['hotel_name'] ?? '', subtitle: o['destination'])),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          sliver: SliverList.list(children: [
            if (o['hotel_photo'] != null)
              ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.network(o['hotel_photo'], height: 190, fit: BoxFit.cover)),
            const SizedBox(height: 14),
            if (live != null) ...[
              Row(children: [
                const Icon(Icons.flight_takeoff, color: AppColors.accent),
                const SizedBox(width: 8),
                Text('טיסה', style: _t(16, w: FontWeight.w800)),
                const Spacer(),
                Text(_price(o['flight_price'], cur), style: _t(18, w: FontWeight.w800, c: AppColors.primaryDark)),
              ]),
              const SizedBox(height: 10),
              _FlightTicket(
                live: live, cur: cur, pax: ((_search?['adults'] as num?) ?? 1).toInt() + ((_search?['children'] as num?) ?? 0).toInt(),
                footer: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if ((live['bag_note'] ?? '') != '') Text('🧳 ${live['bag_note']}', style: _t(13, w: FontWeight.w700, c: AppColors.primaryDark)),
                    Text('כרטיס ${_price(live['fare_total'], cur)}${(live['bag_total'] ?? 0) > 0 ? ' + כבודה ${_price(live['bag_total'], cur)}' : ''} · מחיר חי, יאומת שוב לפני התשלום', style: _t(11, c: AppColors.textBody)),
                    const SizedBox(height: 12),
                    LtPrimaryButton(
                      label: 'הזמן טיסה באפליקציה',
                      icon: Icons.flight_takeoff,
                      onPressed: () async {
                        final add = await Navigator.of(context).push<bool>(_fade(
                          FlightCheckoutScreen(offer: o, adults: (_search?['adults'] as num?)?.toInt() ?? 1, children: (_search?['children'] as num?)?.toInt() ?? 0),
                        ));
                        if (add == true) _createTrip();
                      },
                    ),
                    if (link != null)
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => FlightWebViewScreen(url: link))),
                        icon: const Icon(Icons.open_in_new, size: 16, color: AppColors.textBody),
                        label: Text('או השווה ב-Aviasales', style: _t(13, c: AppColors.textBody)),
                      ),
                  ]),
                ),
              ),
            ] else if (o['flight_price'] != null || flight?['origin'] != null)
              LtCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.flight, color: AppColors.accent),
                    const SizedBox(width: 8),
                    Text('טיסה', style: _t(16, w: FontWeight.w800)),
                    const Spacer(),
                    Text(_price(o['flight_price'], cur), style: _t(16, w: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 6),
                  if (flight?['depart'] != null)
                    Text('${flight!['origin']} → ${flight['destination']} · ${flight['depart']} / ${flight['ret']} · ${live?['airline'] ?? flight['airline'] ?? ''}', style: _t(13, c: AppColors.textBody)),
                  if (live != null) ...[
                    if ((live['bag_note'] ?? '') != '') Text('🧳 ${live['bag_note']}', style: _t(13, w: FontWeight.w700, c: AppColors.primaryDark)),
                    Text('${live['fare_family'] ?? ''} · כרטיס ${_price(live['fare_total'], cur)}${(live['bag_total'] ?? 0) > 0 ? ' + כבודה ${_price(live['bag_total'], cur)}' : ''}', style: _t(12, c: AppColors.textBody)),
                    Text('מחיר חי (LiteAPI), יאומת שוב בתשלום', style: _t(11, c: AppColors.textBody)),
                    const SizedBox(height: 10),
                    LtPrimaryButton(
                      label: 'הזמן טיסה באפליקציה',
                      icon: Icons.flight_takeoff,
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => FlightCheckoutScreen(offer: o, adults: (_search?['adults'] as num?)?.toInt() ?? 1, children: (_search?['children'] as num?)?.toInt() ?? 0),
                      )),
                    ),
                  ] else
                    Text(o['flight_price'] == null ? 'אין מחיר שמור לטיסה, בדוק באתר' : 'מחיר משוער ממטמון חיפושים, יאומת באתר ההזמנה', style: _t(11, c: AppColors.textBody)),
                  if (link != null) ...[
                    const SizedBox(height: 10),
                    LtSecondaryButton(
                      label: live != null ? 'השווה ב-Aviasales' : 'הזמן טיסה',
                      icon: Icons.open_in_new,
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => FlightWebViewScreen(url: link),
                      )),
                    ),
                  ],
                ]),
              ),
            const SizedBox(height: 14),
            LtCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.hotel, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Text('מלון', style: _t(16, w: FontWeight.w800)),
                  const Spacer(),
                  Text(_price(o['hotel_price'], cur), style: _t(16, w: FontWeight.w800)),
                ]),
                const SizedBox(height: 6),
                Text('${o['room_name'] ?? ''} · ${o['board_name'] ?? ''}', style: _t(13, c: AppColors.textBody)),
                Text('${_d.format(DateTime.parse(o['checkin']))} – ${_d.format(DateTime.parse(o['checkout']))} · ${o['nights']} לילות', style: _t(13, c: AppColors.textBody)),
                if (o['hotel_address'] != null) Text(o['hotel_address'], style: _t(12, c: AppColors.textBody)),
                if (o['hotel_rating'] != null) Text('דירוג אורחים ${o['hotel_rating']}', style: _t(12, c: AppColors.textBody)),
                Text(o['refundable'] == true ? 'ניתן לביטול' : 'ללא החזר', style: _t(12, c: o['refundable'] == true ? AppColors.success : AppColors.danger)),
              ]),
            ),
            const SizedBox(height: 14),
            LtCard(
              child: Row(children: [
                Text('סה"כ', style: _t(16, w: FontWeight.w700)),
                const Spacer(),
                Text(_price(o['total'], cur), style: _t(22, w: FontWeight.w800, c: AppColors.primaryDark)),
              ]),
            ),
            const SizedBox(height: 20),
            LtSecondaryButton(
              label: _creating ? 'יוצר טיול... (עד דקה)' : 'צור טיול מההצעה',
              icon: _creating ? Icons.hourglass_top : Icons.auto_awesome,
              onPressed: _creating || _busy ? null : _createTrip,
            ),
            if (_creating)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(color: AppColors.accent, backgroundColor: AppColors.sectionTint),
              ),
            const SizedBox(height: 16),
            if (_confirmation != null)
              LtCard(child: Text('✅ ההזמנה אושרה: $_confirmation', style: _t(14, w: FontWeight.w700, c: AppColors.success)))
            else ...[
              Text('פרטי האורח הראשי (באנגלית)', style: _t(14, w: FontWeight.w700)),
              const SizedBox(height: 10),
              _field(_first, 'First name'),
              _field(_last, 'Last name'),
              _field(_email, 'Email'),
              const SizedBox(height: 6),
              LtPrimaryButton(label: _busy ? 'מעבד...' : 'הזמן מלון', icon: Icons.lock_outline, onPressed: _busy ? null : _book),
              const SizedBox(height: 8),
              Text('התשלום מתבצע ישירות מול Nuitee (LiteAPI), שגובה את הכסף ומנפיק את ההזמנה.', style: _t(11, c: AppColors.textBody)),
            ],
          ]),
        ),
      ]),
    );
  }
}

/// Hosts the LiteAPI payment SDK. Pops `true` when the SDK redirects to the return URL.
class PaymentWebViewScreen extends StatefulWidget {
  const PaymentWebViewScreen({super.key, required this.secretKey, required this.sandbox, this.amount, this.route});
  final String secretKey;
  final bool sandbox;
  final String? amount;
  final String? route;
  static const returnUrl = 'https://lazytravel.app/booking-return';
  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _c;

  @override
  void initState() {
    super.initState();
    final html = '''<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
<script src="https://payment-wrapper.liteapi.travel/dist/liteAPIPayment.js?v=a1"></script></head>
<body style="font-family:sans-serif;margin:16px;background:#F0FAFA;color:#0D2B35">
${widget.sandbox ? '<p style="background:#fff3cd;padding:10px 12px;border-radius:12px;font-size:14px">🧪 Sandbox: card 4242 4242 4242 4242, any future date, any CVC</p>' : ''}
<style>#pay{background:#fff;border-radius:18px;padding:14px;box-shadow:0 4px 18px rgba(27,79,92,.08);border:1.5px solid #C8E8E8} button{background:linear-gradient(135deg,#3DD6C6,#2DBFAD,#1B4F5C)!important;color:#fff!important;border:0!important;border-radius:16px!important;padding:14px!important;width:100%;font-size:16px!important;font-weight:700;margin-top:12px}</style>
<div id="pay"></div>
<script>
new LiteAPIPayment({publicKey:'${widget.sandbox ? 'sandbox' : 'live'}',appearance:{theme:'flat'},
 options:{business:{name:'LAZYTRAVEL'}},targetElement:'#pay',
 secretKey:'${widget.secretKey}',returnUrl:'${PaymentWebViewScreen.returnUrl}'}).handlePayment();
</script></body></html>''';
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(onNavigationRequest: (req) {
        if (req.url.startsWith(PaymentWebViewScreen.returnUrl)) {
          Navigator.of(context).pop(true);
          return NavigationDecision.prevent;
        }
        return NavigationDecision.navigate;
      }))
      ..loadHtmlString(html, baseUrl: 'https://lazytravel.app/');
  }

  @override
  Widget build(BuildContext context) {
    if (widget.route == null) {
      return Scaffold(
        appBar: AppBar(title: Text('תשלום מאובטח', style: _t(17, w: FontWeight.w700))),
        body: WebViewWidget(controller: _c),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: Column(children: [
        _SkyHeader(title: 'תשלום מאובטח', subtitle: '${widget.route} · ${widget.amount ?? ''}', height: 170, child: const _Steps(1)),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(children: [
            const Icon(Icons.lock, size: 16, color: AppColors.success),
            const SizedBox(width: 6),
            Expanded(child: Text('פרטי הכרטיס מוצפנים ונשלחים ישירות לספק התשלום', style: _t(12, c: AppColors.textBody))),
            if (widget.amount != null) Text(widget.amount!, style: _t(16, w: FontWeight.w800, c: AppColors.primaryDark)),
          ]),
        ),
        Expanded(child: WebViewWidget(controller: _c)),
      ]),
    );
  }
}


/// Aviasales booking page inside the app. Uses a full WebView (JS + DOM storage, mobile Chrome UA)
/// instead of a Custom Tab, which rendered blank on first launch. Falls back to the external browser.
class FlightWebViewScreen extends StatefulWidget {
  const FlightWebViewScreen({super.key, required this.url});
  final String url;
  @override
  State<FlightWebViewScreen> createState() => _FlightWebViewScreenState();
}

class _FlightWebViewScreenState extends State<FlightWebViewScreen> {
  late final WebViewController _c;
  int _progress = 0;
  String? _error;

  static const _ua =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Mobile Safari/537.36';

  @override
  void initState() {
    super.initState();
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_ua)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => mounted ? setState(() => _progress = p) : null,
        onWebResourceError: (e) {
          if (e.isForMainFrame ?? true) setState(() => _error = e.description);
        },
        onNavigationRequest: (req) {
          final u = Uri.tryParse(req.url);
          if (u != null && u.scheme != 'http' && u.scheme != 'https') {
            launchUrl(u, mode: LaunchMode.externalApplication);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('הזמנת טיסה', style: _t(17, w: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: 'פתח בדפדפן',
            icon: const Icon(Icons.open_in_browser),
            onPressed: () => launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication),
          ),
        ],
        bottom: _progress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(value: _progress / 100, minHeight: 3, color: AppColors.accent),
              )
            : null,
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('הדף לא נטען: $_error', style: _t(14), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  LtPrimaryButton(
                    label: 'פתח בדפדפן',
                    onPressed: () => launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication),
                  ),
                ]),
              ),
            )
          : WebViewWidget(controller: _c),
    );
  }
}

