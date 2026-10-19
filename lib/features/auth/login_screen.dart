import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import 'data/auth_repository.dart';

/// Form rules for S02, kept apart from the widget so they are easy to test.
abstract final class AuthValidation {
  static const minPasswordLength = 8;
  static const nicknameMin = 2;
  static const nicknameMax = 24;

  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static bool isEmail(String value) => _email.hasMatch(value.trim());

  static bool isNickname(String value) {
    final length = value.trim().length;
    return length >= nicknameMin && length <= nicknameMax;
  }
}

/// S02 Logowanie i rejestracja. After a successful sign-in or registration
/// the start flow moves on by itself (S03 or the map).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 2, vsync: this);
  final _formKey = GlobalKey<FormState>();
  final _emailField = GlobalKey<FormFieldState<String>>();
  final _passwordField = GlobalKey<FormFieldState<String>>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _nickname = TextEditingController();

  bool _obscure = true;
  bool _loading = false;

  /// Errors from Firebase, shown under the field until it is edited.
  String? _emailServerError;
  String? _passwordServerError;

  bool get _register => _tabs.index == 1;

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) return;
      setState(() {
        _emailServerError = null;
        _passwordServerError = null;
      });
      _formKey.currentState?.reset();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _email.dispose();
    _password.dispose();
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _emailServerError = null;
      _passwordServerError = null;
    });
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    final repo = ref.read(authRepositoryProvider);
    try {
      if (_register) {
        await repo.register(
          email: _email.text,
          password: _password.text,
          nickname: _nickname.text,
        );
      } else {
        await repo.signIn(email: _email.text, password: _password.text);
      }
    } on AuthException catch (e) {
      if (mounted) _showFailure(e.failure);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showFailure(AuthFailure failure) {
    final l10n = AppLocalizations.of(context);
    switch (failure) {
      case AuthFailure.wrongCredentials:
        _passwordServerError = l10n.authErrorWrongCredentials;
      case AuthFailure.emailInUse:
        _emailServerError = l10n.authErrorEmailInUse;
      case AuthFailure.invalidEmail:
        _emailServerError = l10n.authEmailInvalid;
      case AuthFailure.weakPassword:
        _passwordServerError = l10n.authErrorWeakPassword;
      case AuthFailure.network:
        _showMessage(l10n.authErrorNetwork, warning: true);
        return;
      case AuthFailure.unknown:
        _showMessage(l10n.authErrorUnknown, warning: true);
        return;
    }
    _formKey.currentState!.validate();
  }

  void _showMessage(String text, {bool warning = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              if (warning) ...[
                const Icon(Icons.warning_rounded, color: AppColors.heat1),
                const SizedBox(width: AppSizes.s12),
              ],
              Expanded(child: Text(text)),
            ],
          ),
        ),
      );
  }

  Future<void> _forgotPassword() async {
    final l10n = AppLocalizations.of(context);
    var email = _email.text.trim();
    if (!AuthValidation.isEmail(email)) {
      final entered = await showDialog<String>(
        context: context,
        builder: (_) => _ResetDialog(initialEmail: email),
      );
      if (entered == null || !mounted) return;
      email = entered.trim();
    }
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(email);
      if (mounted) _showMessage(l10n.authResetSent(email));
    } on AuthException catch (e) {
      if (!mounted) return;
      _showMessage(switch (e.failure) {
        AuthFailure.network => l10n.authErrorNetwork,
        AuthFailure.invalidEmail => l10n.authEmailInvalid,
        _ => l10n.authErrorUnknown,
      }, warning: true);
    }
  }

  String? _validateEmail(String? value) {
    final l10n = AppLocalizations.of(context);
    final email = value?.trim() ?? '';
    if (email.isEmpty) return l10n.authEmailRequired;
    if (!AuthValidation.isEmail(email)) return l10n.authEmailInvalid;
    return _emailServerError;
  }

  String? _validatePassword(String? value) {
    final l10n = AppLocalizations.of(context);
    final password = value ?? '';
    if (password.isEmpty) return l10n.authPasswordRequired;
    if (_register && password.length < AuthValidation.minPasswordLength) {
      return l10n.authPasswordTooShort;
    }
    return _passwordServerError;
  }

  String? _validateNickname(String? value) =>
      AuthValidation.isNickname(value ?? '')
      ? null
      : AppLocalizations.of(context).authNicknameLength;

  /// Editing a field hides the Firebase error shown under it.
  void _clearServerError(GlobalKey<FormFieldState<String>> field) {
    if (field == _emailField && _emailServerError != null) {
      _emailServerError = null;
      field.currentState?.validate();
    } else if (field == _passwordField && _passwordServerError != null) {
      _passwordServerError = null;
      field.currentState?.validate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.screenPadding),
          children: [
            const SizedBox(height: AppSizes.s16),
            _Header(tagline: l10n.authTagline),
            const SizedBox(height: AppSizes.s24),
            _AuthTabs(
              controller: _tabs,
              signIn: l10n.authTabSignIn,
              register: l10n.authTabRegister,
            ),
            const SizedBox(height: AppSizes.s24),
            AutofillGroup(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      key: _emailField,
                      controller: _email,
                      enabled: !_loading,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.email],
                      decoration: InputDecoration(
                        labelText: l10n.authEmailLabel,
                      ),
                      validator: _validateEmail,
                      onChanged: (_) => _clearServerError(_emailField),
                    ),
                    const SizedBox(height: AppSizes.s16),
                    TextFormField(
                      key: _passwordField,
                      controller: _password,
                      enabled: !_loading,
                      obscureText: _obscure,
                      textInputAction: _register
                          ? TextInputAction.next
                          : TextInputAction.done,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: [
                        _register
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      decoration: InputDecoration(
                        labelText: l10n.authPasswordLabel,
                        helperText: _register ? l10n.authPasswordHelper : null,
                        suffixIcon: IconButton(
                          tooltip: _obscure
                              ? l10n.authShowPassword
                              : l10n.authHidePassword,
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: _validatePassword,
                      onChanged: (_) => _clearServerError(_passwordField),
                      onFieldSubmitted: (_) => _register ? null : _submit(),
                    ),
                    if (_register) ...[
                      const SizedBox(height: AppSizes.s16),
                      TextFormField(
                        key: const Key('auth-nickname'),
                        controller: _nickname,
                        enabled: !_loading,
                        textInputAction: TextInputAction.done,
                        maxLength: AuthValidation.nicknameMax,
                        autofillHints: const [AutofillHints.nickname],
                        decoration: InputDecoration(
                          labelText: l10n.authNicknameLabel,
                          helperText: l10n.authNicknameHelper,
                          helperMaxLines: 3,
                          errorMaxLines: 3,
                          counterText: '',
                        ),
                        validator: _validateNickname,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (!_register)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _loading ? null : _forgotPassword,
                  child: Text(l10n.authForgotPassword),
                ),
              ),
            const SizedBox(height: AppSizes.s16),
            FilledButton(
              key: const Key('auth-submit'),
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? SizedBox.square(
                      dimension: AppSizes.s24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        semanticsLabel: l10n.authLoading,
                      ),
                    )
                  : Text(
                      _register
                          ? l10n.authRegisterButton
                          : l10n.authSignInButton,
                    ),
            ),
            const SizedBox(height: AppSizes.s32),
            Text(
              l10n.authFooter,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.tagline});

  final String tagline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(AppSizes.radiusCard),
          ),
          child: const Icon(
            Icons.home_rounded,
            color: AppColors.onPrimary,
            size: 32,
          ),
        ),
        const SizedBox(width: AppSizes.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  AppLocalizations.of(context).appTitle,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              Text(tagline, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

/// «Zaloguj się» / «Załóż konto» as a segmented pill.
class _AuthTabs extends StatelessWidget {
  const _AuthTabs({
    required this.controller,
    required this.signIn,
    required this.register,
  });

  final TabController controller;
  final String signIn;
  final String register;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSizes.s4),
    decoration: BoxDecoration(
      color: AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(AppSizes.radiusCard),
    ),
    child: TabBar(
      controller: controller,
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
      labelColor: AppColors.primary,
      unselectedLabelColor: AppColors.onSurfaceVariant,
      labelStyle: AppTextStyles.bodyS.copyWith(fontWeight: FontWeight.w600),
      unselectedLabelStyle: AppTextStyles.bodyS,
      indicator: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusChip),
      ),
      tabs: [
        Tab(height: AppSizes.minTouchTarget, text: signIn),
        Tab(height: AppSizes.minTouchTarget, text: register),
      ],
    ),
  );
}

/// Asks for the e-mail when the field on S02 is empty or invalid.
class _ResetDialog extends StatefulWidget {
  const _ResetDialog({required this.initialEmail});

  final String initialEmail;

  @override
  State<_ResetDialog> createState() => _ResetDialogState();
}

class _ResetDialogState extends State<_ResetDialog> {
  late final _controller = TextEditingController(text: widget.initialEmail);
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(_controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.authResetTitle),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.authResetBody),
            const SizedBox(height: AppSizes.s16),
            TextFormField(
              key: const Key('auth-reset-email'),
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: InputDecoration(labelText: l10n.authEmailLabel),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty) return l10n.authEmailRequired;
                if (!AuthValidation.isEmail(email)) {
                  return l10n.authEmailInvalid;
                }
                return null;
              },
              onFieldSubmitted: (_) => _send(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.authResetCancel),
        ),
        TextButton(onPressed: _send, child: Text(l10n.authResetSend)),
      ],
    );
  }
}
