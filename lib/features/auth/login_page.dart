import 'package:flutter/material.dart';
import '../../ui/tokens/colors/app_palette.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.serverUrl,
    this.savedEmail,
    required this.isSubmitting,
    required this.errorMessage,
    required this.onSignIn,
    required this.onSignUp,
    required this.onBackToUrl,
    this.onForgotPassword,
  });

  final String serverUrl;
  final String? savedEmail;
  final bool isSubmitting;
  final String? errorMessage;
  final Future<void> Function(String email, String password) onSignIn;
  final Future<void> Function(String username, String email, String password)
  onSignUp;
  final VoidCallback onBackToUrl;
  final Future<void> Function(String email)? onForgotPassword;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _signInEmail = TextEditingController();
  final _signInPassword = TextEditingController();
  final _signUpUsername = TextEditingController();
  final _signUpEmail = TextEditingController();
  final _signUpPassword = TextEditingController();
  bool _obscureSignIn = true;
  bool _obscureSignUp = true;

  @override
  void initState() {
    super.initState();
    final hasAccount = widget.savedEmail != null;
    _tabs = TabController(length: hasAccount ? 1 : 2, vsync: this);
    if (hasAccount) {
      _signInEmail.text = widget.savedEmail!;
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _signInEmail.dispose();
    _signInPassword.dispose();
    _signUpUsername.dispose();
    _signUpEmail.dispose();
    _signUpPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? AppPalette.neutral900 : AppPalette.neutral50;
    final inkColor = isDark ? AppPalette.neutral100 : AppPalette.neutral800;
    final ruleColor = isDark ? AppPalette.neutral700 : AppPalette.neutral300;

    final hasAccount = widget.savedEmail != null;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // — Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: widget.isSubmitting ? null : widget.onBackToUrl,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.arrow_back,
                        size: 20,
                        color: AppPalette.neutral500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _hostLabel(widget.serverUrl),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppPalette.neutral500,
                        letterSpacing: 0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // — Hero
            const SizedBox(height: 36),
            Center(
              child: Image.asset('assets/logo.png', width: 52, height: 52),
            ),
            const SizedBox(height: 16),
            Text(
              'Sync',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w300,
                color: inkColor,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your private messenger',
              style: TextStyle(
                fontSize: 12,
                color: AppPalette.neutral500,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 36),

            // — Tabs / account-found note
            if (!hasAccount) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Row(
                  children: [
                    _AuthTab(
                      label: 'Sign in',
                      selected: _tabs.index == 0,
                      inkColor: inkColor,
                      mutedColor: AppPalette.neutral500,
                      onTap: () => setState(() => _tabs.index = 0),
                    ),
                    const SizedBox(width: 32),
                    _AuthTab(
                      label: 'Sign up',
                      selected: _tabs.index == 1,
                      inkColor: inkColor,
                      mutedColor: AppPalette.neutral500,
                      onTap: () => setState(() => _tabs.index = 1),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Divider(height: 1, thickness: 1, color: ruleColor),
              ),
              const SizedBox(height: 20),
            ] else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  'Account found for this server',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppPalette.neutral500,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // — Error notice
            if (widget.errorMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppPalette.danger700,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.errorMessage!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppPalette.danger700,
                          fontWeight: FontWeight.w300,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // — Tab content
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _SignInForm(
                    emailController: _signInEmail,
                    emailLocked: hasAccount,
                    passwordController: _signInPassword,
                    obscure: _obscureSignIn,
                    onToggleObscure: () =>
                        setState(() => _obscureSignIn = !_obscureSignIn),
                    isSubmitting: widget.isSubmitting,
                    onSubmit: () => widget.onSignIn(
                      _signInEmail.text,
                      _signInPassword.text,
                    ),
                    onForgotPassword: widget.onForgotPassword,
                    inkColor: inkColor,
                    mutedColor: AppPalette.neutral500,
                    ruleColor: ruleColor,
                    isDark: isDark,
                  ),
                  if (!hasAccount)
                    _SignUpForm(
                      usernameController: _signUpUsername,
                      emailController: _signUpEmail,
                      passwordController: _signUpPassword,
                      obscure: _obscureSignUp,
                      onToggleObscure: () =>
                          setState(() => _obscureSignUp = !_obscureSignUp),
                      isSubmitting: widget.isSubmitting,
                      onSubmit: () => widget.onSignUp(
                        _signUpUsername.text,
                        _signUpEmail.text,
                        _signUpPassword.text,
                      ),
                      inkColor: inkColor,
                      mutedColor: AppPalette.neutral500,
                      ruleColor: ruleColor,
                      isDark: isDark,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _hostLabel(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.isNotEmpty ? uri.host : url;
    } catch (_) {
      return url;
    }
  }
}

class _SignInForm extends StatelessWidget {
  const _SignInForm({
    required this.emailController,
    required this.emailLocked,
    required this.passwordController,
    required this.obscure,
    required this.onToggleObscure,
    required this.isSubmitting,
    required this.onSubmit,
    required this.inkColor,
    required this.mutedColor,
    required this.ruleColor,
    required this.isDark,
    this.onForgotPassword,
  });

  final TextEditingController emailController;
  final bool emailLocked;
  final TextEditingController passwordController;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final bool isSubmitting;
  final VoidCallback onSubmit;
  final Future<void> Function(String email)? onForgotPassword;
  final Color inkColor;
  final Color mutedColor;
  final Color ruleColor;
  final bool isDark;

  void _showForgotDialog(BuildContext context) {
    final emailCtrl = TextEditingController(text: emailController.text);
    showDialog<void>(
      context: context,
      builder: (ctx) {
        var sending = false;
        var done = false;
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Dialog(
              backgroundColor: isDark
                  ? AppPalette.neutral900
                  : AppPalette.neutral50,
              surfaceTintColor: AppPalette.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 36,
                vertical: 60,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Reset password',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w300,
                        color: inkColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (done)
                      Text(
                        'If that email is registered, a reset link was sent.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w300,
                          color: mutedColor,
                          height: 1.6,
                        ),
                      )
                    else ...[
                      Text(
                        "Enter your email and we'll send a reset link.",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w300,
                          color: mutedColor,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _AuthField(
                        controller: emailCtrl,
                        label: 'Email',
                        keyboardType: TextInputType.emailAddress,
                        inkColor: inkColor,
                        mutedColor: mutedColor,
                        ruleColor: ruleColor,
                      ),
                    ],
                    const SizedBox(height: 28),
                    Divider(height: 1, thickness: 1, color: ruleColor),
                    const SizedBox(height: 16),
                    if (done)
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () => Navigator.of(ctx).pop(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 4,
                            ),
                            child: Text(
                              'close',
                              style: TextStyle(
                                fontSize: 13,
                                color: mutedColor,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          GestureDetector(
                            onTap: sending
                                ? null
                                : () => Navigator.of(ctx).pop(),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 4,
                              ),
                              child: Text(
                                'cancel',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: mutedColor,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 28),
                          GestureDetector(
                            onTap: sending
                                ? null
                                : () async {
                                    setState(() => sending = true);
                                    try {
                                      await onForgotPassword!(
                                        emailCtrl.text.trim(),
                                      );
                                    } catch (_) {}
                                    setState(() {
                                      sending = false;
                                      done = true;
                                    });
                                  },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 4,
                              ),
                              child: sending
                                  ? SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        color: inkColor,
                                      ),
                                    )
                                  : Text(
                                      'S E N D',
                                      style: TextStyle(
                                        fontSize: 11,
                                        letterSpacing: 2.5,
                                        fontWeight: FontWeight.w500,
                                        color: inkColor,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 4, 28, 28),
      children: [
        _AuthField(
          controller: emailController,
          label: 'Email',
          keyboardType: TextInputType.emailAddress,
          readOnly: emailLocked,
          inkColor: inkColor,
          mutedColor: mutedColor,
          ruleColor: ruleColor,
        ),
        const SizedBox(height: 24),
        _AuthField(
          controller: passwordController,
          label: 'Password',
          obscure: obscure,
          toggleObscure: onToggleObscure,
          inkColor: inkColor,
          mutedColor: mutedColor,
          ruleColor: ruleColor,
        ),
        if (onForgotPassword != null)
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: isSubmitting ? null : () => _showForgotDialog(context),
              child: Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Text(
                  'Forgot password?',
                  style: TextStyle(
                    fontSize: 12,
                    color: mutedColor,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 32),
        _SubmitButton(
          label: isSubmitting ? 'signing in…' : 'S I G N   I N',
          busy: isSubmitting,
          onPressed: isSubmitting ? null : onSubmit,
          inkColor: inkColor,
          mutedColor: mutedColor,
        ),
      ],
    );
  }
}

class _SignUpForm extends StatelessWidget {
  const _SignUpForm({
    required this.usernameController,
    required this.emailController,
    required this.passwordController,
    required this.obscure,
    required this.onToggleObscure,
    required this.isSubmitting,
    required this.onSubmit,
    required this.inkColor,
    required this.mutedColor,
    required this.ruleColor,
    required this.isDark,
  });

  final TextEditingController usernameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final bool isSubmitting;
  final VoidCallback onSubmit;
  final Color inkColor;
  final Color mutedColor;
  final Color ruleColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 4, 28, 28),
      children: [
        _AuthField(
          controller: usernameController,
          label: 'Username',
          inkColor: inkColor,
          mutedColor: mutedColor,
          ruleColor: ruleColor,
        ),
        const SizedBox(height: 24),
        _AuthField(
          controller: emailController,
          label: 'Email',
          keyboardType: TextInputType.emailAddress,
          inkColor: inkColor,
          mutedColor: mutedColor,
          ruleColor: ruleColor,
        ),
        const SizedBox(height: 24),
        _AuthField(
          controller: passwordController,
          label: 'Password · min 8 characters',
          obscure: obscure,
          toggleObscure: onToggleObscure,
          inkColor: inkColor,
          mutedColor: mutedColor,
          ruleColor: ruleColor,
        ),
        const SizedBox(height: 32),
        _SubmitButton(
          label: isSubmitting
              ? 'creating account…'
              : 'C R E A T E   A C C O U N T',
          busy: isSubmitting,
          onPressed: isSubmitting ? null : onSubmit,
          inkColor: inkColor,
          mutedColor: mutedColor,
        ),
      ],
    );
  }
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.controller,
    required this.label,
    required this.inkColor,
    required this.mutedColor,
    required this.ruleColor,
    this.keyboardType,
    this.readOnly = false,
    this.obscure = false,
    this.toggleObscure,
  });

  final TextEditingController controller;
  final String label;
  final Color inkColor;
  final Color mutedColor;
  final Color ruleColor;
  final TextInputType? keyboardType;
  final bool readOnly;
  final bool obscure;
  final VoidCallback? toggleObscure;

  @override
  Widget build(BuildContext context) {
    final effectiveInk = readOnly
        ? mutedColor.withValues(alpha: 0.45)
        : inkColor;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      obscureText: obscure,
      autocorrect: false,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w300,
        color: effectiveInk,
        height: 1.4,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 12,
          letterSpacing: 0.4,
          color: mutedColor,
          fontWeight: FontWeight.w400,
        ),
        floatingLabelStyle: TextStyle(
          fontSize: 11,
          letterSpacing: 1.0,
          color: mutedColor,
        ),
        border: UnderlineInputBorder(borderSide: BorderSide(color: ruleColor)),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: ruleColor),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: mutedColor),
        ),
        suffixIcon: toggleObscure != null
            ? GestureDetector(
                onTap: toggleObscure,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Icon(
                    obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 18,
                    color: mutedColor,
                  ),
                ),
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        isDense: true,
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.label,
    required this.inkColor,
    required this.mutedColor,
    required this.busy,
    this.onPressed,
  });

  final String label;
  final Color inkColor;
  final Color mutedColor;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (busy)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: mutedColor,
                ),
              ),
            ),
          Text(
            label,
            style: TextStyle(
              fontSize: busy ? 13 : 12,
              letterSpacing: busy ? 0.2 : 2.4,
              fontWeight: FontWeight.w500,
              color: onPressed == null
                  ? mutedColor.withValues(alpha: 0.4)
                  : inkColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthTab extends StatelessWidget {
  const _AuthTab({
    required this.label,
    required this.selected,
    required this.inkColor,
    required this.mutedColor,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final Color inkColor;
  final Color mutedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w400 : FontWeight.w300,
            color: selected ? inkColor : mutedColor,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
