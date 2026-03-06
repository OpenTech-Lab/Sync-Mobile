import 'package:flutter/material.dart';
import 'package:mobile/l10n/app_localizations.dart';
import '../../ui/components/molecules/altcha_widget.dart';
import '../../ui/tokens/colors/app_palette.dart';
import '../../ui/components/molecules/language_picker.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.serverUrl,
    this.savedUserId,
    required this.isSubmitting,
    required this.errorMessage,
    required this.onAutoLogin,
    required this.onBackToUrl,
  });

  final String serverUrl;
  final String? savedUserId;
  final bool isSubmitting;
  final String? errorMessage;
  final Future<void> Function({String? altchaPayload}) onAutoLogin;
  final VoidCallback onBackToUrl;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _started = false;
  String? _altchaPayload;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.savedUserId != null) {
        widget.onAutoLogin();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? AppPalette.neutral900 : AppPalette.neutral50;
    final inkColor = isDark ? AppPalette.neutral100 : AppPalette.neutral800;
    final mutedColor = AppPalette.neutral500;
    final ruleColor = isDark ? AppPalette.neutral700 : AppPalette.neutral300;

    final isNewUser = widget.savedUserId == null;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: widget.isSubmitting ? null : widget.onBackToUrl,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
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
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppPalette.neutral500,
                        letterSpacing: 0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const LanguagePicker(compact: true),
                ],
              ),
              const Spacer(),
              Center(
                child: Image.asset('assets/logo.png', width: 56, height: 56),
              ),
              const SizedBox(height: 20),
              Text(
                'Sync',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w300,
                  color: inkColor,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.authTagline,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: mutedColor,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 28),
              if (widget.errorMessage != null)
                Text(
                  widget.errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppPalette.danger700,
                    fontWeight: FontWeight.w300,
                    height: 1.5,
                  ),
                ),
              if (isNewUser) ...[
                const SizedBox(height: 20),
                Center(
                  child: SizedBox(
                    width: 280,
                    child: AltchaWidget(
                      apiUrl: '${widget.serverUrl}/auth/altcha',
                      onResponse: (payload) {
                        setState(() {
                          _altchaPayload = payload;
                        });
                      },
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Divider(height: 1, thickness: 1, color: ruleColor),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: (widget.isSubmitting || (isNewUser && _altchaPayload == null))
                      ? null
                      : () => widget.onAutoLogin(altchaPayload: _altchaPayload),
                  child: Opacity(
                    opacity: (isNewUser && _altchaPayload == null) ? 0.5 : 1.0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.isSubmitting)
                          SizedBox(
                            width: 13,
                            height: 13,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: inkColor,
                            ),
                          ),
                        if (widget.isSubmitting) const SizedBox(width: 10),
                        Text(
                          widget.isSubmitting
                              ? (isNewUser ? l10n.creatingAccountProgress : l10n.signingInProgress)
                              : (isNewUser ? l10n.createAccountAction : l10n.signInAction),
                          style: TextStyle(
                            fontSize: widget.isSubmitting ? 13 : 10,
                            letterSpacing: widget.isSubmitting ? 0.2 : 2.2,
                            fontWeight: FontWeight.w500,
                            color: inkColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
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
