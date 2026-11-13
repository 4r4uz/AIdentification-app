import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '/core/service_locator.dart';
import '/core/theme/app_theme.dart';
import '/core/theme/colors.dart';
import '/core/theme/theme_controller.dart';
import '/features/auth/presentation/screens/login_screen.dart';
import '/features/auth/presentation/screens/register_screen.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _authService = ServiceLocator.auth;
  StreamSubscription<AuthState>? _authSubscription;
  bool _showEmail = false;
  bool _isSigningOut = false;

  @override
  void initState() {
    super.initState();
    _authSubscription = _authService.authStateChanges.listen((_) {
      if (mounted) setState(() => _showEmail = false);
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _openAuthScreen(Widget screen) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => screen),
    );

    if (result == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _changeTheme(ThemeMode mode) async {
    try {
      await ThemeController.setMode(mode);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo guardar el tema: $error'),
          backgroundColor: context.palette.error,
        ),
      );
    }
  }

  Future<void> _openDeviceSettings() async {
    final opened = await openAppSettings();
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No se pudieron abrir los ajustes del dispositivo.'),
          backgroundColor: context.palette.error,
        ),
      );
    }
  }

  void _showAppInfo() {
    showAboutDialog(
      context: context,
      applicationName: 'AnimalPedia',
      applicationVersion: '0.1.0',
      applicationLegalese: 'Explora y aprende sobre la fauna.',
    );
  }

  Future<void> _signOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Quieres cerrar tu sesión de AnimalPedia?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Cerrar sesión',
              style: TextStyle(color: context.palette.error),
            ),
          ),
        ],
      ),
    );

    if (shouldSignOut != true || !mounted) return;
    setState(() => _isSigningOut = true);
    try {
      await _authService.signOut();
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo cerrar sesión: $error'),
            backgroundColor: context.palette.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        backgroundColor: context.palette.primarySoft,
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              context.palette.primarySoft.withValues(alpha: 0.45),
              context.palette.background,
              context.palette.background,
            ],
            stops: const [0, 0.3, 1],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            _SettingsSection(
              icon: Icons.person_rounded,
              title: 'Cuenta',
              child: user == null
                  ? _GuestAccount(
                      onLogin: () => _openAuthScreen(const LoginScreen()),
                      onRegister: () =>
                          _openAuthScreen(const RegisterScreen()),
                    )
                  : _AccountCard(
                      user: user,
                      showEmail: _showEmail,
                      onToggleEmail: () =>
                          setState(() => _showEmail = !_showEmail),
                    ),
            ),
            const SizedBox(height: 22),
            _SettingsSection(
              icon: Icons.palette_rounded,
              title: 'Personalización',
              child: ValueListenableBuilder<ThemeMode>(
                valueListenable: ThemeController.mode,
                builder: (context, themeMode, _) => _ThemePreference(
                  selectedMode: themeMode,
                  onChanged: _changeTheme,
                ),
              ),
            ),
            const SizedBox(height: 22),
            _SettingsSection(
              icon: Icons.shield_rounded,
              title: 'Privacidad y seguridad',
              child: Column(
                children: [
                  _SettingsRow(
                    icon: Icons.lock_rounded,
                    title: 'Permisos',
                    subtitle: 'Gestiona los permisos de la aplicación',
                    onTap: _openDeviceSettings,
                  ),
                  const Divider(height: 1),
                  const _SettingsRow(
                    icon: Icons.memory_rounded,
                    title: 'Procesamiento de IA',
                    subtitle: 'Los modelos se ejecutan localmente con CPU',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _SettingsSection(
              icon: Icons.info_rounded,
              title: 'Información',
              child: _SettingsRow(
                icon: Icons.description_rounded,
                title: 'Acerca de AnimalPedia',
                subtitle: 'Versión 0.1.0',
                onTap: _showAppInfo,
              ),
            ),
            if (user != null) ...[
              const SizedBox(height: 24),
              SizedBox(
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: _isSigningOut ? null : _signOut,
                  icon: _isSigningOut
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.logout_rounded),
                  label: Text(
                    _isSigningOut ? 'Cerrando sesión...' : 'Cerrar sesión',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.palette.error,
                    side: BorderSide(
                      color: context.palette.error.withValues(alpha: 0.35),
                    ),
                    backgroundColor: context.palette.surface.withValues(
                      alpha: 0.8,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _SettingsSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Row(
            children: [
              Icon(icon, size: 23, color: palette.primary),
              const SizedBox(width: 9),
              Text(
                title,
                style: AppTheme.headingStyle(
                  context,
                ).copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: palette.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: palette.border),
            boxShadow: [
              BoxShadow(
                color: palette.textPrimary.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      leading: Icon(icon, color: palette.primary, size: 25),
      title: Text(
        title,
        style: TextStyle(
          color: palette.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(subtitle, style: AppTheme.bodyStyle(context)),
      trailing: onTap == null
          ? null
          : Icon(Icons.chevron_right_rounded, color: palette.primary),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final User user;
  final bool showEmail;
  final VoidCallback onToggleEmail;

  const _AccountCard({
    required this.user,
    required this.showEmail,
    required this.onToggleEmail,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final rawUsername = user.userMetadata?['username'];
    final username = rawUsername is String && rawUsername.trim().isNotEmpty
        ? rawUsername.trim()
        : 'Explorador';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: palette.primarySoft,
            foregroundColor: palette.primary,
            child: const Icon(Icons.person_rounded, size: 34),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  showEmail ? (user.email ?? 'Sin correo') : 'Correo oculto',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.bodyStyle(context),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: showEmail ? 'Ocultar correo' : 'Mostrar correo',
            onPressed: onToggleEmail,
            icon: Icon(
              showEmail
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: palette.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _GuestAccount extends StatelessWidget {
  final VoidCallback onLogin;
  final VoidCallback onRegister;

  const _GuestAccount({required this.onLogin, required this.onRegister});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Inicia sesión para sincronizar tus hallazgos y guardar tus fotos.',
            style: AppTheme.bodyStyle(context),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onLogin,
            icon: const Icon(Icons.login_rounded),
            label: const Text('Iniciar sesión'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onRegister,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Crear cuenta'),
          ),
        ],
      ),
    );
  }
}

class _ThemePreference extends StatelessWidget {
  final ThemeMode selectedMode;
  final ValueChanged<ThemeMode> onChanged;

  const _ThemePreference({
    required this.selectedMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tema de la aplicación',
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text('Claro, oscuro o según el dispositivo', style: AppTheme.bodyStyle(context)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_rounded),
                  label: Text('Claro'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_rounded),
                  label: Text('Oscuro'),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.settings_brightness_rounded),
                  label: Text('Sistema'),
                ),
              ],
              selected: {selectedMode},
              onSelectionChanged: (selection) =>
                  onChanged(selection.first),
            ),
          ),
        ],
      ),
    );
  }
}
