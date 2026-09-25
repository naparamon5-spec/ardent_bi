import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/auth_state.dart';
import '../theme.dart';
import 'account_screen.dart';
// Temporarily hidden — kept for quick restore.
// import 'accrued_screen.dart';
import 'info_screens.dart';
import 'periods_screen.dart';
import 'reorder_point_screen.dart';

/// The "More" tab: analytics modules that don't warrant a bottom-bar slot, plus
/// the account. Entries are role-gated to match the web sidebar — Re-Order Point
/// shows only for BU heads and above.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = BiTokens.of(context);
    final auth = context.watch<AuthState>();

    void open(Widget screen) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('More'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionLabel(t, 'ANALYTICS'),
            if (auth.isBuHeadOrAbove)
              _tile(
                t,
                Icons.trending_up,
                'Re-Order Point',
                'What to order and how much',
                () => open(const ReorderPointScreen()),
              ),
            // Accrued Incidentals — temporarily hidden (uncomment to restore,
            // along with the accrued_screen.dart import above).
            // _tile(
            //   t,
            //   Icons.receipt_long_outlined,
            //   'Accrued Incidentals',
            //   'Charges booked against job orders',
            //   () => open(const AccruedScreen()),
            // ),
            _tile(
              t,
              Icons.calendar_month_outlined,
              'Period reports',
              'Year, quarter and month comparisons',
              () => open(const PeriodsScreen()),
            ),
            const SizedBox(height: 16),
            _sectionLabel(t, 'ACCOUNT'),
            _tile(
              t,
              Icons.person_outline,
              'Account & settings',
              'Profile, server, sign out',
              () => open(const AccountScreen()),
            ),
            const SizedBox(height: 16),
            _sectionLabel(t, 'ABOUT'),
            _tile(
              t,
              Icons.help_outline,
              'Support',
              'Get help and contact IT',
              () => open(const SupportScreen()),
            ),
            _tile(
              t,
              Icons.privacy_tip_outlined,
              'Privacy Policy',
              'How your data is handled',
              () => open(const PrivacyPolicyScreen()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(BiTokens t, String s) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      s,
      style: TextStyle(
        fontSize: 10.5,
        letterSpacing: 0.5,
        fontWeight: FontWeight.w600,
        color: t.textMuted,
      ),
    ),
  );

  Widget _tile(
    BiTokens t,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) => Card(
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
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: t.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 11.5, color: t.textMuted),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}
