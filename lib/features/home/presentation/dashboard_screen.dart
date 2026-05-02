import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../shared/config/carma_app_config.dart';
import '../../../shared/domain/app_feature_gate.dart';
import '../../../shared/models/carma_models.dart';
import '../../../shared/plate/plate_country_config.dart';
import '../../../shared/widgets/carma_background.dart';
import '../../../shared/widgets/carma_country_selector_card.dart';
import '../../../shared/widgets/carma_message_card.dart';
import '../../../shared/widgets/carma_page_header.dart';
import '../../../shared/widgets/carma_plate_input_card.dart';
import '../../../shared/widgets/carma_primary_button.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../plate_search/data/plate_search_result.dart';
import '../../plate_search/data/plate_search_service.dart';

const Color _carmaBlue = Color(0xFF139CFF);
const Color _carmaBlueLight = Color(0xFF63D5FF);
const Color _carmaBlueDark = Color(0xFF0A76FF);

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.userState});

  final AppUserState userState;

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

  late SearchCredit _searchCredit;

  bool _isLoadingLocation = true;
  bool _isSearching = false;
  bool _isRequestingContact = false;

  String? _locationError;
  String? _errorMessage;
  String? _successMessage;

  PlateCountryConfig get _plateConfig {
    return plateConfigForCountry(_countryCode);
  }

  int get _regionMaxLength {
    return _plateConfig.regionMaxLength;
  }

  int get _lettersMaxLength {
    return _plateConfig.lettersMaxLength;
  }

  int get _numbersMaxLength {
    return _plateConfig.numbersMaxLength;
  }

  AppUserState get _effectiveUserState {
    return widget.userState.copyWith(searchCredit: _searchCredit);
  }

  AppFeatureDecision get _searchGateDecision {
    return AppFeatureGate.evaluate(
      userState: _effectiveUserState,
      feature: AppFeature.plateSearch,
    );
  }

  AppFeatureDecision get _contactGateDecision {
    return AppFeatureGate.evaluate(
      userState: _effectiveUserState,
      feature: AppFeature.contactRequest,
    );
  }

  CarmaPlate get _currentPlate {
    return CarmaPlate(
      countryCode: _countryCode,
      region: _regionController.text.trim(),
      letters: _lettersController.text.trim(),
      numbers: _numbersController.text.trim(),
    );
  }

  bool get _hasPlateInput {
    return _currentPlate.isComplete;
  }

  bool get _canAttemptSearch {
    return _hasPlateInput &&
        _searchGateDecision.isAllowed &&
        !_isLoadingLocation &&
        !_isSearching;
  }

  bool get _canSearch {
    return _canAttemptSearch && _position != null;
  }

  String get _plateValue {
    return buildPlateValue(
      countryCode: _countryCode,
      region: _regionController.text,
      letters: _lettersController.text,
      numbers: _numbersController.text,
    );
  }

  String get _displayPlate {
    final displayPlate = formatDisplayPlate(
      countryCode: _countryCode,
      region: _regionController.text,
      letters: _lettersController.text,
      numbers: _numbersController.text,
    );

    return displayPlate.isEmpty ? _currentPlate.displayValue : displayPlate;
  }

  @override
  void initState() {
    super.initState();

    _searchCredit = widget.userState.searchCredit.normalizeForCurrentMonth();

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
        if (!mounted) {
          return;
        }

        setState(() {
          _position = null;
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
        if (!mounted) {
          return;
        }

        setState(() {
          _position = null;
          _locationError =
              'Standortberechtigung wurde verweigert. Die Suche ist ohne Standort nicht möglich.';
          _isLoadingLocation = false;
        });
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) {
          return;
        }

        setState(() {
          _position = null;
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
      ).timeout(const Duration(seconds: 8));

      if (!mounted) {
        return;
      }

      setState(() {
        _position = position;
        _locationError = null;
        _isLoadingLocation = false;
      });
    } on TimeoutException {
      if (!mounted) {
        return;
      }

      setState(() {
        _position = null;
        _locationError =
            'Standort lädt zu lange. Bitte prüfe GPS oder setze im Emulator einen Standort.';
        _isLoadingLocation = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _position = null;
        _locationError =
            'Standort konnte nicht geladen werden. Bitte versuche es erneut.';
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _searchPlate() async {
    final position = _position;
    final gateDecision = _searchGateDecision;

    if (!gateDecision.isAllowed) {
      setState(() {
        _errorMessage =
            gateDecision.reason ??
            'Die Kennzeichen-Suche ist aktuell nicht verfügbar.';
        _successMessage = null;
      });
      return;
    }

    if (!_hasPlateInput) {
      setState(() {
        _errorMessage = 'Bitte gib ein vollständiges Kennzeichen ein.';
        _successMessage = null;
      });
      return;
    }

    if (_isLoadingLocation) {
      setState(() {
        _errorMessage = 'Standort wird noch geladen. Bitte warte kurz.';
        _successMessage = null;
      });
      return;
    }

    if (position == null) {
      setState(() {
        _errorMessage =
            _locationError ??
            'Bitte aktiviere den Standort, damit die Suche in deiner Nähe möglich ist.';
        _successMessage = null;
      });
      return;
    }

    if (!_canSearch) {
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
        radiusKm: CarmaAppConfig.defaultSearchRadiusKm,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _result = result;

        if (result.found) {
          _searchCredit = _searchCredit.consume();
        }

        _isSearching = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = _mapFirebaseError(error);
        _isSearching = false;
      });
    }
  }

  Future<void> _requestContact() async {
    final gateDecision = _contactGateDecision;

    if (!gateDecision.isAllowed) {
      setState(() {
        _errorMessage =
            gateDecision.reason ??
            'Kontaktanfragen sind aktuell nicht verfügbar.';
        _successMessage = null;
      });
      return;
    }

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

      if (!mounted) {
        return;
      }

      setState(() {
        _successMessage =
            'Kontaktanfrage wurde gesendet. Sobald sie angenommen wird, erscheint der Chat im Chat-Bereich.';
        _isRequestingContact = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = _mapFirebaseError(error);
        _isRequestingContact = false;
      });
    }
  }

  String _mapFirebaseError(Object error) {
    final raw = error.toString();

    if (raw.contains('resource-exhausted')) {
      return 'Du hast keine kostenlosen Anfragen oder Credits mehr verfügbar.';
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

    return 'Die Suche ist aktuell noch nicht vollständig verbunden. Das Backend richten wir später ein.';
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
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return CarmaBackground(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(20, 18, 20, 112 + keyboardInset),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 112,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CarmaPageHeader(
                      icon: Icons.directions_car_filled_rounded,
                      title: 'Suchen',
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Fahrzeughalter geschützt kontaktieren',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                            height: 1.12,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Gib ein Kennzeichen ein, um eine geschützte Kontaktanfrage vorzubereiten.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _SearchCreditCard(searchCredit: _searchCredit),
                    const SizedBox(height: 14),
                    CarmaCountrySelectorCard(
                      selectedCountryCode: _countryCode,
                      onChanged: _changeCountry,
                    ),
                    const SizedBox(height: 12),
                    CarmaPlateInputCard(
                      countryCode: _countryCode,
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
                      isEnabled: _canAttemptSearch,
                      isLoading: _isSearching,
                      onPressed: _searchPlate,
                    ),
                    if (_isLoadingLocation) ...[
                      const SizedBox(height: 12),
                      const _LocationLoadingCard(),
                    ],
                    if (_locationError != null) ...[
                      const SizedBox(height: 12),
                      CarmaMessageCard(
                        icon: Icons.location_off_rounded,
                        message: _locationError!,
                      ),
                      const SizedBox(height: 10),
                      _RetryLocationButton(
                        isLoading: _isLoadingLocation,
                        onPressed: _loadLocation,
                      ),
                    ],
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      CarmaMessageCard(
                        icon: Icons.error_outline_rounded,
                        message: _errorMessage!,
                      ),
                    ],
                    if (_successMessage != null) ...[
                      const SizedBox(height: 12),
                      CarmaMessageCard(
                        icon: Icons.check_circle_outline_rounded,
                        message: _successMessage!,
                      ),
                    ],
                    const SizedBox(height: 14),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: _buildResultArea(),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LocationLoadingCard extends StatelessWidget {
  const _LocationLoadingCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_carmaBlueDark, _carmaBlue, _carmaBlueLight],
              ),
            ),
            child: const Icon(
              Icons.my_location_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              'Standort wird geladen...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.78),
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RetryLocationButton extends StatelessWidget {
  const _RetryLocationButton({
    required this.isLoading,
    required this.onPressed,
  });

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CarmaPrimaryButton(
      label: 'Standort erneut laden',
      loadingLabel: 'Standort lädt...',
      icon: Icons.refresh_rounded,
      iconSize: 25,
      fontSize: 17,
      isEnabled: !isLoading,
      isLoading: isLoading,
      onPressed: onPressed,
    );
  }
}

class _SearchCreditCard extends StatelessWidget {
  const _SearchCreditCard({required this.searchCredit});

  final SearchCredit searchCredit;

  String get _title {
    if (searchCredit.isExhausted) {
      return 'Keine Anfragen verfügbar';
    }

    if (searchCredit.hasFreeRemaining) {
      return 'Monatliche Anfragen';
    }

    return 'Credits verfügbar';
  }

  String get _description {
    if (searchCredit.hasFreeRemaining) {
      return '${searchCredit.freeRemainingThisMonth} von ${searchCredit.freeMonthlyLimit} kostenlosen Anfragen in diesem Monat verfügbar.';
    }

    if (searchCredit.hasPaidRemaining) {
      return '${searchCredit.availablePaidCredits} Credits verfügbar. Jede verwertbare Anfrage verbraucht 1 Credit.';
    }

    return 'Deine kostenlosen Anfragen sind aufgebraucht. Credits kaufen wird später freigeschaltet.';
  }

  IconData get _icon {
    if (searchCredit.isExhausted) {
      return Icons.lock_outline_rounded;
    }

    if (searchCredit.hasPaidRemaining && !searchCredit.hasFreeRemaining) {
      return Icons.toll_rounded;
    }

    return Icons.search_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_carmaBlueDark, _carmaBlue, _carmaBlueLight],
              ),
            ),
            child: Icon(_icon, color: Colors.white, size: 23),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.70),
                    fontWeight: FontWeight.w700,
                    height: 1.3,
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
    return CarmaPrimaryButton(
      label: 'Anfrage prüfen',
      loadingLabel: 'Prüfung läuft...',
      icon: Icons.search_rounded,
      iconSize: 29,
      fontSize: 19.5,
      isEnabled: isEnabled,
      isLoading: isLoading,
      onPressed: onPressed,
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
                  colors: [_carmaBlueDark, _carmaBlueLight],
                ),
              ),
              child: const Icon(Icons.search_off_rounded, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Kein Nutzer in deiner Nähe gefunden. Dafür wurde keine Anfrage verbraucht.',
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
                    colors: [_carmaBlueDark, _carmaBlue, _carmaBlueLight],
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
          const _ResultInfoRow(label: 'Status', value: 'Aktiv in deiner Nähe'),
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
                isLoading ? 'Anfrage läuft...' : 'Kontakt anfragen',
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
  const _ResultInfoRow({required this.label, required this.value});

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
