import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../state/auth_state.dart';
import '../theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  late final TextEditingController _server;
  bool _showServer = false;
  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _server = TextEditingController(text: context.read<AuthState>().baseUrl);
  }

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    _server.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthState>();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await auth.setBaseUrl(_server.text);
      await auth.login(_user.text.trim(), _pass.text);
      // Navigation is handled by the root listening to auth state.
    } on ApiException catch (e) {
      setState(
        () => _error = e.hint != null ? '${e.message}\n${e.hint}' : e.message,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = BiTokens.of(context);
    final topPadding = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: t.chrome,
                padding: EdgeInsets.fromLTRB(24, topPadding + 56, 24, 64),
                child: Column(
                  children: [
                    Image.asset('assets/logo.png', width: 64, height: 64),
                    const SizedBox(height: 16),
                    const Text(
                      'Ardent BI',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.chromeText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'BUSINESS INTELLIGENCE',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                        color: AppColors.chromeTextMuted,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Sign in to your analytics workspace',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: t.chromeTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -36),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_error != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.critical.withValues(
                                      alpha: 0.10,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppColors.critical.withValues(
                                        alpha: 0.4,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(
                                      color: AppColors.critical,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                              TextField(
                                controller: _user,
                                autofillHints: const [AutofillHints.username],
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Username',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _pass,
                                obscureText: _obscure,
                                autofillHints: const [AutofillHints.password],
                                onSubmitted: (_) => _submit(),
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscure
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                    onPressed: () =>
                                        setState(() => _obscure = !_obscure),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: () => setState(
                                    () => _showServer = !_showServer,
                                  ),
                                  icon: Icon(
                                    _showServer
                                        ? Icons.expand_less
                                        : Icons.dns_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Server settings'),
                                ),
                              ),
                              if (_showServer) ...[
                                TextField(
                                  controller: _server,
                                  keyboardType: TextInputType.url,
                                  decoration: const InputDecoration(
                                    labelText: 'Server URL',
                                    hintText: 'http://localhost:4000',
                                    prefixIcon: Icon(Icons.link),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'On the Android emulator use http://10.0.2.2:4000; on a real phone use the server’s LAN IP.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: t.textMuted,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              FilledButton(
                                onPressed: _submitting ? null : _submit,
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  backgroundColor: t.brand,
                                  foregroundColor: t.brandInk,
                                ),
                                child: _submitting
                                    ? SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: t.brandInk,
                                        ),
                                      )
                                    : const Text(
                                        'Sign in',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(child: Divider(color: t.gridline)),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    child: Text(
                                      'or',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: t.textMuted,
                                      ),
                                    ),
                                  ),
                                  Expanded(child: Divider(color: t.gridline)),
                                ],
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: _submitting
                                    ? null
                                    : () =>
                                          context.read<AuthState>().enterDemo(),
                                icon: const Icon(
                                  Icons.visibility_outlined,
                                  size: 18,
                                ),
                                label: const Text('Preview the UI (demo data)'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                  ),
                                  side: BorderSide(color: t.gridline),
                                  foregroundColor: t.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'No server needed — browse every screen with sample figures.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: t.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}
