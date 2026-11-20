part of '../admin_dashboard_screen.dart';

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
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'Todos';
  int _currentPage = 0;
  static const int _pageSize = 50;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showCreateUserDialog() async {
    final emailController = TextEditingController();
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        ),
        title: const Text(
          'Crear Usuario',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: usernameController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Nombre de usuario',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Contraseña temporal',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final username = usernameController.text.trim();
              final email = emailController.text.trim();
              final password = passwordController.text;

              if (username.isEmpty || email.isEmpty || password.length < 6) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Completa todos los campos. La contraseña debe tener al menos 6 caracteres.',
                    ),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }

              try {
                await widget.adminService.createUser(
                  email: email,
                  password: password,
                  username: username,
                );
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, true);
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text('Error al crear usuario: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
            ),
            child: const Text('Crear usuario'),
          ),
        ],
      ),
    );

    emailController.dispose();
    usernameController.dispose();
    passwordController.dispose();

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Usuario creado correctamente'),
          backgroundColor: AppColors.success,
        ),
      );
      widget.onRefresh();
    }
  }

  Future<void> _showEditUserDialog(
    BuildContext context,
    Map<String, dynamic> user,
  ) async {
    final userId = user['id']?.toString();
    final usernameCtrl = TextEditingController(
      text: user['username']?.toString() ?? '',
    );
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();

    if (userId != null) {
      try {
        final managedUser = await widget.adminService.getManagedUser(userId);
        emailCtrl.text = managedUser['email']?.toString() ?? '';
      } catch (_) {
        // El perfil sigue pudiendo editarse aunque Auth no esté disponible.
      }
    }
    if (!context.mounted) return;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        ),
        title: const Text(
          'Editar Usuario',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: usernameCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Nombre de usuario',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordCtrl,
                  obscureText: true,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Nueva contraseña',
                    hintText: 'Déjala vacía para no cambiarla',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (userId == null) return;
              final username = usernameCtrl.text.trim();
              final email = emailCtrl.text.trim();
              final password = passwordCtrl.text;

              if (username.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('El nombre de usuario es obligatorio'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }
              if (email.isNotEmpty &&
                  !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ingresa un correo electrónico válido'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }
              if (password.isNotEmpty && password.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'La contraseña debe tener al menos 6 caracteres',
                    ),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }

              try {
                await widget.adminService.updateManagedUser(
                  userId: userId,
                  username: username,
                  email: email,
                  password: password,
                );
                if (context.mounted) Navigator.pop(context, true);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al actualizar: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
            ),
            child: const Text('Guardar cambios'),
          ),
        ],
      ),
    );
    usernameCtrl.dispose();
    emailCtrl.dispose();
    passwordCtrl.dispose();

    if (saved == true) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Usuario actualizado correctamente'),
          backgroundColor: AppColors.success,
        ),
      );
      widget.onRefresh();
    }
  }

  Future<void> _handleToggleUserStatus(
    BuildContext context,
    Map<String, dynamic> user,
  ) async {
    final userId = user['id']?.toString();
    final username = user['username']?.toString() ?? 'Usuario';
    final isActive = user['is_active'] != false;
    if (userId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        ),
        title: Text(
          isActive ? 'Deshabilitar Usuario' : 'Habilitar Usuario',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          isActive
              ? '¿Deseas deshabilitar a "$username"? El usuario no podrá iniciar sesión.'
              : '¿Deseas habilitar nuevamente a "$username"?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isActive ? AppColors.error : AppColors.success,
              foregroundColor: Colors.white,
            ),
            child: Text(isActive ? 'Deshabilitar' : 'Habilitar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await widget.adminService.setUserStatus(userId, !isActive);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isActive
                ? 'Usuario deshabilitado correctamente'
                : 'Usuario habilitado correctamente',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      widget.onRefresh();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cambiar el estado del usuario: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _showUserDetails(
    BuildContext context,
    Map<String, dynamic> user,
  ) async {
    final userId = user['id']?.toString() ?? '';
    final username = user['username']?.toString() ?? 'Sin nombre';
    final isActive = user['is_active'] != false;
    final avatarUrl = user['avatar_url']?.toString();
    Map<String, dynamic> managedUser = {};
    try {
      managedUser = await widget.adminService.getManagedUser(userId);
    } catch (_) {}
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.surfaceElevated,
              backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl == null || avatarUrl.isEmpty
                  ? const Icon(Icons.person, color: AppColors.textSecondary)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    isActive ? 'Habilitado' : 'Deshabilitado',
                    style: TextStyle(
                      color: isActive ? AppColors.success : AppColors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Cerrar',
              onPressed: () => Navigator.pop(dialogContext),
              icon: const Icon(Icons.close, color: AppColors.textSecondary),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _UserDetailField(label: 'ID', value: userId),
              const SizedBox(height: 12),
              _UserDetailField(
                label: 'Correo',
                value: managedUser['email']?.toString() ?? 'No disponible',
              ),
              const SizedBox(height: 12),
              _UserDetailField(
                label: 'Rol',
                value:
                    managedUser['role']?.toString() ??
                    user['role']?.toString() ??
                    'user',
              ),
              const SizedBox(height: 12),
              _UserDetailField(
                label: 'Registrado',
                value: _formatDate(user['created_at']?.toString()),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              _handleToggleUserStatus(context, user);
            },
            icon: Icon(
              isActive ? Icons.block_outlined : Icons.check_circle_outline,
            ),
            label: Text(isActive ? 'Deshabilitar' : 'Habilitar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isActive ? AppColors.error : AppColors.success,
              foregroundColor: Colors.white,
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              _showEditUserDialog(context, user);
            },
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Modificar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
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
            message: 'No se pudieron cargar los usuarios del sistema.',
            onRetry: widget.onRetry,
          );
        }
        final users = snapshot.data ?? [];
        if (users.isEmpty) {
          return const _EmptyState(
            icon: Icons.people_outline,
            message: 'No hay usuarios registrados en la plataforma.',
          );
        }

        final query = _searchController.text.trim().toLowerCase();
        final filteredUsers = users.where((user) {
          final isActive = user['is_active'] != false;
          final matchesStatus =
              _statusFilter == 'Todos' ||
              (_statusFilter == 'Habilitados' && isActive) ||
              (_statusFilter == 'Deshabilitados' && !isActive);
          final searchable = [
            user['username'],
            user['id'],
          ].whereType<dynamic>().map((value) => value.toString().toLowerCase());
          final matchesQuery =
              query.isEmpty || searchable.any((value) => value.contains(query));
          return matchesStatus && matchesQuery;
        }).toList();
        final pageCount = filteredUsers.isEmpty
            ? 0
            : ((filteredUsers.length + _pageSize - 1) ~/ _pageSize);
        final safePage = pageCount == 0
            ? 0
            : _currentPage.clamp(0, pageCount - 1);
        final pageStart = safePage * _pageSize;
        final pageEnd = (pageStart + _pageSize).clamp(0, filteredUsers.length);
        final pageUsers = filteredUsers.isEmpty
            ? const <Map<String, dynamic>>[]
            : filteredUsers.sublist(pageStart, pageEnd);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() => _currentPage = 0),
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Buscar por nombre o ID',
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
                    value: _statusFilter,
                    dropdownColor: AppColors.surfaceElevated,
                    style: const TextStyle(color: AppColors.textPrimary),
                    items: const [
                      DropdownMenuItem(value: 'Todos', child: Text('Todos')),
                      DropdownMenuItem(
                        value: 'Habilitados',
                        child: Text('Habilitados'),
                      ),
                      DropdownMenuItem(
                        value: 'Deshabilitados',
                        child: Text('Deshabilitados'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _statusFilter = value;
                          _currentPage = 0;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _showCreateUserDialog,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Crear usuario'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (pageCount > 1)
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: pageCount,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final start = index * _pageSize + 1;
                    final end = ((index + 1) * _pageSize).clamp(
                      0,
                      filteredUsers.length,
                    );
                    final selected = index == safePage;
                    return TextButton(
                      onPressed: () => setState(() => _currentPage = index),
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
            if (pageCount > 1) const SizedBox(height: 10),
            Expanded(
              child: filteredUsers.isEmpty
                  ? const _EmptyState(
                      icon: Icons.search_off,
                      message: 'No hay usuarios que coincidan con el filtro.',
                    )
                  : ListView.separated(
                      itemCount: pageUsers.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final user = pageUsers[index];
                        final username =
                            user['username']?.toString() ?? 'Sin nombre';
                        final id = user['id']?.toString() ?? 'N/A';
                        final avatarUrl = user['avatar_url']?.toString();
                        final createdAt = _formatDate(
                          user['created_at']?.toString(),
                        );
                        final shortId = id.length > 8
                            ? '${id.substring(0, 8)}...'
                            : id;
                        final isActive = user['is_active'] != false;

                        return InkWell(
                          onTap: () => _showUserDetails(context, user),
                          borderRadius: BorderRadius.circular(
                            AppTheme.cardRadius,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: AppTheme.cardDecoration(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor:
                                          AppColors.surfaceElevated,
                                      backgroundImage:
                                          (avatarUrl != null &&
                                              avatarUrl.isNotEmpty)
                                          ? NetworkImage(avatarUrl)
                                          : null,
                                      child:
                                          (avatarUrl == null ||
                                              avatarUrl.isEmpty)
                                          ? const Icon(
                                              Icons.person,
                                              color: AppColors.textSecondary,
                                              size: 22,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            username,
                                            style: const TextStyle(
                                              color: AppColors.textPrimary,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Text(
                                                'ID: $shortId',
                                                style: const TextStyle(
                                                  color:
                                                      AppColors.textSecondary,
                                                  fontFamily: 'monospace',
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Reg: $createdAt',
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                (isActive
                                                        ? AppColors.success
                                                        : AppColors.error)
                                                    .withValues(alpha: 0.14),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            isActive
                                                ? 'Habilitado'
                                                : 'Deshabilitado',
                                            style: TextStyle(
                                              color: isActive
                                                  ? AppColors.success
                                                  : AppColors.error,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              onPressed: () =>
                                                  _showEditUserDialog(
                                                    context,
                                                    user,
                                                  ),
                                              tooltip: 'Editar usuario',
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                                size: 18,
                                                color: AppColors.primary,
                                              ),
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                            IconButton(
                                              onPressed: () =>
                                                  _handleToggleUserStatus(
                                                    context,
                                                    user,
                                                  ),
                                              tooltip: isActive
                                                  ? 'Deshabilitar usuario'
                                                  : 'Habilitar usuario',
                                              icon: Icon(
                                                isActive
                                                    ? Icons.block_outlined
                                                    : Icons
                                                          .check_circle_outline,
                                                size: 18,
                                                color: isActive
                                                    ? AppColors.error
                                                    : AppColors.success,
                                              ),
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _UserDetailField extends StatelessWidget {
  final String label;
  final String value;

  const _UserDetailField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: AppColors.textPrimary)),
      ],
    );
  }
}
