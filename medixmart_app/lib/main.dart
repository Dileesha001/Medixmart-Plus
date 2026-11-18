import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/dashboard_provider.dart';
import 'screens/dashboard/admin_dashboard_screen.dart';

void main() {
  runApp(const MedixmartApp());
}

class MedixmartApp extends StatelessWidget {
  const MedixmartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
      ],
      child: MaterialApp(
        title: 'Medixmart Plus',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const AdminDashboardScreen(),
      ),
    );
  }
}
