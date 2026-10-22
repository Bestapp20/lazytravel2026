# Attraction tickets ("קנה כרטיס") — provider research (2026-10-22)

## 1. LiteAPI / Nuitee Experiences (preferred: native, merchant of record = LiteAPI/Nuitee via Stripe SDK)
- Endpoints (base https://api.liteapi.travel/v3.0, X-API-Key): GET /experiences/tours (search),
  /tours/{id}, /tours/{id}/availability, POST /tours/{id}/booking-options, POST /tours/{id}/prebooks
  (usePaymentSdk:true -> transactionId + secretKey for Stripe, same as the flight flow), POST /experiences/bookings,
  GET /experiences/bookings/{id}, cancel-preview / cancel.
- Earnings: booking-options slots expose totals.commission; booking returns price / commission / clientCommission.
- **Status on this account: 403 code 40301 "Experiences API access is not enabled for this account. Please
  contact support to get access"** (sandbox key sand_…, tested 2026-10-22). Selecting Experiences at signup is not enough:
  Edward must request access (dashboard / support), then production access separately.
- The edge function already calls it first and switches to native results automatically once access is on.

## 2. Travelpayouts affiliate fallback (marker 744429)
- Redirect format: https://tp.media/r?marker=744429&p=<program>&u=<urlencoded partner url>
  - p=2074 Tiqets -> tiqets.com/...?partner=travelpayouts.com&tq_campaign=…-744429 (verified 302)
  - p=4110 Klook -> affiliate.klook.com/redirect?aid=…744429… (verified 302)
  - GetYourGuide: program id unknown until joined (set secret TP_GYG_P).
- links/v1/create API needs `trs` (project id) – returns "invalid traffic source" without it. Optional secret TP_TRS.
- Commission (Travelpayouts listing): Tiqets ~8%, GetYourGuide 7-10% (web only, not GYG app), Klook 2-5%,
  Viator ~4-10%. Merchant of record = the partner; user pays on partner site; cookie 30 days.
- Redirect carries the marker even before joining, but **rewards only accrue for programs Edward joined** in the
  Travelpayouts dashboard: Tiqets (must), GetYourGuide, Klook (optional).
- No public product/price API via Travelpayouts, so affiliate buttons show "קנה כרטיס" without a price and open
  the partner's search for the exact place name + city (never a guessed product).
