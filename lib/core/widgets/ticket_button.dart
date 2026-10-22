import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../theme/app_colors.dart';

/// A bookable ticket for an itinerary item, from the `tickets` edge function
/// (LiteAPI Experiences when matched with high confidence, else a tracked partner search).
class TicketOffer {
  TicketOffer(this.m);
  final Map<String, dynamic> m;
  String get provider => m['provider'] as String;
  String get partner => (m['partner_name'] as String?) ?? 'Tiqets';
  String? get url => m['url'] as String?;
  num? get price => m['price'] as num?;
  String? get currency => m['currency'] as String?;
  bool get native => provider == 'liteapi';
}

/// Offers for every item of a trip, keyed by item id. Cached server-side (7 days).
final ticketOffersProvider = FutureProvider.family<Map<String, TicketOffer>, String>((ref, tripId) async {
  try {
    final res = await Supabase.instance.client.functions.invoke('tickets', body: {'trip_id': tripId});
    final offers = (res.data is Map ? res.data['offers'] : null) as Map? ?? {};
    return offers.map((k, v) => MapEntry(k as String, TicketOffer(Map<String, dynamic>.from(v as Map))));
  } catch (_) {
    return {};
  }
});

String _sym(String? c) => switch (c) { 'ILS' => '₪', 'EUR' => '€', 'USD' => '\$', _ => c ?? '' };

/// 'קנה כרטיס · מ-₪X' – hidden when no confident match exists for the place.
class TicketButton extends ConsumerWidget {
  const TicketButton({super.key, required this.tripId, required this.itemId, this.compact = false});
  final String tripId;
  final String itemId;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = ref.watch(ticketOffersProvider(tripId)).valueOrNull?[itemId];
    if (o == null) return const SizedBox.shrink();
    final price = o.price != null ? ' · מ-${_sym(o.currency)}${o.price!.round()}' : '';
    return Padding(
      padding: EdgeInsets.only(top: compact ? 10 : 0, bottom: compact ? 0 : 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _open(context, o),
          child: Ink(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 9 : 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(colors: [Color(0xFFFF8A5B), Color(0xFFFF6B4A)]),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.confirmation_number_outlined, size: 18, color: Colors.white),
                const SizedBox(width: 6),
                Text('קנה כרטיס$price',
                    style: GoogleFonts.notoSansHebrew(color: Colors.white, fontWeight: FontWeight.w800, fontSize: compact ? 13 : 15)),
                const SizedBox(width: 6),
                Text('· ${o.partner}', style: GoogleFonts.notoSansHebrew(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, TicketOffer o) {
    if (o.url == null) return; // native LiteAPI checkout: enabled once Experiences access is granted
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PartnerWebViewScreen(partner: o.partner, url: o.url!)));
  }
}

/// In-app browser clearly labelled with the selling partner (they are merchant of record).
class PartnerWebViewScreen extends StatefulWidget {
  const PartnerWebViewScreen({super.key, required this.partner, required this.url});
  final String partner;
  final String url;
  @override
  State<PartnerWebViewScreen> createState() => _PartnerWebViewScreenState();
}

class _PartnerWebViewScreenState extends State<PartnerWebViewScreen> {
  late final WebViewController _c;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(onProgress: (p) => setState(() => _progress = p)))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primaryDark,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('רכישה דרך ${widget.partner}', style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w800, fontSize: 16)),
          Text('התשלום מתבצע אצל ${widget.partner}', style: GoogleFonts.notoSansHebrew(fontSize: 11, color: AppColors.textBody)),
        ]),
        bottom: _progress < 100
            ? PreferredSize(preferredSize: const Size.fromHeight(3), child: LinearProgressIndicator(value: _progress / 100, minHeight: 3))
            : null,
      ),
      body: WebViewWidget(controller: _c),
    );
  }
}
