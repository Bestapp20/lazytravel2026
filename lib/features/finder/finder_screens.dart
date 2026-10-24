import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show PointMode;

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
part 'finder_visuals.dart';

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
  String _bagMode = 'none'; // none | carryon | trolley | checked
  final Set<String> _comps = {'flight', 'hotel', 'itinerary'};
  double _budgetVal = 0; // 0 = no limit
  bool get _hasF => _comps.contains('flight');
  bool get _hasH => _comps.contains('hotel');
  bool get _onlyItinerary => _comps.length == 1 && _comps.contains('itinerary');

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
    if (_comps.isEmpty) return;
    if (anywhere && !_hasF) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('בלי טיסה צריך לבחור יעד')));
      return;
    }
    if (_onlyItinerary) return _itineraryOnly(win);
    setState(() => _busy = true);
    try {
      final f = DateFormat('yyyy-MM-dd');
      await _freshSession(client);
      final res = await client.functions.invoke('trip-search-start', body: {
        'origin': _origin.text.trim().isEmpty ? 'TLV' : _origin.text.trim(),
        'destination': anywhere ? null : _dest.text.trim(),
        'date_from': f.format(win.start),
        'date_to': f.format(win.end),
        'bag_mode': _hasF ? _bagMode : 'none',
        'components': _comps.toList(),
        // Exact dates: the chosen range IS the trip.
        'nights_min': _dateMode == 'exact' && _range != null ? _range!.duration.inDays : _nights.start.round(),
        'nights_max': _dateMode == 'exact' && _range != null ? _range!.duration.inDays : _nights.end.round(),
        'adults': _adults,
        'children': _children,
        'budget': _budgetVal > 0 ? _budgetVal.round() : null,
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

  /// Itinerary only: no price search, straight to an AI route for the destination + dates.
  Future<void> _itineraryOnly(DateTimeRange win) async {
    final repo = ref.read(tripsRepositoryProvider);
    if (repo == null) return;
    final f = DateFormat('yyyy-MM-dd');
    final start = win.start;
    final end = _dateMode == 'exact' && _range != null ? _range!.end : start.add(Duration(days: _nights.start.round()));
    setState(() => _busy = true);
    final nav = Navigator.of(context);
    nav.push(PageRouteBuilder(opaque: false, pageBuilder: (_, _, _) => const _RouteBuilding()));
    try {
      await _freshSession(ref.read(supabaseProvider));
      final id = await repo.generateRoute({
        'destination': {'city': _dest.text.trim()},
        'start_date': f.format(start),
        'end_date': f.format(end),
        'adults': _adults,
        'kids': _children,
        if (_budgetVal > 0) 'budget_total': _budgetVal.round(),
        'currency': 'ILS',
      });
      ref.invalidate(tripsProvider);
      if (mounted) {
        nav.pop();
        context.go('/trips/$id');
      }
    } catch (e) {
      if (mounted) {
        nav.pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('שגיאה: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _comp(String key, String emoji, String label) {
    final on = _comps.contains(key);
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => on ? _comps.remove(key) : _comps.add(key)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: on ? AppColors.accent.withValues(alpha: 0.12) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: on ? AppColors.accent : AppColors.border, width: on ? 2 : 1.5),
          ),
          child: Column(children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 4),
            Text(label, style: _t(13, w: FontWeight.w700, c: on ? AppColors.primaryDark : AppColors.textBody)),
          ]),
        ),
      ),
    );
  }

  Widget _budgetCard() {
    final none = _budgetVal <= 0;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.accentLight, AppColors.accent, AppColors.primaryDark], begin: Alignment.topRight, end: Alignment.bottomLeft),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.3), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.savings_outlined, color: Colors.white),
          const SizedBox(width: 8),
          Text('תקציב כולל (₪)', style: _t(15, w: FontWeight.w700, c: Colors.white)),
          const Spacer(),
          if (!none)
            GestureDetector(onTap: () => setState(() => _budgetVal = 0), child: Text('ללא הגבלה', style: _t(12, c: Colors.white70))),
        ]),
        const SizedBox(height: 6),
        Text(none ? 'ללא הגבלה' : '₪${_money.format(_budgetVal.round())}', style: _t(34, w: FontWeight.w900, c: Colors.white)),
        Text(none ? 'גרור כדי לקבוע תקרה לכל הטיול' : 'לכל ${_adults + _children} הנוסעים, ${[if (_hasF) 'טיסה', if (_hasH) 'מלון'].join(' + ')}',
            style: _t(12, c: Colors.white.withValues(alpha: 0.85))),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(activeTrackColor: Colors.white, inactiveTrackColor: Colors.white30, thumbColor: Colors.white, overlayColor: Colors.white24, trackHeight: 5),
          child: Slider(value: _budgetVal, min: 0, max: 40000, divisions: 80, onChanged: (v) => setState(() => _budgetVal = v)),
        ),
      ]),
    );
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
          const _Header(title: 'תכנן טיול', subtitle: 'טיסה, מלון ומסלול, בתאריכים הגמישים שלך'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
              children: [
                _label('מה להכין לך?'),
                Row(children: [
                  _comp('flight', '✈️', 'טיסה'),
                  const SizedBox(width: 8),
                  _comp('hotel', '🏨', 'מלון'),
                  const SizedBox(width: 8),
                  _comp('itinerary', '🗺️', 'מסלול'),
                ]),
                const SizedBox(height: 8),
                LtChip(label: '✨ טיול שלם', selected: _comps.length == 3, onTap: () => setState(() => _comps.addAll(['flight', 'hotel', 'itinerary']))),
                if (!_onlyItinerary) _budgetCard(),
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
                if (_hasF) ...[
                _label('יוצאים מ'),
                TextField(controller: _origin, decoration: _dec('קוד שדה/עיר, למשל TLV', Icons.flight_takeoff)),
                ],
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
                if (_hasF) ...[
                _label('כבודה'),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  LtChip(label: 'לא חשוב', selected: _bagMode == 'none', onTap: () => setState(() => _bagMode = 'none')),
                  LtChip(label: '🎒 תיק עלייה בלבד', selected: _bagMode == 'carryon', onTap: () => setState(() => _bagMode = 'carryon')),
                  LtChip(label: '🧳 טרולי', selected: _bagMode == 'trolley', onTap: () => setState(() => _bagMode = 'trolley')),
                  LtChip(label: '🛄 כולל מזוודה', selected: _bagMode == 'checked', onTap: () => setState(() => _bagMode = 'checked')),
                ]),
                if (_bagMode == 'trolley')
                  Padding(padding: const EdgeInsets.only(top: 6), child: Text('טרולי = תיק עלייה למטוס 8–10 ק״ג, בנוסף לפריט האישי', style: _t(12, c: AppColors.textBody))),
                ],
                if (_hasF && _bagMode != 'none')
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
                const SizedBox(height: 28),
                LtPrimaryButton(
                  label: _busy ? 'מחפש...' : _onlyItinerary ? 'בנה לי מסלול' : _comps.length == 3 ? 'מצא לי טיול שלם' : 'חפש לי ${[if (_hasF) 'טיסה', if (_hasH) 'מלון'].join(' + ')}',
                  icon: _onlyItinerary ? Icons.auto_awesome : Icons.search,
                  onPressed: _busy || _window == null || _comps.isEmpty ? null : _submit,
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
    _finderClient = client;
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

  String _stage(String? st, [int p = 0]) => switch (st) {
        'discovering' when p >= 15 => 'בודק מחירי טיסות חיים...',
        'discovering' => _search?['destination'] == null ? 'סורק יעדים מסביב לעולם...' : 'מחפש תאריכים זולים...',
        'verifying' when p >= 70 => 'מדרג את ההצעות הזולות ביותר...',
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
            Expanded(
              child: SingleChildScrollView(
                child: GlobeLoader(stage: _stage(status, ((s?['progress'] ?? 0) as num).toInt()), progress: ((s?['progress'] ?? 0) as num) / 100),
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
      final s = await client.from('trip_searches').select('adults,children,components').eq('id', o['search_id']).maybeSingle();
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
      await _freshSession(client);
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

  bool get _withItinerary => ((_search?['components'] as List?) ?? const []).contains('itinerary');

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
        if (o['hotel_name'] != null) 'hotel': {'name': o['hotel_name'], 'address': o['hotel_address']},
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
        SliverToBoxAdapter(child: _Header(title: o['hotel_name'] ?? o['destination'] ?? '', subtitle: o['hotel_name'] == null ? null : o['destination'])),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          sliver: SliverList.list(children: [
            if (o['hotel_photo'] != null)
              ClipRRect(borderRadius: BorderRadius.circular(18), child: CachedNetworkImage(imageUrl: o['hotel_photo'], height: 190, fit: BoxFit.cover, memCacheWidth: 1080)),
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
                        label: Text('השוואה באתר חיצוני (Aviasales)', style: _t(13, c: AppColors.textBody)),
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
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.sectionTint, borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      const Icon(Icons.info_outline, size: 18, color: AppColors.textBody),
                      const SizedBox(width: 8),
                      Expanded(child: Text('הטיסה הזו לא זמינה להזמנה באפליקציה כרגע (אין מחיר חי). המחיר משוער.', style: _t(12.5, c: AppColors.textBody))),
                    ]),
                  ),
                  if (link != null)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => FlightWebViewScreen(url: link))),
                        icon: const Icon(Icons.open_in_new, size: 15, color: AppColors.textBody),
                        label: Text('השוואה באתר חיצוני (Aviasales)', style: _t(12.5, c: AppColors.textBody)),
                      ),
                    ),
                ]),
              ),
            const SizedBox(height: 14),
            if (o['hotel_id'] != null) LtCard(
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
            if (_withItinerary) LtSecondaryButton(
              label: _creating ? 'בונה מסלול... (עד דקה)' : '🗺️ צור טיול עם מסלול מההצעה',
              icon: _creating ? Icons.hourglass_top : Icons.auto_awesome,
              onPressed: _creating || _busy ? null : _createTrip,
            ),
            if (_creating)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(color: AppColors.accent, backgroundColor: AppColors.sectionTint),
              ),
            const SizedBox(height: 16),
            if (o['hotel_id'] == null)
              const SizedBox.shrink()
            else if (_confirmation != null)
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

/// Payment step. Card fields live in Stripe's secure Payment Element (PCI, inside an iframe we never read);
/// everything around them (header, steps, summary, skeleton, pay button, errors) is native Flutter.
/// Mounts Stripe Elements directly with LiteAPI's publishable key, fetched at runtime from LiteAPI's own
/// payment-wrapper config endpoint (the same one their SDK uses), so we control appearance + Hebrew locale.
/// If that fails it falls back to the stock LiteAPI wrapper. Pops `true` when Stripe redirects to the return URL.
class PaymentWebViewScreen extends StatefulWidget {
  const PaymentWebViewScreen({super.key, required this.secretKey, required this.sandbox, this.amount, this.route, this.summary});
  final String secretKey;
  final bool sandbox;
  final String? amount;
  final String? route;
  final List<(String, String)>? summary;
  static const returnUrl = 'https://lazytravel.app/booking-return';
  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _c;
  bool _ready = false, _complete = false, _paying = false, _fallback = false;
  String? _error;
  double _h = 320;

  String get _env => widget.sandbox ? 'sandbox' : 'live';

  String get _html => '''<!doctype html><html dir="rtl" lang="he"><head>
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
<style>html,body{margin:0;padding:0;background:transparent;overscroll-behavior:none}
#pay{padding:2px 2px 8px}.lp-submit-button-wrapper{display:none}</style>
<script src="https://js.stripe.com/v3/"></script></head><body><div id="pay"></div><script>
var stripe,elements,el;
function post(o){LT.postMessage(JSON.stringify(o))}
function size(){post({t:'h',h:document.body.scrollHeight})}
new ResizeObserver(size).observe(document.body);
async function go(){
 try{
  var r=await fetch('https://payment-wrapper.liteapi.travel/config',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({publicKey:'$_env'})});
  var cfg=await r.json(); if(!cfg.publicKey||!window.Stripe) throw new Error('cfg');
  stripe=Stripe(cfg.publicKey,{locale:'he'});
  elements=stripe.elements({clientSecret:'${widget.secretKey}',locale:'he',
   fonts:[{cssSrc:'https://fonts.googleapis.com/css2?family=Noto+Sans+Hebrew:wght@400;500;700&display=swap'}],
   appearance:{theme:'flat',labels:'floating',variables:{colorPrimary:'#2DBFAD',colorBackground:'#FFFFFF',colorText:'#0D2B35',
    colorTextSecondary:'#4A7A87',colorDanger:'#FF6B4A',fontFamily:'"Noto Sans Hebrew",sans-serif',fontSizeBase:'15px',
    borderRadius:'16px',spacingUnit:'4px',gridRowSpacing:'14px'},
    rules:{'.Input':{border:'1.5px solid #C8E8E8',boxShadow:'none',padding:'14px'},'.Input:focus':{border:'1.5px solid #2DBFAD',boxShadow:'0 0 0 3px rgba(45,191,173,.18)'},
     '.Label':{color:'#4A7A87',fontWeight:'500'},'.Tab':{border:'1.5px solid #C8E8E8',boxShadow:'none'},'.Tab--selected':{borderColor:'#2DBFAD',color:'#1B4F5C'},
     '.Block':{boxShadow:'none',border:'1.5px solid #C8E8E8'}}}});
  el=elements.create('payment',{layout:{type:'tabs'},wallets:{applePay:'never',googlePay:'never'},business:{name:'LAZYTRAVEL'}});
  el.on('ready',function(){post({t:'ready'});size()});
  el.on('change',function(e){post({t:'complete',v:!!e.complete})});
  el.on('loaderror',function(){fallback()});
  el.mount('#pay');
 }catch(e){fallback()}
}
function fallback(){
 post({t:'fallback'});
 document.getElementById('pay').innerHTML='';
 var st=document.createElement('style');st.textContent='.lp-submit-button-wrapper{display:block}.lp-submit-button{background:linear-gradient(135deg,#3DD6C6,#2DBFAD,#1B4F5C);color:#fff;border:0;border-radius:16px;padding:14px;width:100%;font-size:16px;font-weight:700;margin-top:12px}';
 document.head.appendChild(st);
 var s=document.createElement('script');s.src='https://payment-wrapper.liteapi.travel/dist/liteAPIPayment.js?v=a1';
 s.onload=function(){new LiteAPIPayment({publicKey:'$_env',targetElement:'#pay',secretKey:'${widget.secretKey}',
  returnUrl:'${PaymentWebViewScreen.returnUrl}',submitButton:{text:'שלם'}}).handlePayment();
  setTimeout(function(){post({t:'ready'});size()},3000)};
 document.head.appendChild(s);
}
async function pay(){
 var r=await stripe.confirmPayment({elements:elements,confirmParams:{return_url:'${PaymentWebViewScreen.returnUrl}'}});
 if(r.error) post({t:'error',m:r.error.message||''});
}
go();
</script></body></html>''';

  @override
  void initState() {
    super.initState();
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..enableZoom(false)
      ..addJavaScriptChannel('LT', onMessageReceived: (m) {
        final o = jsonDecode(m.message) as Map;
        if (!mounted) return;
        setState(() {
          switch (o['t']) {
            case 'ready':
              _ready = true;
            case 'complete':
              _complete = o['v'] == true;
            case 'fallback':
              _fallback = true;
            case 'h':
              _h = math.max(200, (o['h'] as num).toDouble() + 16);
            case 'error':
              _paying = false;
              _error = o['m'] as String?;
          }
        });
      })
      ..setNavigationDelegate(NavigationDelegate(onNavigationRequest: (req) {
        if (req.url.startsWith(PaymentWebViewScreen.returnUrl)) {
          Navigator.of(context).pop(true);
          return NavigationDecision.prevent;
        }
        return NavigationDecision.navigate;
      }))
      ..loadHtmlString(_html, baseUrl: 'https://lazytravel.app/');
  }

  Future<void> _pay() async {
    if (_paying || !_ready) return;
    setState(() {
      _paying = true;
      _error = null;
    });
    await _c.runJavaScript('pay()');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: Column(children: [
        widget.route != null
            ? _SkyHeader(title: 'תשלום מאובטח', subtitle: widget.route, height: 170, child: const _Steps(1))
            : _SkyHeader(title: 'תשלום מאובטח', subtitle: widget.amount, height: 130),
        Expanded(
          child: ListView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              _PaySummary(rows: widget.summary, amount: widget.amount),
              const SizedBox(height: 14),
              if (widget.sandbox)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: const Color(0xFFFFF6DB), borderRadius: BorderRadius.circular(14)),
                  child: Text('🧪 מצב בדיקה: כרטיס 4242 4242 4242 4242, כל תוקף עתידי וכל CVC', style: _t(12.5, c: const Color(0xFF7A5B00))),
                ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.border, width: 1.5),
                    boxShadow: [BoxShadow(color: AppColors.primaryDark.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.credit_card, color: AppColors.accent, size: 20),
                    const SizedBox(width: 8),
                    Text('פרטי כרטיס', style: _t(15, w: FontWeight.w700)),
                    const Spacer(),
                    const Icon(Icons.lock, size: 14, color: AppColors.success),
                    const SizedBox(width: 4),
                    Text('מוצפן', style: _t(12, c: AppColors.success)),
                  ]),
                  const SizedBox(height: 10),
                  Stack(children: [
                    Opacity(opacity: _ready ? 1 : 0, child: SizedBox(height: _h, child: WebViewWidget(controller: _c))),
                    if (!_ready) const Positioned.fill(child: _PaySkeleton()),
                  ]),
                ]),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: _t(13, c: AppColors.danger)),
              ],
              const SizedBox(height: 10),
              Text('פרטי הכרטיס נשלחים ישירות לספק התשלום המאובטח (Stripe דרך Nuitee). LAZYTRAVEL לא רואה ולא שומרת אותם.',
                  style: _t(11.5, c: AppColors.textBody)),
            ],
          ),
        ),
        if (!_fallback)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Opacity(
                opacity: _ready && _complete && !_paying ? 1 : 0.55,
                child: LtPrimaryButton(label: _paying ? 'מעבד תשלום...' : 'שלם ${widget.amount ?? ''}', onPressed: _pay),
              ),
            ),
          ),
      ]),
    );
  }
}

class _PaySummary extends StatelessWidget {
  const _PaySummary({this.rows, this.amount});
  final List<(String, String)>? rows;
  final String? amount;
  @override
  Widget build(BuildContext context) {
    final r = rows ?? const <(String, String)>[];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border, width: 1.5)),
      child: Column(children: [
        for (final x in r)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(x.$1, style: _t(13, c: AppColors.textBody)),
              const SizedBox(width: 12),
              Expanded(child: Text(x.$2, style: _t(13.5, w: FontWeight.w600), textAlign: TextAlign.left)),
            ]),
          ),
        if (r.isNotEmpty) const Divider(height: 14, color: AppColors.border),
        Row(children: [
          Text('לתשלום עכשיו', style: _t(15, w: FontWeight.w700)),
          const Spacer(),
          Text(amount ?? '', style: _t(22, w: FontWeight.w800, c: AppColors.primaryDark)),
        ]),
      ]),
    );
  }
}

class _PaySkeleton extends StatefulWidget {
  const _PaySkeleton();
  @override
  State<_PaySkeleton> createState() => _PaySkeletonState();
}

class _PaySkeletonState extends State<_PaySkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget bar(double h, {double? w}) => Container(
        height: h, width: w, margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: AppColors.sectionTint, borderRadius: BorderRadius.circular(16)));
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(_a),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        bar(52),
        Row(children: [Expanded(child: bar(52)), const SizedBox(width: 10), Expanded(child: bar(52))]),
        bar(52),
        Align(alignment: Alignment.centerRight, child: bar(14, w: 140)),
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
      backgroundColor: AppColors.bgLight,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(104 + MediaQuery.of(context).padding.top + 34),
        child: Column(children: [
          _SkyHeader(title: 'השוואת מחירים', subtitle: 'Aviasales · אתר חיצוני', height: 104),
          Container(
            width: double.infinity,
            color: const Color(0xFFFFF6DB),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(children: [
              const Icon(Icons.open_in_new, size: 15, color: Color(0xFF7A5B00)),
              const SizedBox(width: 6),
              Expanded(child: Text('אתר חיצוני להשוואה. הזמנה כאן לא מתבצעת דרך LAZYTRAVEL', style: _t(11.5, c: const Color(0xFF7A5B00)))),
              GestureDetector(
                onTap: () => launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication),
                child: Text('פתח בדפדפן', style: _t(11.5, w: FontWeight.w700, c: AppColors.primaryDark)),
              ),
            ]),
          ),
          if (_progress < 100) LinearProgressIndicator(value: _progress / 100, minHeight: 3, color: AppColors.accent) else const SizedBox(height: 3),
        ]),
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


class _RouteBuilding extends StatelessWidget {
  const _RouteBuilding();
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.bgLight,
        body: Column(children: [
          const _Header(title: 'בונים לך מסלול'),
          const Expanded(child: SingleChildScrollView(child: GlobeLoader(stage: 'ה-AI מתכנן את המסלול שלך יום אחרי יום...'))),
        ]),
      );
}

/// Refresh the auth session if it's expired or about to expire, so edge
/// functions (verify_jwt) don't reject the call with 401 after a slow cold start.
Future<void> _freshSession(dynamic client) async {
  if (client == null) return;
  try {
    final auth = client.auth;
    final s = auth.currentSession;
    if (s == null) return;
    final exp = s.expiresAt as int?;
    final soon = exp == null || DateTime.fromMillisecondsSinceEpoch(exp * 1000).isBefore(DateTime.now().add(const Duration(minutes: 2)));
    if (soon) await auth.refreshSession();
  } catch (_) {}
}

dynamic _finderClient;
