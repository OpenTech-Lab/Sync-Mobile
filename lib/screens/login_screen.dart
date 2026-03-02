import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.serverUrl,
    required this.isSubmitting,
    required this.errorMessage,
    required this.onSubmit,
  });

  final String serverUrl;
  final bool isSubmitting;
  final String? errorMessage;
  final Future<void> Function(String email, String password) onSubmit;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Connected to ${widget.serverUrl}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
          ),
          if (widget.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                widget.errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: widget.isSubmitting
                ? null
                : () => widget.onSubmit(
                      _emailController.text,
                      _passwordController.text,
                    ),
            child:
                Text(widget.isSubmitting ? 'Signing in...' : 'Sign in to Sync'),
          ),
        ],
      ),
    );
  }
}
