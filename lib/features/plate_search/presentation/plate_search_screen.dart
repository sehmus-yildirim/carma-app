import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../../../shared/models/search_credit.dart';
import '../../../shared/plate/plate_country_config.dart';
import '../../../shared/plate/plate_speech_parser.dart';
import '../../../shared/theme/carisma_design_tokens.dart';
import '../../../shared/widgets/carisma_background.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../auth/data/search_credit_repository.dart';
import '../../settings/data/user_settings_repository.dart';
import '../../chats/presentation/chats_screen.dart';
import '../data/plate_search_result.dart';
import '../data/plate_search_service.dart';
import '../data/plate_speech_bridge.dart';

class PlateSearchScreen extends StatefulWidget {
  const PlateSearchScreen({super.key});

  @override
  State<PlateSearchScreen> createState() => _PlateSearchScreenState();
}

class _PlateSearchScreenState extends State<PlateSearchScreen> {
  final PlateSearchService _service = PlateSearchService();
  final PlateSpeechBridge _speechBridge = PlateSpeechBridge();
  final SearchCreditRepository _searchCreditRepository =
      SearchCreditRepository();
  final UserSettingsRepository _userSettingsRepository =
      UserSettingsRepository();
  final TextEditingController _regionController = TextEditingController();
  final TextEditingController _lettersController = TextEditingController();
  final TextEditingController _numbersController = TextEditingController();
  final FocusNode _regionFocusNode = FocusNode();
  final FocusNode _lettersFocusNode = FocusNode();
  final FocusNode _numbersFocusNode = FocusNode();

  String _countryCode = 'DE';
  int _radiusKm = 5;

  Position? _position;
  bool _isLoadingLocation = true;
  bool _isLoadingSearchCredit = true;
  bool _isSearching = false;
  bool _isRequestingContact = false;
  bool _isListeningPlateSpeech = false;

  String? _locationError;
  String? _searchCreditError;
  String? _errorMessage;
  String? _successMessage;

  SearchCredit? _searchCredit;
  PlateSearchResult? _result;
  StreamSubscription<SearchCredit?>? _searchCreditSubscription;

  PlateCountryConfig get _plateConfig => plateConfigForCountry(_countryCode);

  String get _plateValue {
    return buildPlateValue(
      countryCode: _countryCode,
      region: _regionController.text,
      letters: _lettersController.text,
      numbers: _numbersController.text,
    );
  }

  bool get _isPlateComplete {
    final config = _plateConfig;
    final region = _regionController.text.trim();
    final letters = _lettersController.text.trim();
    final numbers = _numbersController.text.trim();

    return region.isNotEmpty &&
        numbers.isNotEmpty &&
        (!config.usesLettersField || letters.isNotEmpty);
  }

  bool get _isDemoPlateInput {
    final directPlateKey = <String>[
      _regionController.text,
      _lettersController.text,
      _numbersController.text,
    ].join().toUpperCase().replaceAll(RegExp(r'[^A-ZÄÖÜ0-9]'), '');

    return PlateSearchService.isDemoPlate(
      countryCode: _countryCode,
      plateKey: directPlateKey,
    );
  }

  bool get _canSearch {
    if (_isSearching) {
      return false;
    }

    if (_isDemoPlateInput) {
      return true;
    }

    if (!_isPlateComplete) {
      return false;
    }

    return _position != null && !_isLoadingLocation && _hasSearchCredit;
  }

  bool get _hasSearchCredit => _searchCredit?.hasRemaining ?? false;

  @override
  void initState() {
    super.initState();
    _regionController.addListener(_handlePlateInputChanged);
    _lettersController.addListener(_handlePlateInputChanged);
    _numbersController.addListener(_handlePlateInputChanged);
    _loadLocation();
    _loadDefaultPlateCountry();
    _watchSearchCredit();
  }

  @override
  void dispose() {
    unawaited(_searchCreditSubscription?.cancel());
    _regionController.dispose();
    _lettersController.dispose();
    _numbersController.dispose();
    _regionFocusNode.dispose();
    _lettersFocusNode.dispose();
    _numbersFocusNode.dispose();
    super.dispose();
  }

  void _handlePlateInputChanged() {
    setState(_clearSearchOutcome);
  }

  Future<void> _loadDefaultPlateCountry() async {
    final userId = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';

    if (userId.isEmpty) {
      return;
    }

    try {
      final settings = await _userSettingsRepository.load(userId);
      final defaultCountry = settings.appPreferences.defaultPlateCountry
          .trim()
          .toUpperCase();

      if (!mounted ||
          defaultCountry.isEmpty ||
          defaultCountry == _countryCode ||
          !const <String>{'DE', 'AT', 'CH'}.contains(defaultCountry)) {
        return;
      }

      setState(() {
        _countryCode = defaultCountry;
        _regionController.clear();
        _lettersController.clear();
        _numbersController.clear();
        _clearSearchOutcome();
      });
    } catch (_) {
      // App preferences are comfort settings and must not block search.
    }
  }

  void _clearSearchOutcome() {
    _result = null;
    _errorMessage = null;
    _successMessage = null;
    _isRequestingContact = false;
  }

  void _handleRegionChanged(String value) {
    if (value.length >= _plateConfig.regionMaxLength) {
      if (_plateConfig.usesLettersField) {
        _lettersFocusNode.requestFocus();
      } else {
        _numbersFocusNode.requestFocus();
      }
    }
  }

  void _watchSearchCredit() {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null || userId.trim().isEmpty) {
      setState(() {
        _searchCredit = null;
        _isLoadingSearchCredit = false;
        _searchCreditError = 'Bitte melde dich an, um suchen zu können.';
      });
      return;
    }

    _searchCreditSubscription = _searchCreditRepository
        .watchSearchCredit(userId: userId)
        .listen(
          (credit) {
            if (!mounted) return;

            final normalized =
                credit?.normalizeForCurrentMonth() ??
                SearchCredit.freeDefault(userId: userId);

            setState(() {
              _searchCredit = normalized;
              _isLoadingSearchCredit = false;
              _searchCreditError = null;

              if (!normalized.hasRemaining) {
                _clearSearchOutcome();
              }
            });
          },
          onError: (_) {
            if (!mounted) return;

            setState(() {
              _searchCredit = null;
              _isLoadingSearchCredit = false;
              _searchCreditError =
                  'Suchlimit konnte nicht geladen werden. Bitte versuche es erneut.';
            });
          },
        );

    unawaited(
      _searchCreditRepository.createSearchCreditIfMissing(userId: userId),
    );
  }

  void _handleLettersChanged(String value) {
    if (value.length >= _plateConfig.lettersMaxLength) {
      _numbersFocusNode.requestFocus();
    }
  }

  void _handleNumbersChanged(String value) {
    if (value.length >= _plateConfig.numbersMaxLength) {
      _numbersFocusNode.unfocus();
    }
  }

  void _handleCountryChanged(String countryCode) {
    setState(() {
      _countryCode = countryCode;
      _regionController.clear();
      _lettersController.clear();
      _numbersController.clear();
      _clearSearchOutcome();
    });
    _regionFocusNode.requestFocus();
  }

  Future<void> _startPlateSpeechInput() async {
    if (_isListeningPlateSpeech) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isListeningPlateSpeech = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final speechResult = await _speechBridge.recognizePlateSpeech();

      if (!mounted) {
        return;
      }

      if (speechResult == null) {
        setState(() {
          _isListeningPlateSpeech = false;
          _errorMessage =
              'Ich konnte kein Kennzeichen erkennen. Bitte sprich Stadt, Buchstaben und Zahlen deutlich einzeln.';
        });
        return;
      }

      final candidates = <String>[
        speechResult.transcript,
        ...speechResult.alternatives,
      ].where((value) => value.trim().isNotEmpty).toList(growable: false);

      final parsed = _bestSpeechParseResult(candidates);

      if (parsed == null || !parsed.hasAnyValue) {
        setState(() {
          _isListeningPlateSpeech = false;
          _errorMessage =
              'Ich konnte kein Kennzeichen erkennen. Bitte versuche es noch einmal.';
        });
        return;
      }

      _regionController.text = parsed.region;
      _lettersController.text = parsed.letters;
      _numbersController.text = parsed.numbers;

      setState(() {
        _isListeningPlateSpeech = false;
        _clearSearchOutcome();
      });

      if (!_isPlateComplete) {
        if (_regionController.text.isEmpty) {
          _regionFocusNode.requestFocus();
        } else if (_plateConfig.usesLettersField &&
            _lettersController.text.isEmpty) {
          _lettersFocusNode.requestFocus();
        } else if (_numbersController.text.isEmpty) {
          _numbersFocusNode.requestFocus();
        }
      }
    } on PlatformException catch (error) {
      if (!mounted) return;

      setState(() {
        _isListeningPlateSpeech = false;
        _errorMessage = error.code == 'permission-denied'
            ? 'Bitte erlaube den Mikrofonzugriff, um Kennzeichen per Sprache einzugeben.'
            : 'Spracheingabe konnte nicht gestartet werden. Bitte versuche es erneut.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isListeningPlateSpeech = false;
        _errorMessage =
            'Spracheingabe konnte nicht ausgewertet werden. Bitte versuche es erneut.';
      });
    }
  }

  PlateSpeechParseResult? _bestSpeechParseResult(List<String> candidates) {
    PlateSpeechParseResult? bestResult;
    var bestScore = -1;

    for (final candidate in candidates) {
      final parsed = parseSpokenPlateInput(
        countryCode: _countryCode,
        transcript: candidate,
        currentRegion: _regionController.text,
        currentLetters: _lettersController.text,
        currentNumbers: _numbersController.text,
      );
      final score = _scoreSpeechParseResult(parsed);

      if (score > bestScore) {
        bestScore = score;
        bestResult = parsed;
      }
    }

    return bestResult;
  }

  int _scoreSpeechParseResult(PlateSpeechParseResult result) {
    var score = 0;

    if (result.region.isNotEmpty) score += 3;
    if (!_plateConfig.usesLettersField || result.letters.isNotEmpty) score += 3;
    if (result.numbers.isNotEmpty) score += 4;

    if (result.region.length <= _plateConfig.regionMaxLength) score += 1;
    if (result.letters.length <= _plateConfig.lettersMaxLength) score += 1;
    if (result.numbers.length <= _plateConfig.numbersMaxLength) score += 1;

    final isComplete =
        result.region.isNotEmpty &&
        result.numbers.isNotEmpty &&
        (!_plateConfig.usesLettersField || result.letters.isNotEmpty);

    if (isComplete) score += 20;

    return score;
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
    final isDemoSearch = _isDemoPlateInput;

    if (!_canSearch || (!isDemoSearch && position == null)) {
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
      final result = kDebugMode && isDemoSearch
          ? PlateSearchService.demoSearchResult
          : await _service.searchPlate(
              countryCode: _countryCode,
              plate: _plateValue,
              latitude: position?.latitude ?? 0,
              longitude: position?.longitude ?? 0,
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

    final isDemoTarget = PlateSearchService.isDemoTarget(result.targetUid);

    if (!_hasSearchCredit && !isDemoTarget) {
      setState(() {
        _errorMessage = 'Du hast aktuell keine monatlichen Anfragen mehr.';
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _isRequestingContact = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final request = await _service.requestPlateContact(
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

      setState(() {
        _successMessage = null;
        _isRequestingContact = false;
      });

      final chatId = request.chatId.trim();
      final isDemoChat = PlateSearchService.isDemoChat(chatId);

      if (chatId.isEmpty && !isDemoChat) {
        setState(() {
          _errorMessage =
              'Der Chat konnte nicht geöffnet werden. Bitte öffne ihn im Chat-Bereich.';
        });
        return;
      }

      if (!mounted) {
        return;
      }

      await Navigator.of(context).push(
        buildChatConversationRoute(
          chatId: isDemoChat ? '' : chatId,
          displayName: result.displayName ?? 'CaRisma Nutzer',
          profilePhotoUrl: result.profilePhotoUrl,
          vehicleModel: result.vehicleLabel?.trim().isNotEmpty == true
              ? result.vehicleLabel!.trim()
              : result.vehicleModel?.trim().isNotEmpty == true
              ? result.vehicleModel!.trim()
              : 'Fahrzeug',
          vehicleColor: result.vehicleColor ?? '',
          displayPlate: result.displayPlate,
        ),
      );
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
    return CaRismaBackground(
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
                  regionController: _regionController,
                  lettersController: _lettersController,
                  numbersController: _numbersController,
                  regionFocusNode: _regionFocusNode,
                  lettersFocusNode: _lettersFocusNode,
                  numbersFocusNode: _numbersFocusNode,
                  countryCode: _countryCode,
                  config: _plateConfig,
                  radiusKm: _radiusKm,
                  isLoadingLocation: _isLoadingLocation,
                  locationError: _locationError,
                  searchCredit: _searchCredit,
                  isLoadingSearchCredit: _isLoadingSearchCredit,
                  searchCreditError: _searchCreditError,
                  isListeningPlateSpeech: _isListeningPlateSpeech,
                  onCountryChanged: (value) {
                    if (value == null) return;
                    _handleCountryChanged(value);
                  },
                  onRegionChanged: _handleRegionChanged,
                  onLettersChanged: _handleLettersChanged,
                  onNumbersChanged: _handleNumbersChanged,
                  onPlateSpeechInput: _startPlateSpeechInput,
                  onRadiusChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _radiusKm = value;
                      _clearSearchOutcome();
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
                if (_result == null) ...[
                  _PlateSearchButton(
                    label:
                        !_hasSearchCredit &&
                            !_isLoadingSearchCredit &&
                            !_isDemoPlateInput
                        ? 'Keine Anfragen verfügbar'
                        : _isSearching
                        ? 'Suche läuft...'
                        : 'Anfrage prüfen',
                    icon: Icons.search_rounded,
                    onPressed: _canSearch ? _search : null,
                  ),
                  const SizedBox(height: 22),
                ],
                if (_isSearching)
                  const _LoadingCard()
                else if (_result != null)
                  _ResultCard(
                    result: _result!,
                    canRequestContact:
                        _hasSearchCredit ||
                        PlateSearchService.isDemoTarget(_result!.targetUid),
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
  const _UpperCasePlateFormatter({this.allowDigits = true});

  final bool allowDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final pattern = allowDigits ? r'[^A-ZÄÖÜ0-9]' : r'[^A-ZÄÖÜ]';
    final normalized = newValue.text.toUpperCase().replaceAll(
      RegExp(pattern),
      '',
    );

    return TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
  }
}

class _PlateSegmentFields extends StatelessWidget {
  const _PlateSegmentFields({
    required this.config,
    required this.regionController,
    required this.lettersController,
    required this.numbersController,
    required this.regionFocusNode,
    required this.lettersFocusNode,
    required this.numbersFocusNode,
    required this.onRegionChanged,
    required this.onLettersChanged,
    required this.onNumbersChanged,
    required this.inputDecorationBuilder,
  });

  final PlateCountryConfig config;
  final TextEditingController regionController;
  final TextEditingController lettersController;
  final TextEditingController numbersController;
  final FocusNode regionFocusNode;
  final FocusNode lettersFocusNode;
  final FocusNode numbersFocusNode;
  final ValueChanged<String> onRegionChanged;
  final ValueChanged<String> onLettersChanged;
  final ValueChanged<String> onNumbersChanged;
  final InputDecoration Function({
    required String label,
    required String hint,
    required IconData icon,
  })
  inputDecorationBuilder;

  @override
  Widget build(BuildContext context) {
    final fields = <Widget>[
      Expanded(
        child: _PlateSegmentTextField(
          controller: regionController,
          focusNode: regionFocusNode,
          label: config.regionLabel,
          hint: config.countryCode == 'DE' ? 'HH' : 'ZH',
          maxLength: config.regionMaxLength,
          textInputAction: config.usesLettersField
              ? TextInputAction.next
              : TextInputAction.done,
          allowDigits: false,
          onChanged: onRegionChanged,
          decoration: inputDecorationBuilder(
            label: config.regionLabel,
            hint: config.countryCode == 'DE' ? 'HH' : 'ZH',
            icon: Icons.location_city_outlined,
          ),
        ),
      ),
      if (config.usesLettersField) ...[
        const SizedBox(width: 10),
        Expanded(
          child: _PlateSegmentTextField(
            controller: lettersController,
            focusNode: lettersFocusNode,
            label: 'Buchstaben',
            hint: 'SY',
            maxLength: config.lettersMaxLength,
            textInputAction: TextInputAction.next,
            allowDigits: false,
            onChanged: onLettersChanged,
            decoration: inputDecorationBuilder(
              label: 'Buchstaben',
              hint: 'SY',
              icon: Icons.text_fields_rounded,
            ),
          ),
        ),
      ],
      const SizedBox(width: 10),
      Expanded(
        child: _PlateSegmentTextField(
          controller: numbersController,
          focusNode: numbersFocusNode,
          label: 'Zahlen',
          hint: '4700',
          maxLength: config.numbersMaxLength,
          textInputAction: TextInputAction.done,
          allowDigits: true,
          onChanged: onNumbersChanged,
          decoration: inputDecorationBuilder(
            label: 'Zahlen',
            hint: '4700',
            icon: Icons.pin_rounded,
          ),
        ),
      ),
    ];

    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: fields);
  }
}

class _PlateSegmentTextField extends StatelessWidget {
  const _PlateSegmentTextField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.hint,
    required this.maxLength,
    required this.textInputAction,
    required this.allowDigits,
    required this.onChanged,
    required this.decoration,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final String hint;
  final int maxLength;
  final TextInputAction textInputAction;
  final bool allowDigits;
  final ValueChanged<String> onChanged;
  final InputDecoration decoration;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      maxLength: maxLength,
      inputFormatters: [_UpperCasePlateFormatter(allowDigits: allowDigits)],
      textInputAction: textInputAction,
      textCapitalization: TextCapitalization.characters,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.1,
      ),
      decoration: decoration.copyWith(counterText: ''),
      onChanged: onChanged,
    );
  }
}

class _PlateSpeechInputButton extends StatelessWidget {
  const _PlateSpeechInputButton({
    required this.isListening,
    required this.onPressed,
  });

  final bool isListening;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isListening ? null : onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isListening)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                const Icon(
                  Icons.mic_none_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  isListening
                      ? 'Kennzeichen wird erkannt...'
                      : 'Kennzeichen sprechen',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
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
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
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
    required this.regionController,
    required this.lettersController,
    required this.numbersController,
    required this.regionFocusNode,
    required this.lettersFocusNode,
    required this.numbersFocusNode,
    required this.countryCode,
    required this.config,
    required this.radiusKm,
    required this.isLoadingLocation,
    required this.locationError,
    required this.searchCredit,
    required this.isLoadingSearchCredit,
    required this.searchCreditError,
    required this.isListeningPlateSpeech,
    required this.onCountryChanged,
    required this.onRegionChanged,
    required this.onLettersChanged,
    required this.onNumbersChanged,
    required this.onPlateSpeechInput,
    required this.onRadiusChanged,
    required this.onRetryLocation,
  });

  final TextEditingController regionController;
  final TextEditingController lettersController;
  final TextEditingController numbersController;
  final FocusNode regionFocusNode;
  final FocusNode lettersFocusNode;
  final FocusNode numbersFocusNode;
  final String countryCode;
  final PlateCountryConfig config;
  final int radiusKm;
  final bool isLoadingLocation;
  final String? locationError;
  final SearchCredit? searchCredit;
  final bool isLoadingSearchCredit;
  final String? searchCreditError;
  final bool isListeningPlateSpeech;
  final ValueChanged<String?> onCountryChanged;
  final ValueChanged<String> onRegionChanged;
  final ValueChanged<String> onLettersChanged;
  final ValueChanged<String> onNumbersChanged;
  final VoidCallback onPlateSpeechInput;
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
          _SearchCreditStatus(
            searchCredit: searchCredit,
            isLoading: isLoadingSearchCredit,
            errorMessage: searchCreditError,
          ),
          const SizedBox(height: 16),
          _PlateSegmentFields(
            config: config,
            regionController: regionController,
            lettersController: lettersController,
            numbersController: numbersController,
            regionFocusNode: regionFocusNode,
            lettersFocusNode: lettersFocusNode,
            numbersFocusNode: numbersFocusNode,
            onRegionChanged: onRegionChanged,
            onLettersChanged: onLettersChanged,
            onNumbersChanged: onNumbersChanged,
            inputDecorationBuilder: _inputDecoration,
          ),
          const SizedBox(height: 12),
          _PlateSpeechInputButton(
            isListening: isListeningPlateSpeech,
            onPressed: onPlateSpeechInput,
          ),
          const SizedBox(height: 10),
          Text(
            formatDisplayPlate(
              countryCode: countryCode,
              region: regionController.text,
              letters: lettersController.text,
              numbers: numbersController.text,
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.54),
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: countryCode,
            dropdownColor: CaRismaDesignTokens.controlSurface,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration(
              label: 'Land',
              hint: 'Land auswählen',
              icon: Icons.flag_outlined,
            ),
            items: const [
              DropdownMenuItem(value: 'DE', child: Text('Deutschland 🇩🇪')),
              DropdownMenuItem(value: 'AT', child: Text('Österreich 🇦🇹')),
              DropdownMenuItem(value: 'CH', child: Text('Schweiz 🇨🇭')),
            ],
            onChanged: onCountryChanged,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<int>(
            initialValue: radiusKm,
            dropdownColor: CaRismaDesignTokens.controlSurface,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration(
              label: 'Radius',
              hint: 'Radius auswählen',
              icon: Icons.radar_rounded,
            ),
            items: const [
              DropdownMenuItem(value: 1, child: Text('1 km')),
              DropdownMenuItem(value: 5, child: Text('5 km')),
              DropdownMenuItem(value: 10, child: Text('10 km')),
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
      fillColor: CaRismaDesignTokens.controlSurface,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.46)),
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
          Expanded(
            child: Text(
              'Standort wird abgefragt...',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
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
            style: TextButton.styleFrom(foregroundColor: Colors.white),
          ),
        ],
      );
    }

    return Row(
      children: [
        const Icon(Icons.my_location_rounded, color: Colors.white, size: 18),
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

class _SearchCreditStatus extends StatelessWidget {
  const _SearchCreditStatus({
    required this.searchCredit,
    required this.isLoading,
    required this.errorMessage,
  });

  final SearchCredit? searchCredit;
  final bool isLoading;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final remaining = searchCredit?.remaining ?? 0;
    final limit = searchCredit?.freeMonthlyLimit ?? 2;
    final hasRemaining = searchCredit?.hasRemaining ?? false;
    final statusColor = hasRemaining
        ? const Color(0xFF22C55E)
        : const Color(0xFFEF4444);
    final title = isLoading
        ? 'Anfragen werden geladen'
        : '$remaining von $limit monatliche Anfragen';
    final subtitle =
        errorMessage ??
        (hasRemaining
            ? 'Die nächste Anfrage ist verfügbar.'
            : 'Keine verfügbaren Anfragen mehr.');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withValues(alpha: 0.1),
            ),
            child: const Icon(Icons.search_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.68),
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (isLoading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          else
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor,
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withValues(alpha: 0.36),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.result,
    required this.canRequestContact,
    required this.isRequestingContact,
    required this.onRequestContact,
  });

  final PlateSearchResult result;
  final bool canRequestContact;
  final bool isRequestingContact;
  final VoidCallback onRequestContact;

  @override
  Widget build(BuildContext context) {
    if (!result.found) {
      return GlassCard(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.search_off_rounded, color: Colors.white, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Kein aktiver Nutzer innerhalb von 5 km gefunden. Der Standort muss innerhalb der letzten Stunde aktualisiert worden sein.',
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
                child: const Icon(Icons.person_rounded, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.displayName ?? 'CaRisma Nutzer',
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
            label: !canRequestContact
                ? 'Keine Anfragen verfügbar'
                : isRequestingContact
                ? 'Anfrage wird gesendet...'
                : 'Kontakt anfragen',
            icon: Icons.mark_chat_unread_outlined,
            onPressed: isRequestingContact || !canRequestContact
                ? null
                : onRequestContact,
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
  const _MessageCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white),
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
              border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
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
                Icon(icon, color: Colors.white, size: 21),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
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
