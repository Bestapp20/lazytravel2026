part of 'finder_screens.dart';

// ───────────────────────── Destination info (hero cards) ─────────────────────────
/// IATA city/airport code → (Hebrew name, ISO country code, Hebrew country).
const Map<String, (String, String, String)> _cities = {
  'BKK': ('בנגקוק', 'TH', 'תאילנד'), 'DMK': ('בנגקוק', 'TH', 'תאילנד'), 'HKT': ('פוקט', 'TH', 'תאילנד'), 'USM': ('קו סמוי', 'TH', 'תאילנד'),
  'CNX': ('צ׳יאנג מאי', 'TH', 'תאילנד'), 'BUH': ('בוקרשט', 'RO', 'רומניה'), 'OTP': ('בוקרשט', 'RO', 'רומניה'), 'ATH': ('אתונה', 'GR', 'יוון'),
  'SKG': ('סלוניקי', 'GR', 'יוון'), 'HER': ('כרתים', 'GR', 'יוון'), 'RHO': ('רודוס', 'GR', 'יוון'), 'LCA': ('לרנקה', 'CY', 'קפריסין'),
  'PFO': ('פאפוס', 'CY', 'קפריסין'), 'ROM': ('רומא', 'IT', 'איטליה'), 'FCO': ('רומא', 'IT', 'איטליה'), 'MIL': ('מילאנו', 'IT', 'איטליה'),
  'MXP': ('מילאנו', 'IT', 'איטליה'), 'VCE': ('ונציה', 'IT', 'איטליה'), 'NAP': ('נאפולי', 'IT', 'איטליה'), 'PAR': ('פריז', 'FR', 'צרפת'),
  'CDG': ('פריז', 'FR', 'צרפת'), 'NCE': ('ניס', 'FR', 'צרפת'), 'LON': ('לונדון', 'GB', 'בריטניה'), 'LHR': ('לונדון', 'GB', 'בריטניה'),
  'BER': ('ברלין', 'DE', 'גרמניה'), 'MUC': ('מינכן', 'DE', 'גרמניה'), 'FRA': ('פרנקפורט', 'DE', 'גרמניה'), 'AMS': ('אמסטרדם', 'NL', 'הולנד'),
  'BCN': ('ברצלונה', 'ES', 'ספרד'), 'MAD': ('מדריד', 'ES', 'ספרד'), 'LIS': ('ליסבון', 'PT', 'פורטוגל'), 'PRG': ('פראג', 'CZ', 'צ׳כיה'),
  'BUD': ('בודפשט', 'HU', 'הונגריה'), 'VIE': ('וינה', 'AT', 'אוסטריה'), 'WAW': ('ורשה', 'PL', 'פולין'), 'KRK': ('קרקוב', 'PL', 'פולין'),
  'SOF': ('סופיה', 'BG', 'בולגריה'), 'VAR': ('ורנה', 'BG', 'בולגריה'), 'BEG': ('בלגרד', 'RS', 'סרביה'), 'TBS': ('טביליסי', 'GE', 'גאורגיה'),
  'BUS': ('בטומי', 'GE', 'גאורגיה'), 'IST': ('איסטנבול', 'TR', 'טורקיה'), 'AYT': ('אנטליה', 'TR', 'טורקיה'), 'DXB': ('דובאי', 'AE', 'איחוד האמירויות'),
  'AUH': ('אבו דאבי', 'AE', 'איחוד האמירויות'), 'NYC': ('ניו יורק', 'US', 'ארה״ב'), 'JFK': ('ניו יורק', 'US', 'ארה״ב'), 'LAX': ('לוס אנג׳לס', 'US', 'ארה״ב'),
  'MIA': ('מיאמי', 'US', 'ארה״ב'), 'DEL': ('דלהי', 'IN', 'הודו'), 'BOM': ('מומבאי', 'IN', 'הודו'), 'GOI': ('גואה', 'IN', 'הודו'),
  'SGN': ('הו צ׳י מין', 'VN', 'וייטנאם'), 'HAN': ('האנוי', 'VN', 'וייטנאם'), 'DPS': ('באלי', 'ID', 'אינדונזיה'), 'TYO': ('טוקיו', 'JP', 'יפן'),
  'NRT': ('טוקיו', 'JP', 'יפן'), 'SIN': ('סינגפור', 'SG', 'סינגפור'), 'KUL': ('קואלה לומפור', 'MY', 'מלזיה'), 'MLE': ('האיים המלדיביים', 'MV', 'המלדיביים'),
  'SEZ': ('סיישל', 'SC', 'סיישל'), 'ZNZ': ('זנזיבר', 'TZ', 'טנזניה'), 'RAK': ('מרקש', 'MA', 'מרוקו'), 'CAI': ('קהיר', 'EG', 'מצרים'),
  'SSH': ('שארם א-שייח׳', 'EG', 'מצרים'), 'TIA': ('טירנה', 'AL', 'אלבניה'), 'TIV': ('טיבט', 'ME', 'מונטנגרו'), 'DBV': ('דוברובניק', 'HR', 'קרואטיה'),
  'SPU': ('ספליט', 'HR', 'קרואטיה'), 'ZAG': ('זאגרב', 'HR', 'קרואטיה'), 'LJU': ('ליובליאנה', 'SI', 'סלובניה'), 'BTS': ('ברטיסלבה', 'SK', 'סלובקיה'),
  'RIX': ('ריגה', 'LV', 'לטביה'), 'VNO': ('וילנה', 'LT', 'ליטא'), 'TLL': ('טאלין', 'EE', 'אסטוניה'), 'CPH': ('קופנהגן', 'DK', 'דנמרק'),
  'STO': ('שטוקהולם', 'SE', 'שוודיה'), 'OSL': ('אוסלו', 'NO', 'נורווגיה'), 'HEL': ('הלסינקי', 'FI', 'פינלנד'), 'DUB': ('דבלין', 'IE', 'אירלנד'),
  'ZRH': ('ציריך', 'CH', 'שווייץ'), 'GVA': ('ז׳נבה', 'CH', 'שווייץ'), 'BRU': ('בריסל', 'BE', 'בלגיה'), 'MLA': ('מלטה', 'MT', 'מלטה'),
  'KIV': ('קישינב', 'MD', 'מולדובה'), 'EVN': ('ירוואן', 'AM', 'ארמניה'), 'GYD': ('באקו', 'AZ', 'אזרבייג׳ן'), 'TAS': ('טשקנט', 'UZ', 'אוזבקיסטן'),
};

String _flag(String cc) => String.fromCharCodes(cc.toUpperCase().codeUnits.map((u) => 0x1F1E6 + u - 65));

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.offer, required this.onTap});
  final Map<String, dynamic> offer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cur = offer['currency'] as String? ?? 'ILS';
    final photo = offer['hotel_photo'] as String?;
    final f = offer['flight'] as Map?;
    final dcode = (f?['destination'] ?? '') as String;
    final orig = (f?['origin'] ?? 'TLV') as String;
    final info = _cities[dcode];
    final en = (offer['destination'] ?? '') as String;
    final bookable = f?['live'] != null;
    const h = 190.0;
    return LtCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
          child: SizedBox(
            height: h,
            child: Stack(fit: StackFit.expand, children: [
              photo == null
                  ? const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.accentLight, AppColors.primaryDark])))
                  : Image.network(photo, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.accentLight, AppColors.primaryDark])))),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: [0, 0.35, 1],
                      colors: [Color(0x55000000), Color(0x00000000), Color(0xCC0B2530)]),
                ),
              ),
              Positioned(
                top: 10, right: 10,
                child: _pill('#${offer['rank']}', AppColors.primaryDark),
              ),
              if (dcode.isNotEmpty)
                Positioned(
                  top: 10, left: 10,
                  child: _pill('$orig ✈ $dcode', const Color(0x66000000)),
                ),
              Positioned(
                right: 14, left: 14, bottom: 12,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(info?.$1 ?? en, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: _t(30, w: FontWeight.w900, c: Colors.white).copyWith(height: 1.1, shadows: const [Shadow(blurRadius: 8, color: Color(0x88000000))])),
                  Text([if (info != null) en, if (info != null) '${_flag(info.$2)} ${info.$3}'].join(' · '),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: _t(14, w: FontWeight.w600, c: Colors.white.withValues(alpha: 0.92))),
                ]),
              ),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${_d.format(DateTime.parse(offer['checkin']))} – ${_d.format(DateTime.parse(offer['checkout']))} · ${offer['nights']} לילות',
                style: _t(13, w: FontWeight.w700, c: AppColors.primaryDark)),
            const SizedBox(height: 4),
            if (offer['hotel_name'] != null) Row(children: [
              const Icon(Icons.hotel, size: 15, color: AppColors.textBody),
              const SizedBox(width: 4),
              Expanded(child: Text(offer['hotel_name'] ?? '', style: _t(12.5, c: AppColors.textBody), maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (offer['hotel_stars'] != null) Text('★' * (offer['hotel_stars'] as num).round(), style: _t(12, c: AppColors.warning)),
            ]),
            if (offer['ai_reason'] != null) ...[
              const SizedBox(height: 4),
              Text(offer['ai_reason'], style: _t(11.5, c: AppColors.textBody), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 10),
            Row(children: [
              if (offer['flight_price'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: bookable ? AppColors.accent.withValues(alpha: 0.12) : AppColors.sectionTint, borderRadius: BorderRadius.circular(10)),
                  child: Text(bookable ? '✈ ניתן להזמין באפליקציה' : '✈ מחיר משוער', style: _t(11, w: FontWeight.w700, c: bookable ? AppColors.primaryDark : AppColors.textBody)),
                ),
              const Spacer(),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(_price(offer['total'], cur), style: _t(20, w: FontWeight.w900, c: AppColors.primaryDark)),
                Text(offer['hotel_name'] == null ? 'סה״כ טיסה' : offer['flight_price'] == null ? 'סה״כ מלון' : 'סה״כ טיסה + מלון', style: _t(10.5, c: AppColors.textBody)),
              ]),
            ]),
          ]),
        ),
      ]),
    );
  }

  static Widget _pill(String s, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(s, textDirection: TextDirection.ltr, style: _t(12, w: FontWeight.w800, c: Colors.white)),
      );
}

// ───────────────────────── Globe loader ─────────────────────────
/// Rotating globe with an orbiting plane over a sky background, stage text and progress bar.
class GlobeLoader extends StatefulWidget {
  const GlobeLoader({super.key, required this.stage, this.progress});
  final String stage;
  final double? progress;
  @override
  State<GlobeLoader> createState() => _GlobeLoaderState();
}

class _GlobeLoaderState extends State<GlobeLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF7FD8EC), Color(0xFFDDF6F4)]),
        boxShadow: [BoxShadow(color: AppColors.primaryDark.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        RepaintBoundary(child: SizedBox(height: 250, width: double.infinity, child: CustomPaint(painter: _GlobePainter(_a)))),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: Text(widget.stage, key: ValueKey(widget.stage), textAlign: TextAlign.center, style: _t(16, w: FontWeight.w800, c: AppColors.primaryDark)),
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: widget.progress ?? 0),
            duration: const Duration(milliseconds: 600),
            builder: (_, v, _) => LinearProgressIndicator(value: widget.progress == null ? null : v, minHeight: 10,
                backgroundColor: Colors.white.withValues(alpha: 0.7), color: AppColors.accent),
          ),
        ),
      ]),
    );
  }
}

class _GlobePainter extends CustomPainter {
  _GlobePainter(this.t) : super(repaint: t);
  final Animation<double> t;

  // Land as lat/lon points, generated once from coarse continent ellipses.
  static final Float32List _land = () {
    const blobs = [ // lat, lon, dLat, dLon
      (50.0, 15.0, 14.0, 22.0), (8.0, 20.0, 28.0, 18.0), (50.0, 90.0, 20.0, 50.0), (22.0, 80.0, 12.0, 12.0), (15.0, 103.0, 10.0, 8.0),
      (45.0, -100.0, 18.0, 30.0), (62.0, -110.0, 10.0, 35.0), (-15.0, -60.0, 22.0, 14.0), (-25.0, 134.0, 10.0, 16.0), (25.0, 45.0, 8.0, 10.0),
      (72.0, -40.0, 8.0, 14.0), (36.0, 138.0, 6.0, 4.0), (-2.0, 115.0, 6.0, 12.0),
    ];
    final pts = <double>[];
    for (var lat = -60.0; lat <= 80; lat += 4.5) {
      for (var lon = -180.0; lon < 180; lon += 4.5) {
        for (final b in blobs) {
          final dy = (lat - b.$1) / b.$3, dx = (lon - b.$2) / b.$4;
          if (dx * dx + dy * dy <= 1) {
            pts..add(lat * math.pi / 180)..add(lon * math.pi / 180);
            break;
          }
        }
      }
    }
    return Float32List.fromList(pts);
  }();
  static final Float32List _buf = Float32List(_land.length);
  static final Paint _landP = Paint()..color = const Color(0xFF27AE60)..strokeWidth = 5..strokeCap = StrokeCap.round;
  static final Paint _gridP = Paint()..color = const Color(0x33FFFFFF)..style = PaintingStyle.stroke..strokeWidth = 1;
  static final Paint _orbitP = Paint()..color = const Color(0x88FFFFFF)..style = PaintingStyle.stroke..strokeWidth = 1.5;
  static final Paint _cloudP = Paint()..color = const Color(0xE6FFFFFF);
  static final Paint _shadeP = Paint();
  static final Paint _seaP = Paint();
  static final TextPainter _plane = TextPainter(
    text: const TextSpan(text: '✈', style: TextStyle(fontSize: 30, color: AppColors.primaryDark)),
    textDirection: TextDirection.ltr,
  )..layout();
  static Size? _shaderFor;

  void _cloud(Canvas c, double x, double y, double s) {
    c.drawCircle(Offset(x, y), 12 * s, _cloudP);
    c.drawCircle(Offset(x + 14 * s, y - 6 * s), 15 * s, _cloudP);
    c.drawCircle(Offset(x + 30 * s, y), 11 * s, _cloudP);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final v = t.value;
    final cx = size.width / 2, cy = size.height / 2 + 4;
    final r = math.min(size.height * 0.36, size.width * 0.3);
    final c = Offset(cx, cy);
    if (_shaderFor != size) {
      _shaderFor = size;
      final rect = Rect.fromCircle(center: c, radius: r);
      _seaP.shader = const RadialGradient(center: Alignment(-0.35, -0.4), colors: [Color(0xFF6FE3D6), Color(0xFF2DBFAD), Color(0xFF1B4F5C)], stops: [0, 0.55, 1]).createShader(rect);
      _shadeP.shader = const RadialGradient(center: Alignment(-0.4, -0.45), radius: 1.1, colors: [Color(0x00000000), Color(0x00000000), Color(0x55061A22)], stops: [0, 0.6, 1]).createShader(rect);
    }
    // drifting clouds behind
    final w = size.width + 120;
    _cloud(canvas, (v * w * 2) % w - 60, size.height * 0.18, 0.9);
    _cloud(canvas, ((v * w + w * 0.55) % w) - 60, size.height * 0.8, 0.7);

    // orbit back half (behind globe)
    final orbit = Rect.fromCenter(center: c, width: r * 2.9, height: r * 0.9);
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(-0.28);
    canvas.translate(-cx, -cy);
    canvas.drawArc(orbit, math.pi, math.pi, false, _orbitP);
    final pa = v * 2 * math.pi * 2; // two orbits per rotation
    final behind = math.sin(pa) < 0;
    if (behind) _drawPlane(canvas, orbit, pa, 0.75);
    canvas.restore();

    canvas.drawCircle(c, r, _seaP);
    // meridians
    final rot = v * 2 * math.pi;
    for (var i = 0; i < 6; i++) {
      final a = rot + i * math.pi / 6;
      final ew = (r * math.cos(a)).abs();
      canvas.drawOval(Rect.fromCenter(center: c, width: ew * 2, height: r * 2), _gridP);
    }
    for (var k = -2; k <= 2; k++) {
      final y = cy + r * k / 3;
      final hw = math.sqrt(math.max(0, r * r - (y - cy) * (y - cy)));
      canvas.drawLine(Offset(cx - hw, y), Offset(cx + hw, y), _gridP);
    }
    // land (front hemisphere only), no allocations: project into a reused buffer
    var n = 0;
    const tilt = 0.35;
    final ct = math.cos(tilt), st = math.sin(tilt);
    for (var i = 0; i < _land.length; i += 2) {
      final lat = _land[i], lon = _land[i + 1] + rot;
      final x = math.cos(lat) * math.sin(lon);
      final y0 = math.sin(lat);
      final z0 = math.cos(lat) * math.cos(lon);
      final y = y0 * ct - z0 * st;
      final z = y0 * st + z0 * ct;
      if (z <= 0.05) continue;
      _buf[n++] = cx + x * r;
      _buf[n++] = cy - y * r;
    }
    canvas.drawRawPoints(PointMode.points, Float32List.sublistView(_buf, 0, n), _landP);
    canvas.drawCircle(c, r, _shadeP);

    // orbit front half + plane in front
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(-0.28);
    canvas.translate(-cx, -cy);
    canvas.drawArc(orbit, 0, math.pi, false, _orbitP);
    if (!behind) _drawPlane(canvas, orbit, pa, 1);
    canvas.restore();
  }

  void _drawPlane(Canvas canvas, Rect orbit, double a, double scale) {
    final px = orbit.center.dx + orbit.width / 2 * math.cos(a);
    final py = orbit.center.dy + orbit.height / 2 * math.sin(a);
    final dx = -orbit.width / 2 * math.sin(a), dy = orbit.height / 2 * math.cos(a);
    canvas.save();
    canvas.translate(px, py);
    canvas.rotate(math.atan2(dy, dx));
    canvas.scale(scale);
    _plane.paint(canvas, Offset(-_plane.width / 2, -_plane.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlobePainter old) => false;
}
