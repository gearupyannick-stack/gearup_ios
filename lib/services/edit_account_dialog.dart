// lib/widgets/edit_account_dialog.dart
// Dialog complet pour éditer le compte et proposer Connect / Disconnect Apple ID
// Usage: showDialog(context: context, builder: (_) => const EditAccountDialog());

import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/auth_service.dart';

class EditAccountDialog extends StatefulWidget {
  const EditAccountDialog({Key? key}) : super(key: key);

  @override
  State<EditAccountDialog> createState() => _EditAccountDialogState();
}

class _EditAccountDialogState extends State<EditAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  bool _loadingConnect = false;
  bool _loadingDisconnect = false;
  bool _saving = false;

  User? get _user => FirebaseAuth.instance.currentUser;
  bool get _isLinkedWithApple =>
      _user?.providerData.any((p) => p.providerId == 'apple.com') ?? false;

  @override
  void initState() {
    super.initState();
    _displayNameController.text = _user?.displayName ?? '';
    _emailController.text = _user?.email ?? '';
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _connectApple() async {
    if (!Platform.isIOS) {
      _showSnack('profile.appleOnlyIOS'.tr());
      return;
    }

    setState(() => _loadingConnect = true);
    try {
      // Utilise la méthode qui retourne un UserCredential (compatible avec ton code)
      final auth = AuthService();
      final UserCredential cred = await auth.signInWithAppleCredential();

      // Sécurité : récupère l'utilisateur soit depuis le credential soit le currentUser
      final user = cred.user ?? FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw 'Apple sign-in returned no user.';
      }

      // Met à jour les champs affichés si Apple fournit des infos
      _displayNameController.text = user.displayName ?? _displayNameController.text;
      _emailController.text = user.email ?? _emailController.text;

      _showSnack('profile.connectedApple'.tr());
      setState(() {}); // force refresh du UI (notamment _isLinkedWithApple)
    } on FirebaseAuthException catch (e) {
      _showSnack('profile.appleError'.tr(namedArgs: {'error': e.message ?? e.code}));
    } catch (e) {
      _showSnack('profile.appleSignInFailed'.tr(namedArgs: {'error': e.toString()}));
    } finally {
      if (mounted) setState(() => _loadingConnect = false);
    }
  }

  Future<void> _disconnectApple() async {
    if (!_isLinkedWithApple) {
      _showSnack('profile.noAppleLink'.tr());
      return;
    }

    setState(() => _loadingDisconnect = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showSnack('profile.noSignedInUser'.tr());
        return;
      }

      // Try to unlink the apple provider (removes provider from account)
      try {
        await user.unlink('apple.com');
        _showSnack('profile.appleUnlinked'.tr());
      } on FirebaseAuthException catch (e) {
        // In some cases unlink may fail (provider not linked). As fallback, sign out the user.
        // Only use signOut fallback if unlink explicitly fails for platform reasons.
        _showSnack('profile.unlinkFailed'.tr(namedArgs: {'error': e.message ?? ''}));
        await FirebaseAuth.instance.signOut();
      }

      // Refresh local fields
      final refreshedUser = FirebaseAuth.instance.currentUser;
      _displayNameController.text = refreshedUser?.displayName ?? '';
      _emailController.text = refreshedUser?.email ?? '';

      setState(() {}); // refresh _isLinkedWithApple
    } catch (e) {
      _showSnack('profile.errorDisconnecting'.tr(namedArgs: {'error': e.toString()}));
    } finally {
      if (mounted) setState(() => _loadingDisconnect = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final newName = _displayNameController.text.trim();
        if (newName.isNotEmpty && newName != user.displayName) {
          await user.updateDisplayName(newName);
        }
        // Note: changing email may require re-auth; we keep it read-only by default.
        _showSnack('profile.profileSaved'.tr());
      } else {
        _showSnack('profile.noSignedInUser'.tr());
      }
      Navigator.of(context).pop(true); // close dialog (return true = saved)
    } catch (e) {
      _showSnack('profile.errorSaving'.tr(namedArgs: {'error': e.toString()}));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Layout: fields, then the Apple connect / disconnect buttons, then Save (as requested)
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('profile.editAccount'.tr(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),

                // Display name
                TextFormField(
                  controller: _displayNameController,
                  style: const TextStyle(color: Colors.white70),
                  decoration: InputDecoration(
                    labelText: 'profile.displayName'.tr(),
                    labelStyle: const TextStyle(color: Colors.white70),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'profile.enterName'.tr() : null,
                ),
                const SizedBox(height: 12),

                // Email (read-only if coming from provider)
                TextFormField(
                  controller: _emailController,
                  enabled: false, // editing email typically requires reauth; keep read-only
                  style: const TextStyle(color: Colors.white70),
                  decoration: InputDecoration(
                    labelText: 'profile.email'.tr(),
                    labelStyle: const TextStyle(color: Colors.white70),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),

                const SizedBox(height: 18),

                // --- BUTTONS: Connect / Disconnect Apple ---
                // We put them above the Save button as requested.
                // Connect: only on iOS. Disconnect: only visible if linked with apple.
                if (Platform.isIOS) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loadingConnect ? null : _connectApple,
                      icon: const Icon(Icons.apple),
                      label: _loadingConnect
                          ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text('profile.connectApple'.tr()),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ] else ...[
                  // Optionally show disabled hint on non-iOS so user knows where it will appear
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.apple, color: Colors.grey),
                      label: Text('profile.connectAppleIOSOnly'.tr()),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                if (_isLinkedWithApple) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _loadingDisconnect ? null : _disconnectApple,
                      icon: _loadingDisconnect
                          ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.link_off),
                      label: Text('profile.disconnectApple'.tr()),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Save button at the bottom
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _saveProfile,
                    child: _saving
                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text('common.save'.tr(), style: const TextStyle(fontSize: 16)),
                          ),
                    style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  ),
                ),

                const SizedBox(height: 8),

                TextButton(
                  onPressed: _saving || _loadingConnect || _loadingDisconnect ? null : () => Navigator.of(context).pop(false),
                  child: Text('common.cancel'.tr()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}