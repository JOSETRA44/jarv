import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../presentation/pages/splash/splash_page.dart';
import '../../presentation/pages/setup/setup_page.dart';
import '../../presentation/widgets/main_scaffold.dart';


final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/setup',
        builder: (context, state) => const SetupPage(),
      ),
      GoRoute(
        path: '/terminal',
        builder: (context, state) => const MainScaffold(initialIndex: 0),
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const MainScaffold(initialIndex: 1),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const MainScaffold(initialIndex: 2),
      ),
      GoRoute(
        path: '/control',
        builder: (context, state) => const MainScaffold(initialIndex: 3),
      ),
    ],
  );
});
