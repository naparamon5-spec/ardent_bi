import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../state/auth_state.dart';
import '../theme.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<AuthState>().api.post(
        '/api/auth/change-password',
        {'currentPassword': _current.text, 'newPassword': _next.text},
        false,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated')),
      );
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(
    TextEditingController c,
    String label,
    IconData icon, {
    String? Function(String?)? validator,
    TextInputAction action = TextInputAction.next,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: c,
      obscureText: _obscure,
      textInputAction: action,
      onFieldSubmitted: action == TextInputAction.done ? (_) => _submit() : null,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
      validator: validator,
    ),
  );

  Widget _header(BiTokens t) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.brand.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.shield_outlined, color: t.brand, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Keep your account secure',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: t.textPrimary),
                ),
                const SizedBox(height: 3),
                Text(
                  'Enter your current password, then choose a new one you don\'t use elsewhere.',
                  style: TextStyle(fontSize: 12, color: t.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _rule(BiTokens t, String label, bool ok) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 6),
    child: Row(
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 16,
          color: ok ? AppColors.good : t.textMuted,
        ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 12.5, color: ok ? t.textPrimary : t.textMuted)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = BiTokens.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Change password')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
          children: [
            _header(t),
            const SizedBox(height: 20),
            _field(
              _current,
              'Current password',
              Icons.lock_outline,
              validator: (v) => (v == null || v.isEmpty) ? 'Enter your current password' : null,
            ),
            _field(
              _next,
              'New password',
              Icons.lock_reset_outlined,
              validator: (v) => (v == null || v.length < 8) ? 'At least 8 characters' : null,
            ),
            _field(
              _confirm,
              'Confirm new password',
              Icons.check_circle_outline,
              action: TextInputAction.done,
              validator: (v) => v != _next.text ? 'Passwords do not match' : null,
            ),
            _rule(t, 'At least 8 characters', _next.text.length >= 8),
            _rule(t, 'Passwords match', _next.text.isNotEmpty && _next.text == _confirm.text),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(color: AppColors.critical, fontSize: 12.5)),
              ),
            const SizedBox(height: 4),
            FilledButton(
              onPressed: _saving ? null : _submit,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _saving
                  ? SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: t.brandInk),
                    )
                  : const Text('Update password'),
            ),
          ],
        ),
      ),
    );
  }
}
