# LAZYTRAVEL v1

Hebrew-first Flutter app (iOS + Android) for planning a family trip: itinerary, documents, read-only sharing, and AI route generation. Booking / suppliers are **v2** — only empty extension points exist.

Design: teal `#1B4F5C` / `#2DBFAD`, Noto Sans Hebrew, RTL, rounded cards, pill buttons.

## What works in v1

- **Auth:** email + password and magic link (Supabase).
- **Trips:** list, Trip Detail Hub, daily itinerary, place detail, map (OpenStreetMap), budget + expenses.
- **Owner edit:** create/edit days and items (place, time, address, map link, notes).
- **Documents:** upload PDF/images per trip (flight / hotel / insurance / other), in-app viewer (image + PDF), files cached on device.
- **Share:** invite family by email as **viewer** (read-only). Existing users get access immediately; new users are invited and attached on signup.
- **Route wizard:** destination (Places autocomplete via edge function), extra cities, dates, adults + kids, budget, kosher, interests rated 0–3, hotel as daily start/end → Edge Function `generate-route` (Google Places + LLM) writes `trips` / `days` / `items`.
- **Welcome, Home, Explore** match the PNG designs. Unified bottom nav: בית / גילוי / תכנן / קבוצתי / Match.

## Stubbed / placeholders (v2)

- Live Mode, Group Chat, TravelMatch, in-app booking (flights/hotels), votes, shared split-budget.
- Voice search on Explore.
- Scan-from-old-app extras beyond the route wizard (pending old-repo port).

Clean v2 hook: `lib/core/booking/booking_engine.dart` plus empty `bookings` table.

## You need to provide

1. A **Supabase** project (URL + anon key).
2. Secrets for Edge Functions (never put these in the app):
   - `GOOGLE_PLACES_API_KEY`
   - `OPENAI_API_KEY` (optional `OPENAI_MODEL`, default `gpt-4o-mini`)
   - optional `WEATHER_API_KEY` (WeatherAPI.com)
3. Auth email (magic link) working in the Supabase dashboard, plus redirect URL:
   - `com.lazytravel.lazytravel://login-callback/`
4. Store accounts later (TestFlight / Play) — not required to run locally.

The **anon key** is a public client key. Service role and Google/OpenAI keys stay in Edge Function secrets only.

## Flutter run

```bash
flutter pub get
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

Android:

```bash
flutter build apk --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

Without dart-defines the app opens a setup screen instead of crashing.

## Supabase setup

```bash
# one-time
supabase login
supabase link --project-ref YOUR_REF
supabase db push
supabase secrets set GOOGLE_PLACES_API_KEY=... OPENAI_API_KEY=...
supabase functions deploy generate-route
supabase functions deploy places-autocomplete
supabase functions deploy places-search
supabase functions deploy places-photo
supabase functions deploy invite-member
supabase functions deploy suggest-points
supabase functions deploy reorder-day
```

Or paste `supabase/migrations/0001_init.sql` in the SQL editor. That migration creates:

- `profiles`, `trips`, `trip_members` (owner/viewer), `days`, `items`, `documents`, `expenses`, `trip_invites`
- RLS via `trip_members`
- private storage bucket **`trip-docs`** (path `{trip_id}/...`)
- empty `bookings` table for v2

Auth → URL config: add `com.lazytravel.lazytravel://login-callback/` to Redirect URLs. Disable email confirmations in local/dev if you want password sign-up without clicking a mail.

Optional demo trip: see comments in `supabase/seed.sql`.

## Project layout

```
lib/                 Flutter app (Riverpod + go_router + supabase_flutter)
supabase/migrations  Schema + RLS + storage
supabase/functions   Edge functions (Places proxy, generate-route, invite)
extracted-designs/   Original 17 PNG screens
extracted-flutter/   Original 5 static screens (reference)
```

## Deep links

- Android / iOS scheme: `com.lazytravel.lazytravel`
- Host: `login-callback`

Package / application id: `com.lazytravel.lazy_travel`.
