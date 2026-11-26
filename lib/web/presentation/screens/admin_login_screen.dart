import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/colors.dart';
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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: _buildLoginCard(),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Acceso administrativo',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 24),

          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: _inputDecoration(
              label: 'Correo',
              icon: Icons.alternate_email_rounded,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            onSubmitted: (_) => _isLoading ? null : _handleLogin(),
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: _inputDecoration(
              label: 'Contraseña',
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
          const SizedBox(height: 20),
          SizedBox(
            height: 46,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
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
                          'Ingresar',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.never,
      labelStyle: TextStyle(
        color: AppColors.textSecondary.withValues(alpha: 0.8),
        fontSize: 13,
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
