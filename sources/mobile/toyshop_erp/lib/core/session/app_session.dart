import 'package:flutter/material.dart';

import '../models/account.dart';

/// Holds the signed-in account for the running prototype. In production this
/// would wrap the JWT session + secure token store; here it just carries the
/// [Account] chosen at login so screens can greet the user and route by role.
class AppSession extends ChangeNotifier {
  Account? _account;
  Account? get account => _account;
  bool get isSignedIn => _account != null;
  UserRole? get role => _account?.role;

  /// Prototype-wide toggles that some screens react to.
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  void signIn(Account account) {
    _account = account;
    notifyListeners();
  }

  void signOut() {
    _account = null;
    notifyListeners();
  }

  void toggleConnectivity() {
    _isOnline = !_isOnline;
    notifyListeners();
  }
}

/// Provides the [AppSession] to the widget tree. Read via
/// `SessionScope.of(context)` (rebuilds on change) or
/// `SessionScope.read(context)` (no rebuild).
class SessionScope extends InheritedNotifier<AppSession> {
  const SessionScope({
    super.key,
    required AppSession session,
    required super.child,
  }) : super(notifier: session);

  static AppSession of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'No SessionScope found in context');
    return scope!.notifier!;
  }

  static AppSession read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'No SessionScope found in context');
    return scope!.notifier!;
  }
}
