import 'dart:async';

import 'package:neoauth/neoauth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';

enum OtpChannel { phone, email }

/// E.164: a plus, a non-zero country code digit, 7 to 15 digits in total.
final e164Pattern = RegExp(r'^\+[1-9]\d{6,14}$');
final emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
final otpPattern = RegExp(r'^\d{4,8}$');

/// Strips the spaces, dashes and brackets people type in phone numbers.
String normalisePhone(String input) => input.replaceAll(RegExp(r'[\s\-().]'), '');

String? validatePhone(String? input) {
  final v = normalisePhone(input ?? '');
  if (v.isEmpty) return 'Enter your phone number';
  if (!v.startsWith('+')) return 'Start with + and your country code, e.g. +91 98765 43210';
  if (!e164Pattern.hasMatch(v)) return 'Enter a valid number in international format, e.g. +919876543210';
  return null;
}

String? validateEmail(String? input) {
  final v = (input ?? '').trim();
  if (v.isEmpty) return 'Enter your email address';
  if (!emailPattern.hasMatch(v)) return 'Enter a valid email address';
  return null;
}

String? validateOtp(String? input) {
  final v = (input ?? '').trim();
  if (v.isEmpty) return 'Enter the code we sent you';
  if (!otpPattern.hasMatch(v)) return 'The code is 4 to 8 digits';
  return null;
}

/// A friendly message for a failed sign-in step.
String friendlySignInError(Object error, {bool verifying = false}) {
  if (error is NeoAuthCancelled) return 'Sign-in was cancelled.';
  if (error is NeoAuthException) {
    if (error.isRateLimited) {
      final wait = error.retryAfter;
      return wait != null && wait > 0
          ? 'Too many attempts. Try again in $wait seconds.'
          : 'Too many attempts. Wait a moment and try again.';
    }
    switch (error.error) {
      case 'access_denied' when verifying:
        return "That code isn't right. Check it and try again, or send a new one.";
      case 'invalid_grant' when verifying:
        return 'That code has expired. Send a new one.';
      case 'network_error':
        return "Can't reach the sign-in server. Check your connection and try again.";
      case 'invalid_client':
        return 'This console is not registered with the sign-in server (check NEOAUTH_CLIENT_ID).';
      case 'temporarily_unavailable':
      case 'server_error':
        return 'The sign-in server had a problem. Try again in a moment.';
    }
    final d = error.description.trim();
    return d.isEmpty ? 'Sign-in failed. Please try again.' : d[0].toUpperCase() + d.substring(1);
  }
  if (error is PlatformException) return "Passkeys aren't available on this device (${error.message ?? error.code}).";
  return 'Sign-in failed. Please try again.';
}

/// Phone OTP, email OTP and passkey sign-in, used both on the sign-in screen
/// and in the step-up (re-authenticate) sheet.
class SignInForm extends ConsumerStatefulWidget {
  const SignInForm({super.key, required this.onSignedIn, this.initialPhone, this.initialEmail, this.submitLabel});

  final ValueChanged<NeoAuthUser> onSignedIn;
  final String? initialPhone;
  final String? initialEmail;
  final String? submitLabel;

  @override
  ConsumerState<SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends ConsumerState<SignInForm> {
  final _formKey = GlobalKey<FormState>();
  final _codeFormKey = GlobalKey<FormState>();
  late final _phone = TextEditingController(text: widget.initialPhone);
  late final _email = TextEditingController(text: widget.initialEmail);
  final _code = TextEditingController();
  late OtpChannel _channel = (widget.initialPhone == null && widget.initialEmail != null)
      ? OtpChannel.email
      : OtpChannel.phone;

  NeoPendingSignIn? _pending;
  String? _error;
  bool _busy = false;
  int _resendIn = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  NeoAuthClient get _auth => ref.read(neoAuthClientProvider);

  void _startCountdown(int? seconds) {
    _timer?.cancel();
    setState(() => _resendIn = seconds ?? 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn = _resendIn > 0 ? _resendIn - 1 : 0);
      if (_resendIn == 0) t.cancel();
    });
  }

  Future<void> _guard(Future<void> Function() fn, {bool verifying = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await fn();
    } catch (e) {
      if (mounted) setState(() => _error = friendlySignInError(e, verifying: verifying));
      if (e is NeoAuthException && e.isRateLimited && e.retryAfter != null && _pending != null) {
        _startCountdown(e.retryAfter);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    await _guard(() async {
      final pending = _channel == OtpChannel.phone
          ? await _auth.startPhone(normalisePhone(_phone.text))
          : await _auth.startEmail(_email.text.trim());
      if (!mounted) return;
      setState(() {
        _pending = pending;
        _code.clear();
      });
      _startCountdown(pending.retryAfter);
    });
  }

  Future<void> _verify() async {
    final pending = _pending;
    if (pending == null || !_codeFormKey.currentState!.validate()) return;
    await _guard(() async {
      final user = await _auth.verifyCode(pending, _code.text.trim());
      if (mounted) widget.onSignedIn(user);
    }, verifying: true);
  }

  Future<void> _resend() async {
    final pending = _pending;
    if (pending == null) return;
    await _guard(() async {
      final next = await _auth.resendCode(pending);
      if (!mounted) return;
      setState(() => _pending = next);
      _startCountdown(next.retryAfter);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('A new code is on its way')));
    });
  }

  Future<void> _passkey() => _guard(() async {
    final user = await _auth.signInWithPasskey();
    if (mounted) widget.onSignedIn(user);
  });

  void _back() {
    _timer?.cancel();
    setState(() {
      _pending = null;
      _error = null;
      _resendIn = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      alignment: Alignment.topCenter,
      child: _pending == null ? _buildStart(context) : _buildCode(context, _pending!),
    );
  }

  Widget _errorBox(BuildContext context) {
    if (_error == null) return const SizedBox.shrink();
    final s = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Semantics(
        liveRegion: true,
        child: Container(
          key: const Key('signin.error'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: s.errorContainer, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: s.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(_error!, style: TextStyle(color: s.onErrorContainer)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStart(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _errorBox(context),
          SegmentedButton<OtpChannel>(
            segments: const [
              ButtonSegment(value: OtpChannel.phone, icon: Icon(Icons.phone_outlined), label: Text('Phone')),
              ButtonSegment(value: OtpChannel.email, icon: Icon(Icons.email_outlined), label: Text('Email')),
            ],
            selected: {_channel},
            onSelectionChanged: _busy
                ? null
                : (s) => setState(() {
                    _channel = s.first;
                    _error = null;
                  }),
          ),
          const SizedBox(height: 16),
          if (_channel == OtpChannel.phone)
            TextFormField(
              key: const Key('signin.phone'),
              controller: _phone,
              enabled: !_busy,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumber],
              textInputAction: TextInputAction.send,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-()]'))],
              decoration: const InputDecoration(
                labelText: 'Phone number',
                hintText: '+91 98765 43210',
                helperText: 'Include your country code',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: validatePhone,
              onFieldSubmitted: (_) => _send(),
            )
          else
            TextFormField(
              key: const Key('signin.email'),
              controller: _email,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.send,
              decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.email_outlined)),
              validator: validateEmail,
              onFieldSubmitted: (_) => _send(),
            ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('signin.send'),
            onPressed: _busy ? null : _send,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: _busy
                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Send code'),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('or', style: theme.textTheme.bodySmall),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            key: const Key('signin.passkey'),
            onPressed: _busy ? null : _passkey,
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            icon: const Icon(Icons.fingerprint),
            label: const Text('Sign in with a passkey'),
          ),
        ],
      ),
    );
  }

  Widget _buildCode(BuildContext context, NeoPendingSignIn pending) {
    final theme = Theme.of(context);
    final destination = _channel == OtpChannel.phone ? normalisePhone(_phone.text) : _email.text.trim();
    return Form(
      key: _codeFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _errorBox(context),
          Text(
            pending.message.isNotEmpty ? pending.message : 'Enter the code sent to $destination',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('signin.code'),
            controller: _code,
            enabled: !_busy,
            autofocus: true,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            textInputAction: TextInputAction.done,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
            style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 8),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(labelText: 'Verification code'),
            validator: validateOtp,
            onFieldSubmitted: (_) => _verify(),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('signin.verify'),
            onPressed: _busy ? null : _verify,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: _busy
                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(widget.submitLabel ?? 'Sign in'),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton.icon(
                onPressed: _busy ? null : _back,
                icon: const Icon(Icons.arrow_back),
                label: Text(_channel == OtpChannel.phone ? 'Change number' : 'Change email'),
              ),
              TextButton(
                key: const Key('signin.resend'),
                onPressed: _busy || _resendIn > 0 ? null : _resend,
                child: Text(_resendIn > 0 ? 'Resend code in ${_resendIn}s' : 'Resend code'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
