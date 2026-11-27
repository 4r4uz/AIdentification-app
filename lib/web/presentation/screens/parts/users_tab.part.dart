part of '../admin_dashboard_screen.dart';

enum _UserStatusFilter { all, active, inactive }

enum _UserRoleFilter { all, user, admin }

class _UsersTab extends StatefulWidget {
  final Future<List<Map<String, dynamic>>> usersFuture;
  final AdminService adminService;
  final VoidCallback onRefresh;
  final VoidCallback onRetry;

  const _UsersTab({
    required this.usersFuture,
    required this.adminService,
    required this.onRefresh,
    required this.onRetry,
  });

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  static const int _pageSize = 10;

  final TextEditingController _searchController = TextEditingController();
  _UserStatusFilter _statusFilter = _UserStatusFilter.all;
  _UserRoleFilter _roleFilter = _UserRoleFilter.all;
  int _page = 0;
  final Set<String> _busyUserIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    _page = 0;
    widget.onRefresh();
  }

  Future<void> _showUserForm({Map<String, dynamic>? user}) async {
    Map<String, dynamic>? managedUser;
    final userId = user?['id']?.toString();

    if (userId != null) {
      try {
        managedUser = await widget.adminService.getManagedUser(userId);
      } catch (error) {
        if (!mounted) return;
        _showMessage('No se pudieron cargar los datos de la cuenta: $error');
        return;
      }
    }
    if (!mounted) return;

    final values = await showDialog<_UserFormValues>(
      context: context,
      builder: (context) => _UserFormDialog(
        username: user?['username']?.toString() ?? '',
        email: managedUser?['email']?.toString() ?? '',
        isCreating: user == null,
      ),
    );
    if (values == null || !mounted) return;

    try {
      if (userId == null) {
        await widget.adminService.createUser(
          email: values.email,
          password: values.password,
          username: values.username,
        );
      } else {
        await widget.adminService.updateManagedUser(
          userId: userId,
          username: values.username,
          email: values.email,
          password: values.password,
        );
      }

      if (!mounted) return;
      _showMessage(
        userId == null
            ? 'La cuenta se creó correctamente.'
            : 'Los cambios se guardaron correctamente.',
        isError: false,
      );
      _refresh();
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        userId == null
            ? 'No se pudo crear la cuenta: $error'
            : 'No se pudieron guardar los cambios: $error',
      );
    }
  }

  Future<void> _toggleUserStatus(Map<String, dynamic> user) async {
    final userId = user['id']?.toString();
    if (userId == null || !_startUserAction(userId)) return;

    final isActive = user['is_active'] != false;
    final username = _username(user);
    if (isActive && userId == Supabase.instance.client.auth.currentUser?.id) {
      _finishUserAction(userId);
      _showMessage('No puedes desactivar tu propia cuenta administrativa.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          isActive ? 'Desactivar cuenta' : 'Reactivar cuenta',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          isActive
              ? 'La cuenta de $username no podrá iniciar sesión. '
                    'Sus datos se conservarán y podrás reactivarla después.'
              : 'La cuenta de $username podrá volver a iniciar sesión.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: isActive ? AppColors.warning : AppColors.success,
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(isActive ? 'Desactivar cuenta' : 'Reactivar cuenta'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      _finishUserAction(userId);
      return;
    }

    try {
      await widget.adminService.setUserStatus(userId, !isActive);
      if (!mounted) return;
      _showMessage(
        isActive ? 'Cuenta desactivada.' : 'Cuenta reactivada.',
        isError: false,
      );
      _refresh();
    } catch (error) {
      if (!mounted) return;
      _showMessage('No se pudo cambiar el estado de la cuenta: $error');
    } finally {
      _finishUserAction(userId);
    }
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final userId = user['id']?.toString();
    if (userId == null || !_startUserAction(userId)) return;

    final username = _username(user);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Eliminar cuenta permanentemente',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Se eliminará la cuenta de $username. Esta acción no se puede '
          'deshacer. Si la cuenta tiene registros relacionados, el sistema '
          'puede impedir la eliminación para proteger esos datos.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar cuenta'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      _finishUserAction(userId);
      return;
    }

    try {
      await widget.adminService.deleteUser(userId);
      if (!mounted) return;
      _showMessage('La cuenta se eliminó correctamente.', isError: false);
      _refresh();
    } catch (error) {
      if (!mounted) return;
      _showMessage('No se pudo eliminar la cuenta: $error');
    } finally {
      _finishUserAction(userId);
    }
  }

  Future<void> _showUserDetails(Map<String, dynamic> user) async {
    final userId = user['id']?.toString();
    if (userId == null || !_startUserAction(userId)) return;

    try {
      final managedUser = await widget.adminService.getManagedUser(userId);
      if (!mounted) return;

      final action = await showDialog<_UserDetailsAction>(
        context: context,
        builder: (context) => _UserDetailsDialog(
          user: user,
          managedUser: managedUser,
          canDelete: userId != Supabase.instance.client.auth.currentUser?.id,
        ),
      );
      _finishUserAction(userId);
      if (!mounted) return;

      switch (action) {
        case _UserDetailsAction.edit:
          await _showUserForm(user: user);
          break;
        case _UserDetailsAction.toggleStatus:
          await _toggleUserStatus(user);
          break;
        case _UserDetailsAction.delete:
          await _deleteUser(user);
          break;
        case null:
          break;
      }
    } catch (error) {
      if (mounted) {
        _showMessage('No se pudieron cargar los detalles de la cuenta: $error');
      }
    } finally {
      _finishUserAction(userId);
    }
  }

  bool _startUserAction(String userId) {
    if (_busyUserIds.contains(userId)) return false;
    setState(() => _busyUserIds.add(userId));
    return true;
  }

  void _finishUserAction(String userId) {
    if (!mounted || !_busyUserIds.contains(userId)) return;
    setState(() => _busyUserIds.remove(userId));
  }

  void _showMessage(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppColors.error : AppColors.success,
        ),
      );
  }

  List<Map<String, dynamic>> _filterUsers(List<Map<String, dynamic>> users) {
    final query = _searchController.text.trim().toLowerCase();
    return users.where((user) {
      final isActive = user['is_active'] != false;
      final role = user['role']?.toString() ?? 'user';
      final matchesStatus = switch (_statusFilter) {
        _UserStatusFilter.all => true,
        _UserStatusFilter.active => isActive,
        _UserStatusFilter.inactive => !isActive,
      };
      final matchesRole = switch (_roleFilter) {
        _UserRoleFilter.all => true,
        _UserRoleFilter.user => role == 'user',
        _UserRoleFilter.admin => role == 'admin',
      };
      final searchableValues = [
        user['username'],
        user['id'],
        user['role'],
      ].whereType<Object>().map((value) => value.toString().toLowerCase());
      final matchesSearch =
          query.isEmpty ||
          searchableValues.any((value) => value.contains(query));

      return matchesStatus && matchesRole && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: widget.usersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        if (snapshot.hasError) {
          return _ErrorState(
            message: 'No se pudieron cargar las cuentas de usuario.',
            onRetry: widget.onRetry,
          );
        }

        final users = snapshot.data ?? const <Map<String, dynamic>>[];
        final filteredUsers = _filterUsers(users);
        final pageCount = (filteredUsers.length / _pageSize).ceil();
        if (pageCount > 0 && _page >= pageCount) _page = pageCount - 1;
        if (pageCount == 0) _page = 0;
        final start = _page * _pageSize;
        final end = start + _pageSize < filteredUsers.length
            ? start + _pageSize
            : filteredUsers.length;
        final pageUsers = filteredUsers.sublist(start, end);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(users.length),
            const SizedBox(height: 18),
            _buildSummary(users),
            const SizedBox(height: 20),
            _buildFilters(),
            const SizedBox(height: 12),
            Expanded(
              child: filteredUsers.isEmpty
                  ? _buildEmptyState(users.isEmpty)
                  : _buildUsersTable(pageUsers),
            ),
            if (filteredUsers.isNotEmpty)
              _buildPagination(filteredUsers.length),
          ],
        );
      },
    );
  }

  Widget _buildHeader(int totalUsers) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Usuarios', style: AppTheme.headingStyle()),
              const SizedBox(height: 4),
              Text(
                '$totalUsers cuentas registradas',
                style: AppTheme.bodyStyle(),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Actualizar lista',
          onPressed: widget.onRetry,
          icon: const Icon(Icons.refresh_rounded),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: () => _showUserForm(),
          icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
          label: const Text('Crear usuario'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildSummary(List<Map<String, dynamic>> users) {
    final activeCount = users
        .where((user) => user['is_active'] != false)
        .length;
    final adminCount = users
        .where((user) => user['role']?.toString() == 'admin')
        .length;
    final items = [
      _UserSummaryItem(
        label: 'Total de cuentas',
        value: users.length,
        icon: Icons.people_alt_outlined,
        color: AppColors.primary,
      ),
      _UserSummaryItem(
        label: 'Activas',
        value: activeCount,
        icon: Icons.check_circle_outline_rounded,
        color: AppColors.success,
      ),
      _UserSummaryItem(
        label: 'Administradores',
        value: adminCount,
        icon: Icons.admin_panel_settings_outlined,
        color: AppColors.info,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 3 : 1;
        final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items
              .map((item) => SizedBox(width: width, child: item))
              .toList(),
        );
      },
    );
  }

  Widget _buildFilters() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 740;
        final search = TextField(
          controller: _searchController,
          onChanged: (_) => setState(() => _page = 0),
          decoration: const InputDecoration(
            hintText: 'Buscar por nombre, ID o rol',
            prefixIcon: Icon(Icons.search_rounded),
            isDense: true,
          ),
        );
        final status = DropdownButtonFormField<_UserStatusFilter>(
          initialValue: _statusFilter,
          decoration: const InputDecoration(labelText: 'Estado', isDense: true),
          items: const [
            DropdownMenuItem(
              value: _UserStatusFilter.all,
              child: Text('Todos los estados'),
            ),
            DropdownMenuItem(
              value: _UserStatusFilter.active,
              child: Text('Activas'),
            ),
            DropdownMenuItem(
              value: _UserStatusFilter.inactive,
              child: Text('Desactivadas'),
            ),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _statusFilter = value);
          },
        );
        final role = DropdownButtonFormField<_UserRoleFilter>(
          initialValue: _roleFilter,
          decoration: const InputDecoration(
            labelText: 'Tipo de cuenta',
            isDense: true,
          ),
          items: const [
            DropdownMenuItem(
              value: _UserRoleFilter.all,
              child: Text('Todos los roles'),
            ),
            DropdownMenuItem(
              value: _UserRoleFilter.user,
              child: Text('Usuario'),
            ),
            DropdownMenuItem(
              value: _UserRoleFilter.admin,
              child: Text('Administrador'),
            ),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _roleFilter = value);
          },
        );

        if (narrow) {
          return Column(
            children: [
              search,
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: status),
                  const SizedBox(width: 10),
                  Expanded(child: role),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(flex: 3, child: search),
            const SizedBox(width: 12),
            Expanded(child: status),
            const SizedBox(width: 12),
            Expanded(child: role),
          ],
        );
      },
    );
  }

  Widget _buildUsersTable(List<Map<String, dynamic>> users) {
    return Container(
      decoration: AppTheme.cardDecoration(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                showCheckboxColumn: false,
                columns: const [
                  DataColumn(label: Text('Cuenta')),
                  DataColumn(label: Text('Rol')),
                  DataColumn(label: Text('Registro')),
                  DataColumn(label: Text('Estado')),
                  DataColumn(label: Text('Acciones')),
                ],
                rows: users.map(_buildUserRow).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  DataRow _buildUserRow(Map<String, dynamic> user) {
    final id = user['id']?.toString() ?? '';
    final username = _username(user);
    final isActive = user['is_active'] != false;
    final role = user['role']?.toString() ?? 'user';
    final isSelf = id == Supabase.instance.client.auth.currentUser?.id;

    return DataRow(
      onSelectChanged: _busyUserIds.contains(id)
          ? null
          : (_) => _showUserDetails(user),
      cells: [
        DataCell(
          SizedBox(
            width: 260,
            child: Row(
              children: [
                ProfileAvatar(
                  name: username,
                  avatarUrl: user['avatar_url']?.toString(),
                  radius: 19,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        id,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        DataCell(_UserRoleBadge(role: role)),
        DataCell(Text(_formatDate(user['created_at']?.toString()))),
        DataCell(_UserStatusBadge(isActive: isActive)),
        DataCell(
          _busyUserIds.contains(id)
              ? const SizedBox(
                  width: 40,
                  height: 24,
                  child: Padding(
                    padding: EdgeInsets.all(4),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                )
              : PopupMenuButton<_UserRowAction>(
                  tooltip: 'Acciones de $username',
                  onSelected: (action) {
                    switch (action) {
                      case _UserRowAction.details:
                        _showUserDetails(user);
                        break;
                      case _UserRowAction.edit:
                        _showUserForm(user: user);
                        break;
                      case _UserRowAction.toggleStatus:
                        _toggleUserStatus(user);
                        break;
                      case _UserRowAction.delete:
                        _deleteUser(user);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: _UserRowAction.details,
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.visibility_outlined),
                        title: Text('Ver detalles'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: _UserRowAction.edit,
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Editar cuenta'),
                      ),
                    ),
                    PopupMenuItem(
                      value: _UserRowAction.toggleStatus,
                      child: ListTile(
                        dense: true,
                        leading: Icon(
                          isActive
                              ? Icons.pause_circle_outline
                              : Icons.play_circle_outline,
                        ),
                        title: Text(isActive ? 'Desactivar' : 'Reactivar'),
                      ),
                    ),
                    if (!isSelf)
                      const PopupMenuItem(
                        value: _UserRowAction.delete,
                        child: ListTile(
                          dense: true,
                          leading: Icon(
                            Icons.delete_outline,
                            color: AppColors.error,
                          ),
                          title: Text(
                            'Eliminar permanentemente',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ),
                      ),
                  ],
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.more_horiz_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildPagination(int totalCount) {
    final first = _page * _pageSize + 1;
    final last = (first + _pageSize - 1).clamp(0, totalCount);
    final pageCount = (totalCount / _pageSize).ceil();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '$first–$last de $totalCount',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Página anterior',
            onPressed: _page > 0 ? () => setState(() => _page--) : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Text(
            '${_page + 1} / $pageCount',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          IconButton(
            tooltip: 'Página siguiente',
            onPressed: _page + 1 < pageCount
                ? () => setState(() => _page++)
                : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool hasNoUsers) {
    if (hasNoUsers) {
      return const _EmptyState(
        icon: Icons.people_outline_rounded,
        message: 'Todavía no hay cuentas registradas.',
      );
    }
    return const _EmptyState(
      icon: Icons.search_off_rounded,
      message: 'No hay cuentas que coincidan con estos filtros.',
    );
  }

  String _username(Map<String, dynamic> user) {
    final username = user['username']?.toString().trim();
    return username == null || username.isEmpty ? 'Sin nombre' : username;
  }
}

enum _UserRowAction { details, edit, toggleStatus, delete }

enum _UserDetailsAction { edit, toggleStatus, delete }

class _UserSummaryItem extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const _UserSummaryItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: AppTheme.cardDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value.toString(),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(label, style: AppTheme.bodyStyle().copyWith(fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _UserStatusBadge extends StatelessWidget {
  final bool isActive;

  const _UserStatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isActive ? 'Activa' : 'Desactivada',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _UserRoleBadge extends StatelessWidget {
  final String role;

  const _UserRoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == 'admin';
    final color = isAdmin ? AppColors.info : AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isAdmin ? Icons.admin_panel_settings_outlined : Icons.person_outline,
          color: color,
          size: 17,
        ),
        const SizedBox(width: 6),
        Text(
          isAdmin ? 'Administrador' : 'Usuario',
          style: TextStyle(color: color, fontSize: 12),
        ),
      ],
    );
  }
}

class _UserFormValues {
  final String username;
  final String email;
  final String password;

  const _UserFormValues({
    required this.username,
    required this.email,
    required this.password,
  });
}

class _UserFormDialog extends StatefulWidget {
  final String username;
  final String email;
  final bool isCreating;

  const _UserFormDialog({
    required this.username,
    required this.email,
    required this.isCreating,
  });

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.username);
    _emailController = TextEditingController(text: widget.email);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _UserFormValues(
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isCreating ? 'Crear cuenta' : 'Editar cuenta';
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _usernameController,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de usuario',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresa un nombre de usuario.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: widget.isCreating
                      ? TextInputAction.next
                      : TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty) return 'Ingresa un correo electrónico.';
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                        .hasMatch(email)) {
                      return 'Ingresa un correo válido.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: widget.isCreating
                        ? 'Contraseña temporal'
                        : 'Nueva contraseña (opcional)',
                    helperText: widget.isCreating
                        ? 'Mínimo 6 caracteres.'
                        : 'Déjala vacía para conservar la contraseña actual.',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword
                          ? 'Mostrar contraseña'
                          : 'Ocultar contraseña',
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) {
                    final password = value ?? '';
                    if (widget.isCreating && password.length < 6) {
                      return 'La contraseña debe tener al menos 6 caracteres.';
                    }
                    if (password.isNotEmpty && password.length < 6) {
                      return 'La contraseña debe tener al menos 6 caracteres.';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _submit(),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save_outlined, size: 18),
          label: Text(widget.isCreating ? 'Crear cuenta' : 'Guardar cambios'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.black,
          ),
        ),
      ],
    );
  }
}

class _UserDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> user;
  final Map<String, dynamic> managedUser;
  final bool canDelete;

  const _UserDetailsDialog({
    required this.user,
    required this.managedUser,
    required this.canDelete,
  });

  @override
  Widget build(BuildContext context) {
    final username = user['username']?.toString().trim();
    final displayName = username == null || username.isEmpty
        ? 'Sin nombre'
        : username;
    final isActive = user['is_active'] != false;
    final userId = user['id']?.toString() ?? '';

    return AlertDialog(
      backgroundColor: AppColors.surface,
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 16, 8),
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
      title: Row(
        children: [
          ProfileAvatar(
            name: displayName,
            avatarUrl: user['avatar_url']?.toString(),
            radius: 23,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                _UserStatusBadge(isActive: isActive),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cerrar',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _UserDetailRow(label: 'Correo', value: managedUser['email']),
              _UserDetailRow(label: 'Nombre', value: user['username']),
              _UserDetailRow(
                label: 'Rol',
                value: managedUser['role'] ?? user['role'],
              ),
              _UserDetailRow(label: 'ID', value: userId),
              _UserDetailRow(label: 'Registrado', value: user['created_at']),
            ],
          ),
        ),
      ),
      actions: [
        if (canDelete)
          TextButton.icon(
            onPressed: () => Navigator.pop(context, _UserDetailsAction.delete),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Eliminar'),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
          ),
        TextButton.icon(
          onPressed: () =>
              Navigator.pop(context, _UserDetailsAction.toggleStatus),
          icon: Icon(
            isActive
                ? Icons.pause_circle_outline_rounded
                : Icons.play_circle_outline_rounded,
          ),
          label: Text(isActive ? 'Desactivar' : 'Reactivar'),
          style: TextButton.styleFrom(
            foregroundColor: isActive ? AppColors.warning : AppColors.success,
          ),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, _UserDetailsAction.edit),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Editar'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.black,
          ),
        ),
      ],
    );
  }
}

class _UserDetailRow extends StatelessWidget {
  final String label;
  final Object? value;

  const _UserDetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final text = value?.toString().trim();
    final displayValue = text == null || text.isEmpty ? 'No disponible' : text;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              label == 'Registrado' ? _formatDate(displayValue) : displayValue,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
