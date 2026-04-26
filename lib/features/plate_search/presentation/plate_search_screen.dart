import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../../../shared/widgets/carma_background.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/plate_search_result.dart';
import '../data/plate_search_service.dart';

class PlateSearchScreen extends StatefulWidget {
  const PlateSearchScreen({super.key});

  @override
  State<PlateSearchScreen> createState() => _PlateSearchScreenState();
}

class _PlateSearchScreenState extends State<PlateSearchScreen> {
  final PlateSearchService _service = PlateSearchService();
  final TextEditingController _plateController = TextEditingController();

  String _countryCode = 'DE';
  int _radiusKm = 5;

  Position? _position;
  bool _isLoadingLocation = true;
  bool _isSearching = false;
  bool _isRequestingContact = false;

  String? _locationError;
  String? _errorMessage;
  String? _successMessage;

  PlateSearchResult? _result;

  bool get _canSearch {
    return _plateController.text.trim().isNotEmpty &&
        _position != null &&
        !_isLoadingLocation &&
        !_isSearching;
  }

  @override
  void initState() {
    super.initState();
    _plateController.addListener(() {
      setState(() {});
    });
    _loadLocation();
  }

  @override
  void dispose() {
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _loadLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
      _errorMessage = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        setState(() {
          _locationError =
          'Standortdienste sind deaktiviert. Bitte aktiviere GPS auf deinem Gerät.';
          _isLoadingLocation = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        setState(() {
          _locationError =
          'Standortberechtigung wurde verweigert. Die Suche ist ohne Standort nicht möglich.';
          _isLoadingLocation = false;
        });
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationError =
          'Standortberechtigung wurde dauerhaft verweigert. Bitte erlaube Standortzugriff in den App-Einstellungen.';
          _isLoadingLocation = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() {
        _position = position;
        _isLoadingLocation = false;
      });
    } catch (_) {
      setState(() {
        _locationError =
        'Standort konnte nicht geladen werden. Bitte versuche es erneut.';
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _search() async {
    final position = _position;

    if (position == null || !_canSearch) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _successMessage = null;
      _result = null;
    });

    try {
      final result = await _service.searchPlate(
        countryCode: _countryCode,
        plate: _plateController.text,
        latitude: position.latitude,
        longitude: position.longitude,
        radiusKm: _radiusKm,
      );

      setState(() {
        _result = result;
        _isSearching = false;
      });
    } catch (error) {
      setState(() {
        _errorMessage = _mapFirebaseError(error);
        _isSearching = false;
      });
    }
  }

  Future<void> _requestContact() async {
    final result = _result;

    if (result == null || result.targetUid == null || result.plateKey == null) {
      return;
    }

    setState(() {
      _isRequestingContact = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await _service.requestPlateContact(
        targetUid: result.targetUid!,
        plateKey: result.plateKey!,
      );

      setState(() {
        _successMessage =
        'Kontaktanfrage wurde gesendet. Sobald sie angenommen wird, erscheint der Chat in deinem Chat-Bereich.';
        _isRequestingContact = false;
      });
    } catch (error) {
      setState(() {
        _errorMessage = _mapFirebaseError(error);
        _isRequestingContact = false;
      });
    }
  }

  String _mapFirebaseError(Object error) {
    final raw = error.toString();

    if (raw.contains('resource-exhausted')) {
      return 'Du hast dein kostenloses Suchlimit erreicht. Später kannst du über Credits weitere Suchen kaufen.';
    }

    if (raw.contains('unauthenticated')) {
      return 'Bitte melde dich an, um Kennzeichen suchen zu können.';
    }

    if (raw.contains('invalid-argument')) {
      return 'Bitte prüfe deine Eingaben.';
    }

    if (raw.contains('permission-denied')) {
      return 'Diese Aktion ist nicht erlaubt.';
    }

    if (raw.contains('already-exists')) {
      return 'Für diesen Treffer existiert bereits eine Anfrage.';
    }

    return 'Es ist ein Fehler aufgetreten. Bitte versuche es erneut.';
  }

  @override
  Widget build(BuildContext context) {
    return CarmaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          title: const Text('Kennzeichen suchen'),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _IntroCard(),
                const SizedBox(height: 18),
                _SearchFormCard(
                  plateController: _plateController,
                  countryCode: _countryCode,
                  radiusKm: _radiusKm,
                  isLoadingLocation: _isLoadingLocation,
                  locationError: _locationError,
                  onCountryChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _countryCode = value;
                    });
                  },
                  onRadiusChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _radiusKm = value;
                    });
                  },
                  onRetryLocation: _loadLocation,
                ),
                const SizedBox(height: 18),
                if (_errorMessage != null) ...[
                  _MessageCard(
                    icon: Icons.error_outline_rounded,
                    message: _errorMessage!,
                  ),
                  const SizedBox(height: 18),
                ],
                if (_successMessage != null) ...[
                  _MessageCard(
                    icon: Icons.check_circle_outline_rounded,
                    message: _successMessage!,
                  ),
                  const SizedBox(height: 18),
                ],
                _PlateSearchButton(
                  label: _isSearching ? 'Suche läuft...' : 'Suchen',
                  icon: Icons.search_rounded,
                  onPressed: _canSearch ? _search : null,
                ),
                const SizedBox(height: 22),
                if (_isSearching)
                  const _LoadingCard()
                else if (_result != null)
                  _ResultCard(
                    result: _result!,
                    isRequestingContact: _isRequestingContact,
                    onRequestContact: _requestContact,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UpperCasePlateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final normalized = newValue.text.toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '',
    );

    return TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.22),
              ),
            ),
            child: const Icon(
              Icons.directions_car_filled_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Suche gezielt nach einem Kennzeichen in deiner Nähe. Treffer werden nur angezeigt, wenn Standort, Aktivität und Radius passen.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.78),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchFormCard extends StatelessWidget {
  const _SearchFormCard({
    required this.plateController,
    required this.countryCode,
    required this.radiusKm,
    required this.isLoadingLocation,
    required this.locationError,
    required this.onCountryChanged,
    required this.onRadiusChanged,
    required this.onRetryLocation,
  });

  final TextEditingController plateController;
  final String countryCode;
  final int radiusKm;
  final bool isLoadingLocation;
  final String? locationError;
  final ValueChanged<String?> onCountryChanged;
  final ValueChanged<int?> onRadiusChanged;
  final VoidCallback onRetryLocation;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Suchdaten',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: plateController,
            inputFormatters: [
              _UpperCasePlateFormatter(),
            ],
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
            decoration: _inputDecoration(
              label: 'Kennzeichen',
              hint: 'z. B. BAB123',
              icon: Icons.confirmation_number_outlined,
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: countryCode,
            dropdownColor: const Color(0xFF1A1A2E),
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration(
              label: 'Land',
              hint: 'Land auswählen',
              icon: Icons.flag_outlined,
            ),
            items: const [
              DropdownMenuItem(
                value: 'DE',
                child: Text('Deutschland 🇩🇪'),
              ),
              DropdownMenuItem(
                value: 'AT',
                child: Text('Österreich 🇦🇹'),
              ),
              DropdownMenuItem(
                value: 'CH',
                child: Text('Schweiz 🇨🇭'),
              ),
            ],
            onChanged: onCountryChanged,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<int>(
            initialValue: radiusKm,
            dropdownColor: const Color(0xFF1A1A2E),
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration(
              label: 'Radius',
              hint: 'Radius auswählen',
              icon: Icons.radar_rounded,
            ),
            items: const [
              DropdownMenuItem(
                value: 1,
                child: Text('1 km'),
              ),
              DropdownMenuItem(
                value: 5,
                child: Text('5 km'),
              ),
              DropdownMenuItem(
                value: 10,
                child: Text('10 km'),
              ),
            ],
            onChanged: onRadiusChanged,
          ),
          const SizedBox(height: 16),
          _LocationStatus(
            isLoadingLocation: isLoadingLocation,
            locationError: locationError,
            onRetryLocation: onRetryLocation,
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.78)),
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.38)),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.08),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.16),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.46),
        ),
      ),
    );
  }
}

class _LocationStatus extends StatelessWidget {
  const _LocationStatus({
    required this.isLoadingLocation,
    required this.locationError,
    required this.onRetryLocation,
  });

  final bool isLoadingLocation;
  final String? locationError;
  final VoidCallback onRetryLocation;

  @override
  Widget build(BuildContext context) {
    if (isLoadingLocation) {
      return Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Standort wird abgefragt...',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
        ],
      );
    }

    if (locationError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            locationError!,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onRetryLocation,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Erneut versuchen'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        const Icon(
          Icons.my_location_rounded,
          color: Colors.white,
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(
          'Standort bereit',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.78),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.result,
    required this.isRequestingContact,
    required this.onRequestContact,
  });

  final PlateSearchResult result;
  final bool isRequestingContact;
  final VoidCallback onRequestContact;

  @override
  Widget build(BuildContext context) {
    if (!result.found) {
      return GlassCard(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(
              Icons.search_off_rounded,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Kein Nutzer in deiner Nähe gefunden.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Treffer gefunden',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.displayName ?? 'Carma Nutzer',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result.distanceKm == null
                          ? 'In deiner Nähe'
                          : '${result.distanceKm!.toStringAsFixed(1)} km entfernt',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.68),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _PlateSearchButton(
            label: isRequestingContact
                ? 'Anfrage wird gesendet...'
                : 'Kontakt anfragen',
            icon: Icons.mark_chat_unread_outlined,
            onPressed: isRequestingContact ? null : onRequestContact,
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Text(
            'Suche läuft...',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: Colors.white,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlateSearchButton extends StatelessWidget {
  const _PlateSearchButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;

    return Opacity(
      opacity: isEnabled ? 1 : 0.48,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: Colors.white.withValues(alpha: 0.16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.28),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: 21,
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}