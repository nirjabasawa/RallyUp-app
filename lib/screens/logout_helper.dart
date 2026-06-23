import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

/// Clean sign-out used by every entry point (Profile, drawer, etc.).
///
/// Order matters: we collapse the navigator down to AuthGate FIRST,
/// then call `signOut()`. If we signed out first, any pushed route
/// above the home route would briefly read `currentUser == null`
/// and paint a stale blank Scaffold while AuthGate caught up.
Future<void> performLogout(BuildContext context) async {
  // Capture before anything pops.
  final rootNavigator = Navigator.of(context, rootNavigator: true);
  final auth = context.read<AuthProvider>();

  // Close the drawer explicitly so its dismiss animation tracks the
  // user's tap rather than the popUntil below.
  final scaffold = Scaffold.maybeOf(context);
  if (scaffold?.isDrawerOpen ?? false) {
    scaffold!.closeDrawer();
  }

  rootNavigator.popUntil((route) => route.isFirst);
  await auth.signOut();
}
