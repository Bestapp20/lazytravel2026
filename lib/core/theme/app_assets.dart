class AppAssets {
  static const logo =
      'assets/images/2ef5382b7_lazy_travel_logo-removebg-preview.png';
  static const avatarEdward =
      'assets/images/young_man_edward_profile_portrait_warm_smile_casual_style.jpg';
  static const globe =
      'assets/images/vibrant_3d_globe_illustration_teal_cyan_location_pins_map_routes_sparkles_ocean_teal_color_palette_modern_travel_app_style_transparent_background.png';
  static const barcelonaHero =
      'assets/images/barcelona_skyline_sagrada_familia_aerial_golden_hour_warm_light_spain.jpg';
  static const barcelonaStreet =
      'assets/images/barcelona_gothic_quarter_narrow_streets_warm_evening_light_spain.jpg';
  static const tokyo =
      'assets/images/tokyo_shibuya_crossing_night_neon_lights_busy_intersection_japan.jpg';
  static const santorini =
      'assets/images/santorini_oia_blue_domes_white_buildings_caldera_view_sunset.jpg';
  static const lisbon =
      'assets/images/lisbon_alfama_district_colorful_tiled_buildings_tram_hilltop_view_portugal.jpg';
  static const kyoto =
      'assets/images/kyoto_arashiyama_bamboo_grove_morning_light_misty_green_japan.jpg';
  static const amalfi =
      'assets/images/amalfi_coast_italy_colorful_cliffside_villages_turquoise_mediterranean_sea_summer.jpg';
  static const bali =
      'assets/images/bali_indonesia_rice_terraces_tropical_lush_greenery_palm_trees.jpg';
  static const rome =
      'assets/images/rome_colosseum_aerial_golden_hour_ancient_rome_italy_tourism.jpg';

  static const cardFlight = 'assets/images/card_flight.jpg';
  static const cardBoat = 'assets/images/card_boat.jpg';
  static const cardTransfer = 'assets/images/card_transfer.jpg';

  static String forDestination(String? city) {
    final c = (city ?? '').toLowerCase();
    if (c.contains('barc')) return barcelonaHero;
    if (c.contains('tokyo') || c.contains('טוק')) return tokyo;
    if (c.contains('santo') || c.contains('סנט')) return santorini;
    if (c.contains('lisb') || c.contains('ליס')) return lisbon;
    if (c.contains('kyoto') || c.contains('קיו')) return kyoto;
    if (c.contains('amalf') || c.contains('אמאל')) return amalfi;
    if (c.contains('bali') || c.contains('באלי')) return bali;
    if (c.contains('rome') || c.contains('roma') || c.contains('רומא')) {
      return rome;
    }
    return barcelonaHero;
  }
}

class InterestDef {
  const InterestDef(this.id, this.emoji, this.label);
  final String id;
  final String emoji;
  final String label;
}

const kInterests = <InterestDef>[
  InterestDef('food', '🍽️', 'אוכל'),
  InterestDef('nightlife', '🎉', 'חיי לילה'),
  InterestDef('culture', '🎭', 'תרבות'),
  InterestDef('history', '🏛️', 'היסטוריה'),
  InterestDef('nature', '🌿', 'טבע'),
  InterestDef('shopping', '🛍️', 'קניות'),
  InterestDef('museums', '🖼️', 'מוזיאונים'),
  InterestDef('attractions', '✨', 'אטרקציות'),
  InterestDef('photography', '📷', 'צילום'),
  InterestDef('kids', '👶', 'ילדים'),
  InterestDef('hidden', '🗺️', 'מקומות מיוחדים'),
];
