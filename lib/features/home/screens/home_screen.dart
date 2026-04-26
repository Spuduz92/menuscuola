import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/home_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../widgets/school_favorite_card.dart';
import '../widgets/today_menu_card.dart';
import '../../../app/theme.dart';

class HomeScreen extends ConsumerWidget {
  final bool showFavoritesOnly;
  const HomeScreen({super.key, this.showFavoritesOnly = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final favoritesAsync = ref.watch(favoritesProvider);
    final now = DateTime.now();
    final dateStr = DateFormat("EEEE d MMMM", 'it_IT').format(now);
    // Capitalize first letter
    final dateFormatted = dateStr[0].toUpperCase() + dateStr.substring(1);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.forest,
          onRefresh: () => ref.refresh(favoritesProvider.future),
          child: CustomScrollView(
            slivers: [
              // ─── HEADER ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ciao${profile != null ? ', ${profile.displayName.split(' ').first}' : ''} 👋',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: AppColors.muted,
                                  ),
                            ).animate().fadeIn(duration: 400.ms),
                            const SizedBox(height: 4),
                            Text(
                              'OggiAMensa',
                              style: Theme.of(context).textTheme.displaySmall,
                            ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
                          ],
                        ),
                      ),
                      // Avatar
                      GestureDetector(
                        onTap: () => context.go('/profile'),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.sage, AppColors.forest],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              profile?.initials ?? '?',
                              style: GoogleFonts.dmSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
                    ],
                  ),
                ),
              ),

              // ─── DATE ─────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.sageLight.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today_rounded,
                            size: 12, color: AppColors.forest),
                        const SizedBox(width: 6),
                        Text(
                          dateFormatted,
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.forest,
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: 150.ms, duration: 400.ms),
              ),

              // ─── SEARCH BAR ───────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: GestureDetector(
                    onTap: () => context.go('/search'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.warmWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search_rounded,
                              color: AppColors.muted, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'Cerca una scuola…',
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
              ),

              // ─── FAVORITES SECTION ────────────────────────────────────
              favoritesAsync.when(
                loading: () =>
                    SliverToBoxAdapter(child: _buildFavoritesLoading()),
                error: (e, _) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Errore: $e',
                        style: const TextStyle(color: AppColors.error)),
                  ),
                ),
                data: (favorites) {
                  if (favorites.isEmpty) {
                    return SliverToBoxAdapter(
                        child: _buildEmptyFavorites(context));
                  }

                  return SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                          child: Row(
                            children: [
                              const Text('⭐', style: TextStyle(fontSize: 14)),
                              const SizedBox(width: 6),
                              Text(
                                'Preferite',
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.muted,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 250.ms),

                        // Horizontal scroll favorites
                        SizedBox(
                          height: 120,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            itemCount: favorites.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (ctx, i) => SchoolFavoriteCard(
                              school: favorites[i],
                              index: i,
                            ).animate().fadeIn(
                                delay: Duration(milliseconds: 300 + i * 60)),
                          ),
                        ),

                        // Today menu for each favorite
                        ...favorites.map((school) => TodayMenuCard(
                              school: school,
                              index: favorites.indexOf(school),
                            )),
                      ],
                    ),
                  );
                },
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFavoritesLoading() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Shimmer.fromColors(
        baseColor: AppColors.border,
        highlightColor: AppColors.warmWhite,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
                width: 80,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                )),
            const SizedBox(height: 14),
            Row(
              children: List.generate(
                  3,
                  (i) => Padding(
                        padding: EdgeInsets.only(right: i < 2 ? 12 : 0),
                        child: Container(
                          width: 130,
                          height: 110,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      )),
            ),
            const SizedBox(height: 20),
            Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyFavorites(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.sageLight.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child:
                const Center(child: Text('⭐', style: TextStyle(fontSize: 36))),
          ),
          const SizedBox(height: 20),
          Text(
            'Nessuna scuola preferita',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Cerca la scuola di tuo figlio e aggiungila ai preferiti per vedere il menu ogni giorno.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.muted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 200,
            child: ElevatedButton.icon(
              onPressed: () => context.go('/search'),
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const Text('Cerca scuola'),
            ),
          ),
        ],
      ).animate().fadeIn(delay: 300.ms, duration: 500.ms),
    );
  }
}
