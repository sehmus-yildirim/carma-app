import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../shared/config/carisma_app_config.dart';
import '../../../shared/domain/app_feature_gate.dart';
import '../../../shared/firebase/carisma_firestore_schema.dart';
import '../../../shared/models/carisma_models.dart';
import '../../../shared/plate/dach_plate_presentation.dart';
import '../../../shared/plate/plate_country_config.dart';
import '../../../shared/widgets/carisma_background.dart';
import '../../../shared/widgets/carisma_blue_icon_box.dart';
import '../../../shared/widgets/carisma_country_selector_card.dart';
import '../../../shared/widgets/carisma_message_card.dart';
import '../../../shared/widgets/carisma_premium_license_plate_card.dart';
import '../../../shared/widgets/carisma_primary_button.dart';
import '../../../shared/widgets/carisma_region_identity_card.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/theme/carisma_design_tokens.dart';
import '../../auth/data/search_credit_repository.dart';
import '../../profile/data/plate_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/data/user_profile.dart' as firestore_profile;
import '../../plate_search/data/plate_search_result.dart';
import '../../plate_search/data/plate_search_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.userState, this.onOpenChats});

  final AppUserState userState;
  final VoidCallback? onOpenChats;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final PlateSearchService _plateSearchService = PlateSearchService();
  final SearchCreditRepository _searchCreditRepository =
      SearchCreditRepository();
  final ProfileRepository _profileRepository = ProfileRepository();
  final PlateRepository _plateRepository = PlateRepository();

  final TextEditingController _regionController = TextEditingController();
  final TextEditingController _lettersController = TextEditingController();
  final TextEditingController _numbersController = TextEditingController();

  final FocusNode _regionFocusNode = FocusNode();
  final FocusNode _lettersFocusNode = FocusNode();
  final FocusNode _numbersFocusNode = FocusNode();

  StreamSubscription<SearchCredit?>? _searchCreditSubscription;

  String _countryCode = 'DE';

  Position? _position;
  PlateSearchResult? _result;
  PlateContactRequestState? _requestState;

  late SearchCredit _searchCredit;

  bool _isLoadingLocation = true;
  bool _isLoadingSearchCredit = true;
  bool _isSearching = false;
  bool _isRequestingContact = false;

  String? _locationError;
  String? _creditError;
  String? _errorMessage;
  String? _successMessage;

  String get _effectiveUserId {
    return FirebaseAuth.instance.currentUser?.uid ?? widget.userState.userId;
  }

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
    return widget.userState.copyWith(
      userId: _effectiveUserId,
      searchCredit: _searchCredit,
    );
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

  CaRismaPlate get _currentPlate {
    return CaRismaPlate(
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

    _watchSearchCredit();
    _loadLocation();
  }

  @override
  void dispose() {
    _searchCreditSubscription?.cancel();

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

  void _watchSearchCredit() {
    final userId = _effectiveUserId;

    if (userId.trim().isEmpty) {
      setState(() {
        _isLoadingSearchCredit = false;
        _creditError =
            'Credit-Stand konnte nicht geladen werden, weil kein Nutzer angemeldet ist.';
      });
      return;
    }

    _searchCreditSubscription?.cancel();

    setState(() {
      _isLoadingSearchCredit = true;
      _creditError = null;
    });

    _searchCreditSubscription = _searchCreditRepository
        .watchSearchCredit(userId: userId)
        .listen(
          (searchCredit) {
            if (searchCredit == null) {
              _searchCreditRepository.createSearchCreditIfMissing(
                userId: userId,
              );
            }

            if (!mounted) {
              return;
            }

            setState(() {
              _searchCredit =
                  searchCredit ?? SearchCredit.freeDefault(userId: userId);

              _isLoadingSearchCredit = false;
              _creditError = null;
            });
          },
          onError: (_) {
            if (!mounted) {
              return;
            }

            setState(() {
              _isLoadingSearchCredit = false;
              _creditError =
                  'Credit-Stand konnte nicht aus Firestore geladen werden.';
            });
          },
        );
  }

  void _clearResultMessages() {
    _result = null;
    _requestState = null;
    _errorMessage = null;
    _successMessage = null;
  }

  void _clearResultMessagesAfterInputChange() {
    if (_result == null &&
        _requestState == null &&
        _errorMessage == null &&
        _successMessage == null) {
      return;
    }

    setState(_clearResultMessages);
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
    FocusScope.of(context).unfocus();
  }

  Future<void> _openRegionPicker() async {
    FocusScope.of(context).unfocus();
    final selectedRegion =
        await showModalBottomSheet<RegistrationRegionPresentationData>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          barrierColor: Colors.black.withValues(alpha: 0.72),
          builder: (sheetContext) => _RegistrationRegionPickerSheet(
            countryCode: _countryCode,
            regions: registrationRegionsForCountry(_countryCode),
          ),
        );

    if (!mounted || selectedRegion == null) {
      return;
    }

    setState(() {
      _regionController.value = TextEditingValue(
        text: selectedRegion.plateCode,
        selection: TextSelection.collapsed(
          offset: selectedRegion.plateCode.length,
        ),
      );
      _clearResultMessages();
    });

    if (_countryCode == 'CH' || _countryCode == 'AT') {
      _numbersFocusNode.requestFocus();
    } else {
      _lettersFocusNode.requestFocus();
    }
  }

  Future<void> _syncOwnPlateLocation(Position position) async {
    final userId = _effectiveUserId.trim();

    if (userId.isEmpty) {
      return;
    }

    try {
      final profile = await _profileRepository.getProfile(userId);

      if (profile == null || !_hasRegisteredPlate(profile)) {
        return;
      }

      await _plateRepository.registerPlateForProfile(
        profile,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (_) {
      // Standort-Sync soll die Suche nicht blockieren.
    }
  }

  bool _hasRegisteredPlate(firestore_profile.UserProfile profile) {
    return (profile.countryCode ?? profile.country).trim().isNotEmpty &&
        (profile.plateRegion ?? '').trim().isNotEmpty &&
        (profile.plateNumbers ?? '').trim().isNotEmpty;
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
              'Standortdienste sind deaktiviert. Bitte aktiviere GPS auf deinem Ger\u00e4t.';
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
              'Standortberechtigung wurde verweigert. Die Suche ist ohne Standort nicht m\u00f6glich.';
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

      unawaited(_syncOwnPlateLocation(position));
    } on TimeoutException {
      if (!mounted) {
        return;
      }

      setState(() {
        _position = null;
        _locationError =
            'Standort l\u00e4dt zu lange. Bitte pr\u00fcfe GPS oder setze im Emulator einen Standort.';
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
            'Die Kennzeichen-Suche ist aktuell nicht verf\u00fcgbar.';
        _successMessage = null;
      });
      return;
    }

    if (!_hasPlateInput) {
      setState(() {
        _errorMessage = 'Bitte gib ein vollst\u00e4ndiges Kennzeichen ein.';
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
            'Bitte aktiviere den Standort, damit die Suche in deiner N\u00e4he m\u00f6glich ist.';
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
        radiusKm: CaRismaAppConfig.defaultSearchRadiusKm,
      );
      final requestState =
          result.found && result.targetUid != null && result.plateKey != null
          ? await _plateSearchService.loadExistingRequestState(
              targetUid: result.targetUid!,
              plateKey: result.plateKey!,
            )
          : null;

      if (!mounted) {
        return;
      }

      setState(() {
        _result = result;
        _requestState = requestState;
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
            'Kontaktanfragen sind aktuell nicht verf\u00fcgbar.';
        _successMessage = null;
      });
      return;
    }

    final result = _result;

    if (result == null || result.targetUid == null || result.plateKey == null) {
      return;
    }

    final existingRequestState = _requestState;

    if (existingRequestState?.canOpenChat == true) {
      setState(() {
        _errorMessage = null;
        _successMessage =
            'F\u00fcr dieses Kennzeichen gibt es bereits einen aktiven Chat. Du wirst jetzt weitergeleitet.';
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        widget.onOpenChats?.call();
      });
      return;
    }

    if (existingRequestState?.isOpen == true) {
      setState(() {
        _errorMessage = null;
        _successMessage = existingRequestState!.isAccepted
            ? 'F\u00fcr dieses Kennzeichen wurde die Anfrage bereits angenommen.'
            : 'F\u00fcr dieses Kennzeichen l\u00e4uft bereits eine Anfrage.';
      });
      return;
    }

    setState(() {
      _isRequestingContact = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await _searchCreditRepository.createSearchCreditIfMissing(
        userId: _effectiveUserId,
      );
      final requestId = await _plateSearchService.requestPlateContact(
        targetUid: result.targetUid!,
        plateKey: result.plateKey!,
        receiverDisplayName: result.displayName,
        receiverPhotoUrl: result.profilePhotoUrl,
        displayPlate: result.displayPlate,
        vehicleBrand: result.vehicleBrand,
        vehicleModel: result.vehicleModel,
        vehicleColor: result.vehicleColor,
        vehicleLabel: result.vehicleLabel,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _searchCredit = _searchCredit.consume();
        _requestState = PlateContactRequestState(
          status: FirestoreContactRequestStatus.pending,
          chatId: 'request_$requestId',
        );
        _successMessage =
            'Kontaktanfrage wurde gesendet. Du wirst jetzt zum Chat-Bereich weitergeleitet.';
        _isRequestingContact = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        widget.onOpenChats?.call();
      });
    } catch (error) {
      final requestState = error.toString().contains('already-exists')
          ? await _plateSearchService.loadExistingRequestState(
              targetUid: result.targetUid!,
              plateKey: result.plateKey!,
            )
          : _requestState;

      if (!mounted) {
        return;
      }

      final hasLinkedAcceptedRequest = requestState?.canOpenChat == true;

      setState(() {
        _requestState = requestState;
        _errorMessage = hasLinkedAcceptedRequest
            ? null
            : requestState?.isAccepted == true
            ? 'F\u00fcr dieses Kennzeichen wurde die Anfrage bereits angenommen.'
            : _mapFirebaseError(error);
        _successMessage = hasLinkedAcceptedRequest
            ? 'F\u00fcr dieses Kennzeichen gibt es bereits einen aktiven Chat. Du wirst jetzt weitergeleitet.'
            : null;
        _isRequestingContact = false;
      });

      if (hasLinkedAcceptedRequest) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }

          widget.onOpenChats?.call();
        });
      }
    }
  }

  String _mapFirebaseError(Object error) {
    final raw = error.toString();

    if (raw.contains('resource-exhausted')) {
      return 'Du hast keine kostenlosen Anfragen oder Credits mehr verf\u00fcgbar.';
    }

    if (raw.contains('unauthenticated')) {
      return 'Bitte melde dich an, um Kennzeichen suchen zu k\u00f6nnen.';
    }

    if (raw.contains('invalid-argument')) {
      return 'Bitte pr\u00fcfe deine Eingaben.';
    }

    if (raw.contains('permission-denied')) {
      return 'Diese Aktion ist nicht erlaubt.';
    }

    if (raw.contains('already-exists')) {
      return 'F\u00fcr diesen Treffer existiert bereits eine Anfrage.';
    }

    if (raw.contains('failed-precondition')) {
      return 'Die Anfrage konnte nicht vorbereitet werden. Bitte lade die Seite neu und versuche es erneut.';
    }

    if (raw.contains('unavailable') ||
        raw.contains('deadline-exceeded') ||
        raw.contains('network')) {
      return 'Die Verbindung ist gerade nicht verfügbar. Bitte prüfe dein Netzwerk und versuche es erneut.';
    }

    return 'Die Aktion konnte nicht abgeschlossen werden. Bitte versuche es erneut.';
  }

  void _handleRegionChanged(String value) {
    _clearResultMessagesAfterInputChange();

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
    _clearResultMessagesAfterInputChange();

    if (value.length >= _lettersMaxLength) {
      if (_countryCode == 'AT') {
        _lettersFocusNode.unfocus();
        return;
      }

      _numbersFocusNode.requestFocus();
    }
  }

  void _handleNumbersChanged(String value) {
    _clearResultMessagesAfterInputChange();

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
        requestState: _requestState,
        isRequestingContact: _isRequestingContact,
        onRequestContact: _requestContact,
        onOpenChats: widget.onOpenChats,
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final regionPresentation = registrationRegionPresentationFor(
      countryCode: _countryCode,
      plateCode: _regionController.text,
    );
    return CaRismaBackground(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth <= 380
                ? 14.0
                : constraints.maxWidth <= 480
                ? 16.0
                : 20.0;
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                8,
                horizontalPadding,
                112 + keyboardInset,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 112,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SearchCreditCard(
                      searchCredit: _searchCredit,
                      isLoading: _isLoadingSearchCredit,
                    ),
                    if (_creditError != null) ...[
                      const SizedBox(height: 8),
                      CaRismaMessageCard(
                        icon: Icons.cloud_off_rounded,
                        message: _creditError!,
                      ),
                    ],
                    const SizedBox(height: 10),
                    CaRismaCountrySelectorCard(
                      selectedCountryCode: _countryCode,
                      onChanged: _changeCountry,
                    ),
                    const SizedBox(height: 15),
                    CaRismaRegionIdentityCard(
                      region: regionPresentation,
                      onTap: _openRegionPicker,
                    ),
                    const SizedBox(height: 15),
                    CaRismaPremiumLicensePlateCard(
                      countryCode: _countryCode,
                      regionPresentation: regionPresentation,
                      regionController: _regionController,
                      lettersController: _lettersController,
                      numbersController: _numbersController,
                      regionFocusNode: _regionFocusNode,
                      lettersFocusNode: _lettersFocusNode,
                      numbersFocusNode: _numbersFocusNode,
                      onRegionChanged: _handleRegionChanged,
                      onLettersChanged: _handleLettersChanged,
                      onNumbersChanged: _handleNumbersChanged,
                      isSubmitEnabled: _canAttemptSearch,
                      isSubmitting: _isSearching,
                      onSubmit: _searchPlate,
                      showSubmit: _result == null,
                    ),
                    if (_isLoadingLocation) ...[
                      const SizedBox(height: 8),
                      const _LocationLoadingCard(),
                    ],
                    if (_locationError != null) ...[
                      const SizedBox(height: 8),
                      CaRismaMessageCard(
                        icon: Icons.location_off_rounded,
                        message: _locationError!,
                      ),
                      const SizedBox(height: 8),
                      _RetryLocationButton(
                        isLoading: _isLoadingLocation,
                        onPressed: _loadLocation,
                      ),
                    ],
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 8),
                      CaRismaMessageCard(
                        icon: Icons.error_outline_rounded,
                        message: _errorMessage!,
                      ),
                    ],
                    if (_successMessage != null) ...[
                      const SizedBox(height: 8),
                      CaRismaMessageCard(
                        icon: Icons.check_circle_outline_rounded,
                        message: _successMessage!,
                      ),
                    ],
                    const SizedBox(height: 10),
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
          const CaRismaBlueIconBox(
            icon: Icons.my_location_rounded,
            size: 42,
            iconSize: 22,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Standort wird geladen...',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w800,
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

class _RetryLocationButton extends StatelessWidget {
  const _RetryLocationButton({
    required this.isLoading,
    required this.onPressed,
  });

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CaRismaPrimaryButton(
      label: 'Standort erneut laden',
      loadingLabel: 'Standort l\u00e4dt...',
      icon: Icons.refresh_rounded,
      iconSize: 25,
      fontSize: 17,
      isEnabled: !isLoading,
      isLoading: isLoading,
      onPressed: onPressed,
    );
  }
}

class _RegistrationRegionPickerSheet extends StatefulWidget {
  const _RegistrationRegionPickerSheet({
    required this.countryCode,
    required this.regions,
  });

  final String countryCode;
  final List<RegistrationRegionPresentationData> regions;

  @override
  State<_RegistrationRegionPickerSheet> createState() =>
      _RegistrationRegionPickerSheetState();
}

class _RegistrationRegionPickerSheetState
    extends State<_RegistrationRegionPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<RegistrationRegionPresentationData> get _visibleRegions {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return widget.regions;
    }
    return widget.regions
        .where((region) {
          return region.plateCode.toLowerCase().contains(query) ||
              region.displayName.toLowerCase().contains(query) ||
              region.parentRegionName.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final regions = _visibleRegions;
    final country = countryPresentationFor(widget.countryCode);

    return FractionallySizedBox(
      heightFactor: 0.88,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CaRismaDesignTokens.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 28,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.24),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Zulassungsregion wählen',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          country.label,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: CaRismaDesignTokens.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: Colors.white,
                    tooltip: 'Schließen',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  hintText: 'Code oder Stadt suchen',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.46),
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: CaRismaDesignTokens.blueBright,
                  ),
                  filled: true,
                  fillColor: CaRismaDesignTokens.controlSurface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: CaRismaDesignTokens.blueBright,
                      width: 1.2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: regions.isEmpty
                  ? Center(
                      child: Text(
                        'Keine passende Zulassungsregion gefunden.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: CaRismaDesignTokens.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : ListView.separated(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 22),
                      itemCount: regions.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.065),
                      ),
                      itemBuilder: (context, index) {
                        final region = regions[index];
                        return Semantics(
                          button: true,
                          label: '${region.plateCode}, ${region.displayName}',
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => Navigator.of(context).pop(region),
                            child: Container(
                              decoration: BoxDecoration(
                                color: CaRismaDesignTokens.controlSurface,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 48,
                                    child: Text(
                                      region.plateCode,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: CaRismaDesignTokens.bluePrimary,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  SizedBox(
                                    width: 34,
                                    height: 34,
                                    child: region.usesFallback
                                        ? const Icon(
                                            Icons.shield_outlined,
                                            color:
                                                CaRismaDesignTokens.textMuted,
                                          )
                                        : Image.asset(
                                            region.regionCoatAsset,
                                            fit: BoxFit.contain,
                                            filterQuality: FilterQuality.high,
                                            errorBuilder: (_, _, _) =>
                                                const Icon(
                                                  Icons.shield_outlined,
                                                  color: CaRismaDesignTokens
                                                      .textMuted,
                                                ),
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          region.displayName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          region.parentRegionName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: CaRismaDesignTokens
                                                .textSecondary,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchCreditCard extends StatelessWidget {
  const _SearchCreditCard({
    required this.searchCredit,
    required this.isLoading,
  });

  final SearchCredit searchCredit;
  final bool isLoading;

  String get _headline {
    if (isLoading) {
      return 'Anfragen werden geladen...';
    }

    if (searchCredit.isUnlimited) {
      return 'Unbegrenzte monatliche Anfragen';
    }

    return '${searchCredit.freeRemainingThisMonth} von ${searchCredit.freeMonthlyLimit} monatliche Anfragen';
  }

  String get _subline {
    if (isLoading) {
      return 'Wir pr\u00fcfen dein Kontingent.';
    }

    if (searchCredit.isExhausted) {
      return 'Keine verf\u00fcgbare Suche mehr';
    }

    if (searchCredit.hasFreeRemaining) {
      return 'Die n\u00e4chste Suche ist kostenlos.';
    }

    if (searchCredit.hasPaidRemaining) {
      return 'Die n\u00e4chste Suche nutzt einen Credit.';
    }

    return 'Keine verf\u00fcgbare Suche mehr';
  }

  IconData get _icon {
    if (isLoading) {
      return Icons.sync_rounded;
    }

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
    final badgeColor = isLoading
        ? const Color(0xFF6F7A8A)
        : searchCredit.isExhausted
        ? const Color(0xFFFF4D4F)
        : searchCredit.hasFreeRemaining
        ? const Color(0xFF22C55E)
        : const Color(0xFFFBBF24);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: CaRismaDesignTokens.card,
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Icon(_icon, color: CaRismaDesignTokens.bluePrimary, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _headline,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _subline,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.58),
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: badgeColor,
              boxShadow: [
                BoxShadow(
                  color: badgeColor.withValues(alpha: 0.50),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchUserAvatar extends StatelessWidget {
  const _SearchUserAvatar({required this.size, required this.imageUrl});

  final double size;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.30;
    final url = imageUrl?.trim();
    final hasImage = url != null && url.isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: CaRismaDesignTokens.surface2,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.60),
            blurRadius: 12,
            offset: const Offset(4, 4),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.015),
            blurRadius: 8,
            offset: const Offset(-4, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 1),
        child: SizedBox(
          width: size,
          height: size,
          child: hasImage
              ? Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Icon(
                    Icons.person_rounded,
                    color: CaRismaDesignTokens.bluePrimary,
                    size: size * 0.56,
                  ),
                )
              : Icon(
                  Icons.person_rounded,
                  color: CaRismaDesignTokens.bluePrimary,
                  size: size * 0.56,
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
    required this.requestState,
    required this.isRequestingContact,
    required this.onRequestContact,
    this.onOpenChats,
  });

  final PlateSearchResult result;
  final String fallbackDisplayPlate;
  final PlateContactRequestState? requestState;
  final bool isRequestingContact;
  final VoidCallback onRequestContact;
  final VoidCallback? onOpenChats;

  @override
  Widget build(BuildContext context) {
    if (!result.found) {
      return GlassCard(
        key: const ValueKey('no_result'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const CaRismaBlueIconBox(
              icon: Icons.search_off_rounded,
              size: 44,
              iconSize: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Kein Nutzer in deiner N\u00e4he gefunden. Daf\u00fcr wurde keine Anfrage verbraucht.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GlassCard(
      key: const ValueKey('result'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _SearchUserAvatar(size: 48, imageUrl: result.profilePhotoUrl),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.vehicleTitle,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Nutzer in deiner N\u00e4he',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.56),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ResultInfoRow(
            label: 'Kennzeichen',
            value: fallbackDisplayPlate.isEmpty ? '-' : fallbackDisplayPlate,
          ),
          if (result.distanceKm != null) ...[
            const SizedBox(height: 8),
            _ResultInfoRow(
              label: 'Entfernung',
              value: '${result.distanceKm!.toStringAsFixed(1)} km',
            ),
          ],
          if (requestState != null) ...[
            const SizedBox(height: 12),
            _ExistingRequestInfo(requestState: requestState!),
          ],
          const SizedBox(height: 12),
          _RequestContactButton(
            label: requestState?.canOpenChat == true
                ? 'Zu Chats'
                : requestState?.isAccepted == true
                ? 'Bereits angenommen'
                : requestState?.isPending == true
                ? 'Anfrage l\u00e4uft'
                : 'Kontakt anfragen',
            icon: requestState?.canOpenChat == true
                ? Icons.chat_bubble_rounded
                : Icons.mail_outline_rounded,
            isEnabled: requestState == null || requestState!.canOpenChat,
            isLoading: isRequestingContact,
            onPressed: requestState?.canOpenChat == true
                ? (onOpenChats ?? () {})
                : onRequestContact,
          ),
        ],
      ),
    );
  }
}

class _RequestContactButton extends StatelessWidget {
  const _RequestContactButton({
    required this.label,
    required this.icon,
    required this.isEnabled,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool isEnabled;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CaRismaPrimaryButton(
      label: label,
      loadingLabel: 'Anfrage l\u00e4uft...',
      icon: icon,
      isEnabled: isEnabled,
      isLoading: isLoading,
      onPressed: onPressed,
    );
  }
}

class _ExistingRequestInfo extends StatelessWidget {
  const _ExistingRequestInfo({required this.requestState});

  final PlateContactRequestState requestState;

  @override
  Widget build(BuildContext context) {
    final label = requestState.canOpenChat
        ? 'F\u00fcr dieses Kennzeichen gibt es bereits einen aktiven Chat.'
        : requestState.isAccepted
        ? 'Diese Anfrage wurde bereits angenommen.'
        : 'F\u00fcr dieses Kennzeichen l\u00e4uft bereits eine Anfrage.';

    final icon = requestState.canOpenChat || requestState.isAccepted
        ? Icons.check_circle_outline_rounded
        : Icons.schedule_rounded;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: CaRismaDesignTokens.controlSurface,
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Icon(icon, color: CaRismaDesignTokens.bluePrimary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.78),
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
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
