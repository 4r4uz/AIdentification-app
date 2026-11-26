part of '../admin_dashboard_screen.dart';

class _Sidebar extends StatelessWidget {
  final AdminTab selectedTab;
  final ValueChanged<AdminTab> onSelectTab;

  const _Sidebar({required this.selectedTab, required this.onSelectTab});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: AppColors.surface,
      child: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildLogo(),
            const SizedBox(height: 8),
            _SidebarNavItem(
              icon: Icons.dashboard_outlined,
              label: 'Dashboard',
              isSelected: selectedTab == AdminTab.dashboard,
              onTap: () => onSelectTab(AdminTab.dashboard),
            ),
            _SidebarNavItem(
              icon: Icons.travel_explore_outlined,
              label: 'Avistamientos',
              isSelected: selectedTab == AdminTab.detections,
              onTap: () => onSelectTab(AdminTab.detections),
            ),
            _SidebarNavItem(
              icon: Icons.pets_outlined,
              label: 'Especies',
              isSelected: selectedTab == AdminTab.species,
              onTap: () => onSelectTab(AdminTab.species),
            ),
            _SidebarNavItem(
              icon: Icons.military_tech_outlined,
              label: 'Gamificación',
              isSelected: selectedTab == AdminTab.gamification,
              onTap: () => onSelectTab(AdminTab.gamification),
            ),
            _SidebarNavItem(
              icon: Icons.people_outline,
              label: 'Usuarios',
              isSelected: selectedTab == AdminTab.users,
              onTap: () => onSelectTab(AdminTab.users),
            ),
            _SidebarNavItem(
              icon: Icons.receipt_long_outlined,
              label: 'Suscripciones',
              isSelected: selectedTab == AdminTab.subscriptions,
              onTap: () => onSelectTab(AdminTab.subscriptions),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'AnimalPedia',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 19,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontSize: 13.5,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final String? accountName;
  final String? accountEmail;
  final String? avatarUrl;
  final VoidCallback onAccount;
  final VoidCallback onLogout;

  const _TopBar({
    required this.title,
    required this.accountName,
    required this.accountEmail,
    required this.avatarUrl,
    required this.onAccount,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            children: [
              PopupMenuButton<_AccountMenuAction>(
                tooltip: 'Cuenta',
                offset: const Offset(0, 6),
                position: PopupMenuPosition.under,
                color: AppColors.surfaceElevated,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: AppColors.divider),
                ),
                onSelected: (action) {
                  switch (action) {
                    case _AccountMenuAction.account:
                      onAccount();
                      break;
                    case _AccountMenuAction.logout:
                      onLogout();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    enabled: false,
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          accountName ?? 'Administrador',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(height: 8),
                  const PopupMenuItem(
                    value: _AccountMenuAction.account,
                    height: 40,
                    child: Row(
                      children: [
                        Icon(Icons.person_outline, size: 18),
                        SizedBox(width: 10),
                        Text('Mi cuenta'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: _AccountMenuAction.logout,
                    height: 40,
                    child: Row(
                      children: [
                        Icon(
                          Icons.logout_rounded,
                          size: 18,
                          color: AppColors.error,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Cerrar sesión',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.background, width: 1),
                  ),
                  child: ProfileAvatar(
                    name: accountName,
                    avatarUrl: avatarUrl,
                    radius: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _AccountMenuAction { account, logout }

class _AccountPanel extends StatelessWidget {
  final String? name;
  final String? email;
  final String? avatarUrl;
  final String? role;
  final VoidCallback onClose;

  const _AccountPanel({
    required this.name,
    required this.email,
    required this.avatarUrl,
    required this.role,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 10, 10),
              child: Row(
                children: [
                  Text(
                    'Mi cuenta',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: onClose,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.divider, height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: ProfileAvatar(
                        name: name,
                        avatarUrl: avatarUrl,
                        radius: 36,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: Text(
                        name ?? 'Administrador',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (email != null) ...[
                      const SizedBox(height: 4),
                      Center(
                        child: Text(
                          email!,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    _AccountDetail(label: 'Cuenta', value: 'Administrador'),
                    const SizedBox(height: 10),
                    _AccountDetail(label: 'Rol', value: role ?? 'admin'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountDetail extends StatelessWidget {
  final String label;
  final String value;

  const _AccountDetail({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
