import 'package:flutter/material.dart';

import 'auth/login_screen.dart';
import 'core/core.dart';
import 'owner/owner_shell.dart';
import 'staff/staff_shell.dart';

/// Root widget. Owns the [AppSession] and provides it to the tree. A single
/// [MaterialApp] serves every role; [_RootGate] swaps between the login screen
/// and the role-specific shell whenever the session changes.
class ToyShopApp extends StatefulWidget {
  const ToyShopApp({super.key});

  @override
  State<ToyShopApp> createState() => _ToyShopAppState();
}

class _ToyShopAppState extends State<ToyShopApp> {
  final AppSession _session = AppSession();

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      session: _session,
      child: MaterialApp(
        title: 'ToyShop ERP',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.light,
        home: const _RootGate(),
      ),
    );
  }
}

/// Decides the top-level screen from the signed-in role. This is the whole of
/// the "login navigates to the appropriate role" requirement — auth is shared,
/// everything after it forks here.
class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final Widget child;
    if (!session.isSignedIn) {
      child = const LoginScreen();
    } else if (session.role!.isOwnerSide) {
      child = const OwnerShell();
    } else {
      child = const StaffShell();
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOut,
      child: KeyedSubtree(
        key: ValueKey(session.account?.id ?? 'login'),
        child: child,
      ),
    );
  }
}
