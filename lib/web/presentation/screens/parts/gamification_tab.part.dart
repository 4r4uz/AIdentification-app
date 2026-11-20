part of '../admin_dashboard_screen.dart';

class _GamificationTab extends StatefulWidget {
  final AdminService adminService;

  const _GamificationTab({required this.adminService});

  @override
  State<_GamificationTab> createState() => _GamificationTabState();
}

class _GamificationTabState extends State<_GamificationTab> {
  static const int _pageSize = 50;

  final TextEditingController _achievementSearchController =
      TextEditingController();
  final TextEditingController _triviaSearchController = TextEditingController();

  late Future<AdminPageResult> _achievementsFuture;
  late Future<AdminPageResult> _triviasFuture;

  int _achievementPage = 0;
  int _triviaPage = 0;
  String _difficulty = 'Todas';
  Timer? _achievementDebounce;
  Timer? _triviaDebounce;

  @override
  void initState() {
    super.initState();
    _reloadAchievements();
    _reloadTrivias();
  }

  @override
  void dispose() {
    _achievementDebounce?.cancel();
    _triviaDebounce?.cancel();
    _achievementSearchController.dispose();
    _triviaSearchController.dispose();
    super.dispose();
  }

  void _reloadAchievements() {
    setState(() {
      _achievementsFuture = widget.adminService.getAchievementsPage(
        page: _achievementPage,
        pageSize: _pageSize,
        search: _achievementSearchController.text.trim(),
      );
    });
  }

  void _reloadTrivias() {
    setState(() {
      _triviasFuture = widget.adminService.getTriviasPage(
        page: _triviaPage,
        pageSize: _pageSize,
        search: _triviaSearchController.text.trim(),
        difficulty: _difficulty,
      );
    });
  }

  Widget _pageTabs({
    required int count,
    required int currentPage,
    required ValueChanged<int> onPageChanged,
  }) {
    final pageCount = count == 0 ? 0 : ((count + _pageSize - 1) ~/ _pageSize);
    if (pageCount <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: pageCount,
          separatorBuilder: (_, _) => const SizedBox(width: 6),
          itemBuilder: (context, index) {
            final start = index * _pageSize + 1;
            final end = ((index + 1) * _pageSize).clamp(0, count);
            final selected = index == currentPage;
            return TextButton(
              onPressed: () => onPageChanged(index),
              style: TextButton.styleFrom(
                backgroundColor: selected
                    ? AppColors.primary
                    : AppColors.surfaceElevated,
                foregroundColor: selected
                    ? Colors.black
                    : AppColors.textPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text('$start-$end'),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Logros e Insignias', style: AppTheme.headingStyle()),
          const SizedBox(height: 12),
          TextField(
            controller: _achievementSearchController,
            onChanged: (_) {
              _achievementDebounce?.cancel();
              _achievementDebounce = Timer(
                const Duration(milliseconds: 300),
                () {
                  _achievementPage = 0;
                  _reloadAchievements();
                },
              );
            },
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Buscar logros por nombre...',
              prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<AdminPageResult>(
            future: _achievementsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                );
              }
              if (snapshot.hasError) {
                return _ErrorState(
                  message: 'No se pudieron cargar los logros.',
                  onRetry: _reloadAchievements,
                );
              }

              final page = snapshot.data ?? const AdminPageResult.empty();
              if (page.count == 0) {
                return const _EmptyState(
                  icon: Icons.emoji_events_outlined,
                  message: 'No hay logros que coincidan con el filtro.',
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _pageTabs(
                    count: page.count,
                    currentPage: _achievementPage,
                    onPageChanged: (pageIndex) {
                      _achievementPage = pageIndex;
                      _reloadAchievements();
                    },
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = (constraints.maxWidth / 280)
                          .floor()
                          .clamp(1, 4);
                      return GridView.builder(
                        itemCount: page.items.length,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 2.2,
                        ),
                        itemBuilder: (context, index) {
                          final achievement = page.items[index];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: AppTheme.cardDecoration(),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.military_tech,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        achievement['name']?.toString() ??
                                            'Logro',
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        achievement['description']
                                                ?.toString() ??
                                            '',
                                        style: AppTheme.bodyStyle(),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Text('Preguntas de Trivias', style: AppTheme.headingStyle()),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _triviaSearchController,
                  onChanged: (_) {
                    _triviaDebounce?.cancel();
                    _triviaDebounce = Timer(
                      const Duration(milliseconds: 300),
                      () {
                        _triviaPage = 0;
                        _reloadTrivias();
                      },
                    );
                  },
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Buscar trivias...',
                    prefixIcon: Icon(
                      Icons.search,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _difficulty,
                  dropdownColor: AppColors.surfaceElevated,
                  style: const TextStyle(color: AppColors.textPrimary),
                  items: const [
                    DropdownMenuItem(value: 'Todas', child: Text('Todas')),
                    DropdownMenuItem(value: 'facil', child: Text('Fácil')),
                    DropdownMenuItem(value: 'medio', child: Text('Medio')),
                    DropdownMenuItem(value: 'dificil', child: Text('Difícil')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      _difficulty = value;
                      _triviaPage = 0;
                      _reloadTrivias();
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<AdminPageResult>(
            future: _triviasFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                );
              }
              if (snapshot.hasError) {
                return _ErrorState(
                  message: 'No se pudieron cargar las trivias.',
                  onRetry: _reloadTrivias,
                );
              }

              final page = snapshot.data ?? const AdminPageResult.empty();
              if (page.count == 0) {
                return const _EmptyState(
                  icon: Icons.quiz_outlined,
                  message: 'No hay trivias que coincidan con el filtro.',
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _pageTabs(
                    count: page.count,
                    currentPage: _triviaPage,
                    onPageChanged: (pageIndex) {
                      _triviaPage = pageIndex;
                      _reloadTrivias();
                    },
                  ),
                  Container(
                    decoration: AppTheme.cardDecoration(),
                    child: ListView.separated(
                      itemCount: page.items.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      separatorBuilder: (_, _) =>
                          const Divider(color: AppColors.divider, height: 1),
                      itemBuilder: (context, index) {
                        final trivia = page.items[index];
                        return ListTile(
                          dense: true,
                          title: Text(
                            trivia['question']?.toString() ?? '',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            'Categoría: ${trivia['category'] ?? 'General'} · Dificultad: ${trivia['difficulty'] ?? 'facil'}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Text(
                            '+${trivia['points'] ?? 10} pts',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
