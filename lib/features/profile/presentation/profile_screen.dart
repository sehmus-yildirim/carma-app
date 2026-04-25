import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../shared/widgets/carma_background.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/profile_repository.dart';
import '../data/user_profile.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileRepository _profileRepository = ProfileRepository();

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _displayNameController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Kein eingeloggter Nutzer gefunden.';
      });
      return;
    }

    try {
      await _profileRepository.createProfileIfMissing(user);

      final profile = await _profileRepository.getProfile(user.uid) ??
          UserProfile.empty(
            uid: user.uid,
            email: user.email ?? '',
          );

      _firstNameController.text = profile.firstName;
      _lastNameController.text = profile.lastName;
      _displayNameController.text = profile.displayName;
      _countryController.text = profile.country;

      if (!mounted) return;

      setState(() {
        _profile = profile;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Profil konnte nicht geladen werden.';
      });
    }
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    final currentProfile = _profile;

    if (user == null || currentProfile == null) {
      setState(() {
        _errorMessage = 'Profil kann aktuell nicht gespeichert werden.';
      });
      return;
    }

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final displayName = _displayNameController.text.trim();
    final country = _countryController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty || displayName.isEmpty) {
      setState(() {
        _errorMessage =
        'Bitte Vorname, Nachname und Anzeigename ausfüllen.';
      });
      return;
    }

    if (country.isEmpty) {
      setState(() {
        _errorMessage = 'Bitte Land ausfüllen.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final updatedProfile = currentProfile.copyWith(
        uid: user.uid,
        email: user.email ?? currentProfile.email,
        firstName: firstName,
        lastName: lastName,
        displayName: displayName,
        country: country,
      );

      await _profileRepository.saveProfile(updatedProfile);

      if (!mounted) return;

      setState(() {
        _profile = updatedProfile;
        _isSaving = false;
        _errorMessage = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil wurde gespeichert.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
        _errorMessage = 'Profil konnte nicht gespeichert werden.';
      });
    }
  }

  String _displayInitials() {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();

    final firstInitial = firstName.isNotEmpty ? firstName[0] : '';
    final lastInitial = lastName.isNotEmpty ? lastName[0] : '';

    final initials = '$firstInitial$lastInitial'.toUpperCase();
    return initials.isEmpty ? 'C' : initials;
  }

  @override
  Widget build(BuildContext context) {
    return CarmaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: _isLoading
              ? const Center(
            child: CircularProgressIndicator(),
          )
              : ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            children: [
              const Text(
                'Profil',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.9,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Verwalte deine öffentlichen Profildaten und bereite dein Konto für Carma vor.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.68),
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              _ProfileHeaderCard(
                initials: _displayInitials(),
                email: FirebaseAuth.instance.currentUser?.email ??
                    'Keine E-Mail gefunden',
                verificationStatus:
                _profile?.verificationStatus ?? 'unverified',
              ),
              const SizedBox(height: 16),
              if (_errorMessage != null) ...[
                _ErrorCard(message: _errorMessage!),
                const SizedBox(height: 16),
              ],
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Profildaten',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Diese Daten helfen später, dein Profil kontrolliert und vertrauenswürdig darzustellen.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _firstNameController,
                      enabled: !_isSaving,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Vorname',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _lastNameController,
                      enabled: !_isSaving,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Nachname',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _displayNameController,
                      enabled: !_isSaving,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Öffentlicher Anzeigename',
                        prefixIcon: Icon(Icons.visibility_outlined),
                        hintText: 'z. B. Sehmus Y.',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _countryController,
                      enabled: !_isSaving,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Land',
                        prefixIcon: Icon(Icons.public),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _saveProfile,
                      icon: _isSaving
                          ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        _isSaving ? 'Speichern...' : 'Profil speichern',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                padding: const EdgeInsets.all(18),
                opacity: 0.08,
                child: Column(
                  children: [
                    _ProfileOptionTile(
                      icon: Icons.directions_car_outlined,
                      title: 'Fahrzeuge',
                      subtitle:
                      'Fahrzeuge werden im nächsten Schritt vorbereitet.',
                      onTap: () {},
                    ),
                    Divider(
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                    _ProfileOptionTile(
                      icon: Icons.verified_user_outlined,
                      title: 'Verifizierung',
                      subtitle:
                      'Profil-Verifizierung wird später ergänzt.',
                      onTap: () {},
                    ),
                    Divider(
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                    _ProfileOptionTile(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Sichtbarkeit',
                      subtitle:
                      'Private und öffentliche Daten werden getrennt.',
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({
    required this.initials,
    required this.email,
    required this.verificationStatus,
  });

  final String initials;
  final String email;
  final String verificationStatus;

  @override
  Widget build(BuildContext context) {
    final isVerified = verificationStatus == 'verified';

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.10),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.20),
              ),
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mein Carma-Profil',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  email,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Text(
                    isVerified ? 'Verifiziert' : 'Nicht verifiziert',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileOptionTile extends StatelessWidget {
  const _ProfileOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.white),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.58),
          height: 1.35,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.white.withValues(alpha: 0.42),
      ),
      onTap: onTap,
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      opacity: 0.10,
      borderOpacity: 0.18,
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFFFFCDD2),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}