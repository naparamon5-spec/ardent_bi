import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/auth_state.dart';
import '../theme.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = BiTokens.of(context);
    final auth = context.watch<AuthState>();
    final user = auth.user ?? const {};

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: t.brand,
                  child: Text(auth.initials, style: TextStyle(color: t.brandInk, fontWeight: FontWeight.w700, fontSize: 18)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text((user['name'] ?? user['username'] ?? 'User').toString(),
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: t.textPrimary)),
                    if (user['role'] != null)
                      Text(user['role'].toString().toUpperCase(),
                          style: TextStyle(fontSize: 11, letterSpacing: 0.5, color: t.textMuted)),
                  ]),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          _infoTile(t, Icons.badge_outlined, 'Username', (user['username'] ?? '—').toString()),
          if (auth.scopeNote != null)
            _infoTile(t, Icons.shield_outlined, 'Data scope', auth.scopeNote!),
          _infoTile(t, Icons.dns_outlined, 'Server', auth.baseUrl),
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

  Widget _infoTile(BiTokens t, IconData icon, String label, String value) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Icon(icon, color: t.textMuted, size: 20),
          title: Text(label, style: TextStyle(fontSize: 12, color: t.textMuted)),
          subtitle: Text(value, style: TextStyle(fontSize: 14, color: t.textPrimary)),
        ),
      );
}
