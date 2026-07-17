import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/core.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushNotifs = true;
  bool _emailNotifs = false;
  bool _darkMode = false;
  bool _twoFactor = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pushNotifs = prefs.getBool('settings_pushNotifs') ?? true;
      _emailNotifs = prefs.getBool('settings_emailNotifs') ?? false;
      _darkMode = prefs.getBool('settings_darkMode') ?? false;
      _twoFactor = prefs.getBool('settings_twoFactor') ?? true;
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _saving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('settings_pushNotifs', _pushNotifs);
    await prefs.setBool('settings_emailNotifs', _emailNotifs);
    await prefs.setBool('settings_darkMode', _darkMode);
    await prefs.setBool('settings_twoFactor', _twoFactor);
    
    // Simulate slight delay for better UX
    await Future.delayed(const Duration(milliseconds: 600));
    
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppScaffold(
      title: 'Settings',
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text('Manage your app and shop preferences.', style: AppType.body.copyWith(color: p.inkMuted)),
          const SizedBox(height: AppSpacing.lg),

          // Notifications
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.notifications_rounded, color: p.primary),
                    const SizedBox(width: AppSpacing.md),
                    Text('Notifications', style: AppType.title),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                SwitchListTile.adaptive(
                  title: const Text('Push Notifications'),
                  subtitle: const Text('Receive alerts on this device'),
                  value: _pushNotifs,
                  onChanged: (val) => setState(() => _pushNotifs = val),
                  contentPadding: EdgeInsets.zero,
                ),
                const Divider(),
                SwitchListTile.adaptive(
                  title: const Text('Email Notifications'),
                  subtitle: const Text('Daily reports and critical alerts'),
                  value: _emailNotifs,
                  onChanged: (val) => setState(() => _emailNotifs = val),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Appearance
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.dark_mode_rounded, color: p.info),
                    const SizedBox(width: AppSpacing.md),
                    Text('Appearance', style: AppType.title),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                SwitchListTile.adaptive(
                  title: const Text('Dark Mode'),
                  subtitle: const Text('Use dark theme across the app'),
                  value: _darkMode,
                  onChanged: (val) => setState(() => _darkMode = val),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Security
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.security_rounded, color: p.success),
                    const SizedBox(width: AppSpacing.md),
                    Text('Security', style: AppType.title),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                SwitchListTile.adaptive(
                  title: const Text('Two-Factor Authentication'),
                  subtitle: const Text('Require OTP for critical actions'),
                  value: _twoFactor,
                  onChanged: (val) => setState(() => _twoFactor = val),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          
          FilledButton(
            onPressed: _saving ? null : _saveSettings,
            child: Text(_saving ? 'Saving...' : 'Save Settings'),
          ),
        ],
      ),
    );
  }
}
