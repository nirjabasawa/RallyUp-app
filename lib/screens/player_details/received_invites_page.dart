import 'package:flutter/material.dart';

import 'invites_page.dart';

/// Backward-compat shim. Old call sites used to push a separate
/// ReceivedInvitesPage; that page now delegates to the unified
/// [InvitesPage] opened on the Received tab. The previous
/// implementation used `Navigator.maybePop` for the Sent tab tap,
/// which caused notification → ReceivedInvitesPage → "Sent Invites"
/// to pop back to NotificationsPage. Routing through the unified
/// page kills that bug because there is no second screen to pop.
class ReceivedInvitesPage extends StatelessWidget {
  const ReceivedInvitesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const InvitesPage(initialTab: InviteTab.received);
  }
}
