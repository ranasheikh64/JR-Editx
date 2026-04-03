import 'package:go_router/go_router.dart';
import '../../features/home/view/home_page.dart';
import '../../features/editor/view/editor_page.dart';

import '../../features/splash/view/splash_page.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/editor',
        builder: (context, state) {
          final imagePath = state.extra as String?;
          return EditorPage(imagePath: imagePath);
        },
      ),
    ],
  );
}
