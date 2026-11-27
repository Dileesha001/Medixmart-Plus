import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_theme.dart';
import 'providers/alert_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/medicine_provider.dart';
import 'providers/staff_user_provider.dart';
import 'screens/auth/auth_gate.dart';
import 'services/alert_service.dart';
import 'services/api_client.dart';
import 'services/medicine_service.dart';
import 'services/staff_user_service.dart';

void main() {
  runApp(const MedixmartApp());
}

class MedixmartApp extends StatefulWidget {
  final AuthProvider? authProvider;
  final DashboardProvider? dashboardProvider;
  final ApiClient? apiClient;
  final MedicineProvider? medicineProvider;
  final AlertProvider? alertProvider;
  final StaffUserProvider? staffUserProvider;

  const MedixmartApp({
    super.key,
    this.authProvider,
    this.dashboardProvider,
    this.apiClient,
    this.medicineProvider,
    this.alertProvider,
    this.staffUserProvider,
  });

  @override
  State<MedixmartApp> createState() => _MedixmartAppState();
}

class _MedixmartAppState extends State<MedixmartApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final AuthProvider _authProvider;
  late final DashboardProvider _dashboardProvider;
  late final ApiClient _apiClient;
  late final MedicineService _medicineService;
  late final MedicineProvider _medicineProvider;
  late final AlertService _alertService;
  late final AlertProvider _alertProvider;
  late final StaffUserService _staffUserService;
  late final StaffUserProvider _staffUserProvider;

  late final bool _ownsAuthProvider;
  late final bool _ownsDashboardProvider;
  late final bool _ownsApiClient;
  late final bool _ownsMedicineProvider;
  late final bool _ownsAlertProvider;
  late final bool _ownsStaffUserProvider;

  @override
  void initState() {
    super.initState();
    _ownsAuthProvider = widget.authProvider == null;
    _authProvider = widget.authProvider ?? AuthProvider();

    _ownsDashboardProvider = widget.dashboardProvider == null;
    _dashboardProvider = widget.dashboardProvider ?? DashboardProvider();

    _ownsApiClient = widget.apiClient == null;
    _apiClient = widget.apiClient ??
        ApiClient(
          tokenStorage: _authProvider.tokenStorage,
        );
    _apiClient.onSessionRevoked = (message) {
      _authProvider.handleSessionRevoked(message);
    };

    _medicineService = MedicineService(_apiClient);

    _ownsMedicineProvider = widget.medicineProvider == null;
    _medicineProvider = widget.medicineProvider ??
        MedicineProvider(service: _medicineService);

    _alertService = AlertService(_apiClient);

    _ownsAlertProvider = widget.alertProvider == null;
    _alertProvider =
        widget.alertProvider ?? AlertProvider(service: _alertService);

    _staffUserService = StaffUserService(_apiClient);

    _ownsStaffUserProvider = widget.staffUserProvider == null;
    _staffUserProvider = widget.staffUserProvider ??
        StaffUserProvider(service: _staffUserService);

    _authProvider.addListener(_handleAuthStateChanged);
  }

  void _handleAuthStateChanged() {
    if (!_authProvider.isAuthenticated) {
      _medicineProvider.reset();
      _alertProvider.reset();
      _staffUserProvider.reset();
      _dashboardProvider.selectNavItem('dashboard');
      _navigatorKey.currentState?.popUntil((route) => route.isFirst);
    }
  }

  @override
  void dispose() {
    _authProvider.removeListener(_handleAuthStateChanged);
    if (_ownsStaffUserProvider) _staffUserProvider.dispose();
    if (_ownsAlertProvider) _alertProvider.dispose();
    if (_ownsMedicineProvider) _medicineProvider.dispose();
    if (_ownsApiClient) _apiClient.close();
    if (_ownsDashboardProvider) _dashboardProvider.dispose();
    if (_ownsAuthProvider) _authProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
        ChangeNotifierProvider<DashboardProvider>.value(
          value: _dashboardProvider,
        ),
        Provider<ApiClient>.value(value: _apiClient),
        Provider<MedicineService>.value(value: _medicineService),
        ChangeNotifierProvider<MedicineProvider>.value(
          value: _medicineProvider,
        ),
        Provider<AlertService>.value(value: _alertService),
        ChangeNotifierProvider<AlertProvider>.value(
          value: _alertProvider,
        ),
        Provider<StaffUserService>.value(value: _staffUserService),
        ChangeNotifierProvider<StaffUserProvider>.value(
          value: _staffUserProvider,
        ),
      ],
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'Medixmart Plus',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const AuthGate(),
      ),
    );
  }
}
