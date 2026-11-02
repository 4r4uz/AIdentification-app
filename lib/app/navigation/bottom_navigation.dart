import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/features/auth/data/services/auth_service.dart';
import '/features/home/presentation/screens/home_screen.dart';
import '/features/camera/presentation/screens/camera_screen.dart';
import '/features/gallery/presentation/screens/gallery_screen.dart';
import '/features/profile/presentation/screens/profile_screen.dart';
import '/core/theme/colors.dart';

/// Modelo de datos para items de navegación
class _NavItemData {
  final IconData icon;
  final String label;

  const _NavItemData({required this.icon, required this.label});
}

class BottomNavigation extends StatefulWidget {
  const BottomNavigation({super.key});

  @override
  State<BottomNavigation> createState() => _BottomNavigationState();
}

class _BottomNavigationState extends State<BottomNavigation> {
  int _currentIndex = 0;
  bool _hasVisitedCamera = false;
  final AuthService _authService = AuthService();
  late bool _isAuthenticated;
  late final StreamSubscription<AuthState> _authSubscription;

  static const List<_NavItemData> _navItems = [
    _NavItemData(icon: Icons.home, label: 'Inicio'),
    _NavItemData(icon: Icons.camera_alt, label: 'Cámara'),
    _NavItemData(icon: Icons.collections, label: 'Galería'),
    _NavItemData(icon: Icons.person, label: 'Perfil'),
  ];

  @override
  void initState() {
    super.initState();
    _isAuthenticated = _authService.isAuthenticated;
    _authSubscription = _authService.authStateChanges.listen((_) {
      if (mounted) {
        setState(() => _isAuthenticated = _authService.isAuthenticated);
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  List<Widget> get _screens => [
    HomeScreen(onNavigate: _onItemTapped),
    _hasVisitedCamera ? const CameraScreen() : const SizedBox.shrink(),
    GalleryScreen(
      isActive: _currentIndex == 2 && _isAuthenticated,
      isAuthenticated: _isAuthenticated,
    ),
    ProfileScreen(
      isActive: _currentIndex == 3,
      isAuthenticated: _isAuthenticated,
    ),
  ];

  void _onItemTapped(int index) {
    if (index != _currentIndex) {
      setState(() {
        _currentIndex = index;
        if (index == 1) _hasVisitedCamera = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onItemTapped,
        backgroundColor: context.palette.surface,
        indicatorColor: context.palette.primarySoft,
        elevation: 0,
        destinations: _navItems
            .map(
              (item) => NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.icon, color: context.palette.primary),
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }
}
