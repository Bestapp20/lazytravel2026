part of 'finder_screens.dart';

// ═══════════════════ Flight booking UI: sky, ticket, steps, confetti ═══════════════════

String _hm(String? iso) => (iso == null || iso.length < 16) ? '--:--' : iso.substring(11, 16);
String _dm(String? iso) {
  final d = iso == null ? null : DateTime.tryParse(iso);
  return d == null ? '' : DateFormat('E d.M', 'he').format(d);
}
String _dur(num? min) => min == null ? '' : '${min ~/ 60}ש׳ ${(min % 60).toInt().toString().padLeft(2, '0')}ד׳';

/// Animated sky: gradient, drifting clouds, and a plane on a dashed arc between two airports.
class _SkyHeader extends StatefulWidget {
  const _SkyHeader({required this.title, this.subtitle, this.from, this.to, this.height = 280, this.back = true, this.child});
  final String title;
  final String? subtitle;
  final String? from;
  final String? to;
  final double height;
  final bool back;
  final Widget? child;
  @override
  State<_SkyHeader> createState() => _SkyHeaderState();
}

class _SkyHeaderState extends State<_SkyHeader> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 24))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      child: SizedBox(
        height: widget.height + top,
        child: Stack(children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: _SkyPainter(_c, hasRoute: widget.from != null, lift: widget.child != null ? 62 : 0)),
            ),
          ),
          if (widget.from != null) ...[
            Positioned(right: 26, bottom: 22 + (widget.child != null ? 62 : 0), child: _code(widget.from!, 'מוצא')),
            Positioned(left: 26, bottom: 22 + (widget.child != null ? 62 : 0), child: _code(widget.to ?? '', 'יעד')),
          ],
          Positioned(
            top: top + 6, right: 8, left: 20,
            child: Row(children: [
              if (widget.back)
                IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_forward, color: Colors.white))
              else
                const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.title, style: _t(22, w: FontWeight.w800, c: Colors.white)),
                  if (widget.subtitle != null) Text(widget.subtitle!, style: _t(13, c: Colors.white.withValues(alpha: 0.85))),
                ]),
              ),
            ]),
          ),
          if (widget.child != null) Positioned(left: 0, right: 0, bottom: 14, child: widget.child!),
        ]),
      ),
    );
  }

  Widget _code(String c, String label) => Column(mainAxisSize: MainAxisSize.min, children: [
        Text(c, style: GoogleFonts.poppins(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1.5)),
        Text(label, style: _t(11, c: Colors.white70)),
      ]);
}

class _SkyPainter extends CustomPainter {
  _SkyPainter(this.anim, {required this.hasRoute, this.lift = 0}) : super(repaint: anim);
  final Animation<double> anim;
  final bool hasRoute;
  final double lift;

  @override
  void paint(Canvas canvas, Size s) {
    final t = anim.value;
    canvas.drawRect(Offset.zero & s, Paint()
      ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [AppColors.primaryDark, Color(0xFF237A84), AppColors.accent, AppColors.accentLight]).createShader(Offset.zero & s));
    // sun glow
    canvas.drawCircle(Offset(s.width * 0.82, s.height * 0.28), 70, Paint()
      ..shader = RadialGradient(colors: [Colors.white.withValues(alpha: 0.35), Colors.white.withValues(alpha: 0)])
          .createShader(Rect.fromCircle(center: Offset(s.width * 0.82, s.height * 0.28), radius: 70)));
    // three cloud layers, each drifting at its own speed
    for (final (y, sc, speed, a) in [(0.30, 0.8, 1.0, 0.20), (0.55, 1.1, 2.0, 0.28), (0.80, 1.4, 3.0, 0.38)]) {
      for (var i = 0; i < 3; i++) {
        final w = s.width + 240;
        final x = ((i / 3 + t * speed) % 1.0) * w - 120;
        _cloud(canvas, Offset(x, s.height * y + (i.isEven ? 0 : 14)), sc, a);
      }
    }
    if (!hasRoute) {
      // free-flying plane across the sky
      final p = (t * 3) % 1.0;
      _drawPlane(canvas, Offset(s.width * (1.1 - 1.2 * p), s.height * 0.55 - 30 * math.sin(p * math.pi)), math.pi, 1);
      return;
    }
    // dashed arc from origin (right) to destination (left)
    final a = Offset(s.width - 60, s.height - 60 - lift), b = Offset(60, s.height - 60 - lift), ctrl = Offset(s.width / 2, s.height * 0.12);
    Offset q(double u) => Offset(
        (1 - u) * (1 - u) * a.dx + 2 * (1 - u) * u * ctrl.dx + u * u * b.dx,
        (1 - u) * (1 - u) * a.dy + 2 * (1 - u) * u * ctrl.dy + u * u * b.dy);
    final dash = Paint()..color = Colors.white.withValues(alpha: 0.7)..strokeWidth = 2..strokeCap = StrokeCap.round;
    for (var u = 0.0; u < 1; u += 0.04) {
      canvas.drawLine(q(u), q(math.min(1, u + 0.02)), dash);
    }
    canvas.drawCircle(a, 5, Paint()..color = Colors.white);
    canvas.drawCircle(b, 5, Paint()..color = Colors.white);
    final u = Curves.easeInOut.transform((t * 4) % 1.0);
    final p0 = q(u), p1 = q(math.min(1, u + 0.01));
    _drawPlane(canvas, p0, math.atan2(p1.dy - p0.dy, p1.dx - p0.dx), 1 - (u > 0.92 ? (u - 0.92) / 0.08 : 0));
  }

  // laid out once; re-laying out text every frame was janky on slow devices
  static final TextPainter _planeTp = TextPainter(
    text: TextSpan(text: String.fromCharCode(Icons.flight.codePoint), style: TextStyle(fontFamily: Icons.flight.fontFamily, package: Icons.flight.fontPackage, fontSize: 34, color: Colors.white, shadows: const [Shadow(color: Color(0x551B4F5C), blurRadius: 8)])),
    textDirection: TextDirection.ltr,
  )..layout();

  void _drawPlane(Canvas c, Offset at, double angle, double opacity) {
    c.save();
    c.translate(at.dx, at.dy);
    c.rotate(angle + math.pi / 2); // icon points up
    final tp = _planeTp;
    if (opacity < 1) c.saveLayer(Rect.fromCircle(center: Offset.zero, radius: 40), Paint()..color = Color.fromRGBO(0, 0, 0, opacity.clamp(0.0, 1.0)));
    tp.paint(c, Offset(-tp.width / 2, -tp.height / 2));
    if (opacity < 1) c.restore();
    c.restore();
  }

  void _cloud(Canvas c, Offset o, double sc, double a) {
    final p = Paint()..color = Colors.white.withValues(alpha: a);
    c.drawCircle(o, 18 * sc, p);
    c.drawCircle(o + Offset(20 * sc, -8 * sc), 22 * sc, p);
    c.drawCircle(o + Offset(44 * sc, 0), 16 * sc, p);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(o.dx, o.dy - 4 * sc, 44 * sc, 20 * sc), Radius.circular(10 * sc)), p);
  }

  @override
  bool shouldRepaint(_SkyPainter old) => false;
}

/// Steps: passengers → payment → confirmation.
class _Steps extends StatelessWidget {
  const _Steps(this.current);
  final int current;
  @override
  Widget build(BuildContext context) {
    const labels = ['נוסעים', 'תשלום', 'אישור'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(children: [
        for (var i = 0; i < 3; i++) ...[
          Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              width: i == current ? 30 : 24, height: i == current ? 30 : 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i <= current ? Colors.white : Colors.white.withValues(alpha: 0.25),
                boxShadow: i == current ? [BoxShadow(color: Colors.white.withValues(alpha: 0.6), blurRadius: 12)] : null,
              ),
              child: Center(
                child: i < current
                    ? const Icon(Icons.check, size: 16, color: AppColors.accent)
                    : Text('${i + 1}', style: _t(12, w: FontWeight.w800, c: i == current ? AppColors.primaryDark : Colors.white)),
              ),
            ),
            const SizedBox(height: 3),
            Text(labels[i], style: _t(11, w: i == current ? FontWeight.w800 : FontWeight.w500, c: Colors.white)),
          ]),
          if (i < 2)
            Expanded(
              child: Container(
                height: 2, margin: const EdgeInsets.only(bottom: 16, left: 4, right: 4),
                color: i < current ? Colors.white : Colors.white.withValues(alpha: 0.3),
              ),
            ),
        ],
      ]),
    );
  }
}

/// Boarding-pass style flight ticket with perforated edge.
class _FlightTicket extends StatelessWidget {
  const _FlightTicket({required this.live, required this.cur, this.footer, this.pax});
  final Map live;
  final String cur;
  final Widget? footer;
  final int? pax;

  @override
  Widget build(BuildContext context) {
    final segs = (live['segments'] as List? ?? []).cast<Map>();
    final legs = (live['legs'] as List? ?? []).cast<Map>();
    final out = segs.where((s) => s['dir'] != 'INBOUND').toList();
    final inb = segs.where((s) => s['dir'] == 'INBOUND').toList();
    final logo = live['logo'] as String? ?? (live['carrier'] != null ? 'https://pics.avs.io/120/40/${live['carrier']}.png' : null);
    return PhysicalShape(
      clipper: _TicketClipper(),
      color: Colors.white,
      elevation: 6,
      shadowColor: AppColors.primaryDark.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: AppColors.sectionTint, borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.all(6),
              child: logo == null
                  ? const Icon(Icons.flight, color: AppColors.accent)
                  : Image.network(logo, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.flight, color: AppColors.accent)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${live['airline'] ?? ''}', style: _t(15, w: FontWeight.w800)),
                Text('${live['fare_family'] ?? 'Economy'}${pax != null ? ' · $pax נוסעים' : ''}', style: _t(12, c: AppColors.textBody)),
              ]),
            ),
            _BagBadge(live: live),
          ]),
          if (out.isNotEmpty) _leg('הלוך', out, legs.where((l) => l['dir'] != 'INBOUND').firstOrNull),
          if (inb.isNotEmpty) ...[
            const _Perforation(),
            _leg('חזור', inb, legs.where((l) => l['dir'] == 'INBOUND').firstOrNull),
          ],
          if (footer != null) ...[const _Perforation(), footer!],
        ]),
      ),
    );
  }

  Widget _leg(String label, List<Map> s, Map? leg) {
    final first = s.first, last = s.last;
    final stops = s.length - 1;
    final dayChange = (leg?['day_change'] as num? ?? 0) > 0;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text(label, style: _t(11, w: FontWeight.w700, c: AppColors.accent)),
          const SizedBox(width: 6),
          Text(_dm(first['dep']), style: _t(11, c: AppColors.textBody)),
          const Spacer(),
          Text(s.map((x) => x['flight']).join(' · '), style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textBody)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          _end(_hm(first['dep']), first['from']),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(children: [
                Text(_dur(leg?['min'] as num?), style: _t(11, w: FontWeight.w700, c: AppColors.textBody)),
                SizedBox(
                  height: 18,
                  child: CustomPaint(painter: _RouteLinePainter(stops), size: Size.infinite),
                ),
                Text(stops == 0 ? 'ישירה' : '$stops עצירות: ${s.take(stops).map((x) => x['to']).join(', ')}'.replaceFirst('1 עצירות', 'עצירה ב'),
                    style: _t(11, c: stops == 0 ? AppColors.success : AppColors.warning)),
              ]),
            ),
          ),
          _end('${_hm(last['arr'])}${dayChange ? '⁺¹' : ''}', last['to']),
        ]),
      ]),
    );
  }

  Widget _end(String time, Object? code) => Column(children: [
        Text(time, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textDark)),
        Text('$code', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textBody, letterSpacing: 1)),
      ]);
}

class _BagBadge extends StatelessWidget {
  const _BagBadge({required this.live});
  final Map live;
  @override
  Widget build(BuildContext context) {
    final checked = live['checked_included'] == true;
    final kg = live['checked_kg'];
    final (txt, col, ic) = checked
        ? ('${kg ?? ''}${kg != null ? 'ק״ג' : 'מזוודה'}', AppColors.success, Icons.luggage)
        : live['carry_on'] == true
            ? ('תיק עלייה', AppColors.accent, Icons.work_outline)
            : ('ללא כבודה', AppColors.warning, Icons.no_luggage_outlined);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: col.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(100)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(ic, size: 15, color: col),
        const SizedBox(width: 4),
        Text(txt, style: _t(12, w: FontWeight.w700, c: col)),
      ]),
    );
  }
}

class _RouteLinePainter extends CustomPainter {
  _RouteLinePainter(this.stops);
  final int stops;
  @override
  void paint(Canvas c, Size s) {
    final y = s.height / 2;
    final p = Paint()..color = AppColors.border..strokeWidth = 2;
    for (var x = 0.0; x < s.width; x += 7) {
      c.drawLine(Offset(x, y), Offset(math.min(s.width, x + 4), y), p);
    }
    final dot = Paint()..color = AppColors.accent;
    c.drawCircle(Offset(3, y), 3.5, dot);
    c.drawCircle(Offset(s.width - 3, y), 3.5, dot);
    for (var i = 1; i <= stops; i++) {
      final x = s.width * i / (stops + 1);
      c.drawCircle(Offset(x, y), 5, Paint()..color = Colors.white);
      c.drawCircle(Offset(x, y), 5, Paint()..color = AppColors.warning..style = PaintingStyle.stroke..strokeWidth = 2);
    }
    // RTL: flying from right (origin) to left
    final tp = TextPainter(
      text: TextSpan(text: String.fromCharCode(Icons.flight.codePoint), style: TextStyle(fontFamily: Icons.flight.fontFamily, package: Icons.flight.fontPackage, fontSize: 16, color: AppColors.primaryDark)),
      textDirection: TextDirection.ltr,
    )..layout();
    c.save();
    c.translate(s.width / 2, y);
    c.rotate(-math.pi / 2);
    c.drawCircle(Offset.zero, 10, Paint()..color = Colors.white);
    tp.paint(c, Offset(-tp.width / 2, -tp.height / 2));
    c.restore();
  }

  @override
  bool shouldRepaint(_RouteLinePainter o) => o.stops != stops;
}

class _Perforation extends StatelessWidget {
  const _Perforation();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: LayoutBuilder(builder: (_, c) {
          final n = (c.maxWidth / 10).floor();
          return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: List.generate(n, (_) => Container(width: 5, height: 1.5, color: AppColors.border)));
        }),
      );
}

class _TicketClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) {
    final r = RRect.fromRectAndRadius(Offset.zero & s, const Radius.circular(20));
    var p = Path()..addRRect(r);
    // notches on both sides at ~ the header divider
    const y = 74.0;
    final holes = Path()
      ..addOval(Rect.fromCircle(center: const Offset(0, y), radius: 11))
      ..addOval(Rect.fromCircle(center: Offset(s.width, y), radius: 11));
    p = Path.combine(PathOperation.difference, p, holes);
    return p;
  }

  @override
  bool shouldReclip(_TicketClipper old) => false;
}

/// Gradient CTA in a sticky bottom bar with the total.
class _StickyBar extends StatelessWidget {
  const _StickyBar({required this.total, required this.caption, required this.label, required this.onTap, this.busy = false});
  final String total;
  final String caption;
  final String label;
  final VoidCallback? onTap;
  final bool busy;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: AppColors.primaryDark.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(caption, style: _t(11, c: AppColors.textBody)),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(total, key: ValueKey(total), style: _t(22, w: FontWeight.w800, c: AppColors.primaryDark)),
          ),
        ]),
        const SizedBox(width: 16),
        Expanded(
          child: GestureDetector(
            onTap: busy ? null : onTap,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: onTap == null || busy ? 0.6 : 1,
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  gradient: AppColors.cta,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 6))],
                ),
                child: Center(
                  child: busy
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(label, style: _t(16, w: FontWeight.w800, c: Colors.white)),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                        ]),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ───────────── Checkout ─────────────

class _Pax {
  final first = TextEditingController();
  final last = TextEditingController();
  final passport = TextEditingController();
  DateTime? birthday;
  DateTime? expiry;
  String gender = 'M';
  bool get complete => first.text.trim().isNotEmpty && last.text.trim().isNotEmpty && birthday != null && (passport.text.trim().isEmpty || expiry != null);
  void dispose() {
    first.dispose();
    last.dispose();
    passport.dispose();
  }
}

final _iso = DateFormat('yyyy-MM-dd');

/// In-app flight checkout via LiteAPI/Nuitee (merchant of record).
/// Passengers → (live re-price) → payment SDK → book → confirmation.
class FlightCheckoutScreen extends ConsumerStatefulWidget {
  const FlightCheckoutScreen({super.key, required this.offer, required this.adults, required this.children});
  final Map<String, dynamic> offer;
  final int adults;
  final int children;
  @override
  ConsumerState<FlightCheckoutScreen> createState() => _FlightCheckoutScreenState();
}

class _FlightCheckoutScreenState extends ConsumerState<FlightCheckoutScreen> {
  late final List<_Pax> _pax = List.generate(widget.adults + widget.children, (_) => _Pax());
  final _email = TextEditingController();
  final _phone = TextEditingController();
  int _open = 0;
  late Map _live = Map.from(widget.offer['flight']?['live'] as Map? ?? {});
  late bool _bags = _live['checked_included'] != true && widget.offer['flight']?['bag_mode'] == 'checked';
  String? _phase; // 'reprice' | 'booking'

  @override
  void initState() {
    super.initState();
    _email.text = ref.read(supabaseProvider)?.auth.currentUser?.email ?? '';
    for (final p in _pax) {
      p.first.addListener(_refresh);
      p.last.addListener(_refresh);
    }
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    for (final p in _pax) {
      p.dispose();
    }
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  String get _cur => widget.offer['currency'] as String? ?? 'ILS';
  bool get _ready => _pax.every((p) => p.complete) && _email.text.contains('@') && _phone.text.replaceAll(RegExp(r'\D'), '').length >= 9;

  Future<void> _pay() async {
    if (_phase != null) return;
    if (!_ready) {
      final i = _pax.indexWhere((p) => !p.complete);
      if (i >= 0) setState(() => _open = i);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('השלם את פרטי כל הנוסעים, מייל וטלפון')));
      return;
    }
    final client = ref.read(supabaseProvider)!;
    FocusScope.of(context).unfocus();
    setState(() => _phase = 'reprice');
    try {
      final phone = _phone.text.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^(972|0)'), '');
      final res = await client.functions.invoke('flight-prebook', body: {
        'offer_id': widget.offer['id'],
        'with_bags': _bags,
        'contact': {
          'firstName': _pax.first.first.text.trim(), 'lastName': _pax.first.last.text.trim(),
          'email': _email.text.trim(), 'phoneCountryCode': '972', 'phoneNumber': phone,
        },
        'passengers': [
          for (var i = 0; i < _pax.length; i++)
            {
              'passengerType': i < widget.adults ? 0 : 1,
              'firstName': _pax[i].first.text.trim(),
              'lastName': _pax[i].last.text.trim(),
              'birthday': _iso.format(_pax[i].birthday!),
              'gender': _pax[i].gender,
              'nationality': 'IL',
              if (_pax[i].passport.text.trim().isNotEmpty && _pax[i].expiry != null) ...{
                'documentType': 'passport',
                'documentNumber': _pax[i].passport.text.trim(),
                'documentIssueCountry': 'IL',
                'documentExpiry': _iso.format(_pax[i].expiry!),
              },
            },
        ],
      });
      final q = Map<String, dynamic>.from(res.data as Map);
      if (q['error'] != null) throw Exception(q['error']);
      if (q['live'] is Map) _live = Map.from(q['live']);
      if (!mounted) return;
      setState(() => _phase = null);
      final paid = await Navigator.of(context).push<bool>(_fade(PaymentWebViewScreen(
        secretKey: q['secret_key'], sandbox: q['sandbox'] == true,
        amount: _price(q['price'] as num?, q['currency'] ?? _cur),
        route: '${widget.offer['flight']['origin']} ⇄ ${widget.offer['flight']['destination']}',
        summary: [
          ('טיסה', '${_live['airline'] ?? ''} · ${widget.offer['flight']['origin']} ⇄ ${widget.offer['flight']['destination']}'),
          ('נוסעים', [for (final p in _pax) '${p.first.text.trim()} ${p.last.text.trim()}'.toUpperCase()].join(', ')),
          if (_bags || _live['checked_included'] == true) ('כבודה', 'מזוודה 23 ק״ג'),
        ],
      )));
      if (paid != true || !mounted) return;
      setState(() => _phase = 'booking');
      final b = await client.functions.invoke('flight-book', body: {'booking_id': q['booking_id']});
      final r = Map<String, dynamic>.from(b.data as Map);
      if (r['error'] != null) throw Exception(r['error']);
      if (!mounted) return;
      final addTrip = await Navigator.of(context).pushReplacement(_fade(FlightConfirmationScreen(
        offer: widget.offer, live: _live, result: r, quote: q,
        names: [for (final p in _pax) '${p.first.text.trim()} ${p.last.text.trim()}'.toUpperCase()],
      )));
      if (addTrip == true && mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _phase = null);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(duration: const Duration(seconds: 8), content: Text('$e'.contains('validation') ? 'חברת התעופה דחתה את פרטי הנוסעים — בדוק שמות, תאריכי לידה ודרכון (מספר + תוקף)' : 'שגיאה: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.offer['flight'] as Map;
    final total = (_live['total'] as num?) ?? (widget.offer['flight_price'] as num?);
    final body = Scaffold(
      backgroundColor: AppColors.bgLight,
      bottomNavigationBar: _StickyBar(
        caption: _bags && _live['checked_included'] != true ? 'משוער + מזוודות' : 'סה״כ ל-${_pax.length} נוסעים',
        total: _price(total, _cur),
        label: 'המשך לתשלום',
        onTap: _pay,
      ),
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: _SkyHeader(
            title: 'הזמנת טיסה', subtitle: '${_dm(f['depart'])} – ${_dm(f['ret'])}',
            from: f['origin'], to: f['destination'], height: 300,
            child: const _Steps(0),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          sliver: SliverList.list(children: [
            _FlightTicket(live: _live, cur: _cur, pax: _pax.length),
            if (_live['checked_included'] != true) ...[
              const SizedBox(height: 12),
              LtCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _bags,
                  activeTrackColor: AppColors.accent,
                  onChanged: (v) => setState(() => _bags = v),
                  secondary: const Icon(Icons.luggage, color: AppColors.accent),
                  title: Text('הוסף מזוודה לכל נוסע', style: _t(14, w: FontWeight.w700)),
                  subtitle: Text('הלוך וחזור · המחיר הסופי מאומת מול חברת התעופה', style: _t(11, c: AppColors.textBody)),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Text('מי טס?', style: _t(18, w: FontWeight.w800)),
            Text('שמות באנגלית בדיוק כמו בדרכון', style: _t(12, c: AppColors.textBody)),
            const SizedBox(height: 10),
            for (var i = 0; i < _pax.length; i++) ...[
              _PaxCard(
                index: i, pax: _pax[i], adult: i < widget.adults, open: _open == i,
                onToggle: () => setState(() => _open = _open == i ? -1 : i),
                onDone: () => setState(() => _open = i + 1 < _pax.length ? i + 1 : -1),
                onChanged: _refresh,
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 8),
            Text('פרטי קשר', style: _t(18, w: FontWeight.w800)),
            const SizedBox(height: 10),
            LtCard(
              child: Column(children: [
                _field(_email, 'מייל', Icons.alternate_email, kb: TextInputType.emailAddress),
                const SizedBox(height: 10),
                _field(_phone, 'טלפון נייד', Icons.phone_iphone, kb: TextInputType.phone, prefix: '+972 '),
              ]),
            ),
            const SizedBox(height: 14),
            Row(children: [
              const Icon(Icons.verified_user_outlined, size: 16, color: AppColors.textBody),
              const SizedBox(width: 6),
              Expanded(child: Text('התשלום מאובטח ומתבצע מול Nuitee (LiteAPI), שמנפיקה את הכרטיס.', style: _t(11, c: AppColors.textBody))),
            ]),
          ]),
        ),
      ]),
    );
    return Stack(children: [
      body,
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: _phase == null
            ? const SizedBox.shrink()
            : _FlightLoading(key: ValueKey(_phase), text: _phase == 'reprice' ? 'מוודאים מחיר בזמן אמת...' : 'מנפיקים את ההזמנה...', from: f['origin'], to: f['destination']),
      ),
    ]);
  }

  Widget _field(TextEditingController c, String label, IconData icon, {TextInputType? kb, String? prefix}) => TextField(
        controller: c,
        keyboardType: kb,
        onChanged: (_) => _refresh(),
        textDirection: TextDirection.ltr,
        decoration: _deco(label, icon).copyWith(prefixText: prefix),
      );
}

InputDecoration _deco(String label, IconData icon) => InputDecoration(
      labelText: label,
      labelStyle: _t(13, c: AppColors.textBody),
      prefixIcon: Icon(icon, color: AppColors.accent, size: 20),
      isDense: true,
      filled: true,
      fillColor: AppColors.bgLight,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
    );

PageRouteBuilder<T> _fade<T>(Widget w) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (_, __, ___) => w,
      transitionsBuilder: (_, a, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
        child: SlideTransition(position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)), child: child),
      ),
    );

class _PaxCard extends StatelessWidget {
  const _PaxCard({required this.index, required this.pax, required this.adult, required this.open, required this.onToggle, required this.onDone, required this.onChanged});
  final int index;
  final _Pax pax;
  final bool adult;
  final bool open;
  final VoidCallback onToggle;
  final VoidCallback onDone;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final name = '${pax.first.text} ${pax.last.text}'.trim();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: open ? AppColors.accent : AppColors.border, width: 1.5),
        boxShadow: [BoxShadow(color: AppColors.primaryDark.withValues(alpha: open ? 0.12 : 0.05), blurRadius: open ? 20 : 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: pax.complete ? AppColors.ctaSimple : null, color: pax.complete ? null : AppColors.sectionTint),
                child: Icon(pax.complete ? Icons.check : (adult ? Icons.person : Icons.child_care), color: pax.complete ? Colors.white : AppColors.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name.isEmpty ? 'נוסע ${index + 1}' : name.toUpperCase(), style: _t(15, w: FontWeight.w800)),
                  Text(adult ? 'מבוגר' : 'ילד', style: _t(12, c: AppColors.textBody)),
                ]),
              ),
              AnimatedRotation(turns: open ? 0.5 : 0, duration: const Duration(milliseconds: 300), child: const Icon(Icons.expand_more, color: AppColors.textBody)),
            ]),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: !open
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      Expanded(child: TextField(controller: pax.first, textCapitalization: TextCapitalization.characters, textDirection: TextDirection.ltr, decoration: _deco('שם פרטי', Icons.badge_outlined))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: pax.last, textCapitalization: TextCapitalization.characters, textDirection: TextDirection.ltr, decoration: _deco('שם משפחה', Icons.badge_outlined))),
                    ]),
                    const SizedBox(height: 10),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'M', label: Text('זכר'), icon: Icon(Icons.male)),
                        ButtonSegment(value: 'F', label: Text('נקבה'), icon: Icon(Icons.female)),
                      ],
                      selected: {pax.gender},
                      showSelectedIcon: false,
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.accent : Colors.white),
                        foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : AppColors.textBody),
                        side: const WidgetStatePropertyAll(BorderSide(color: AppColors.border)),
                      ),
                      onSelectionChanged: (v) {
                        pax.gender = v.first;
                        onChanged();
                      },
                    ),
                    const SizedBox(height: 10),
                    _DateField(
                      label: 'תאריך לידה', icon: Icons.cake_outlined, value: pax.birthday,
                      first: DateTime(1920), last: DateTime.now(), initial: DateTime(adult ? 1990 : 2018),
                      onPicked: (d) { pax.birthday = d; onChanged(); },
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: pax.passport, textDirection: TextDirection.ltr, decoration: _deco('מספר דרכון (לא חובה)', Icons.menu_book_outlined)),
                    const SizedBox(height: 10),
                    _DateField(
                      label: 'תוקף דרכון (לא חובה)', icon: Icons.event_available_outlined, value: pax.expiry,
                      first: DateTime.now(), last: DateTime.now().add(const Duration(days: 365 * 15)), initial: DateTime.now().add(const Duration(days: 365 * 3)),
                      onPicked: (d) { pax.expiry = d; onChanged(); },
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton.icon(
                        onPressed: pax.complete ? onDone : null,
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text('שמור נוסע', style: _t(14, w: FontWeight.w700, c: pax.complete ? AppColors.accent : AppColors.navInactive)),
                      ),
                    ),
                  ]),
                ),
        ),
      ]),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.icon, required this.value, required this.first, required this.last, required this.initial, required this.onPicked});
  final String label;
  final IconData icon;
  final DateTime? value;
  final DateTime first, last, initial;
  final ValueChanged<DateTime> onPicked;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        FocusScope.of(context).unfocus();
        final d = await showDatePicker(
          context: context, firstDate: first, lastDate: last, initialDate: value ?? initial,
          initialEntryMode: DatePickerEntryMode.calendar, initialDatePickerMode: DatePickerMode.year,
          helpText: label,
        );
        if (d != null) onPicked(d);
      },
      child: InputDecorator(
        decoration: _deco(label, icon),
        isEmpty: value == null,
        child: value == null ? null : Text(DateFormat('d MMMM y', 'he').format(value!), style: _t(14, w: FontWeight.w600)),
      ),
    );
  }
}

/// Full-screen loading with the flying-plane sky.
class _FlightLoading extends StatelessWidget {
  const _FlightLoading({super.key, required this.text, this.from, this.to});
  final String text;
  final String? from, to;
  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return Material(
      color: AppColors.bgLight,
      child: Column(children: [
        _SkyHeader(title: '', from: from, to: to, height: h * 0.55, back: false),
        const SizedBox(height: 36),
        Text(text, style: _t(20, w: FontWeight.w800, c: AppColors.primaryDark)),
        const SizedBox(height: 8),
        Text('זה לוקח כמה שניות, אל תסגור את המסך', style: _t(13, c: AppColors.textBody)),
        const SizedBox(height: 26),
        const SizedBox(width: 160, child: LinearProgressIndicator(minHeight: 4, color: AppColors.accent, backgroundColor: AppColors.border, borderRadius: BorderRadius.all(Radius.circular(4)))),
      ]),
    );
  }
}

// ───────────── Confirmation ─────────────

class FlightConfirmationScreen extends StatefulWidget {
  const FlightConfirmationScreen({super.key, required this.offer, required this.live, required this.result, required this.quote, required this.names});
  final Map offer, live, result, quote;
  final List<String> names;
  @override
  State<FlightConfirmationScreen> createState() => _FlightConfirmationScreenState();
}

class _FlightConfirmationScreenState extends State<FlightConfirmationScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..forward();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final st = '${r['status']}'.toUpperCase();
    final pending = st.startsWith('PENDING');
    final ref = '${r['booking_ref'] ?? r['booking_id'] ?? ''}';
    final f = widget.offer['flight'] as Map;
    final cur = widget.quote['currency'] as String? ?? 'ILS';
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      bottomNavigationBar: _StickyBar(
        caption: 'שולם', total: _price(widget.quote['price'] as num?, cur),
        label: 'הוסף לטיול שלי', onTap: () => Navigator.of(context).pop(true),
      ),
      body: Stack(children: [
        CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: _SkyHeader(
              title: pending ? 'ההזמנה התקבלה!' : 'הטיסה הוזמנה!',
              subtitle: pending ? 'ממתין לאישור חברת התעופה · נעדכן במייל' : 'נסיעה טובה ✈️',
              from: f['origin'], to: f['destination'], height: 300, child: const _Steps(2),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            sliver: SliverList.list(children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutBack,
                builder: (_, v, child) => Transform.scale(scale: 0.85 + 0.15 * v, child: Opacity(opacity: v.clamp(0, 1), child: child)),
                child: _FlightTicket(
                  live: widget.live, cur: cur, pax: widget.names.length,
                  footer: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('נוסעים', style: _t(11, c: AppColors.textBody)),
                          for (final n in widget.names) Text(n, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                          const SizedBox(height: 8),
                          Text('מספר הזמנה', style: _t(11, c: AppColors.textBody)),
                          SelectableText(ref, style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.primaryDark, letterSpacing: 1)),
                          if (r['pnr'] != null) Text('PNR ${r['pnr']}', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: (pending ? AppColors.warning : AppColors.success).withValues(alpha: 0.14), borderRadius: BorderRadius.circular(100)),
                            child: Text(pending ? 'ממתין לאישור חברת התעופה' : st == 'CONFIRMED' ? 'מאושר' : st, style: _t(12, w: FontWeight.w700, c: pending ? AppColors.warning : AppColors.success)),
                          ),
                        ]),
                      ),
                      CustomPaint(size: const Size(64, 64), painter: _BarcodePainter(ref)),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (widget.quote['sandbox'] == true)
                Text('🧪 הזמנת Sandbox: לא בוצע חיוב אמיתי', textAlign: TextAlign.center, style: _t(12, c: AppColors.textBody)),
              const SizedBox(height: 8),
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('חזרה להצעה', style: _t(14, w: FontWeight.w700, c: AppColors.accent))),
            ]),
          ),
        ]),
        IgnorePointer(child: RepaintBoundary(child: CustomPaint(size: Size.infinite, painter: _ConfettiPainter(_c)))),
      ]),
    );
  }
}

/// Deterministic pseudo-barcode / QR-ish block from the booking ref (decorative).
class _BarcodePainter extends CustomPainter {
  _BarcodePainter(this.seed);
  final String seed;
  @override
  void paint(Canvas c, Size s) {
    final rnd = math.Random(seed.hashCode);
    const n = 9;
    final cell = s.width / n;
    final p = Paint()..color = AppColors.primaryDark;
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        final corner = (x < 3 && y < 3) || (x > 5 && y < 3) || (x < 3 && y > 5);
        if (corner ? (x % 6 != 1 || y % 6 != 1) && !(x % 6 == 1 && y % 6 == 1) : rnd.nextBool()) {
          c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x * cell, y * cell, cell - 1, cell - 1), const Radius.circular(1.5)), p);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_BarcodePainter o) => o.seed != seed;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.anim) : super(repaint: anim);
  final Animation<double> anim;
  static final _parts = List.generate(90, (i) {
    final r = math.Random(i * 7919);
    return (r.nextDouble(), r.nextDouble() * 0.35, 0.6 + r.nextDouble() * 0.8, r.nextDouble() * 6.28, r.nextInt(5), (r.nextDouble() - 0.5) * 0.3);
  });
  static const _colors = [AppColors.accent, AppColors.accentLight, Color(0xFFFFC94A), AppColors.danger, AppColors.primaryDark];

  @override
  void paint(Canvas c, Size s) {
    final t = anim.value;
    if (t >= 1) return;
    for (final (x0, delay, speed, rot, col, drift) in _parts) {
      final lt = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (lt <= 0) continue;
      final y = -20 + lt * speed * s.height * 1.1;
      final x = (x0 + drift * lt + 0.02 * math.sin(lt * 12 + rot)) * s.width;
      final p = Paint()..color = _colors[col].withValues(alpha: (1 - lt).clamp(0, 1) * 0.95);
      c.save();
      c.translate(x, y);
      c.rotate(rot + lt * 10);
      c.drawRect(const Rect.fromLTWH(-4, -2.5, 8, 5), p);
      c.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter o) => false;
}
