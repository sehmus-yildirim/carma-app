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

  final FocusNode _regionFocusNode = FocusNode();
  final FocusNode _lettersFocusNode = FocusNode();
  final FocusNode _numbersFocusNode = FocusNode();

  String _countryCode = 'DE';

  Position? _position;
  PlateSearchResult? _result;

  bool _isLoadingLocation = true;
  bool _isSearching = false;
  bool _isRequestingContact = false;

  String? _locationError;
  String? _errorMessage;
  String? _successMessage;

  bool get _usesLettersField => _countryCode != 'CH';

  String get _firstFieldLabel {
    switch (_countryCode) {
      case 'AT':
        return 'Bezirk';
      case 'CH':
        return 'Kanton';
      case 'DE':
      default:
        return 'Stadt';
    }
  }

  int get _firstFieldMaxLength {
    switch (_countryCode) {
      case 'AT':
        return 2;
      case 'CH':
        return 2;
      case 'DE':
      default:
        return 3;
    }
  }

  int get _numbersMaxLength {
    switch (_countryCode) {
      case 'CH':
        return 6;
      case 'AT':
      case 'DE':
      default:
        return 5;
    }
  }

  bool get _hasPlateInput {
    final region = _regionController.text.trim();
    final letters = _lettersController.text.trim();
    final numbers = _numbersController.text.trim();

    if (_countryCode == 'CH') {
      return region.isNotEmpty && numbers.isNotEmpty;
    }

    return region.isNotEmpty && letters.isNotEmpty && numbers.isNotEmpty;
  }

  bool get _canSearch {
    return _hasPlateInput &&
        _position != null &&
        !_isLoadingLocation &&
        !_isSearching;
  }

  String get _plateValue {
    final region = _regionController.text.trim().toUpperCase();
    final letters = _lettersController.text.trim().toUpperCase();
    final numbers = _numbersController.text.trim().toUpperCase();

    if (_countryCode == 'CH') {
      return '$region$numbers';
    }

    return '$region$letters$numbers';
  }

  String get _displayPlate {
    final region = _regionController.text.trim().toUpperCase();
    final letters = _lettersController.text.trim().toUpperCase();
    final numbers = _numbersController.text.trim().toUpperCase();

    if (_countryCode == 'CH') {
      if (region.isEmpty && numbers.isEmpty) {
        return '';
      }
      return '$region $numbers';
    }

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

    _regionFocusNode.dispose();
    _lettersFocusNode.dispose();
    _numbersFocusNode.dispose();

    super.dispose();
  }

  void _refresh() {
    setState(() {});
  }

  void _clearResultMessages() {
    _result = null;
    _errorMessage = null;
    _successMessage = null;
  }

  void _changeCountry(String countryCode) {
    if (_countryCode == countryCode) {
      return;
    }

    setState(() {
      _countryCode = countryCode;
      _regionController.clear();
      _lettersController.clear();
      _numbersController.clear();
      _clearResultMessages();
    });

    _regionFocusNode.requestFocus();
  }

  Future<void> _loadLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
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
        _locationError = null;
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
      if (_locationError != null) {
        setState(() {
          _errorMessage = _locationError;
        });
      }
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSearching = true;
      _clearResultMessages();
    });

    try {
      final result = await _plateSearchService.searchPlate(
        countryCode: _countryCode,
        plate: _plateValue,
        latitude: position.latitude,
        longitude: position.longitude,
        radiusKm: 5,
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

    return 'Die Suche ist aktuell noch nicht vollständig verbunden. Das Backend richten wir im nächsten Schritt ein.';
  }

  void _handleRegionChanged(String value) {
    _clearResultMessages();

    if (value.length >= _firstFieldMaxLength) {
      if (_usesLettersField) {
        _lettersFocusNode.requestFocus();
      } else {
        _numbersFocusNode.requestFocus();
      }
    }
  }

  void _handleLettersChanged(String value) {
    _clearResultMessages();

    if (value.length >= 2) {
      _numbersFocusNode.requestFocus();
    }
  }

  void _handleNumbersChanged(String value) {
    _clearResultMessages();

    if (value.length >= _numbersMaxLength) {
      _numbersFocusNode.unfocus();
    }
  }

  Widget _buildResultArea() {
    if (_isSearching) {
      return const _LoadingCard();
    }

    if (_result != null) {
      return _PlateSearchResultCard(
        result: _result!,
        fallbackDisplayPlate: _displayPlate,
        isRequestingContact: _isRequestingContact,
        onRequestContact: _requestContact,
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return CarmaBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _HomeHeader(),
              const SizedBox(height: 20),
              _PlateSearchHomeCard(
                countryCode: _countryCode,
                firstFieldLabel: _firstFieldLabel,
                firstFieldMaxLength: _firstFieldMaxLength,
                numbersMaxLength: _numbersMaxLength,
                usesLettersField: _usesLettersField,
                regionController: _regionController,
                lettersController: _lettersController,
                numbersController: _numbersController,
                regionFocusNode: _regionFocusNode,
                lettersFocusNode: _lettersFocusNode,
                numbersFocusNode: _numbersFocusNode,
                canSearch: _canSearch,
                isSearching: _isSearching,
                onCountryChanged: _changeCountry,
                onSearch: _searchPlate,
                onRegionChanged: _handleRegionChanged,
                onLettersChanged: _handleLettersChanged,
                onNumbersChanged: _handleNumbersChanged,
              ),
              if (_locationError != null) ...[
                const SizedBox(height: 14),
                _MessageCard(
                  icon: Icons.location_off_rounded,
                  message: _locationError!,
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                _MessageCard(
                  icon: Icons.error_outline_rounded,
                  message: _errorMessage!,
                ),
              ],
              if (_successMessage != null) ...[
                const SizedBox(height: 14),
                _MessageCard(
                  icon: Icons.check_circle_outline_rounded,
                  message: _successMessage!,
                ),
              ],
              const SizedBox(height: 16),
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _buildResultArea(),
                  ),
                ),
              ),
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
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withValues(alpha: 0.12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.20),
            ),
          ),
          child: const Icon(
            Icons.directions_car_filled_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            'Carma',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
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
    required this.firstFieldLabel,
    required this.firstFieldMaxLength,
    required this.numbersMaxLength,
    required this.usesLettersField,
    required this.regionController,
    required this.lettersController,
    required this.numbersController,
    required this.regionFocusNode,
    required this.lettersFocusNode,
    required this.numbersFocusNode,
    required this.canSearch,
    required this.isSearching,
    required this.onCountryChanged,
    required this.onSearch,
    required this.onRegionChanged,
    required this.onLettersChanged,
    required this.onNumbersChanged,
  });

  final String countryCode;
  final String firstFieldLabel;
  final int firstFieldMaxLength;
  final int numbersMaxLength;
  final bool usesLettersField;

  final TextEditingController regionController;
  final TextEditingController lettersController;
  final TextEditingController numbersController;

  final FocusNode regionFocusNode;
  final FocusNode lettersFocusNode;
  final FocusNode numbersFocusNode;

  final bool canSearch;
  final bool isSearching;

  final ValueChanged<String> onCountryChanged;
  final VoidCallback onSearch;
  final ValueChanged<String> onRegionChanged;
  final ValueChanged<String> onLettersChanged;
  final ValueChanged<String> onNumbersChanged;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
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
          const SizedBox(height: 14),
          Text(
            'Jemanden gesehen der dir gefällt?',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              height: 1.18,
            ),
          ),
          const SizedBox(height: 6),
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
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Colors.white.withValues(alpha: 0.08),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.16),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _PlateInputField(
                    title: firstFieldLabel,
                    controller: regionController,
                    focusNode: regionFocusNode,
                    textInputAction:
                    usesLettersField ? TextInputAction.next : TextInputAction.next,
                    maxLength: firstFieldMaxLength,
                    inputFormatters: const [
                      _LettersOnlyFormatter(),
                    ],
                    onChanged: onRegionChanged,
                  ),
                ),
                if (usesLettersField) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PlateInputField(
                      title: 'Buchstaben',
                      controller: lettersController,
                      focusNode: lettersFocusNode,
                      textInputAction: TextInputAction.next,
                      maxLength: 2,
                      inputFormatters: const [
                        _LettersOnlyFormatter(),
                      ],
                      onChanged: onLettersChanged,
                    ),
                  ),
                ],
                const SizedBox(width: 10),
                Expanded(
                  child: _PlateInputField(
                    title: 'Zahlen',
                    controller: numbersController,
                    focusNode: numbersFocusNode,
                    textInputAction: TextInputAction.done,
                    keyboardType: TextInputType.text,
                    maxLength: numbersMaxLength,
                    inputFormatters: const [
                      _NumberWithOptionalEFormatter(),
                    ],
                    onChanged: onNumbersChanged,
                  ),
                ),
              ],
            ),
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
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.20),
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
          const _CountryDivider(),
          _CountryTab(
            label: 'Österreich',
            countryCode: 'AT',
            selectedCountryCode: selectedCountryCode,
            onChanged: onChanged,
          ),
          const _CountryDivider(),
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
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0E5BFF),
                Color(0xFF22B8FF),
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
  const _CountryDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 26,
      color: Colors.white.withValues(alpha: 0.18),
    );
  }
}

class _PlateInputField extends StatelessWidget {
  const _PlateInputField({
    required this.title,
    required this.controller,
    required this.focusNode,
    required this.textInputAction,
    required this.maxLength,
    required this.inputFormatters,
    required this.onChanged,
    this.keyboardType = TextInputType.text,
  });

  final String title;
  final TextEditingController controller;
  final FocusNode focusNode;
  final TextInputAction textInputAction;
  final int maxLength;
  final List<TextInputFormatter> inputFormatters;
  final ValueChanged<String> onChanged;
  final TextInputType keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.70),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          focusNode: focusNode,
          maxLength: maxLength,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.12),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 18,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.16),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.42),
              ),
            ),
          ),
        ),
      ],
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
        key: const ValueKey('no_result'),
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
      key: const ValueKey('result'),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0E5BFF),
                      Color(0xFF22B8FF),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                ),
                child: const Icon(
                  Icons.person_rounded,
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
          const SizedBox(height: 20),
          _ResultRow(
            label: 'Kennzeichen',
            value: fallbackDisplayPlate.isEmpty ? '-' : fallbackDisplayPlate,
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
          const SizedBox(height: 20),
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
          width: 112,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.72),
              fontWeight: FontWeight.w700,
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
      key: const ValueKey('loading'),
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

class _LettersOnlyFormatter extends TextInputFormatter {
  const _LettersOnlyFormatter();

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final normalized = newValue.text
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-ZÄÖÜ]'), '');

    return TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
  }
}

class _NumberWithOptionalEFormatter extends TextInputFormatter {
  const _NumberWithOptionalEFormatter();

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final upper = newValue.text.toUpperCase();
    final buffer = StringBuffer();
    bool eUsed = false;

    for (var i = 0; i < upper.length; i++) {
      final char = upper[i];

      if (RegExp(r'[0-9]').hasMatch(char)) {
        if (!eUsed) {
          buffer.write(char);
        }
        continue;
      }

      if (char == 'E' && !eUsed && i == upper.length - 1) {
        buffer.write(char);
        eUsed = true;
      }
    }

    final normalized = buffer.toString();

    return TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
  }
}