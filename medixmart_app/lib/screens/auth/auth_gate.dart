import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/brand_emblem.dart';
import '../dashboard/admin_dashboard_screen.dart';
import 'login_screen.dart';

/// Root authentication router for Medixmart Plus.
///
/// Restores any persisted JWT session on startup via [AuthProvider.tryAutoLogin]
/// and routes between the splash loader, [LoginScreen], and
/// [AdminDashboardScreen].
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final authProvider = context.read<AuthProvider>();
      if (authProvider.status == AuthStatus.uninitialized) {
        authProvider.tryAutoLogin();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    if (authProvider.isAuthenticated) {
      return const AdminDashboardScreen();
    }

    if (authProvider.status == AuthStatus.uninitialized ||
        authProvider.isRestoringSession) {
      return const _SessionRestoreScreen();
    }

    return const LoginScreen();
  }
}

class _SessionRestoreScreen extends StatelessWidget {
  const _SessionRestoreScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MmColors.bgCanvas,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandEmblem(size: 56),
            const SizedBox(height: MmSpacing.lg),
            Text(
              'Medixmart Plus',
              style: MmTypography.headingH3,
            ),
            const SizedBox(height: MmSpacing.md),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(MmColors.bgBrand),
              ),
            ),
            const SizedBox(height: MmSpacing.sm),
            Text(
              'Verifying pharmacy session...',
              style: MmTypography.bodySmall.copyWith(
                color: MmColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
