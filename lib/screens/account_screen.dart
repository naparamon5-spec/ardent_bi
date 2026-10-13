import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/auth_state.dart';
import '../theme.dart';
import 'change_password_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = BiTokens.of(context);
    final auth = context.watch<AuthState>();
    final user = auth.user ?? const {};
    final name = (user['name'] ?? user['username'] ?? 'User').toString();

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: t.brand.withValues(alpha: 0.25), width: 3),
                  ),
                  child: CircleAvatar(
                    radius: 34,
                    backgroundColor: t.brand,
                    child: Text(auth.initials,
                        style: TextStyle(color: t.brandInk, fontWeight: FontWeight.w700, fontSize: 22)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(name,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: t.textPrimary)),
                if (user['role'] != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: t.brand.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(user['role'].toString().toUpperCase(),
                        style: TextStyle(
                            fontSize: 10.5, letterSpacing: 0.6, fontWeight: FontWeight.w700, color: t.brand)),
                  ),
                ],
              ]),
            ),
          ),
          const SizedBox(height: 16),
          _sectionLabel(t, 'PROFILE'),
          _tile(t, Icons.badge_outlined, 'Username', subtitle: (user['username'] ?? '—').toString()),
          if (auth.scopeNote != null) _tile(t, Icons.shield_outlined, 'Data scope', subtitle: auth.scopeNote!),
          const SizedBox(height: 16),
          _sectionLabel(t, 'SECURITY'),
          _tile(
            t,
            Icons.lock_outline,
            'Change password',
            subtitle: 'Update your sign-in password',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
            ),
          ),
          const SizedBox(height: 20),
          if (auth.hasNoData)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Your account is not linked to any records yet. Contact an administrator to be assigned access.',
                style: TextStyle(fontSize: 12.5, color: t.textMuted),
              ),
            ),
          OutlinedButton.icon(
            onPressed: () async {
              final nav = Navigator.of(context);
              await auth.logout();
              // AccountScreen is pushed on top of the shell; pop back to the
              // root so the now-visible LoginScreen isn't hidden beneath it.
              nav.popUntil((r) => r.isFirst);
            },
            icon: const Icon(Icons.logout, color: AppColors.critical),
            label: const Text('Sign out', style: TextStyle(color: AppColors.critical)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: AppColors.critical),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(BiTokens t, String s) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(s,
            style: TextStyle(fontSize: 11, letterSpacing: 0.8, fontWeight: FontWeight.w600, color: t.textMuted)),
      );

  Widget _tile(BiTokens t, IconData icon, String title, {String? subtitle, VoidCallback? onTap}) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.brand.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: t.brand),
          ),
          title: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.textPrimary)),
          subtitle: subtitle == null ? null : Text(subtitle, style: TextStyle(fontSize: 12, color: t.textMuted)),
          trailing: onTap == null ? null : const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );
}
