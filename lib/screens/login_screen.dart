import 'package:flutter/material.dart';

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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final hasAccount = widget.savedEmail != null;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // — Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed:
                        widget.isSubmitting ? null : widget.onBackToUrl,
                    tooltip: 'Change server',
                  ),
                  Expanded(
                    child: Text(
                      _hostLabel(widget.serverUrl),
                      style: tt.labelSmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // — Hero
            const SizedBox(height: 24),
            Center(
              child: Image.asset('assets/logo.png', width: 60, height: 60),
            ),
            const SizedBox(height: 12),
            Text('Sync', style: tt.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            )),
            const SizedBox(height: 4),
            Text(
              'Your private messenger',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 28),

            // — Tabs (hidden when account exists for this server)
            if (!hasAccount) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 28),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabs,
                  indicator: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: cs.onPrimary,
                  unselectedLabelColor: cs.onSurfaceVariant,
                  labelStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  tabs: const [
                    Tab(text: 'Sign in'),
                    Tab(text: 'Sign up'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ] else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.account_circle_outlined,
                          size: 16, color: cs.onPrimaryContainer),
                      const SizedBox(width: 6),
                      Text(
                        'Account found for this server',
                        style: tt.labelSmall?.copyWith(
                          color: cs.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // — Error banner
            if (widget.errorMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: cs.error, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.errorMessage!,
                          style: TextStyle(
                              color: cs.onErrorContainer, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
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
                        _signInEmail.text, _signInPassword.text),
                    onForgotPassword: widget.onForgotPassword,
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
                      onSubmit: () => widget.onSignUp(_signUpUsername.text,
                          _signUpEmail.text, _signUpPassword.text),
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

  void _showForgotDialog(BuildContext context) {
    final emailCtrl = TextEditingController(text: emailController.text);
    showDialog<void>(
      context: context,
      builder: (ctx) {
        var sending = false;
        var done = false;
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('Reset password'),
              content: done
                  ? const Text(
                      'If that email is registered, a reset link was sent.',
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Enter your email address and we'll send you a reset link.',
                          style: TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          autofocus: true,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined, size: 20),
                          ),
                        ),
                      ],
                    ),
              actions: done
                  ? [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Close'),
                      ),
                    ]
                  : [
                      TextButton(
                        onPressed: sending
                            ? null
                            : () => Navigator.of(ctx).pop(),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: sending
                            ? null
                            : () async {
                                setState(() => sending = true);
                                try {
                                  await onForgotPassword!(
                                      emailCtrl.text.trim());
                                } catch (_) {
                                  // Silently swallow — always show success
                                  // to prevent email enumeration.
                                }
                                setState(() {
                                  sending = false;
                                  done = true;
                                });
                              },
                        child: sending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Text('Send link'),
                      ),
                    ],
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
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          readOnly: emailLocked,
        ),
        const SizedBox(height: 12),
        _AuthField(
          controller: passwordController,
          label: 'Password',
          icon: Icons.lock_outline,
          obscure: obscure,
          toggleObscure: onToggleObscure,
        ),
        if (onForgotPassword != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: isSubmitting
                  ? null
                  : () => _showForgotDialog(context),
              child: const Text(
                'Forgot password?',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        const SizedBox(height: 24),
        _SubmitButton(
          label: isSubmitting ? 'Signing in…' : 'Sign in',
          onPressed: isSubmitting ? null : onSubmit,
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
  });

  final TextEditingController usernameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 4, 28, 28),
      children: [
        _AuthField(
          controller: usernameController,
          label: 'Username',
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 12),
        _AuthField(
          controller: emailController,
          label: 'Email',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        _AuthField(
          controller: passwordController,
          label: 'Password (min 8 chars)',
          icon: Icons.lock_outline,
          obscure: obscure,
          toggleObscure: onToggleObscure,
        ),
        const SizedBox(height: 24),
        _SubmitButton(
          label: isSubmitting ? 'Creating account…' : 'Create account',
          onPressed: isSubmitting ? null : onSubmit,
        ),
      ],
    );
  }
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.readOnly = false,
    this.obscure = false,
    this.toggleObscure,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool readOnly;
  final bool obscure;
  final VoidCallback? toggleObscure;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final disabledColor = cs.onSurface.withValues(alpha: .38);
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      obscureText: obscure,
      autocorrect: false,
      style: readOnly ? TextStyle(color: disabledColor) : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: readOnly ? TextStyle(color: disabledColor) : null,
        filled: readOnly,
        fillColor: readOnly ? cs.onSurface.withValues(alpha: .06) : null,
        prefixIcon: Icon(icon, size: 20,
            color: readOnly ? disabledColor : null),
        suffixIcon: toggleObscure != null
            ? IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_off : Icons.visibility,
                  size: 20,
                ),
                onPressed: toggleObscure,
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: readOnly
            ? OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: cs.onSurface.withValues(alpha: .18),
                ),
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 14),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
