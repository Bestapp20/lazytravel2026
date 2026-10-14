# LAZYTRAVEL — Build Plan (v1)

## 1. What we received
- `a/` Flutter project (`lazy_travel`, deps: google_fonts, flutter_svg, provider). ~3.8k lines, static UI, Hebrew RTL, Noto Sans Hebrew. Named routes: `/`, `/wizard/step1-3`, `/ai-generation`. All data hard-coded; most `onTap: () {}`.
- `b/` 17 PNG designs, 430×932 (iPhone Pro Max frame).

## 2. Screens — status
| # | Screen | Content (from design) | Code |
|---|---|---|---|
| 1 | Welcome | Hero photo, "כל הטיול שלך במקום אחד", popular trip carousel (NY/Santorini/Tokyo), "התחל לתכנן", "יש לי כבר חשבון" | ❌ |
| 2 | Home | Greeting, my trips (planned/active/done), AI-picked destinations, deals "מ-₪2,400", FAB → wizard | ✅ static |
| 3 | Explore | Search + voice, category chips (popular/weekend/couples/family), AI advisor card, recommended destinations, weekend picks, bottom nav | ❌ |
| 4 | Wizard 1 | Destinations (multi), dates, optional flight/hotel details | ✅ static (needs flexible-dates + origin + travelers for booking) |
| 5 | Wizard 2 | Companions, pace, budget tier | ✅ static |
| 6 | Wizard 3 | Interests, kosher toggle, "תבנה לי את הטיול" | ✅ static |
| 7 | AI Generation | Progress steps, day preview, "ידעת?" tip | ✅ static (fake animation) |
| 8 | Trip Detail Hub | Hero, dates/nights/travelers, readiness % (flight/hotel/docs), tabs מסלול/לוגיסטיקה/תקציב, day chips, timeline | ❌ |
| 9 | Daily Itinerary | Day header, weather/steps/km/budget chips, list/map toggle, place cards w/ AI tips, walking legs | ❌ |
| 10 | Map View | Map w/ numbered route, category filters, place bottom sheet, navigate | ❌ |
| 11 | Budget | Total vs spent ring, per-day, AI warning, per-category bars, add expense | ❌ |
| 12 | Place Detail | Gallery, rating, address, hours, price, AI recommendation, save/navigate/swap | ❌ |
| 13 | Live Mode | Live map, weather, daily progress stepper, "now" card, AI center button | ❌ |
| 14 | Group Trip Detail | Members, tabs מסלול/צ'אט/תקציב/חברים, suggested places w/ votes | ❌ |
| 15 | Group Chat | Messages, reactions, polls, AI assistant (VoyagerAI) messages | ❌ |
| 16 | TravelMatch | Find travel partners: filters, match %, profile card, request to join | ❌ |
| 17 | Traveler Profile | Avatar, stats, travel style, interests | ❌ |
| NEW | Booking engine | Search results (flight+hotel packages), detail, passenger form, checkout, confirmation, my bookings | ❌ not designed |

**Summary:** 5/17 coded (UI only), 12 + booking flow missing. Zero backend, state, auth, navigation consistency (bottom nav varies between designs — needs unifying).

## 3. Design system
- Colors (`app_colors.dart`): primaryDark #1B4F5C, accent #2DBFAD, accentLight #3DD6C6, bgLight #F0FAFA, textDark #0D2B35, textBody #4A7A87, border #C8E8E8, success #27AE60, warning #F39C12.
- Font Noto Sans Hebrew; RTL; large radii (16–24), soft shadows, teal gradient CTAs, pill chips, emoji accents, photo-heavy cards.
- Action: extract shared widgets (PrimaryButton, Chip, PlaceCard, DayTabs, SectionHeader, BottomNav, TripHero) + `ThemeData` + `Directionality.rtl` + l10n (he first, en later). Replace `status_bar_widget` (design artifact).

## 4. Architecture
- **App:** Flutter (iOS/Android/Web), Riverpod (or keep provider), go_router, freezed models, supabase_flutter, google_maps_flutter / mapbox, flutter_stripe.
- **Backend:** Supabase — Auth (Google/Apple/phone), Postgres + RLS, Storage, Realtime (group chat, live), Edge Functions (all API keys & booking logic server-side).
- **AI:** Edge Function calling LLM w/ structured JSON output → itinerary; Google Places API for real places/photos/hours; weather API.
- **Booking (stay in-app):**
  - Flights: **Duffel** (search → offer → order, in-app; Duffel Payments or own Stripe w/ balance). Alt: Amadeus Self-Service (booking needs consolidator/IATA), Kiwi Tequila (flex dates/virtual interlining).
  - Hotels: **LiteAPI** (fastest onboarding, in-app booking, commission) → later Hotelbeds / Expedia Rapid (need approval/volume).
  - Extras: transfers/activities via Viator / GetYourGuide partner API, eSIM (Airalo), insurance later.
  - Payments: **Stripe** (PaymentSheet, Apple/Google Pay). Merchant-of-record model decides cash flow.
  - Flexible dates: search grid (±3 days / month range) via cached calendar searches + package scoring (total price, duration, stops, hotel rating vs. user budget tier).
- **Legal/merchant setup needed:** company entity, Stripe account (Israel supported), Duffel account+KYC & balance top-up, hotel API contracts, Israeli travel-agency licensing (משרד התיירות — סוכן נסיעות) / consumer-protection cancellation rules, terms & privacy (GDPR/Israeli Privacy Law), PCI handled by Stripe, refund/cancel policy, customer support for disruptions.

## 5. Data model (Supabase)
- `profiles`(id, name, avatar, city, bio, travel_style, interests[], kosher, stats)
- `trips`(id, owner_id, title, destinations jsonb, start, end, flexible bool, travelers, companion_type, pace, budget_tier, budget_total, status, is_group)
- `trip_members`(trip_id, user_id, role)
- `trip_days`(id, trip_id, day_index, date, weather jsonb)
- `itinerary_items`(id, day_id, place_id, start_time, duration, order, ai_tip, transport_to_next jsonb)
- `places`(id, google_place_id, name, category, lat, lng, rating, price_level, hours jsonb, photos[])
- `expenses`(id, trip_id, category, amount, currency, paid_by, date)
- `search_requests`(id, user_id, params jsonb, created_at) / `offers_cache`(provider, key, payload, expires_at)
- `bookings`(id, trip_id, user_id, type flight|hotel|activity, provider, provider_ref, status, amount, currency, payload jsonb)
- `payments`(id, booking_id, stripe_pi, status, amount)
- `passengers`(id, user_id, names, dob, passport enc.)
- `messages`(id, trip_id, user_id|ai, body, type text|poll|suggestion, reactions jsonb)
- `place_votes`(trip_id, place_id, user_id)
- `match_profiles` / `match_requests`(from, to, trip_id, status)

## 6. Fast-build roadmap
- **Phase 0 (2–3 days):** restructure project (features/, core/theme, widgets), go_router, Supabase project + schema + auth, Welcome screen.
- **Phase 1 MVP (2–3 wks):** Home, Explore, Wizard 1-3 (+ origin, travelers, flexible dates), AI generation (real), Trip Hub, Daily Itinerary, Place Detail, Map View, Budget. Booking: Duffel flight search+book (test mode) + LiteAPI hotels, results screen with "best package", Stripe checkout, My bookings.
- **Phase 2 (2 wks):** Live Mode, notifications, booking management (cancel/change), price alerts on flexible dates, extras (activities/transfers).
- **Phase 3 (2–3 wks):** Group trip + chat (Realtime), votes, shared budget split, TravelMatch, Profile, moderation/safety.
- Launch: store assets, legal docs, production keys.

## 7. Open questions
1. Platforms: iOS+Android only, or Web too? Hebrew only or also English?
2. Business model: commission/markup on bookings, subscription, or both? Who is merchant of record?
3. Do you have (or plan) a company + travel-agency license? Existing Stripe/Duffel/hotel accounts?
4. MVP booking scope: flights+hotels only first, or also cars/activities/insurance?
5. Origin airport default TLV? Currency ILS only?
6. Flexible dates definition: "any weekend in month X", "±N days", or "cheapest in range of trip length N"?
7. Group trips & TravelMatch in MVP or later? (social = safety/moderation work)
8. Which AI provider/budget per itinerary? Kosher filter — restaurants only or also Shabbat-aware planning?
9. Design for booking results/checkout screens — should I design in same style, or will you supply PNGs?
10. What exactly did the "travel bot" specify for the booking part (if parent got details)?
11. Timeline/target launch date; who deploys to stores (Apple/Google dev accounts)?

## Input from the travel bot (real-trip lessons)
- Search params needed: multi-stop routes, flexible range (month/season, N–M nights), total budget in ILS, passengers with child ages (15+ = adult fare), number of rooms, baggage-included as hard filter, hotel stars/rating, distance to center/beach, lodging type, internal transport preference (flight/boat/no minivan).
- Results that worked: one total package price vs budget, breakdown (flights/hotels/transport), alternatives comparison (different start/stop/return city).
- Pitfalls to solve: missing carrier prices, agent vs airline price gaps, ambiguous per-room vs total hotel prices, "1 left" availability, hotel prices jumping between dates -> always show total for all rooms, re-price before checkout.

## Revised v1 scope (user priority, 2026-10-14)
v1 = Edward can load the trip he planned for his parents and they view it nicely in the app. Suppliers/booking move to v2.
- Trip → Days → Items (place, time, address/map link, notes)
- Documents per trip/day/item: upload PDF/image (flight tickets, hotel vouchers, insurance) to Supabase Storage, viewer + offline cache
- Share trip with parents (invite by email/phone, read-only role)
- Scan feature ported from old app (Bestapp20/LazyTravels, old Flutter app) — PENDING repo access
Tables: trips, trip_members(role), days, items, documents(storage_path, type, item_id nullable). RLS by trip_members. Bucket `trip-docs` (private).
Build steps: 1) Supabase schema+RLS+bucket 2) Flutter auth + trip list 3) trip/day/item screens (reuse 5 existing coded screens' styling) 4) upload+viewer 5) sharing 6) port scan 7) seed parents' trip, TestFlight/APK.

## Existing old Flutter app (LazyTravels) — read 2026-10-14
Repo Bestapp20/LazyTravels (main). Flutter + flutter_bloc, Firebase phone-SMS auth, i18n en/he/ru, Google Maps. All logic lives on an external REST backend `https://lazytravels.site/api/v1/` (backend code NOT in repo). No feature literally named "scan" — the closest is the **route generation wizard** ("A route is being compiled for you").

### Route generation ("scan") flow
1. Choose country/city (Google Places Autocomplete `types=(regions)` + Place Details) — choose_country_screen
2. Dates, people, kids, budget range (slider), kashrut, option, restaurants/bars toggles — choose widgets/dialogs
3. Interests with weight 0-3 (Not at all/Some/Much/Very much) from `GET preferance/options` — choose_interesting_screen
4. Hotel as daily start/end point (Google Places Text Search type=lodging) or "no hotel" — choose_hotel_screen
5. Optional extra cities (`childs` = nested requests)
6. `POST route/create/` with SendRouteInfoModel → server returns RouteDataModel: days[] (date, weather) → points[] (name, place_id, lat/lng, start/end time, duration, order, image, description, rating, icon)
Other endpoints: route/edite, route/last, route/list (paged), route/order/{route}/{day} (reorder), route/intereset-best-points/{interest}/{day} (suggestions), route/add-point, route/search-point (+next_page), route/day-went, went-place/set-went-rating, preferance/check-country, famous_place/get-famous-place/{id} (video), account/set-notification.
Other features: onboarding, login/register/OTP, home (flights/apartments/attractions = coming soon), map route screen with day info, weather, navigation, currency calculator, chat, profile with visited-countries map, rating dialog.

### Port to Supabase
- Edge fn `generate-route`: input = SendRouteInfoModel JSON; calls Google Places (Nearby/Text Search per interest, weighted) + LLM to pick & order points per day around hotel, time slots; writes trips/days/items. Env: GOOGLE_PLACES_API_KEY, OPENAI_API_KEY (or chosen LLM), WEATHER_API_KEY.
- Edge fns `places-autocomplete`, `places-search` (proxy Google so key isn't in app), `suggest-points`, `reorder-day`.
- Tables map: route→trips, RouteDay→days, RoutePoint→items, interests/route_interests, ratings.
### Reusable directly
models (route_data_model, send_route_info_model, google/*), choose/* wizard screens+widgets, route/* map screens, widget/map/* (day_info, weather, route_edit), sliders, number picker, pin_put, map_helper/map_marker, i18n json (he/ru/en), icons, map_style.json. Replace ApiProvider/repositories with supabase_flutter; drop Firebase auth for Supabase auth.
### Security issues (fix now)
Hardcoded Google API key in lib/src/provider/api_provider.dart; `AuthKey_3TTKX6CKWS.p8` (Apple key) and `lazy_travel.jks` (Android keystore) committed. Rotate/restrict and remove from git history.
