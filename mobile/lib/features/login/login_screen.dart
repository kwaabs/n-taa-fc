import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../core/auth/auth_state.dart';
import '../../core/server_config.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _error;
  AuthErrorType _errorType = AuthErrorType.unknown;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).login(
            _emailController.text.trim(),
            _passwordController.text,
          );
      // success — router will swap to HomeScreen automatically
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _errorType = e.type;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitOAuth(String provider) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).loginWithOAuth(provider);
      // success — router will swap to HomeScreen
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _errorType = e.type;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _switchServer() async {
    await ref.read(serverConfigProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final configAsync = ref.watch(serverConfigProvider);
    final config = configAsync.value;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.map_outlined,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Sign in',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (config != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        config.label ?? config.url,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Email is required';
                        }
                        if (!v.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                                        if (_error != null) ...[
                      const SizedBox(height: 16),
                      Builder(builder: (context) {
                        final isCancelled =
                            _errorType == AuthErrorType.cancelled;
                        final bg = isCancelled
                            ? theme.colorScheme.surfaceContainerHighest
                            : theme.colorScheme.errorContainer;
                        final fg = isCancelled
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.onErrorContainer;
                        final icon = isCancelled
                            ? Icons.info_outline
                            : Icons.error_outline;
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(icon, size: 18, color: fg),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: TextStyle(color: fg),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.login),
                      label: Text(_submitting ? 'Signing in...' : 'Sign in'),
                    ),
                    const SizedBox(height: 12),
                    const SizedBox(height: 16),

                    // ── OR divider ──
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'OR',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),

                    const SizedBox(height: 16),

                    OutlinedButton.icon(
                      onPressed:
                          _submitting ? null : () => _submitOAuth('azure'),
                      icon: const Icon(Icons.window),
                      label: const Text('Sign in with Microsoft'),
                    ),

                    const SizedBox(height: 8),

                    OutlinedButton.icon(
                      onPressed:
                          _submitting ? null : () => _submitOAuth('google'),
                      icon: const Icon(Icons.g_mobiledata, size: 28),
                      label: const Text('Sign in with Google'),
                    ),
                    TextButton.icon(
                      onPressed: _submitting ? null : _switchServer,
                      icon: const Icon(Icons.swap_horiz, size: 18),
                      label: const Text('Switch server'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
