import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '/core/service_locator.dart';
import '/core/theme/app_theme.dart';
import '/core/theme/colors.dart';
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
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        padding: AppTheme.defaultPadding,
        children: [
          _SettingsSection(
            title: 'Cuenta',
            child: user == null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Inicia sesión para sincronizar tus hallazgos y guardar tus fotos en tu galería.',
                        style: AppTheme.bodyStyle(context),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: () => _openAuthScreen(
                          const LoginScreen(),
                        ),
                        icon: const Icon(Icons.login_rounded),
                        label: const Text('Iniciar sesión'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => _openAuthScreen(
                          const RegisterScreen(),
                        ),
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: const Text('Crear cuenta'),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: palette.primarySoft,
                            foregroundColor: palette.primary,
                            child: const Icon(Icons.alternate_email_rounded),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Correo electrónico',
                                  style: TextStyle(
                                    color: palette.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _showEmail
                                      ? (user.email ?? 'Sin correo')
                                      : '••••••••••••••••',
                                  style: AppTheme.bodyStyle(context),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: _showEmail
                                ? 'Ocultar correo'
                                : 'Mostrar correo',
                            onPressed: () =>
                                setState(() => _showEmail = !_showEmail),
                            icon: Icon(
                              _showEmail
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Divider(color: palette.border),
                      Material(
                        color: Colors.transparent,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.logout_rounded,
                            color: palette.error,
                          ),
                          title: Text(
                            'Cerrar sesión',
                            style: TextStyle(
                              color: palette.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: _isSigningOut
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.chevron_right_rounded),
                          onTap: _isSigningOut ? null : _signOut,
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 18),
          _SettingsSection(
            title: 'Acerca de',
            child: Row(
              children: [
                SizedBox(
                  width: 46,
                  height: 46,
                  child: Text("info")
                ),
                
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _SettingsSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            title,
            style: TextStyle(
              color: context.palette.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: .5,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: AppTheme.cardPadding,
          decoration: AppTheme.cardDecoration(context),
          child: child,
        ),
      ],
    );
  }
}
