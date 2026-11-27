import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../config/app_assets.dart';
import '../../config/app_theme.dart';
import '../../models/api_exception.dart';
import '../../models/dashboard_models.dart';
import '../../models/staff_user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/staff_user_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/kpi_summary_card.dart';
import '../../widgets/mm_button.dart';
import '../../widgets/mm_feedback_states.dart';
import '../../widgets/mm_input_field.dart';
import '../../widgets/pos_search_bar.dart';
import '../../widgets/status_badge.dart';

abstract final class _StaffBreakpoints {
  static const double compactHeader = 760.0;
  static const double kpiFourCol = 960.0;
  static const double kpiTwoCol = 560.0;
  static const double desktopSplit = 1040.0;
  static const double tableLayout = 680.0;
}

/// Responsive Staff & Account Security screen matching Figma page `66:2`
/// (`66:69` Desktop, `67:262` Mobile, `67:423` Dialogs & RBAC States).
///
/// - **All Roles (`admin`, `pharmacist`):** Change Password via
///   `PUT /api/auth/change-password` with seamless JWT rotation.
/// - **Admin Only:** Staff KPI summary strip and Staff Accounts management via
///   `GET /api/users`, `PATCH /api/users/:id/status`, and
///   `PATCH /api/users/:id/role`, including `AUTH_LAST_ADMIN_PROTECTED`
///   self-lockout error presentation.
class StaffSecurityScreen extends StatefulWidget {
  final bool showMenuButton;
  final VoidCallback? onOpenDrawer;

  const StaffSecurityScreen({
    super.key,
    this.showMenuButton = false,
    this.onOpenDrawer,
  });

  @override
  State<StaffSecurityScreen> createState() => _StaffSecurityScreenState();
}

class _StaffSecurityScreenState extends State<StaffSecurityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPwdController = TextEditingController();
  final _newPwdController = TextEditingController();
  final _confirmPwdController = TextEditingController();
  final _searchController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  String? _currentPwdServerError;
  String? _newPwdServerError;
  String? _confirmPwdServerError;
  String? _formBannerError;

  bool _staffLoadQueued = false;

  @override
  void initState() {
    super.initState();
    _scheduleStaffLoad();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleStaffLoad();
  }

  void _scheduleStaffLoad() {
    if (_staffLoadQueued) return;
    final authUser = context.read<AuthProvider?>()?.user;
    final staffProvider = context.read<StaffUserProvider?>();
    if (authUser?.isAdmin != true ||
        staffProvider == null ||
        staffProvider.hasLoadedOnce ||
        staffProvider.isLoading ||
        staffProvider.errorMessage != null) {
      return;
    }
    _staffLoadQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _staffLoadQueued = false;
      if (!mounted) return;
      final auth = context.read<AuthProvider?>()?.user;
      final provider = context.read<StaffUserProvider?>();
      if (auth?.isAdmin == true &&
          provider != null &&
          !provider.hasLoadedOnce &&
          !provider.isLoading) {
        provider.ensureLoaded();
      }
    });
  }

  @override
  void dispose() {
    _currentPwdController.dispose();
    _newPwdController.dispose();
    _confirmPwdController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: MmTypography.bodyMedium.copyWith(
              color: MmColors.textOnBrand,
            ),
          ),
          backgroundColor: isError ? MmColors.bgDanger : MmColors.textPrimary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  void _resetPasswordForm() {
    _currentPwdController.clear();
    _newPwdController.clear();
    _confirmPwdController.clear();
    setState(() {
      _currentPwdServerError = null;
      _newPwdServerError = null;
      _confirmPwdServerError = null;
      _formBannerError = null;
    });
    _formKey.currentState?.reset();
  }

  Future<void> _handleChangePassword() async {
    final authProvider = context.read<AuthProvider?>();
    if (authProvider == null || authProvider.isChangingPassword) return;

    setState(() {
      _currentPwdServerError = null;
      _newPwdServerError = null;
      _confirmPwdServerError = null;
      _formBannerError = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    try {
      final message = await authProvider.changePassword(
        currentPassword: _currentPwdController.text,
        newPassword: _newPwdController.text,
        confirmPassword: _confirmPwdController.text,
      );
      if (!mounted) return;
      _resetPasswordForm();
      _showSnackBar(message);
      if (authProvider.user?.isAdmin == true) {
        context.read<StaffUserProvider?>()?.refresh();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isSessionRevoked) return;

      final currentErr = e.fieldError('current_password') ??
          (e.code == 'AUTH_INVALID_CREDENTIALS' ? e.message : null);
      final newErr = e.fieldError('new_password');
      final confirmErr = e.fieldError('confirm_password');

      setState(() {
        _currentPwdServerError = currentErr;
        _newPwdServerError = newErr;
        _confirmPwdServerError = confirmErr;
        if (currentErr == null && newErr == null && confirmErr == null) {
          _formBannerError = e.message;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _formBannerError =
            'Unable to update password. Verify your connection and try again.';
      });
    }
  }

  Future<void> _handleToggleStatus(StaffUserModel staff) async {
    final staffProvider = context.read<StaffUserProvider?>();
    final authProvider = context.read<AuthProvider?>();
    if (staffProvider == null) return;

    final nextActive = !staff.isActive;
    final confirmed = await _showStaffActionDialog(
      context,
      iconAsset:
          nextActive ? AppAssets.iconCheckKpi : AppAssets.iconAlertTriangle,
      iconBgColor:
          nextActive ? MmColors.bgBrandSubtle : MmColors.bgDangerSubtle,
      title:
          nextActive ? 'Activate Staff Account?' : 'Deactivate Staff Account?',
      message: nextActive
          ? 'Activating "${staff.username}" restores terminal login access for this account.'
          : 'Deactivating "${staff.username}" immediately revokes all active sessions and prevents login until reactivated by an Administrator.',
      confirmLabel: nextActive ? 'Activate Account' : 'Deactivate Account',
      confirmVariant:
          nextActive ? MmButtonVariant.primary : MmButtonVariant.danger,
      confirmIconAsset: nextActive ? AppAssets.iconCheckOnBrand : null,
    );
    if (!confirmed || !mounted) return;

    try {
      final result = await staffProvider.updateUserStatus(
        staff.id,
        isActive: nextActive,
      );
      if (!mounted || result == null) return;

      if (authProvider?.user?.id == staff.id) {
        await authProvider!.handleSessionRevoked(
          'Your account status was updated. Please sign in again.',
        );
        return;
      }
      _showSnackBar(result.message);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isSessionRevoked) return;
      if (e.code != 'AUTH_LAST_ADMIN_PROTECTED') {
        _showSnackBar(e.message, isError: true);
      }
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Unable to update staff status.', isError: true);
    }
  }

  Future<void> _handleSwitchRole(StaffUserModel staff) async {
    final staffProvider = context.read<StaffUserProvider?>();
    final authProvider = context.read<AuthProvider?>();
    if (staffProvider == null) return;

    final promoteToAdmin = !staff.isAdmin;
    final targetRole = promoteToAdmin ? 'admin' : 'pharmacist';

    final confirmed = await _showStaffActionDialog(
      context,
      iconAsset: AppAssets.iconUser,
      iconBgColor: MmColors.bgInfoSubtle,
      title: promoteToAdmin
          ? 'Change Role to Administrator?'
          : 'Change Role to Pharmacist?',
      message: promoteToAdmin
          ? 'Promoting "${staff.username}" from Pharmacist to Admin grants full access to medicines, alerts, and staff management. Active sessions will be revoked so new permissions apply on next login.'
          : 'Demoting "${staff.username}" from Admin to Pharmacist restricts access to read-only catalog and standard operations. Active sessions will be revoked so new permissions apply on next login.',
      confirmLabel: promoteToAdmin ? 'Promote to Admin' : 'Demote to Pharmacist',
      confirmVariant:
          promoteToAdmin ? MmButtonVariant.primary : MmButtonVariant.danger,
      confirmIconAsset: promoteToAdmin ? AppAssets.iconCheckOnBrand : null,
    );
    if (!confirmed || !mounted) return;

    try {
      final result = await staffProvider.updateUserRole(
        staff.id,
        role: targetRole,
      );
      if (!mounted || result == null) return;

      if (authProvider?.user?.id == staff.id) {
        await authProvider!.handleSessionRevoked(
          'Your account role was updated. Please sign in again.',
        );
        return;
      }
      _showSnackBar(result.message);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isSessionRevoked) return;
      if (e.code != 'AUTH_LAST_ADMIN_PROTECTED') {
        _showSnackBar(e.message, isError: true);
      }
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Unable to update staff role.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider?>();
    final staffProvider = context.watch<StaffUserProvider?>();
    final authUser = authProvider?.user;
    final isAdmin = authUser?.isAdmin == true;

    final currentStaffRecord = staffProvider?.findUserById(authUser?.id);
    final effectiveLastPwdChange =
        authProvider?.lastPasswordChangedAt ??
        currentStaffRecord?.passwordChangedAt;

    return LayoutBuilder(
      builder: (context, constraints) {
        final areaWidth = constraints.maxWidth;
        final isCompact = areaWidth < _StaffBreakpoints.compactHeader;
        final horizontalPadding = isCompact ? MmSpacing.lg : MmSpacing.xxxl;
        final verticalPadding = isCompact ? MmSpacing.lg : MmSpacing.xxl;
        final useDesktopSplit = areaWidth >= _StaffBreakpoints.desktopSplit;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(
              isCompact: isCompact,
              isAdmin: isAdmin,
              staffProvider: staffProvider,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isAdmin && staffProvider != null) ...[
                      _buildKpiSection(
                        areaWidth: areaWidth,
                        staffProvider: staffProvider,
                        lastPwdChange: effectiveLastPwdChange,
                      ),
                      SizedBox(
                        height: isCompact ? MmSpacing.lg : MmSpacing.xl,
                      ),
                    ],
                    if (isAdmin && staffProvider != null)
                      useDesktopSplit
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 368,
                                  child: _buildChangePasswordCard(
                                    isCompact: false,
                                    isSubmitting:
                                        authProvider?.isChangingPassword ??
                                            false,
                                  ),
                                ),
                                const SizedBox(width: MmSpacing.xl),
                                Expanded(
                                  child: _buildStaffAccountsCard(
                                    staffProvider: staffProvider,
                                    currentUserId: authUser?.id,
                                    useTableLayout: true,
                                    isCompact: false,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildChangePasswordCard(
                                  isCompact: isCompact,
                                  isSubmitting:
                                      authProvider?.isChangingPassword ?? false,
                                ),
                                SizedBox(
                                  height:
                                      isCompact ? MmSpacing.lg : MmSpacing.xl,
                                ),
                                _buildStaffAccountsCard(
                                  staffProvider: staffProvider,
                                  currentUserId: authUser?.id,
                                  useTableLayout: areaWidth -
                                          (horizontalPadding * 2) >=
                                      _StaffBreakpoints.tableLayout,
                                  isCompact: isCompact,
                                ),
                              ],
                            )
                    else
                      Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: _buildChangePasswordCard(
                            isCompact: isCompact,
                            isSubmitting:
                                authProvider?.isChangingPassword ?? false,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader({
    required bool isCompact,
    required bool isAdmin,
    required StaffUserProvider? staffProvider,
  }) {
    final isRefreshing =
        staffProvider != null && (staffProvider.isLoading || staffProvider.isRefreshing);

    if (isCompact) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: MmSpacing.lg,
          vertical: MmSpacing.md,
        ),
        decoration: const BoxDecoration(
          color: MmColors.bgSurface,
          border: Border(
            bottom: BorderSide(
              color: MmColors.borderDefault,
              width: MmElevation.strokeThin,
            ),
          ),
        ),
        child: Row(
          children: [
            if (widget.showMenuButton) ...[
              InkWell(
                key: const Key('dashboard_menu_button'),
                onTap: widget.onOpenDrawer,
                borderRadius: BorderRadius.circular(MmRadius.md),
                child: Padding(
                  padding: const EdgeInsets.all(MmSpacing.xs),
                  child: SvgPicture.asset(
                    AppAssets.iconMenu,
                    width: 20,
                    height: 20,
                  ),
                ),
              ),
              const SizedBox(width: MmSpacing.sm),
            ],
            Expanded(
              child: Text(
                isAdmin ? 'Staff & Security' : 'Account Security',
                style: MmTypography.headingH4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isAdmin && staffProvider != null)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const Key('staff_refresh_button'),
                  onTap: isRefreshing ? null : () => staffProvider.refresh(),
                  borderRadius: BorderRadius.circular(MmRadius.md),
                  child: Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: MmColors.bgSubtle,
                      borderRadius: BorderRadius.circular(MmRadius.md),
                      border: Border.all(
                        color: MmColors.borderDefault,
                        width: MmElevation.strokeThin,
                      ),
                    ),
                    child: isRefreshing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                MmColors.bgBrand,
                              ),
                            ),
                          )
                        : SvgPicture.asset(
                            AppAssets.iconRefresh,
                            width: 16,
                            height: 16,
                          ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MmSpacing.xxxl,
        vertical: MmSpacing.lg,
      ),
      decoration: const BoxDecoration(
        color: MmColors.bgSurface,
        border: Border(
          bottom: BorderSide(
            color: MmColors.borderDefault,
            width: MmElevation.strokeThin,
          ),
        ),
      ),
      child: Row(
        children: [
          if (widget.showMenuButton) ...[
            InkWell(
              key: const Key('dashboard_menu_button'),
              onTap: widget.onOpenDrawer,
              borderRadius: BorderRadius.circular(MmRadius.md),
              child: Padding(
                padding: const EdgeInsets.all(MmSpacing.xs),
                child: SvgPicture.asset(
                  AppAssets.iconMenu,
                  width: 20,
                  height: 20,
                ),
              ),
            ),
            const SizedBox(width: MmSpacing.md),
          ],
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: MmSpacing.md,
              runSpacing: MmSpacing.xs,
              children: [
                Text(
                  isAdmin ? 'Staff & Account Security' : 'Account Security',
                  style: MmTypography.headingH2,
                ),
                Text(
                  isAdmin
                      ? 'Manage credentials & pharmacy staff access'
                      : 'Manage your account password & active sessions',
                  style: MmTypography.bodySmall.copyWith(
                    color: MmColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: MmSpacing.md),
          if (isAdmin)
            const StatusBadge(
              label: 'Admin Access',
              tone: StatusTone.inStock,
              showDot: true,
              isMedium: true,
            )
          else
            const _InfoPillBadge(
              label: 'Pharmacist',
              isMedium: true,
            ),
          if (isAdmin && staffProvider != null) ...[
            const SizedBox(width: MmSpacing.md),
            MmButton(
              key: const Key('staff_refresh_button'),
              label: 'Refresh',
              leadingIconAsset: AppAssets.iconRefresh,
              variant: MmButtonVariant.secondary,
              size: MmButtonSize.medium,
              isLoading: isRefreshing,
              onPressed: () => staffProvider.refresh(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKpiSection({
    required double areaWidth,
    required StaffUserProvider staffProvider,
    required DateTime? lastPwdChange,
  }) {
    final total = staffProvider.totalCount;
    final admins = staffProvider.adminCount;
    final pharmacists = staffProvider.pharmacistCount;
    final active = staffProvider.activeCount;
    final disabled = staffProvider.disabledCount;

    final totalValue =
        '${MmFormatters.twoDigitCount(total)} ${total == 1 ? 'User' : 'Users'}';
    final totalSub =
        '$admins ${admins == 1 ? 'Admin' : 'Admins'} · $pharmacists ${pharmacists == 1 ? 'Pharmacist' : 'Pharmacists'}';
    final activeValue = '${MmFormatters.twoDigitCount(active)} Active';
    final disabledValue = '${MmFormatters.twoDigitCount(disabled)} Disabled';
    final pwdDesktopVal = lastPwdChange != null
        ? MmFormatters.dayMonthYear(lastPwdChange)
        : 'Not set';
    final pwdCompactVal =
        lastPwdChange != null ? MmFormatters.dayMonth(lastPwdChange) : '—';

    // Compact 2x2 stat cards matching Figma Mobile 67:275
    if (areaWidth < _StaffBreakpoints.kpiTwoCol) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _CompactStatCard(
                  label: 'Total Staff',
                  value: totalValue,
                  valueColor: MmColors.textBrand,
                ),
              ),
              const SizedBox(width: MmSpacing.sm),
              Expanded(
                child: _CompactStatCard(
                  label: 'Active',
                  value: activeValue,
                  valueColor: MmColors.textInfo,
                ),
              ),
            ],
          ),
          const SizedBox(height: MmSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _CompactStatCard(
                  label: 'Disabled',
                  value: disabledValue,
                  valueColor: MmColors.textDanger,
                ),
              ),
              const SizedBox(width: MmSpacing.sm),
              Expanded(
                child: _CompactStatCard(
                  label: 'Pwd Updated',
                  value: pwdCompactVal,
                  valueColor: MmColors.textWarning,
                ),
              ),
            ],
          ),
        ],
      );
    }

    final cards = <Widget>[
      KpiSummaryCard(
        metric: KpiMetricType.todaySales,
        title: 'Total Staff',
        value: totalValue,
        subtitle: totalSub,
        iconAssetOverride: AppAssets.iconUser,
        onTap: () => staffProvider.setStatusFilter(StaffStatusFilter.all),
      ),
      KpiSummaryCard(
        metric: KpiMetricType.creditDue,
        title: 'Active Accounts',
        value: activeValue,
        subtitle: 'Authorized for POS & inventory',
        iconAssetOverride: AppAssets.iconCheckKpi,
        onTap: () => staffProvider.setStatusFilter(StaffStatusFilter.active),
      ),
      KpiSummaryCard(
        metric: KpiMetricType.expiring7M,
        title: 'Disabled Accounts',
        value: disabledValue,
        subtitle: 'Sessions revoked immediately',
        iconAssetOverride: AppAssets.iconAlertTriangle,
        onTap: () => staffProvider.setStatusFilter(StaffStatusFilter.disabled),
      ),
      KpiSummaryCard(
        metric: KpiMetricType.lowStock,
        title: 'Last Password Change',
        value: pwdDesktopVal,
        subtitle: 'Session verified',
        iconAssetOverride: AppAssets.iconClock,
      ),
    ];

    if (areaWidth >= _StaffBreakpoints.kpiFourCol) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: MmSpacing.lg),
            Expanded(child: cards[i]),
          ],
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: MmSpacing.lg),
            Expanded(child: cards[1]),
          ],
        ),
        const SizedBox(height: MmSpacing.lg),
        Row(
          children: [
            Expanded(child: cards[2]),
            const SizedBox(width: MmSpacing.lg),
            Expanded(child: cards[3]),
          ],
        ),
      ],
    );
  }

  Widget _buildChangePasswordCard({
    required bool isCompact,
    required bool isSubmitting,
  }) {
    final currentText = _currentPwdController.text;
    final newText = _newPwdController.text;
    final confirmText = _confirmPwdController.text;

    final meetsMinLength = newText.length >= 8;
    final isDifferent = newText.isNotEmpty && newText != currentText;
    final matchesConfirm = confirmText.isNotEmpty && confirmText == newText;

    return Container(
      key: const Key('change_password_card'),
      padding: EdgeInsets.all(isCompact ? MmSpacing.lg : MmSpacing.xl),
      decoration: BoxDecoration(
        color: MmColors.bgSurface,
        borderRadius: BorderRadius.circular(MmRadius.lg),
        border: Border.all(
          color: MmColors.borderDefault,
          width: MmElevation.strokeThin,
        ),
        boxShadow: MmElevation.xs,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCompact)
              Row(
                children: [
                  SvgPicture.asset(
                    AppAssets.iconShieldCheck,
                    width: 20,
                    height: 20,
                  ),
                  const SizedBox(width: MmSpacing.sm),
                  Text('Change Password', style: MmTypography.headingH4),
                ],
              )
            else
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: MmColors.bgBrandSubtle,
                      borderRadius: BorderRadius.circular(MmRadius.md),
                    ),
                    child: SvgPicture.asset(
                      AppAssets.iconShieldCheck,
                      width: 20,
                      height: 20,
                    ),
                  ),
                  const SizedBox(width: MmSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Change Password', style: MmTypography.headingH3),
                        const SizedBox(height: MmSpacing.xxs),
                        Text(
                          'Rotate credentials & revoke other devices',
                          style: MmTypography.bodySmall.copyWith(
                            color: MmColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            if (_formBannerError != null) ...[
              const SizedBox(height: MmSpacing.md),
              Container(
                key: const Key('pwd_form_error_banner'),
                padding: const EdgeInsets.all(MmSpacing.md),
                decoration: BoxDecoration(
                  color: MmColors.bgDangerSubtle,
                  borderRadius: BorderRadius.circular(MmRadius.md),
                  border: Border.all(
                    color: MmColors.borderDanger,
                    width: MmElevation.strokeThin,
                  ),
                ),
                child: Text(
                  _formBannerError!,
                  style: MmTypography.bodySmall.copyWith(
                    color: MmColors.textDanger,
                  ),
                ),
              ),
            ],
            SizedBox(height: isCompact ? MmSpacing.md : MmSpacing.lg),
            MmInputField(
              fieldKey: const Key('pwd_current_field'),
              label: 'Current Password *',
              hintText: 'Enter current password',
              controller: _currentPwdController,
              obscureText: _obscureCurrent,
              enabled: !isSubmitting,
              errorText: _currentPwdServerError,
              textInputAction: TextInputAction.next,
              leadingIcon: SvgPicture.asset(
                AppAssets.iconLock,
                width: 16,
                height: 16,
              ),
              trailingIcon: _VisibilityToggle(
                obscured: _obscureCurrent,
                onTap: () =>
                    setState(() => _obscureCurrent = !_obscureCurrent),
              ),
              onChanged: (_) => setState(() {
                _currentPwdServerError = null;
                _formBannerError = null;
              }),
              validator: (val) {
                if (val == null || val.isEmpty) {
                  return 'Current password is required.';
                }
                return null;
              },
            ),
            const SizedBox(height: MmSpacing.md),
            MmInputField(
              fieldKey: const Key('pwd_new_field'),
              label: 'New Password *',
              hintText: 'Enter new password',
              helperText: isCompact
                  ? null
                  : 'Min 8 characters · Different from current',
              controller: _newPwdController,
              obscureText: _obscureNew,
              enabled: !isSubmitting,
              errorText: _newPwdServerError,
              textInputAction: TextInputAction.next,
              leadingIcon: SvgPicture.asset(
                AppAssets.iconLock,
                width: 16,
                height: 16,
              ),
              trailingIcon: _VisibilityToggle(
                obscured: _obscureNew,
                onTap: () => setState(() => _obscureNew = !_obscureNew),
              ),
              onChanged: (_) => setState(() {
                _newPwdServerError = null;
                _formBannerError = null;
              }),
              validator: (val) {
                if (val == null || val.isEmpty) {
                  return 'New password is required.';
                }
                if (val.length < 8) {
                  return 'Password must be at least 8 characters long.';
                }
                if (val == _currentPwdController.text) {
                  return 'New password must differ from current password.';
                }
                return null;
              },
            ),
            const SizedBox(height: MmSpacing.md),
            MmInputField(
              fieldKey: const Key('pwd_confirm_field'),
              label: 'Confirm New Password *',
              hintText: 'Re-enter new password',
              controller: _confirmPwdController,
              obscureText: _obscureConfirm,
              enabled: !isSubmitting,
              errorText: _confirmPwdServerError,
              textInputAction: TextInputAction.done,
              leadingIcon: SvgPicture.asset(
                AppAssets.iconLock,
                width: 16,
                height: 16,
              ),
              trailingIcon: _VisibilityToggle(
                obscured: _obscureConfirm,
                onTap: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              onChanged: (_) => setState(() {
                _confirmPwdServerError = null;
                _formBannerError = null;
              }),
              onFieldSubmitted: (_) => _handleChangePassword(),
              validator: (val) {
                if (val == null || val.isEmpty) {
                  return 'Password confirmation is required.';
                }
                if (val != _newPwdController.text) {
                  return 'Confirmation password does not match.';
                }
                return null;
              },
            ),
            if (!isCompact) ...[
              const SizedBox(height: MmSpacing.lg),
              Container(
                padding: const EdgeInsets.all(MmSpacing.md),
                decoration: BoxDecoration(
                  color: MmColors.bgSubtle,
                  borderRadius: BorderRadius.circular(MmRadius.md),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PasswordRuleRow(
                      label: 'At least 8 characters long',
                      satisfied: meetsMinLength,
                    ),
                    const SizedBox(height: MmSpacing.xs),
                    _PasswordRuleRow(
                      label: 'Different from your current password',
                      satisfied: isDifferent,
                    ),
                    const SizedBox(height: MmSpacing.xs),
                    _PasswordRuleRow(
                      label: 'Confirmation matches new password',
                      satisfied: matchesConfirm,
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: isCompact ? MmSpacing.md : MmSpacing.lg),
            if (isCompact)
              MmButton(
                key: const Key('pwd_submit_button'),
                label: 'Update Password',
                leadingIconAsset: AppAssets.iconCheckOnBrand,
                variant: MmButtonVariant.primary,
                size: MmButtonSize.large,
                isLoading: isSubmitting,
                onPressed: _handleChangePassword,
              )
            else
              Row(
                children: [
                  Expanded(
                    child: MmButton(
                      key: const Key('pwd_submit_button'),
                      label: 'Update Password',
                      leadingIconAsset: AppAssets.iconCheckOnBrand,
                      variant: MmButtonVariant.primary,
                      size: MmButtonSize.large,
                      isLoading: isSubmitting,
                      onPressed: _handleChangePassword,
                    ),
                  ),
                  const SizedBox(width: MmSpacing.sm),
                  MmButton(
                    key: const Key('pwd_reset_button'),
                    label: 'Reset',
                    variant: MmButtonVariant.secondary,
                    size: MmButtonSize.large,
                    onPressed: isSubmitting ? null : _resetPasswordForm,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffAccountsCard({
    required StaffUserProvider staffProvider,
    required int? currentUserId,
    required bool useTableLayout,
    required bool isCompact,
  }) {
    final filtered = staffProvider.filteredUsers;

    if (isCompact) {
      return Column(
        key: const Key('staff_accounts_section'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Staff Accounts (${staffProvider.totalCount})',
                  style: MmTypography.headingH4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: MmSpacing.sm),
              const _InfoPillBadge(label: 'Admin Only'),
            ],
          ),
          const SizedBox(height: MmSpacing.md),
          PosSearchBar(
            key: const Key('staff_search_bar'),
            placeholder: 'Search staff username...',
            width: null,
            controller: _searchController,
            onChanged: staffProvider.setSearchQuery,
          ),
          const SizedBox(height: MmSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _buildStatusSegmentedControl(staffProvider),
          ),
          if (staffProvider.actionError != null) ...[
            const SizedBox(height: MmSpacing.md),
            _ActionErrorBanner(
              error: staffProvider.actionError!,
              onDismiss: staffProvider.clearActionError,
            ),
          ],
          const SizedBox(height: MmSpacing.md),
          _buildStaffCollectionBody(
            staffProvider: staffProvider,
            filtered: filtered,
            currentUserId: currentUserId,
            useTableLayout: false,
          ),
        ],
      );
    }

    return Container(
      key: const Key('staff_accounts_section'),
      padding: const EdgeInsets.all(MmSpacing.xl),
      decoration: BoxDecoration(
        color: MmColors.bgSurface,
        borderRadius: BorderRadius.circular(MmRadius.lg),
        border: Border.all(
          color: MmColors.borderDefault,
          width: MmElevation.strokeThin,
        ),
        boxShadow: MmElevation.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Staff Accounts', style: MmTypography.headingH3),
                        const SizedBox(width: MmSpacing.sm),
                        const _InfoPillBadge(label: 'Admin Only'),
                      ],
                    ),
                    const SizedBox(height: MmSpacing.xxs),
                    Text(
                      'Manage staff roles and active terminal access',
                      style: MmTypography.bodySmall.copyWith(
                        color: MmColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Showing ${filtered.length} of ${staffProvider.totalCount} staff',
                style: MmTypography.bodySmall.copyWith(
                  color: MmColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: MmSpacing.lg),
          LayoutBuilder(
            builder: (context, toolbarConstraints) {
              final singleRowToolbar = toolbarConstraints.maxWidth >= 560;
              if (singleRowToolbar) {
                return Row(
                  children: [
                    Expanded(
                      child: PosSearchBar(
                        key: const Key('staff_search_bar'),
                        placeholder: 'Search staff by username...',
                        width: null,
                        controller: _searchController,
                        onChanged: staffProvider.setSearchQuery,
                      ),
                    ),
                    const SizedBox(width: MmSpacing.md),
                    _buildStatusSegmentedControl(staffProvider),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PosSearchBar(
                    key: const Key('staff_search_bar'),
                    placeholder: 'Search staff by username...',
                    width: null,
                    controller: _searchController,
                    onChanged: staffProvider.setSearchQuery,
                  ),
                  const SizedBox(height: MmSpacing.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _buildStatusSegmentedControl(staffProvider),
                  ),
                ],
              );
            },
          ),
          if (staffProvider.actionError != null) ...[
            const SizedBox(height: MmSpacing.md),
            _ActionErrorBanner(
              error: staffProvider.actionError!,
              onDismiss: staffProvider.clearActionError,
            ),
          ],
          if (staffProvider.isRefreshing) ...[
            const SizedBox(height: MmSpacing.md),
            const ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(MmRadius.full)),
              child: LinearProgressIndicator(
                minHeight: 2,
                color: MmColors.bgBrand,
                backgroundColor: MmColors.bgBrandSubtle,
              ),
            ),
          ],
          const SizedBox(height: MmSpacing.lg),
          _buildStaffCollectionBody(
            staffProvider: staffProvider,
            filtered: filtered,
            currentUserId: currentUserId,
            useTableLayout: useTableLayout,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSegmentedControl(StaffUserProvider staffProvider) {
    final tabs = [
      (
        key: const Key('staff_filter_all'),
        filter: StaffStatusFilter.all,
        label: 'All (${staffProvider.totalCount})',
      ),
      (
        key: const Key('staff_filter_active'),
        filter: StaffStatusFilter.active,
        label: 'Active (${staffProvider.activeCount})',
      ),
      (
        key: const Key('staff_filter_disabled'),
        filter: StaffStatusFilter.disabled,
        label: 'Disabled (${staffProvider.disabledCount})',
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(MmSpacing.xs),
      decoration: BoxDecoration(
        color: MmColors.bgSubtle,
        borderRadius: BorderRadius.circular(MmRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < tabs.length; i++) ...[
            if (i > 0) const SizedBox(width: MmSpacing.xs),
            InkWell(
              key: tabs[i].key,
              onTap: () => staffProvider.setStatusFilter(tabs[i].filter),
              borderRadius: BorderRadius.circular(MmRadius.sm),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: MmSpacing.md,
                  vertical: MmSpacing.xs,
                ),
                decoration: staffProvider.statusFilter == tabs[i].filter
                    ? BoxDecoration(
                        color: MmColors.bgSurface,
                        borderRadius: BorderRadius.circular(MmRadius.sm),
                        boxShadow: MmElevation.xs,
                      )
                    : null,
                child: Text(
                  tabs[i].label,
                  style: MmTypography.labelMedium.copyWith(
                    color: staffProvider.statusFilter == tabs[i].filter
                        ? MmColors.textPrimary
                        : MmColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStaffCollectionBody({
    required StaffUserProvider staffProvider,
    required List<StaffUserModel> filtered,
    required int? currentUserId,
    required bool useTableLayout,
  }) {
    if (staffProvider.isLoading && !staffProvider.hasLoadedOnce) {
      return const MmLoadingView(message: 'Loading staff accounts...');
    }

    if (staffProvider.errorMessage != null && staffProvider.users.isEmpty) {
      return MmErrorState(
        title: 'Unable to load staff accounts',
        message: staffProvider.errorMessage!,
        onRetry: () => staffProvider.refresh(),
      );
    }

    if (filtered.isEmpty) {
      final hasActiveFilter = staffProvider.searchQuery.trim().isNotEmpty ||
          staffProvider.statusFilter != StaffStatusFilter.all;
      return MmEmptyState(
        icon: Icons.people_outline_rounded,
        title: hasActiveFilter
            ? 'No staff match your filters'
            : 'No staff accounts found',
        message: hasActiveFilter
            ? 'Try clearing your search query or switching the status filter.'
            : 'Staff accounts registered in the backend will appear here.',
        actionLabel: hasActiveFilter ? 'Clear Filters' : null,
        onAction: hasActiveFilter
            ? () {
                _searchController.clear();
                staffProvider.setSearchQuery('');
                staffProvider.setStatusFilter(StaffStatusFilter.all);
              }
            : null,
      );
    }

    if (!useTableLayout) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < filtered.length; i++) ...[
            if (i > 0) const SizedBox(height: MmSpacing.md),
            _StaffMobileCard(
              user: filtered[i],
              isCurrentUser: filtered[i].id == currentUserId,
              isMutating: staffProvider.isMutatingUser(filtered[i].id),
              onSwitchRole: () => _handleSwitchRole(filtered[i]),
              onToggleStatus: () => _handleToggleStatus(filtered[i]),
            ),
          ],
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: MmColors.bgSurface,
        borderRadius: BorderRadius.circular(MmRadius.md),
        border: Border.all(
          color: MmColors.borderDefault,
          width: MmElevation.strokeThin,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MmRadius.md - 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Table Header Row matching Figma 66:332
            Container(
              padding: const EdgeInsets.all(MmSpacing.md),
              decoration: const BoxDecoration(
                color: MmColors.bgSubtle,
                border: Border(
                  bottom: BorderSide(
                    color: MmColors.borderDefault,
                    width: MmElevation.strokeThin,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'STAFF MEMBER',
                      style: MmTypography.labelSmall.copyWith(
                        color: MmColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: MmSpacing.sm),
                  SizedBox(
                    width: 84,
                    child: Text(
                      'ROLE',
                      style: MmTypography.labelSmall.copyWith(
                        color: MmColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: MmSpacing.sm),
                  SizedBox(
                    width: 82,
                    child: Text(
                      'STATUS',
                      style: MmTypography.labelSmall.copyWith(
                        color: MmColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: MmSpacing.sm),
                  SizedBox(
                    width: 84,
                    child: Text(
                      'PWD DATE',
                      style: MmTypography.labelSmall.copyWith(
                        color: MmColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: MmSpacing.sm),
                  SizedBox(
                    width: 168,
                    child: Text(
                      'ACTIONS',
                      textAlign: TextAlign.right,
                      style: MmTypography.labelSmall.copyWith(
                        color: MmColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            for (var i = 0; i < filtered.length; i++)
              _StaffTableRow(
                user: filtered[i],
                isCurrentUser: filtered[i].id == currentUserId,
                isMutating: staffProvider.isMutatingUser(filtered[i].id),
                showBottomBorder: i < filtered.length - 1,
                onSwitchRole: () => _handleSwitchRole(filtered[i]),
                onToggleStatus: () => _handleToggleStatus(filtered[i]),
              ),
          ],
        ),
      ),
    );
  }
}

class _StaffTableRow extends StatelessWidget {
  final StaffUserModel user;
  final bool isCurrentUser;
  final bool isMutating;
  final bool showBottomBorder;
  final VoidCallback onSwitchRole;
  final VoidCallback onToggleStatus;

  const _StaffTableRow({
    required this.user,
    required this.isCurrentUser,
    required this.isMutating,
    required this.showBottomBorder,
    required this.onSwitchRole,
    required this.onToggleStatus,
  });

  String _metaLine() {
    if (isCurrentUser) {
      return 'ID #${user.id} · Current session (You)';
    }
    if (!user.isActive && user.updatedAt != null) {
      return 'ID #${user.id} · Disabled ${MmFormatters.dayMonth(user.updatedAt!)}';
    }
    if (user.createdAt != null) {
      return 'ID #${user.id} · Since ${MmFormatters.monthYear(user.createdAt!)}';
    }
    return 'ID #${user.id}';
  }

  @override
  Widget build(BuildContext context) {
    final rowBg = user.isActive ? MmColors.bgSurface : MmColors.bgSubtle;
    final avatarBg = !user.isActive
        ? MmColors.bgSubtle
        : user.isAdmin
            ? MmColors.bgBrandSubtle
            : MmColors.bgInfoSubtle;
    final avatarBorder = !user.isActive
        ? MmColors.borderStrong
        : user.isAdmin
            ? MmColors.borderBrand
            : MmColors.borderInfo;
    final avatarText = !user.isActive
        ? MmColors.textMuted
        : user.isAdmin
            ? MmColors.textBrand
            : MmColors.textInfo;

    return Container(
      key: Key('staff_row_${user.id}'),
      padding: const EdgeInsets.all(MmSpacing.md),
      decoration: BoxDecoration(
        color: rowBg,
        border: showBottomBorder
            ? const Border(
                bottom: BorderSide(
                  color: MmColors.borderDefault,
                  width: MmElevation.strokeThin,
                ),
              )
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: avatarBg,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: avatarBorder,
                      width: MmElevation.strokeThin,
                    ),
                  ),
                  child: Text(
                    user.initials,
                    style: MmTypography.labelSmall.copyWith(color: avatarText),
                  ),
                ),
                const SizedBox(width: MmSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user.username,
                        style: MmTypography.labelLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: MmSpacing.xxs),
                      Text(
                        _metaLine(),
                        style: MmTypography.bodySmall.copyWith(
                          color: MmColors.textMuted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: MmSpacing.sm),
          SizedBox(
            width: 84,
            child: Align(
              alignment: Alignment.centerLeft,
              child: user.isAdmin
                  ? const StatusBadge(
                      label: 'Admin',
                      tone: StatusTone.inStock,
                      showDot: false,
                    )
                  : const _InfoPillBadge(label: 'Pharmacist'),
            ),
          ),
          const SizedBox(width: MmSpacing.sm),
          SizedBox(
            width: 82,
            child: Align(
              alignment: Alignment.centerLeft,
              child: StatusBadge(
                label: user.isActive ? 'Active' : 'Disabled',
                tone: user.isActive ? StatusTone.inStock : StatusTone.expired,
                showDot: true,
              ),
            ),
          ),
          const SizedBox(width: MmSpacing.sm),
          SizedBox(
            width: 84,
            child: Text(
              user.passwordChangedAt != null
                  ? MmFormatters.isoDate(user.passwordChangedAt!)
                  : '—',
              style: MmTypography.codeMono,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: MmSpacing.sm),
          SizedBox(
            width: 168,
            child: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: MmSpacing.xs,
              runSpacing: MmSpacing.xs,
              children: [
                MmButton(
                  key: Key('staff_role_btn_${user.id}'),
                  label: user.isAdmin ? 'Demote' : 'Promote',
                  variant: MmButtonVariant.secondary,
                  size: MmButtonSize.small,
                  onPressed: isMutating ? null : onSwitchRole,
                ),
                MmButton(
                  key: Key('staff_status_btn_${user.id}'),
                  label: user.isActive ? 'Disable' : 'Activate',
                  variant: user.isActive
                      ? MmButtonVariant.danger
                      : MmButtonVariant.primary,
                  size: MmButtonSize.small,
                  isLoading: isMutating,
                  onPressed: isMutating ? null : onToggleStatus,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StaffMobileCard extends StatelessWidget {
  final StaffUserModel user;
  final bool isCurrentUser;
  final bool isMutating;
  final VoidCallback onSwitchRole;
  final VoidCallback onToggleStatus;

  const _StaffMobileCard({
    required this.user,
    required this.isCurrentUser,
    required this.isMutating,
    required this.onSwitchRole,
    required this.onToggleStatus,
  });

  String _metaLine() {
    if (isCurrentUser) {
      return 'ID #${user.id} · Current session (You)';
    }
    if (!user.isActive && user.updatedAt != null) {
      return 'ID #${user.id} · Deactivated ${MmFormatters.isoDate(user.updatedAt!)}';
    }
    if (user.passwordChangedAt != null) {
      return 'ID #${user.id} · Pwd changed ${MmFormatters.isoDate(user.passwordChangedAt!)}';
    }
    return 'ID #${user.id}';
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = user.isActive ? MmColors.bgSurface : MmColors.bgSubtle;
    final avatarBg = !user.isActive
        ? MmColors.bgSubtle
        : user.isAdmin
            ? MmColors.bgBrandSubtle
            : MmColors.bgInfoSubtle;
    final avatarBorder = !user.isActive
        ? MmColors.borderStrong
        : user.isAdmin
            ? MmColors.borderBrand
            : MmColors.borderInfo;
    final avatarText = !user.isActive
        ? MmColors.textMuted
        : user.isAdmin
            ? MmColors.textBrand
            : MmColors.textInfo;

    return Container(
      key: Key('staff_mobile_card_${user.id}'),
      padding: const EdgeInsets.all(MmSpacing.lg),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(MmRadius.lg),
        border: Border.all(
          color: MmColors.borderDefault,
          width: MmElevation.strokeThin,
        ),
        boxShadow: MmElevation.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: avatarBg,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: avatarBorder,
                    width: MmElevation.strokeThin,
                  ),
                ),
                child: Text(
                  user.initials,
                  style: MmTypography.labelSmall.copyWith(color: avatarText),
                ),
              ),
              const SizedBox(width: MmSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.username,
                      style: MmTypography.labelLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: MmSpacing.xxs),
                    Text(
                      _metaLine(),
                      style: MmTypography.bodySmall.copyWith(
                        color: MmColors.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: MmSpacing.md),
          Wrap(
            spacing: MmSpacing.sm,
            runSpacing: MmSpacing.xs,
            children: [
              if (user.isAdmin)
                const StatusBadge(
                  label: 'Admin',
                  tone: StatusTone.inStock,
                  showDot: false,
                )
              else
                const _InfoPillBadge(label: 'Pharmacist'),
              StatusBadge(
                label: user.isActive ? 'Active' : 'Disabled',
                tone: user.isActive ? StatusTone.inStock : StatusTone.expired,
                showDot: true,
              ),
            ],
          ),
          const SizedBox(height: MmSpacing.md),
          Row(
            children: [
              Expanded(
                child: MmButton(
                  key: Key('staff_role_btn_${user.id}'),
                  label: user.isAdmin ? 'Demote' : 'Make Admin',
                  variant: MmButtonVariant.secondary,
                  size: MmButtonSize.small,
                  onPressed: isMutating ? null : onSwitchRole,
                ),
              ),
              const SizedBox(width: MmSpacing.sm),
              Expanded(
                child: MmButton(
                  key: Key('staff_status_btn_${user.id}'),
                  label: user.isActive ? 'Deactivate' : 'Activate',
                  variant: user.isActive
                      ? MmButtonVariant.danger
                      : MmButtonVariant.primary,
                  size: MmButtonSize.small,
                  isLoading: isMutating,
                  onPressed: isMutating ? null : onToggleStatus,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _CompactStatCard({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(MmSpacing.md),
      decoration: BoxDecoration(
        color: MmColors.bgSurface,
        borderRadius: BorderRadius.circular(MmRadius.lg),
        border: Border.all(
          color: MmColors.borderDefault,
          width: MmElevation.strokeThin,
        ),
        boxShadow: MmElevation.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: MmTypography.labelMedium.copyWith(
              color: MmColors.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: MmSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: MmTypography.headingH3.copyWith(color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordRuleRow extends StatelessWidget {
  final String label;
  final bool satisfied;

  const _PasswordRuleRow({
    required this.label,
    required this.satisfied,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (satisfied)
          SvgPicture.asset(
            AppAssets.iconCheckBrand,
            width: 14,
            height: 14,
          )
        else
          Container(
            width: 14,
            height: 14,
            alignment: Alignment.center,
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: MmColors.textMuted,
                shape: BoxShape.circle,
              ),
            ),
          ),
        const SizedBox(width: MmSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: MmTypography.bodySmall.copyWith(
              color: satisfied ? MmColors.textBrand : MmColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _VisibilityToggle extends StatelessWidget {
  final bool obscured;
  final VoidCallback onTap;

  const _VisibilityToggle({
    required this.obscured,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(MmRadius.sm),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Icon(
          obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          size: 16,
          color: MmColors.textMuted,
        ),
      ),
    );
  }
}

class _InfoPillBadge extends StatelessWidget {
  final String label;
  final bool isMedium;

  const _InfoPillBadge({
    required this.label,
    this.isMedium = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMedium ? MmSpacing.md : MmSpacing.sm,
        vertical: isMedium ? MmSpacing.xs : MmSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: MmColors.bgInfoSubtle,
        borderRadius: BorderRadius.circular(MmRadius.full),
        border: Border.all(
          color: MmColors.borderInfo,
          width: MmElevation.strokeThin,
        ),
      ),
      child: Text(
        label,
        style: (isMedium ? MmTypography.labelMedium : MmTypography.labelSmall)
            .copyWith(color: MmColors.textInfo),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }
}

/// Inline danger callout card matching Figma `67:462` (`AUTH_LAST_ADMIN_PROTECTED`).
class _ActionErrorBanner extends StatelessWidget {
  final ApiException error;
  final VoidCallback onDismiss;

  const _ActionErrorBanner({
    required this.error,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isLastAdmin = error.code == 'AUTH_LAST_ADMIN_PROTECTED';

    return Container(
      key: const Key('staff_action_error_banner'),
      padding: const EdgeInsets.all(MmSpacing.lg),
      decoration: BoxDecoration(
        color: MmColors.bgDangerSubtle,
        borderRadius: BorderRadius.circular(MmRadius.lg),
        border: Border.all(
          color: MmColors.borderDanger,
          width: MmElevation.strokeThin,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isLastAdmin
                      ? 'Action Blocked — Last Active Admin'
                      : 'Action Blocked',
                  style: MmTypography.headingH4.copyWith(
                    color: MmColors.textDanger,
                  ),
                ),
              ),
              if (error.statusCode == 403)
                const StatusBadge(
                  label: '403 Forbidden',
                  tone: StatusTone.expired,
                  showDot: false,
                ),
              const SizedBox(width: MmSpacing.xs),
              InkWell(
                key: const Key('staff_action_error_dismiss'),
                onTap: onDismiss,
                borderRadius: BorderRadius.circular(MmRadius.sm),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: MmColors.textDanger,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: MmSpacing.sm),
          Text(
            error.message,
            style: MmTypography.bodySmall.copyWith(
              color: MmColors.textDanger,
            ),
          ),
          const SizedBox(height: MmSpacing.sm),
          Text(
            'code: ${error.code}',
            style: MmTypography.codeMono.copyWith(
              color: MmColors.textDanger,
            ),
          ),
        ],
      ),
    );
  }
}

/// Modal confirmation dialog matching Figma `67:425` and `67:443`.
Future<bool> _showStaffActionDialog(
  BuildContext context, {
  required String iconAsset,
  required Color iconBgColor,
  required String title,
  required String message,
  required String confirmLabel,
  required MmButtonVariant confirmVariant,
  String? confirmIconAsset,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Container(
            padding: const EdgeInsets.all(MmSpacing.xxl),
            decoration: BoxDecoration(
              color: MmColors.bgSurface,
              borderRadius: BorderRadius.circular(MmRadius.lg),
              border: Border.all(
                color: MmColors.borderDefault,
                width: MmElevation.strokeThin,
              ),
              boxShadow: MmElevation.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: iconBgColor,
                        borderRadius: BorderRadius.circular(MmRadius.md),
                      ),
                      child: SvgPicture.asset(
                        iconAsset,
                        width: 20,
                        height: 20,
                      ),
                    ),
                    const SizedBox(width: MmSpacing.md),
                    Expanded(
                      child: Text(title, style: MmTypography.headingH3),
                    ),
                  ],
                ),
                const SizedBox(height: MmSpacing.lg),
                Text(
                  message,
                  style: MmTypography.bodyMedium.copyWith(
                    color: MmColors.textSecondary,
                  ),
                ),
                const SizedBox(height: MmSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    MmButton(
                      key: const Key('staff_dialog_cancel'),
                      label: 'Cancel',
                      variant: MmButtonVariant.secondary,
                      size: MmButtonSize.medium,
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                    ),
                    const SizedBox(width: MmSpacing.sm),
                    MmButton(
                      key: const Key('staff_dialog_confirm'),
                      label: confirmLabel,
                      leadingIconAsset: confirmIconAsset,
                      variant: confirmVariant,
                      size: MmButtonSize.medium,
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  return result ?? false;
}
