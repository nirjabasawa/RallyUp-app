import 'package:flutter/material.dart';

import '../main.dart';

/// Switches the active bottom-nav tab inside the existing [MainShell]
/// from a pushed route.
///
/// Do NOT push a fresh MainShell — that pops AuthGate off the stack
/// and the next sign-out would render an empty Scaffold. Instead pop
/// to the root to expose the singleton MainShell, then flip its
/// IndexedStack via the global key.
void switchToMainShellTab(BuildContext context, int index) {
  Navigator.of(context).popUntil((route) => route.isFirst);
  MainShell.globalKey.currentState?.switchTo(index);
}
