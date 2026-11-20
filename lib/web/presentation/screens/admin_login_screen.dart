import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/app_theme.dart';
import 'admin_dashboard_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _restoreAdminSession();
  }

  Future<void> _restoreAdminSession() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      Map<String, dynamic>? profile;
      try {
        profile = await Supabase.instance.client
            .from('profiles')
            .select('role, is_active')
            .eq('id', user.id)
            .maybeSingle();
      } on PostgrestException catch (error) {
        if (error.code != '42703') rethrow;
        profile = await Supabase.instance.client
            .from('profiles')
            .select('role')
            .eq('id', user.id)
            .maybeSingle();
      }

      final role = profile?['role']?.toString();
      final isActive = profile?['is_active'] != false;

      if (!mounted) return;
      if (role != 'admin' || !isActive) {
        await Supabase.instance.client.auth.signOut();
        if (!mounted) return;
        setState(() {
          _errorMessage = !isActive
              ? 'Tu cuenta está deshabilitada. Contacta al administrador.'
              : 'Acceso denegado: tu cuenta no tiene permisos de administrador.';
        });
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'No se pudo validar tu sesión existente. Inicia sesión nuevamente.';
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Ingresa tu correo y contraseña.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (response.session == null || user == null) {
        setState(() => _errorMessage = 'No se pudo iniciar sesión.');
        return;
      }

      Map<String, dynamic>? profile;
      try {
        profile = await supabase
            .from('profiles')
            .select('role, is_active')
            .eq('id', user.id)
            .maybeSingle();
      } on PostgrestException catch (error) {
        if (error.code != '42703') rethrow;
        profile = await supabase
            .from('profiles')
            .select('role')
            .eq('id', user.id)
            .maybeSingle();
      }

      final role = profile?['role']?.toString();
      final isActive = profile?['is_active'] != false;

      if (!isActive) {
        await supabase.auth.signOut();
        if (mounted) {
          setState(() {
            _errorMessage =
                'Tu cuenta está deshabilitada. Contacta al administrador.';
          });
        }
        return;
      }

      if (role != 'admin') {
        await supabase.auth.signOut();
        if (mounted) {
          setState(() {
            _errorMessage = 'Acceso denegado: tu cuenta no tiene permisos de administrador.';
          });
        }
        return;
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
        );
      }
    } on AuthException {
      if (mounted) {
        setState(() => _errorMessage = 'Correo o contraseña incorrectos.');
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage = 'Error de conexión al validar credenciales.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;

          if (isWide) {
            return Row(
              children: [
                Expanded(flex: 6, child: _BrandShowcasePanel()),
                Expanded(
                  flex: 5,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 32,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: _buildLoginCard(showCompactLogo: false),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return Stack(
            children: [
              Positioned(
                top: -120,
                right: -120,
                child: _AmbientGlow(size: 320, opacity: 0.14),
              ),
              Positioned(
                bottom: -140,
                left: -100,
                child: _AmbientGlow(size: 300, opacity: 0.10),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: _buildLoginCard(showCompactLogo: true),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoginCard({required bool showCompactLogo}) {
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showCompactLogo) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Icon(
                    Icons.eco_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'AnimalPedia',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],

          // Etiqueta RBAC
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'PORTAL ADMINISTRATIVO',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          const Text(
            'Iniciar Sesión',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Ingresa con tu cuenta de administrador para gestionar avistamientos, especies y usuarios.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 26),

          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.error,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Campo Correo
          const Text(
            'Correo electrónico',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: _inputDecoration(
              hint: 'admin@animalpedia.cl',
              icon: Icons.alternate_email_rounded,
            ),
          ),
          const SizedBox(height: 18),

          // Campo Contraseña
          const Text(
            'Contraseña',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            onSubmitted: (_) => _isLoading ? null : _handleLogin(),
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: _inputDecoration(
              hint: '••••••••••••',
              icon: Icons.lock_outline_rounded,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.textSecondary,
                  size: 19,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Botón principal
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                disabledBackgroundColor: AppColors.primary.withValues(
                  alpha: 0.4,
                ),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.black,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Ingresar al Panel',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 22),

          // Pie de seguridad
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.verified_user_outlined,
                size: 14,
                color: AppColors.textSecondary.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 6),
              Text(
                'Autenticación protegida con Supabase RLS',
                style: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.75),
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: AppColors.textSecondary.withValues(alpha: 0.5),
        fontSize: 13.5,
      ),
      prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 19),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.background.withValues(alpha: 0.7),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.divider.withValues(alpha: 0.8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }
}

class _BrandShowcasePanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceElevated.withValues(alpha: 0.85),
            AppColors.background,
          ],
        ),
        border: Border(
          right: BorderSide(color: AppColors.divider.withValues(alpha: 0.6)),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -100,
            left: -80,
            child: _AmbientGlow(size: 380, opacity: 0.16),
          ),
          Positioned(
            bottom: -120,
            right: -60,
            child: _AmbientGlow(size: 340, opacity: 0.10),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo superior
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Icon(
                        Icons.eco_rounded,
                        color: AppColors.primary,
                        size: 25,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AnimalPedia',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Admin Console',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const Spacer(),

                // Mensaje central
                const Text(
                  'Gestión inteligente\nde biodiversidad y\navistamientos.',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    height: 1.15,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Supervisa identificaciones impulsadas por IA, administra el catálogo de especies y analiza métricas en tiempo real desde un solo lugar.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 36),

                // Tarjetas de características
                const _FeatureRow(
                  icon: Icons.bar_chart_rounded,
                  title: 'Analítica Visual en Vivo',
                  subtitle: 'Monitoreo de actividad diaria y distribución por rareza.',
                ),
                const SizedBox(height: 16),
                const _FeatureRow(
                  icon: Icons.security_rounded,
                  title: 'Control de Acceso RBAC',
                  subtitle: 'Políticas de seguridad a nivel de fila (RLS) en PostgreSQL.',
                ),
                const SizedBox(height: 16),
                const _FeatureRow(
                  icon: Icons.public_rounded,
                  title: 'Catálogo & Geolocalización',
                  subtitle: 'Registro centralizado de especies y coordenadas PostGIS.',
                ),

                const Spacer(),

                // Footer
                Text(
                  '© ${DateTime.now().year} AnimalPedia · Plataforma Web de Administración',
                  style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.divider.withValues(alpha: 0.7)),
          ),
          child: Icon(icon, color: AppColors.primary, size: 19),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AmbientGlow extends StatelessWidget {
  final double size;
  final double opacity;

  const _AmbientGlow({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              AppColors.primary.withValues(alpha: opacity),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}
