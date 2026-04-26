import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../../../shared/widgets/carma_background.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../plate_search/data/plate_search_result.dart';
import '../../plate_search/data/plate_search_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final PlateSearchService _plateSearchService = PlateSearchService();

  final TextEditingController _regionController = TextEditingController();
  final TextEditingController _lettersController = TextEditingController();
  final TextEditingController _numbersController = TextEditingController();

  String _countryCode = 'DE';
  int _radiusKm = 5;

  Position? _position;
  PlateSearchResult? _result;

  bool _isLoadingLocation = true;
  bool _isSearching = false;
  bool _isRequestingContact = false;

  String? _locationError;
  String? _errorMessage;
  String? _successMessage;

  bool get _hasPlateInput {
    return _regionController.text.trim().isNotEmpty &&
        _lettersController.text.trim().isNotEmpty &&
        _numbersController.text.trim().isNotEmpty;
  }

  bool get _canSearch {
    return _hasPlateInput &&
        _position != null &&
        !_isLoadingLocation &&
        !_isSearching;
  }

  String get _plateValue {
    return '${_regionController.text}${_lettersController.text}${_numbersController.text}';
  }

  String get _displayPlate {
    final region = _regionController.text.trim().toUpperCase();
    final letters = _lettersController.text.trim().toUpperCase();
    final numbers = _numbersController.text.trim().toUpperCase();

    if (region.isEmpty && letters.isEmpty && numbers.isEmpty) {
      return '';
    }

    return '$region-$letters $numbers';
  }

  @override
  void initState() {
    super.initState();

    _regionController.addListener(_refresh);
    _lettersController.addListener(_refresh);
    _numbersController.addListener(_refresh);

    _loadLocation();
  }

  @override
  void dispose() {
    _regionController.removeListener(_refresh);
    _lettersController.removeListener(_refresh);
    _numbersController.removeListener(_refresh);

    _regionController.dispose();
    _lettersController.dispose();
    _numbersController.dispose();

    super.dispose();
  }

  void _refresh() {
    setState(() {});
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

  Future<void> _searchPlate() async {
    final position = _position;

    if (position == null || !_canSearch) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSearching = true;
      _result = null;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final result = await _plateSearchService.searchPlate(
        countryCode: _countryCode,
        plate: _plateValue,
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
      await _plateSearchService.requestPlateContact(
        targetUid: result.targetUid!,
        plateKey: result.plateKey!,
      );

      setState(() {
        _successMessage =
        'Kontaktanfrage wurde gesendet. Sobald sie angenommen wird, erscheint der Chat im Chat-Bereich.';
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

    return 'Die Suche ist aktuell noch nicht vollständig verbunden. Das Backend wird im nächsten Schritt eingerichtet.';
  }

  @override
  Widget build(BuildContext context) {
    return CarmaBackground(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _HomeHeader(),
              const SizedBox(height: 28),
              _PlateSearchHomeCard(
                countryCode: _countryCode,
                radiusKm: _radiusKm,
                regionController: _regionController,
                lettersController: _lettersController,
                numbersController: _numbersController,
                isLoadingLocation: _isLoadingLocation,
                locationError: _locationError,
                canSearch: _canSearch,
                isSearching: _isSearching,
                onCountryChanged: (countryCode) {
                  setState(() {
                    _countryCode = countryCode;
                    _result = null;
                    _errorMessage = null;
                    _successMessage = null;
                  });
                },
                onRadiusChanged: (radiusKm) {
                  setState(() {
                    _radiusKm = radiusKm;
                  });
                },
                onRetryLocation: _loadLocation,
                onSearch: _searchPlate,
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
              if (_isSearching)
                const _LoadingCard()
              else if (_result != null)
                _PlateSearchResultCard(
                  result: _result!,
                  fallbackDisplayPlate: _displayPlate,
                  isRequestingContact: _isRequestingContact,
                  onRequestContact: _requestContact,
                )
              else
                const _EmptyStateCard(),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withValues(alpha: 0.13),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.22),
            ),
          ),
          child: const Icon(
            Icons.directions_car_filled_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            'Carma',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlateSearchHomeCard extends StatelessWidget {
  const _PlateSearchHomeCard({
    required this.countryCode,
    required this.radiusKm,
    required this.regionController,
    required this.lettersController,
    required this.numbersController,
    required this.isLoadingLocation,
    required this.locationError,
    required this.canSearch,
    required this.isSearching,
    required this.onCountryChanged,
    required this.onRadiusChanged,
    required this.onRetryLocation,
    required this.onSearch,
  });

  final String countryCode;
  final int radiusKm;
  final TextEditingController regionController;
  final TextEditingController lettersController;
  final TextEditingController numbersController;
  final bool isLoadingLocation;
  final String? locationError;
  final bool canSearch;
  final bool isSearching;
  final ValueChanged<String> onCountryChanged;
  final ValueChanged<int> onRadiusChanged;
  final VoidCallback onRetryLocation;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hallo Sehmus!',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Jemanden gesehen der dir gefällt?',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              height: 1.18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Dann tippe hier das Kennzeichen ein.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.78),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          _CountrySelector(
            selectedCountryCode: countryCode,
            onChanged: onCountryChanged,
          ),
          const SizedBox(height: 16),
          _PlateInputBox(
            regionController: regionController,
            lettersController: lettersController,
            numbersController: numbersController,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _RadiusSelector(
                  radiusKm: radiusKm,
                  onChanged: onRadiusChanged,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LocationStatus(
                  isLoadingLocation: isLoadingLocation,
                  locationError: locationError,
                  onRetryLocation: onRetryLocation,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _HomeSearchButton(
            label: isSearching ? 'Suche läuft...' : 'Suchen',
            icon: Icons.search_rounded,
            onPressed: canSearch ? onSearch : null,
          ),
        ],
      ),
    );
  }
}

class _CountrySelector extends StatelessWidget {
  const _CountrySelector({
    required this.selectedCountryCode,
    required this.onChanged,
  });

  final String selectedCountryCode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.26),
        ),
        color: Colors.white.withValues(alpha: 0.05),
      ),
      child: Row(
        children: [
          _CountryTab(
            label: 'Deutschland',
            countryCode: 'DE',
            selectedCountryCode: selectedCountryCode,
            onChanged: onChanged,
          ),
          _CountryDivider(),
          _CountryTab(
            label: 'Österreich',
            countryCode: 'AT',
            selectedCountryCode: selectedCountryCode,
            onChanged: onChanged,
          ),
          _CountryDivider(),
          _CountryTab(
            label: 'Schweiz',
            countryCode: 'CH',
            selectedCountryCode: selectedCountryCode,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _CountryTab extends StatelessWidget {
  const _CountryTab({
    required this.label,
    required this.countryCode,
    required this.selectedCountryCode,
    required this.onChanged,
  });

  final String label;
  final String countryCode;
  final String selectedCountryCode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedCountryCode == countryCode;

    return Expanded(
      child: InkWell(
        onTap: () => onChanged(countryCode),
        borderRadius: BorderRadius.circular(17),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            gradient: isSelected
                ? const LinearGradient(
              colors: [
                Color(0xFF7C22FF),
                Color(0xFFB235FF),
              ],
            )
                : null,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _CountryDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      color: Colors.white.withValues(alpha: 0.22),
    );
  }
}

class _PlateInputBox extends StatelessWidget {
  const _PlateInputBox({
    required this.regionController,
    required this.lettersController,
    required this.numbersController,
  });

  final TextEditingController regionController;
  final TextEditingController lettersController;
  final TextEditingController numbersController;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: Colors.white.withValues(alpha: 0.10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _PlateTextField(
              controller: regionController,
              hint: 'HH',
              maxLength: 3,
              keyboardType: TextInputType.text,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _PlateTextField(
              controller: lettersController,
              hint: 'SY',
              maxLength: 2,
              keyboardType: TextInputType.text,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _PlateTextField(
              controller: numbersController,
              hint: '4700',
              maxLength: 4,
              keyboardType: TextInputType.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlateTextField extends StatelessWidget {
  const _PlateTextField({
    required this.controller,
    required this.hint,
    required this.maxLength,
    required this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLength;
  final TextInputType keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      keyboardType: keyboardType,
      textAlign: TextAlign.center,
      textCapitalization: TextCapitalization.characters,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
        _UpperCaseTextFormatter(),
      ],
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.8,
      ),
      decoration: InputDecoration(
        counterText: '',
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.58),
          fontWeight: FontWeight.w900,
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.12),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 18,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.18),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.48),
          ),
        ),
      ),
    );
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
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

class _RadiusSelector extends StatelessWidget {
  const _RadiusSelector({
    required this.radiusKm,
    required this.onChanged,
  });

  final int radiusKm;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      initialValue: radiusKm,
      color: const Color(0xFF1A1A2E),
      onSelected: onChanged,
      itemBuilder: (context) {
        return const [
          PopupMenuItem(
            value: 1,
            child: Text('1 km'),
          ),
          PopupMenuItem(
            value: 5,
            child: Text('5 km'),
          ),
          PopupMenuItem(
            value: 10,
            child: Text('10 km'),
          ),
        ];
      },
      child: _SmallInfoPill(
        icon: Icons.radar_rounded,
        label: '$radiusKm km',
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
      return const _SmallInfoPill(
        icon: Icons.my_location_rounded,
        label: 'GPS...',
      );
    }

    if (locationError != null) {
      return InkWell(
        onTap: onRetryLocation,
        borderRadius: BorderRadius.circular(16),
        child: const _SmallInfoPill(
          icon: Icons.refresh_rounded,
          label: 'GPS prüfen',
        ),
      );
    }

    return const _SmallInfoPill(
      icon: Icons.my_location_rounded,
      label: 'Standort',
    );
  }
}

class _SmallInfoPill extends StatelessWidget {
  const _SmallInfoPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.09),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: Colors.white.withValues(alpha: 0.82),
            size: 18,
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeSearchButton extends StatelessWidget {
  const _HomeSearchButton({
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
      opacity: isEnabled ? 1 : 0.46,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Colors.white.withValues(alpha: 0.94),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: Colors.black.withValues(alpha: 0.82),
                  size: 21,
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.black.withValues(alpha: 0.86),
                    fontWeight: FontWeight.w900,
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

class _PlateSearchResultCard extends StatelessWidget {
  const _PlateSearchResultCard({
    required this.result,
    required this.fallbackDisplayPlate,
    required this.isRequestingContact,
    required this.onRequestContact,
  });

  final PlateSearchResult result;
  final String fallbackDisplayPlate;
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
              size: 30,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Kein Nutzer in deiner Nähe gefunden.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
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
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF7C22FF),
                      Color(0xFF31D4FF),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.32),
                  ),
                ),
                child: const Icon(
                  Icons.directions_car_filled_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  result.displayName ?? 'Carma Nutzer',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _ResultRow(
            label: 'Kennzeichen',
            value: fallbackDisplayPlate,
          ),
          const SizedBox(height: 10),
          _ResultRow(
            label: 'Entfernung',
            value: result.distanceKm == null
                ? 'In deiner Nähe'
                : '${result.distanceKm!.toStringAsFixed(1)} km',
          ),
          const SizedBox(height: 10),
          const _ResultRow(
            label: 'Status',
            value: 'Aktiv in deiner Nähe',
          ),
          const SizedBox(height: 22),
          _HomeSearchButton(
            label: isRequestingContact ? 'Anfrage läuft...' : 'Anfragen',
            icon: Icons.mail_outline_rounded,
            onPressed: isRequestingContact ? null : onRequestContact,
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 116,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.76),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
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
              fontWeight: FontWeight.w800,
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
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Icon(
            Icons.lock_outline_rounded,
            color: Colors.white.withValues(alpha: 0.82),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Suchergebnisse erscheinen hier direkt auf der Startseite. Kein neues Fenster, kein extra Screen.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}