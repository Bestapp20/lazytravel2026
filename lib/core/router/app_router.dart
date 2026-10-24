import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/setup_screen.dart';
import '../../features/auth/verify_email_screen.dart';
import '../../features/bookings/my_bookings_screen.dart';
import '../../features/documents/document_viewer_screen.dart';
import '../../features/documents/documents_screen.dart';
import '../../features/explore/explore_screen.dart';
import '../../features/finder/finder_screens.dart';
import '../../features/home/home_screen.dart';
import '../../features/placeholders/group_screens.dart';
import '../../features/placeholders/live_mode_screen.dart';
import '../../features/placeholders/travel_match_screen.dart';
import '../../features/profile/traveler_profile_screen.dart';
import '../../features/sharing/share_trip_screen.dart';
import '../../features/trips/budget_screen.dart';
import '../../features/trips/daily_itinerary_screen.dart';
import '../../features/trips/add_place_screen.dart';
import '../../features/trips/edit_item_screen.dart';
import '../../features/trips/map_view_screen.dart';
import '../../features/trips/place_detail_screen.dart';
import '../../features/trips/trip_hub_screen.dart';
import '../../features/welcome/welcome_screen.dart';
import '../../features/wizard/ai_generation_screen.dart';
import '../../features/wizard/wizard_step1_screen.dart';
import '../../features/wizard/wizard_step2_screen.dart';
import '../../features/wizard/wizard_step3_screen.dart';
import '../config/app_config.dart';

class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(authStateProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);
  return GoRouter(
    initialLocation: AppConfig.isConfigured ? '/welcome' : '/setup',
    refreshListenable: refresh,
    redirect: (context, state) {
      if (!AppConfig.isConfigured) {
        return state.uri.path == '/setup' ? null : '/setup';
      }
      final loc = state.uri.path;
      final loggedIn = ref.read(authRepositoryProvider)?.session != null;
      const public = ['/welcome', '/login', '/setup', '/verify-email'];
      if (!loggedIn && !public.contains(loc)) return '/welcome';
      if (loggedIn && (loc == '/welcome' || loc == '/login' || loc == '/setup')) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/setup', builder: (_, _) => const SetupScreen()),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
      GoRoute(path: '/finder', builder: (_, _) => const FinderFormScreen()),
      GoRoute(
        path: '/finder/:searchId',
        builder: (_, s) => FinderResultsScreen(searchId: s.pathParameters['searchId']!),
      ),
      GoRoute(
        path: '/finder/:searchId/offer/:offerId',
        builder: (_, s) => FinderOfferScreen(offerId: s.pathParameters['offerId']!),
      ),
      GoRoute(path: '/explore', builder: (_, _) => const ExploreScreen()),
      GoRoute(path: '/group', builder: (_, _) => const GroupPlaceholderScreen()),
      GoRoute(path: '/match', builder: (_, _) => const TravelMatchScreen()),
      GoRoute(path: '/profile', builder: (_, _) => const TravelerProfileScreen()),
      GoRoute(path: '/bookings', builder: (_, _) => const MyBookingsScreen()),
      GoRoute(
        path: '/verify-email',
        builder: (_, s) => VerifyEmailScreen(email: (s.extra as String?) ?? s.uri.queryParameters['email'] ?? ''),
      ),
      GoRoute(path: '/wizard/step1', builder: (_, _) => const WizardStep1Screen()),
      GoRoute(path: '/wizard/step2', builder: (_, _) => const WizardStep2Screen()),
      GoRoute(path: '/wizard/step3', builder: (_, _) => const WizardStep3Screen()),
      GoRoute(path: '/wizard/generating', builder: (_, _) => const AiGenerationScreen()),
      GoRoute(
        path: '/trips/:id',
        builder: (_, s) => TripHubScreen(tripId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/trips/:id/day/:dayId',
        builder: (_, s) => DailyItineraryScreen(
          tripId: s.pathParameters['id']!,
          dayId: s.pathParameters['dayId']!,
        ),
      ),
      GoRoute(
        path: '/trips/:id/map',
        builder: (_, s) => MapViewScreen(
          tripId: s.pathParameters['id']!,
          dayId: s.uri.queryParameters['day'],
        ),
      ),
      GoRoute(
        path: '/trips/:id/budget',
        builder: (_, s) => BudgetScreen(tripId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/trips/:id/place/:itemId',
        builder: (_, s) => PlaceDetailScreen(
          tripId: s.pathParameters['id']!,
          itemId: s.pathParameters['itemId']!,
        ),
      ),
      GoRoute(
        path: '/trips/:id/item/add',
        builder: (_, s) => AddPlaceScreen(
          tripId: s.pathParameters['id']!,
          dayId: s.uri.queryParameters['day'],
        ),
      ),
      GoRoute(
        path: '/trips/:id/item/edit',
        builder: (_, s) => EditItemScreen(
          tripId: s.pathParameters['id']!,
          dayId: s.uri.queryParameters['day'],
          itemId: s.uri.queryParameters['item'],
        ),
      ),
      GoRoute(
        path: '/trips/:id/docs',
        builder: (_, s) => DocumentsScreen(tripId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/trips/:id/docs/:docId',
        builder: (_, s) => DocumentViewerScreen(
          tripId: s.pathParameters['id']!,
          docId: s.pathParameters['docId']!,
        ),
      ),
      GoRoute(
        path: '/trips/:id/share',
        builder: (_, s) => ShareTripScreen(tripId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/trips/:id/live',
        builder: (_, s) => LiveModeScreen(tripId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/trips/:id/chat',
        builder: (_, s) => GroupChatScreen(tripId: s.pathParameters['id']!),
      ),
    ],
  );
});
