import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/dashboard_provider.dart';
import 'screens/auth/auth_gate.dart';

void main() {
  runApp(const MedixmartApp());
}

class MedixmartApp extends StatelessWidget {
  final AuthProvider? authProvider;
  final DashboardProvider? dashboardProvider;

  const MedixmartApp({
    super.key,
    this.authProvider,
    this.dashboardProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        if (authProvider != null)
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider!)
        else
          ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        if (dashboardProvider != null)
          ChangeNotifierProvider<DashboardProvider>.value(
            value: dashboardProvider!,
          )
        else
          ChangeNotifierProvider<DashboardProvider>(
            create: (_) => DashboardProvider(),
          ),
      ],
      child: MaterialApp(
        title: 'Medixmart Plus',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const AuthGate(),
      ),
    );
  }
}
