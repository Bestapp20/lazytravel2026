import 'package:flutter/material.dart';

/// One visual language for place categories: map markers, timeline nodes, chips.
class CatStyle {
  const CatStyle(this.key, this.icon, this.color, this.label);
  final String key;
  final IconData icon;
  final Color color;
  final String label;
}

const _styles = <String, CatStyle>{
  'museum': CatStyle('museum', Icons.museum_rounded, Color(0xFF7E57C2), 'מוזיאון'),
  'cafe': CatStyle('cafe', Icons.local_cafe_rounded, Color(0xFF8D6E63), 'בית קפה'),
  'restaurant': CatStyle('restaurant', Icons.restaurant_rounded, Color(0xFFF4511E), 'מסעדה'),
  'bar': CatStyle('bar', Icons.local_bar_rounded, Color(0xFFD81B60), 'בר וחיי לילה'),
  'beach': CatStyle('beach', Icons.beach_access_rounded, Color(0xFF039BE5), 'חוף'),
  'park': CatStyle('park', Icons.park_rounded, Color(0xFF43A047), 'פארק וטבע'),
  'temple': CatStyle('temple', Icons.church_rounded, Color(0xFFB8860B), 'מקדש / כנסייה'),
  'market': CatStyle('market', Icons.storefront_rounded, Color(0xFFFB8C00), 'שוק וקניות'),
  'viewpoint': CatStyle('viewpoint', Icons.landscape_rounded, Color(0xFF00897B), 'תצפית'),
  'hotel': CatStyle('hotel', Icons.hotel_rounded, Color(0xFF3949AB), 'מלון'),
  'flight': CatStyle('flight', Icons.flight_rounded, Color(0xFF1E88E5), 'טיסה'),
  'transport': CatStyle('transport', Icons.directions_car_filled_rounded, Color(0xFF546E7A), 'העברה'),
  'boat': CatStyle('boat', Icons.directions_boat_filled_rounded, Color(0xFF0277BD), 'שייט'),
  'attraction': CatStyle('attraction', Icons.attractions_rounded, Color(0xFF26A69A), 'אטרקציה'),
};

/// Resolve the display category. Legacy values (food/nature/shopping/nightlife) are refined from the
/// place name so older trips get the right icon without touching their data.
CatStyle catStyle(String? category, [String name = '']) {
  final n = name.toLowerCase();
  bool any(List<String> k) => k.any(n.contains);
  var c = category ?? 'attraction';
  if (c == 'transport' && any(['סירה', 'boat', 'ferry', 'מעבורת', 'speedboat'])) c = 'boat';
  if (const {'food', 'nature', 'shopping', 'nightlife', 'attraction'}.contains(c)) {
    if (any(['beach', 'חוף', 'plage', 'playa'])) {
      c = 'beach';
    } else if (any(['viewpoint', 'lookout', 'תצפית', 'panoram'])) {
      c = 'viewpoint';
    } else if (any(['church', 'cathedral', 'basilica', 'temple', 'mosque', 'tekke', 'buddha', 'בודהה', 'מקדש', 'כנסי', 'wat '])) {
      c = 'temple';
    } else if (any(['market', 'שוק', 'mercato', 'bazaar', 'village', 'ויליג'])) {
      c = 'market';
    } else if (any(['האיים', 'island', 'boat', 'סירה'])) {
      c = 'boat';
    } else if (any(['museum', 'מוזיאון'])) {
      c = 'museum';
    } else if (any(['café', 'cafe', 'coffee', 'קפה', 'bakery'])) {
      c = 'cafe';
    } else {
      c = switch (c) { 'food' => 'restaurant', 'nature' => 'park', 'shopping' => 'market', 'nightlife' => 'bar', _ => c };
    }
  }
  return _styles[c] ?? _styles['attraction']!;
}

/// Category marker: colored icon bubble + small order badge; selected = larger with a halo.
class CategoryMarker extends StatelessWidget {
  const CategoryMarker({super.key, required this.style, this.order, this.selected = false, this.size = 40});
  final CatStyle style;
  final int? order;
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = selected ? size * 1.25 : size;
    return AnimatedScale(
      scale: 1,
      duration: const Duration(milliseconds: 200),
      child: SizedBox(
        width: s + 10,
        height: s + 10,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            if (selected)
              Container(
                width: s + 10,
                height: s + 10,
                decoration: BoxDecoration(shape: BoxShape.circle, color: style.color.withValues(alpha: 0.25)),
              ),
            Container(
              width: s,
              height: s,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: style.color,
                border: Border.all(color: Colors.white, width: selected ? 3.5 : 2.5),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: Icon(style.icon, color: Colors.white, size: s * 0.52),
            ),
            if (order != null)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: style.color, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text('$order', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: style.color, height: 1)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
