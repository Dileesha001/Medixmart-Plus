import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/brand_emblem.dart';

/// Staff authentication screen for Medixmart Plus (Admin & Pharmacist).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _serverHostController = TextEditingController(
    text: ApiConfig.customHost,
  );
  final _passwordFocusNode = FocusNode();

  bool _obscurePassword = true;
  bool _showServerSettings = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _serverHostController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.isSubmitting) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    await authProvider.login(
      _usernameController.text.trim(),
      _passwordController.text,
    );
  }

  void _applyServerHost() {
    setState(() {
      ApiConfig.customHost = _serverHostController.text.trim();
      _showServerSettings = false;
    });
    context.read<AuthProvider>().clearError();
  }

  void _resetServerHost() {
    setState(() {
      _serverHostController.clear();
      ApiConfig.customHost = '';
      _showServerSettings = false;
    });
    context.read<AuthProvider>().clearError();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: MmColors.bgCanvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 860;

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? MmSpacing.xxxl : MmSpacing.lg,
                  vertical: MmSpacing.xxl,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isWide ? 900 : 440,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: MmColors.bgSurface,
                      borderRadius: BorderRadius.circular(MmRadius.lg),
                      border: Border.all(
                        color: MmColors.borderDefault,
                        width: MmElevation.strokeThin,
                      ),
                      boxShadow: MmElevation.xs,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: isWide
                        ? Stack(
                            children: [
                              Positioned.fill(
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 5,
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          color: MmColors.bgBrandSubtle,
                                          border: Border(
                                            right: BorderSide(
                                              color: MmColors.borderDefault,
                                              width: MmElevation.strokeThin,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const Expanded(
                                      flex: 6,
                                      child: ColoredBox(
                                        color: MmColors.bgSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Expanded(
                                    flex: 5,
                                    child: _BrandOverviewPane(),
                                  ),
                                  Expanded(
                                    flex: 6,
                                    child: _buildFormPane(
                                      authProvider,
                                      showCompactBrand: false,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                        : _buildFormPane(
                            authProvider,
                            showCompactBrand: true,
                          ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFormPane(
    AuthProvider authProvider, {
    required bool showCompactBrand,
  }) {
    final isSubmitting = authProvider.isSubmitting;
    final errorMessage = authProvider.errorMessage;

    return Padding(
      padding: EdgeInsets.all(showCompactBrand ? MmSpacing.xxl : 40),
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showCompactBrand) ...[
                Row(
                  children: [
                    const BrandEmblem(size: 40),
                    const SizedBox(width: MmSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Medixmart Plus',
                            style: MmTypography.headingH3,
                          ),
                          Text(
                            'PHARMACY MANAGEMENT SYSTEM',
                            style: MmTypography.labelSmall.copyWith(
                              color: MmColors.textBrand,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: MmSpacing.xxl),
              ],

              Text(
                'Staff Sign In',
                style: MmTypography.headingH2,
              ),
              const SizedBox(height: MmSpacing.xs),
              Text(
                'Sign in with your administrator or pharmacist credentials to continue.',
                style: MmTypography.bodyMedium.copyWith(
                  color: MmColors.textSecondary,
                ),
              ),
              const SizedBox(height: MmSpacing.xxl),

              if (errorMessage != null) ...[
                _AuthErrorBanner(message: errorMessage),
                const SizedBox(height: MmSpacing.lg),
              ],

              // Username Field
              Text(
                'Username',
                style: MmTypography.labelMedium.copyWith(
                  color: MmColors.textPrimary,
                ),
              ),
              const SizedBox(height: MmSpacing.xs),
              TextFormField(
                key: const Key('login_username_field'),
                controller: _usernameController,
                enabled: !isSubmitting,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                style: MmTypography.bodyMedium,
                decoration: _inputDecoration(
                  hintText: 'Enter your username',
                  prefixIcon: Icons.person_outline_rounded,
                ),
                onChanged: (_) => authProvider.clearError(),
                onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Username is required.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: MmSpacing.lg),

              // Password Field
              Text(
                'Password',
                style: MmTypography.labelMedium.copyWith(
                  color: MmColors.textPrimary,
                ),
              ),
              const SizedBox(height: MmSpacing.xs),
              TextFormField(
                key: const Key('login_password_field'),
                controller: _passwordController,
                focusNode: _passwordFocusNode,
                enabled: !isSubmitting,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                style: MmTypography.bodyMedium,
                decoration: _inputDecoration(
                  hintText: 'Enter your password',
                  prefixIcon: Icons.lock_outline_rounded,
                  suffixIcon: IconButton(
                    key: const Key('login_password_visibility_toggle'),
                    tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                    onPressed: isSubmitting
                        ? null
                        : () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18,
                      color: MmColors.textSecondary,
                    ),
                  ),
                ),
                onChanged: (_) => authProvider.clearError(),
                onFieldSubmitted: (_) => _handleSubmit(),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Password is required.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: MmSpacing.xxl),

              // Primary Sign In Action
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  key: const Key('login_submit_button'),
                  onPressed: isSubmitting ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MmColors.bgBrand,
                    foregroundColor: MmColors.textOnBrand,
                    disabledBackgroundColor:
                        MmColors.bgBrand.withValues(alpha: 0.65),
                    disabledForegroundColor: MmColors.textOnBrand,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(MmRadius.md),
                    ),
                  ),
                  child: isSubmitting
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  MmColors.textOnBrand,
                                ),
                              ),
                            ),
                            const SizedBox(width: MmSpacing.sm),
                            Text(
                              'Signing in...',
                              style: MmTypography.labelLarge.copyWith(
                                color: MmColors.textOnBrand,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          'Sign In',
                          style: MmTypography.labelLarge.copyWith(
                            color: MmColors.textOnBrand,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: MmSpacing.xl),

              // Local Pharmacy Server Connection Footer
              Container(
                padding: const EdgeInsets.only(top: MmSpacing.md),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: MmColors.borderDefault,
                      width: MmElevation.strokeThin,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.dns_outlined,
                          size: 14,
                          color: MmColors.textMuted,
                        ),
                        const SizedBox(width: MmSpacing.xs),
                        Expanded(
                          child: Text(
                            ApiConfig.baseUrl,
                            style: MmTypography.codeMono.copyWith(
                              fontSize: 11,
                              color: MmColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton(
                          key: const Key('login_server_toggle_button'),
                          onPressed: isSubmitting
                              ? null
                              : () => setState(
                                    () => _showServerSettings =
                                        !_showServerSettings,
                                  ),
                          style: TextButton.styleFrom(
                            foregroundColor: MmColors.textBrand,
                            padding: const EdgeInsets.symmetric(
                              horizontal: MmSpacing.sm,
                              vertical: MmSpacing.xs,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            _showServerSettings ? 'Cancel' : 'Change server',
                            style: MmTypography.labelSmall.copyWith(
                              color: MmColors.textBrand,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_showServerSettings) ...[
                      const SizedBox(height: MmSpacing.md),
                      TextField(
                        key: const Key('login_server_host_field'),
                        controller: _serverHostController,
                        style: MmTypography.codeMono.copyWith(
                          color: MmColors.textPrimary,
                        ),
                        decoration: _inputDecoration(
                          hintText: 'e.g. 192.168.1.100 or http://host:3000',
                          prefixIcon: Icons.wifi_rounded,
                        ),
                        onSubmitted: (_) => _applyServerHost(),
                      ),
                      const SizedBox(height: MmSpacing.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _resetServerHost,
                            style: TextButton.styleFrom(
                              foregroundColor: MmColors.textSecondary,
                            ),
                            child: Text(
                              'Use Default',
                              style: MmTypography.labelMedium.copyWith(
                                color: MmColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: MmSpacing.sm),
                          ElevatedButton(
                            key: const Key('login_server_save_button'),
                            onPressed: _applyServerHost,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: MmColors.bgBrand,
                              foregroundColor: MmColors.textOnBrand,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: MmSpacing.md,
                                vertical: MmSpacing.sm,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(MmRadius.sm),
                              ),
                            ),
                            child: Text(
                              'Apply',
                              style: MmTypography.labelMedium.copyWith(
                                color: MmColors.textOnBrand,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    final defaultBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(MmRadius.md),
      borderSide: const BorderSide(
        color: MmColors.borderDefault,
        width: MmElevation.strokeThin,
      ),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(MmRadius.md),
      borderSide: const BorderSide(
        color: MmColors.borderBrand,
        width: 1.5,
      ),
    );
    final errorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(MmRadius.md),
      borderSide: const BorderSide(
        color: MmColors.borderDanger,
        width: MmElevation.strokeThin,
      ),
    );

    return InputDecoration(
      hintText: hintText,
      hintStyle: MmTypography.bodyMedium.copyWith(color: MmColors.textMuted),
      filled: true,
      fillColor: MmColors.bgCanvas,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: MmSpacing.md,
        vertical: MmSpacing.md,
      ),
      prefixIcon: Icon(
        prefixIcon,
        size: 18,
        color: MmColors.textSecondary,
      ),
      suffixIcon: suffixIcon,
      border: defaultBorder,
      enabledBorder: defaultBorder,
      focusedBorder: focusedBorder,
      errorBorder: errorBorder,
      focusedErrorBorder: errorBorder.copyWith(
        borderSide: const BorderSide(
          color: MmColors.borderDanger,
          width: 1.5,
        ),
      ),
      errorStyle: MmTypography.bodySmall.copyWith(color: MmColors.textDanger),
    );
  }
}

class _BrandOverviewPane extends StatelessWidget {
  const _BrandOverviewPane();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const BrandEmblem(size: 44),
                  const SizedBox(width: MmSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Medixmart Plus',
                          style: MmTypography.headingH3,
                        ),
                        const SizedBox(height: MmSpacing.xxs),
                        Text(
                          'MEDIXMART PHARMACY',
                          style: MmTypography.labelSmall.copyWith(
                            color: MmColors.textBrand,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: MmSpacing.xxxl),
              Text(
                'Unified Pharmacy Operations & POS',
                style: MmTypography.headingH2.copyWith(
                  color: MmColors.textPrimary,
                ),
              ),
              const SizedBox(height: MmSpacing.md),
              Text(
                'Manage batch-level stock, FEFO counter sales, customer credit ledgers, and 7-month return-window alerts from one workstation.',
                style: MmTypography.bodyMedium.copyWith(
                  color: MmColors.textSecondary,
                ),
              ),
              const SizedBox(height: MmSpacing.xxl),
              const _FeatureBullet(
                icon: Icons.verified_user_outlined,
                title: 'Role-Based Access Control',
                subtitle: 'Protected sessions for Administrators & Pharmacists',
              ),
              const SizedBox(height: MmSpacing.md),
              const _FeatureBullet(
                icon: Icons.inventory_2_outlined,
                title: 'Expiry-First (FEFO) Inventory',
                subtitle: 'Batch tracking with proactive 7-month return alerts',
              ),
              const SizedBox(height: MmSpacing.md),
              const _FeatureBullet(
                icon: Icons.point_of_sale_outlined,
                title: 'Local-Network POS Ready',
                subtitle: 'Shared Windows & Android access over pharmacy Wi-Fi',
              ),
            ],
          ),
          const SizedBox(height: MmSpacing.xxl),
          Text(
            'Session tokens expire automatically after 8 hours for counter security.',
            style: MmTypography.bodySmall.copyWith(
              color: MmColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureBullet extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureBullet({
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
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: MmColors.bgSurface,
            borderRadius: BorderRadius.circular(MmRadius.md),
            border: Border.all(
              color: MmColors.borderBrand.withValues(alpha: 0.35),
              width: MmElevation.strokeThin,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: MmColors.iconBrand),
        ),
        const SizedBox(width: MmSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: MmTypography.labelLarge),
              const SizedBox(height: MmSpacing.xxs),
              Text(
                subtitle,
                style: MmTypography.bodySmall.copyWith(
                  color: MmColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AuthErrorBanner extends StatelessWidget {
  final String message;

  const _AuthErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('login_error_banner'),
      padding: const EdgeInsets.symmetric(
        horizontal: MmSpacing.md,
        vertical: MmSpacing.md,
      ),
      decoration: BoxDecoration(
        color: MmColors.bgDangerSubtle,
        borderRadius: BorderRadius.circular(MmRadius.md),
        border: Border.all(
          color: MmColors.borderDanger,
          width: MmElevation.strokeThin,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.error_outline_rounded,
              size: 18,
              color: MmColors.textDanger,
            ),
          ),
          const SizedBox(width: MmSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: MmTypography.bodySmall.copyWith(
                color: MmColors.textDanger,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
