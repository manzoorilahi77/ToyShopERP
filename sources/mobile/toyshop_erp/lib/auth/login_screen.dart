import 'package:flutter/material.dart';

import '../core/core.dart';
import 'auth_data.dart';

/// Shared auth for the single app. Step 1 is a photo picker of the whole roster
/// (staff **and** owner — the staff-login doc allows the owner to appear here);
/// Step 2 is the PIN pad. On success the account's [UserRole] decides which
/// shell/dashboard the root gate shows — that is the only role-specific routing.
///
/// Docs: docs/mobile/staff/auth/login.md · docs/mobile/owner/auth/login.md
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _repo = const AuthRepository();
  List<Account> _roster = const [];
  Account? _selected;
  String _pin = '';
  bool _error = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await _repo.fetchRoster();
    if (!mounted) return;
    setState(() {
      _roster = r;
      _loading = false;
    });
  }

  void _pickAccount(Account a) => setState(() {
        _selected = a;
        _pin = '';
        _error = false;
      });

  void _key(String d) {
    if (_pin.length >= 4) return;
    setState(() {
      _error = false;
      _pin += d;
    });
    if (_pin.length == 4) _submit();
  }

  void _del() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    // PROTOTYPE: accept any 4-digit PIN. Replace with POST /auth/pin-login.
    await Future.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;
    SessionScope.read(context).signIn(_selected!);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: _selected == null ? _buildPicker(p) : _buildPin(p),
      ),
    );
  }

  // ---- Step 1: who's billing? -------------------------------------------
  Widget _buildPicker(AppPalette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: p.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.toys_rounded, color: p.primaryInk, size: 22),
              ),
              const SizedBox(width: 12),
              Text('ToyShop ERP', style: AppType.h2.copyWith(color: p.ink)),
              const Spacer(),
              const SyncStatusChip(SyncState.synced),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Text("Who's billing?", style: AppType.h1.copyWith(color: p.ink)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(
            'Tap your photo to sign in',
            style: AppType.body.copyWith(color: p.inkMuted),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : GridView.count(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  crossAxisCount: 3,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.82,
                  children: [
                    for (final a in _roster) _RosterTile(account: a, onTap: () => _pickAccount(a)),
                  ],
                ),
        ),
      ],
    );
  }

  // ---- Step 2: PIN pad ---------------------------------------------------
  Widget _buildPin(AppPalette p) {
    final a = _selected!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _selected = null),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const Spacer(),
              const SyncStatusChip(SyncState.synced),
            ],
          ),
        ),
        const SizedBox(height: 8),
        AvatarBadge.account(a, size: 76),
        const SizedBox(height: 12),
        Text(a.name, style: AppType.h2.copyWith(color: p.ink)),
        TonePill.tone(
          a.role.isOwnerSide ? Tone.info : Tone.primary,
          a.roleLabel,
          icon: a.role.isOwnerSide ? Icons.shield_rounded : Icons.person_rounded,
          dense: true,
        ),
        const SizedBox(height: 20),
        Text('Enter PIN', style: AppType.body.copyWith(color: p.inkMuted)),
        const SizedBox(height: 14),
        PinDots(length: 4, filled: _pin.length, error: _error),
        const SizedBox(height: 8),
        Text(kDemoPinHint, style: AppType.caption.copyWith(color: p.inkMuted)),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(36, 0, 36, 24),
          child: NumericPad(
            onKey: _key,
            onDelete: _del,
            onLongDelete: () => setState(() => _pin = ''),
            onBiometric: _submit,
          ),
        ),
      ],
    );
  }
}

class _RosterTile extends StatelessWidget {
  const _RosterTile({required this.account, required this.onTap});
  final Account account;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final owner = account.role.isOwnerSide;
    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: owner ? p.info : p.border, width: owner ? 1.5 : 1),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AvatarBadge.account(account, size: 56),
              const SizedBox(height: 8),
              Text(
                account.name.split(' ').first,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.label.copyWith(color: p.ink, fontWeight: FontWeight.w600),
              ),
              if (owner)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    'Owner',
                    style: AppType.caption.copyWith(color: p.info, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
