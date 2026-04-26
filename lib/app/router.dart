import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_user_screen.dart';
import '../features/auth/screens/register_school_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/home/screens/main_shell.dart';
import '../features/search/screens/search_screen.dart';
import '../features/school_detail/screens/school_detail_screen.dart';
import '../features/school_dashboard/screens/school_dashboard_screen.dart';
import '../features/school_dashboard/screens/menu_editor_screen.dart';
import '../core/models/models.dart';
import '../features/home/screens/user_profile_screen.dart';
import '../features/admin/admin_dashboard_screen.dart';
import '../features/school_dashboard/screens/cyclic_menu_editor_screen.dart';
import '../features/auth/screens/reset_password_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isAuth = authState.isAuthenticated;
      final role = authState.role;
      final isLoading = authState.isLoading;
      final profile = authState.profile; // aggiungi

      if (isLoading) return null;

      // Se autenticato ma profilo non ancora caricato, aspetta
      if (isAuth && profile == null) return null; // aggiungi

      final authRoutes = ['/login', '/register', '/register-school'];
      final isOnAuthRoute =
          authRoutes.any((r) => state.matchedLocation.startsWith(r));

      if (!isAuth && !isOnAuthRoute) return '/login';
      if (isAuth && isOnAuthRoute) {
        if (role == UserRole.admin) return '/admin'; // aggiungi
        return role == UserRole.school ? '/school-dashboard' : '/home';
      }

      if (role == UserRole.user &&
          state.matchedLocation.startsWith('/school-dashboard')) {
        return '/home';
      }

      return null;
    },
    routes: [
      // ─── AUTH ───────────────────────────────────────────────────────────
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (ctx, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (ctx, state) => const RegisterUserScreen(),
      ),
      GoRoute(
        path: '/register-school',
        name: 'register-school',
        builder: (ctx, state) => const RegisterSchoolScreen(),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (ctx, state) => const UserProfileScreen(),
      ),
      GoRoute(
        path: '/admin',
        name: 'admin',
        builder: (ctx, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        name: 'reset-password',
        builder: (ctx, state) => const ResetPasswordScreen(),
      ),

      // ─── USER SHELL (bottom nav) ─────────────────────────────────────
      ShellRoute(
        builder: (ctx, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            name: 'home',
            builder: (ctx, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/search',
            name: 'search',
            builder: (ctx, state) => const SearchScreen(),
          ),
          GoRoute(
            path: '/favorites',
            name: 'favorites',
            builder: (ctx, state) => const HomeScreen(showFavoritesOnly: true),
          ),
        ],
      ),

      // ─── SCHOOL DETAIL (utente vede) ─────────────────────────────────
      GoRoute(
        path: '/school/:id',
        name: 'school-detail',
        builder: (ctx, state) => SchoolDetailScreen(
          schoolId: state.pathParameters['id']!,
        ),
      ),

      // ─── SCHOOL DASHBOARD ─────────────────────────────────────────────
      GoRoute(
        path: '/school-dashboard',
        name: 'school-dashboard',
        builder: (ctx, state) => const SchoolDashboardScreen(),
        routes: [
          GoRoute(
            path: 'menu-editor',
            name: 'menu-editor',
            builder: (ctx, state) {
              final menuId = state.uri.queryParameters['menuId'];
              return MenuEditorScreen(menuId: menuId);
            },
          ),
          GoRoute(
            path: 'cyclic-menu-editor',
            name: 'cyclic-menu-editor',
            builder: (ctx, state) => CyclicMenuEditorScreen(
              menuId: state.uri.queryParameters['menuId'],
            ),
          ),
        ],
      ),
    ],
  );
});
