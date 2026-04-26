import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../../../shared/widgets/carma_background.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../plate_search/data/plate_search_result.dart';
import '../../plate_search/data/plate_search_service.dart';

const Color _carmaBlue = Color(0xFF139CFF);
const Color _carmaBlueLight = Color(0xFF63D5FF);
const Color _carmaBlueDark = Color(0xFF0A76FF);

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

  String get _firstName {
    final fullName =
        FirebaseAuth.instance.currentUser?.displayName?.trim() ?? '';

    if (fullName.isEmpty) {
      return '';
    }

    return fullName.split(RegExp(r'\s+')).first.trim();
  }

  String get _greeting {
    if (_firstName.isEmpty) {
      return 'Hallo!';
    }

    return 'Hallo $_firstName!';
  }

  int get _regionMaxLength {
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

  int get _lettersMaxLength {
    switch (_countryCode) {
      case 'AT':
        return 2;
      case 'DE':
      default:
        return 2;
    }
  }

  int get _numbersMaxLength {
    switch (_countryCode) {
      case 'CH':
        return 6;
      case 'AT':
        return 5;
      case 'DE':
      default:
        return 5;
    }
  }

  bool get _hasLettersField => _countryCode != 'CH';

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

    if (_countryCode == 'AT') {
      return '$region$numbers$letters';
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

    if (_countryCode == 'AT') {
      if (region.isEmpty && numbers.isEmpty && letters.isEmpty) {
        return '';
      }

      return '$region $numbers $letters';
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

    if (value.length >= _regionMaxLength) {
      if (_countryCode == 'CH') {
        _numbersFocusNode.requestFocus();
        return;
      }

      if (_countryCode == 'AT') {
        _numbersFocusNode.requestFocus();
        return;
      }

      _lettersFocusNode.requestFocus();
    }
  }

  void _handleLettersChanged(String value) {
    _clearResultMessages();

    if (value.length >= _lettersMaxLength) {
      if (_countryCode == 'AT') {
        _lettersFocusNode.unfocus();
        return;
      }

      _numbersFocusNode.requestFocus();
    }
  }

  void _handleNumbersChanged(String value) {
    _clearResultMessages();

    if (_countryCode == 'AT') {
      if (value.length >= _numbersMaxLength) {
        _lettersFocusNode.requestFocus();
      }
      return;
    }

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
              const SizedBox(height: 24),
              Text(
                _greeting,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Jemanden gesehen der dir gefällt?',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                  height: 1.12,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Dann tippe hier das Kennzeichen ein.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.76),
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 18),
              _CountrySelectorCard(
                selectedCountryCode: _countryCode,
                onChanged: _changeCountry,
              ),
              const SizedBox(height: 12),
              _PlateInputCard(
                countryCode: _countryCode,
                regionMaxLength: _regionMaxLength,
                lettersMaxLength: _lettersMaxLength,
                numbersMaxLength: _numbersMaxLength,
                hasLettersField: _hasLettersField,
                regionController: _regionController,
                lettersController: _lettersController,
                numbersController: _numbersController,
                regionFocusNode: _regionFocusNode,
                lettersFocusNode: _lettersFocusNode,
                numbersFocusNode: _numbersFocusNode,
                onRegionChanged: _handleRegionChanged,
                onLettersChanged: _handleLettersChanged,
                onNumbersChanged: _handleNumbersChanged,
              ),
              const SizedBox(height: 12),
              _SearchButtonCard(
                isEnabled: _canSearch,
                isLoading: _isSearching,
                onPressed: _searchPlate,
              ),
              if (_locationError != null) ...[
                const SizedBox(height: 12),
                _MessageCard(
                  icon: Icons.location_off_rounded,
                  message: _locationError!,
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                _MessageCard(
                  icon: Icons.error_outline_rounded,
                  message: _errorMessage!,
                ),
              ],
              if (_successMessage != null) ...[
                const SizedBox(height: 12),
                _MessageCard(
                  icon: Icons.check_circle_outline_rounded,
                  message: _successMessage!,
                ),
              ],
              const SizedBox(height: 14),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Align(
                    alignment: Alignment.topCenter,
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
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withValues(alpha: 0.11),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.16),
            ),
            boxShadow: [
              BoxShadow(
                color: _carmaBlue.withValues(alpha: 0.10),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
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

class _CountrySelectorCard extends StatelessWidget {
  const _CountrySelectorCard({
    required this.selectedCountryCode,
    required this.onChanged,
  });

  final String selectedCountryCode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Expanded(
            child: _CountryButton(
              label: 'Deutschland',
              countryCode: 'DE',
              selectedCountryCode: selectedCountryCode,
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _CountryButton(
              label: 'Österreich',
              countryCode: 'AT',
              selectedCountryCode: selectedCountryCode,
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _CountryButton(
              label: 'Schweiz',
              countryCode: 'CH',
              selectedCountryCode: selectedCountryCode,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountryButton extends StatelessWidget {
  const _CountryButton({
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(countryCode),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: isSelected
                ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _carmaBlueDark,
                _carmaBlue,
                _carmaBlueLight,
              ],
            )
                : null,
            color: isSelected ? null : Colors.white.withValues(alpha: 0.04),
            border: Border.all(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.22)
                  : Colors.white.withValues(alpha: 0.10),
            ),
            boxShadow: isSelected
                ? [
              BoxShadow(
                color: _carmaBlue.withValues(alpha: 0.26),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ]
                : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                letterSpacing: -0.1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlateInputCard extends StatelessWidget {
  const _PlateInputCard({
    required this.countryCode,
    required this.regionMaxLength,
    required this.lettersMaxLength,
    required this.numbersMaxLength,
    required this.hasLettersField,
    required this.regionController,
    required this.lettersController,
    required this.numbersController,
    required this.regionFocusNode,
    required this.lettersFocusNode,
    required this.numbersFocusNode,
    required this.onRegionChanged,
    required this.onLettersChanged,
    required this.onNumbersChanged,
  });

  final String countryCode;
  final int regionMaxLength;
  final int lettersMaxLength;
  final int numbersMaxLength;
  final bool hasLettersField;

  final TextEditingController regionController;
  final TextEditingController lettersController;
  final TextEditingController numbersController;

  final FocusNode regionFocusNode;
  final FocusNode lettersFocusNode;
  final FocusNode numbersFocusNode;

  final ValueChanged<String> onRegionChanged;
  final ValueChanged<String> onLettersChanged;
  final ValueChanged<String> onNumbersChanged;

  @override
  Widget build(BuildContext context) {
    final List<Widget> fields = [
      Expanded(
        child: _PlateInputField(
          label: countryCode == 'CH'
              ? 'Kanton'
              : countryCode == 'AT'
              ? 'Bezirk'
              : 'Stadt',
          controller: regionController,
          focusNode: regionFocusNode,
          textInputAction: TextInputAction.next,
          maxLength: regionMaxLength,
          inputFormatters: const [
            _LettersOnlyFormatter(),
          ],
          onChanged: onRegionChanged,
        ),
      ),
    ];

    if (countryCode == 'AT') {
      fields.addAll([
        const SizedBox(width: 10),
        Expanded(
          child: _PlateInputField(
            label: 'Zahlen',
            controller: numbersController,
            focusNode: numbersFocusNode,
            textInputAction: TextInputAction.next,
            maxLength: numbersMaxLength,
            inputFormatters: const [
              _NumbersOnlyFormatter(),
            ],
            onChanged: onNumbersChanged,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PlateInputField(
            label: 'Buchstaben',
            controller: lettersController,
            focusNode: lettersFocusNode,
            textInputAction: TextInputAction.done,
            maxLength: lettersMaxLength,
            inputFormatters: const [
              _LettersOnlyFormatter(),
            ],
            onChanged: onLettersChanged,
          ),
        ),
      ]);
    } else if (countryCode == 'CH') {
      fields.addAll([
        const SizedBox(width: 10),
        Expanded(
          child: _PlateInputField(
            label: 'Zahlen',
            controller: numbersController,
            focusNode: numbersFocusNode,
            textInputAction: TextInputAction.done,
            maxLength: numbersMaxLength,
            inputFormatters: const [
              _NumbersOnlyFormatter(),
            ],
            onChanged: onNumbersChanged,
          ),
        ),
      ]);
    } else {
      fields.addAll([
        const SizedBox(width: 10),
        Expanded(
          child: _PlateInputField(
            label: 'Buchstaben',
            controller: lettersController,
            focusNode: lettersFocusNode,
            textInputAction: TextInputAction.next,
            maxLength: lettersMaxLength,
            inputFormatters: const [
              _LettersOnlyFormatter(),
            ],
            onChanged: onLettersChanged,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PlateInputField(
            label: 'Zahlen',
            controller: numbersController,
            focusNode: numbersFocusNode,
            textInputAction: TextInputAction.done,
            maxLength: numbersMaxLength,
            inputFormatters: const [
              _NumberWithOptionalEFormatter(),
            ],
            onChanged: onNumbersChanged,
          ),
        ),
      ]);
    }

    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: fields,
      ),
    );
  }
}

class _PlateInputField extends StatelessWidget {
  const _PlateInputField({
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.textInputAction,
    required this.maxLength,
    required this.inputFormatters,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final TextInputAction textInputAction;
  final int maxLength;
  final List<TextInputFormatter> inputFormatters;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.48),
            fontWeight: FontWeight.w800,
            fontSize: 12,
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          focusNode: focusNode,
          maxLength: maxLength,
          keyboardType: TextInputType.text,
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
            fillColor: Colors.white.withValues(alpha: 0.10),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 18,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: _carmaBlueLight.withValues(alpha: 0.90),
                width: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchButtonCard extends StatelessWidget {
  const _SearchButtonCard({
    required this.isEnabled,
    required this.isLoading,
    required this.onPressed,
  });

  final bool isEnabled;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isEnabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? onPressed : null,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _carmaBlueDark,
                  _carmaBlue,
                  _carmaBlueLight,
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
              ),
              boxShadow: [
                BoxShadow(
                  color: _carmaBlue.withValues(alpha: 0.26),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isLoading
                      ? Icons.hourglass_top_rounded
                      : Icons.search_rounded,
                  color: Colors.white,
                  size: 21,
                ),
                const SizedBox(width: 10),
                Text(
                  isLoading ? 'Suche läuft...' : 'Suchen',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.1,
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
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [
                    _carmaBlueDark,
                    _carmaBlueLight,
                  ],
                ),
              ),
              child: const Icon(
                Icons.search_off_rounded,
                color: Colors.white,
              ),
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
                      _carmaBlueDark,
                      _carmaBlue,
                      _carmaBlueLight,
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.24),
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
          _ResultInfoRow(
            label: 'Kennzeichen',
            value: fallbackDisplayPlate.isEmpty ? '-' : fallbackDisplayPlate,
          ),
          const SizedBox(height: 10),
          _ResultInfoRow(
            label: 'Entfernung',
            value: result.distanceKm == null
                ? 'In deiner Nähe'
                : '${result.distanceKm!.toStringAsFixed(1)} km',
          ),
          const SizedBox(height: 10),
          const _ResultInfoRow(
            label: 'Status',
            value: 'Aktiv in deiner Nähe',
          ),
          const SizedBox(height: 20),
          _RequestContactButton(
            isLoading: isRequestingContact,
            onPressed: onRequestContact,
          ),
        ],
      ),
    );
  }
}

class _RequestContactButton extends StatelessWidget {
  const _RequestContactButton({
    required this.isLoading,
    required this.onPressed,
  });

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withValues(alpha: 0.92),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isLoading
                    ? Icons.hourglass_top_rounded
                    : Icons.mail_outline_rounded,
                color: Colors.black.withValues(alpha: 0.80),
              ),
              const SizedBox(width: 10),
              Text(
                isLoading ? 'Anfrage läuft...' : 'Anfragen',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.black.withValues(alpha: 0.84),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultInfoRow extends StatelessWidget {
  const _ResultInfoRow({
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
              color: Colors.white.withValues(alpha: 0.68),
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

class _NumbersOnlyFormatter extends TextInputFormatter {
  const _NumbersOnlyFormatter();

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final normalized = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

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