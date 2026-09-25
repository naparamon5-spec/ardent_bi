import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';

/// Static informational pages linked from the More tab: the privacy policy and
/// a support/contact page. Content is plain text so it needs no backend.
const _supportEmail = 'it-support@ardentnetworks.com.ph';
const _appVersion = '1.0.0';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = BiTokens.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ArdentBI — Privacy Policy',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: t.textPrimary)),
            const SizedBox(height: 4),
            Text('Ardent Networks, Inc. · Last updated September 2026',
                style: TextStyle(fontSize: 12, color: t.textMuted)),
            const SizedBox(height: 20),
            _p(t,
                'ArdentBI is an internal business-intelligence application provided by '
                'Ardent Networks for the exclusive use of its authorized staff. This '
                'policy explains what the app accesses and how that information is handled.'),
            _h(t, 'Information we access'),
            _p(t,
                'The app uses your Ardent ERP / SSO credentials to sign you in and to '
                'determine which sales, inventory and related figures you are permitted to '
                'view. It reads company business data from Ardent’s own servers to render '
                'dashboards and reports. It does not collect personal data beyond your '
                'work account identity and role.'),
            _h(t, 'How your data is stored on this device'),
            _p(t,
                'A session token and a small set of preferences (such as your remembered '
                'username and last-used settings) are stored securely on your device. The '
                'session is automatically signed out after a period of inactivity and when '
                'the app is closed or removed from the multitasking view.'),
            _h(t, 'How information is used'),
            _p(t,
                'Data shown in the app is used solely to present analytics to you. It is '
                'not sold, shared with third parties, or used for advertising. Access is '
                'limited by your role and business unit.'),
            _h(t, 'Security'),
            _p(t,
                'Traffic between the app and Ardent’s servers is encrypted. Screens are '
                'hidden from the app switcher, and inactive sessions are locked, to reduce '
                'the risk of unauthorized viewing.'),
            _h(t, 'Your responsibilities'),
            _p(t,
                'Keep your credentials confidential and use the app only for legitimate '
                'company purposes. Report any suspected misuse to the IT department.'),
            _h(t, 'Contact'),
            _p(t,
                'For questions about this policy or your data, contact the Ardent IT '
                'department at $_supportEmail.'),
          ],
        ),
      ),
    );
  }

  Widget _h(BiTokens t, String s) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(s, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: t.textPrimary)),
      );

  Widget _p(BiTokens t, String s) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(s, style: TextStyle(fontSize: 13.5, height: 1.5, color: t.textSecondary)),
      );
}

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = BiTokens.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Support')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Need help?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: t.textPrimary)),
            const SizedBox(height: 6),
            Text(
              'For sign-in problems, password resets, or questions about the figures you '
              'see, reach out to the Ardent IT department. ArdentBI uses your ERP / SSO '
              'account, so password changes are handled there — not in this app.',
              style: TextStyle(fontSize: 13.5, height: 1.5, color: t.textSecondary),
            ),
            const SizedBox(height: 20),
            _contactCard(context, t, Icons.email_outlined, 'Email IT support', _supportEmail),
            const SizedBox(height: 10),
            _infoCard(t, Icons.schedule_outlined, 'Support hours',
                'Monday to Friday, 8:00 AM – 6:00 PM (PHT)'),
            const SizedBox(height: 10),
            _infoCard(t, Icons.info_outline, 'App version', 'ArdentBI Mobile v$_appVersion'),
          ],
        ),
      ),
    );
  }

  Widget _contactCard(BuildContext context, BiTokens t, IconData icon, String title, String value) => Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: _leading(t, icon),
          title: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.textPrimary)),
          subtitle: Text(value, style: TextStyle(fontSize: 12.5, color: t.textSecondary)),
          trailing: Icon(Icons.copy, size: 18, color: t.textMuted),
          onTap: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 2)),
            );
          },
        ),
      );

  Widget _infoCard(BiTokens t, IconData icon, String title, String value) => Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: _leading(t, icon),
          title: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.textPrimary)),
          subtitle: Text(value, style: TextStyle(fontSize: 12.5, color: t.textSecondary)),
        ),
      );

  Widget _leading(BiTokens t, IconData icon) => Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: t.brand.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: t.brand),
      );
}
