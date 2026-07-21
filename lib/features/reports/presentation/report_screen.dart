import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/domain/app_feature_gate.dart';
import '../../../shared/models/carisma_models.dart';
import '../../../shared/plate/dach_plate_presentation.dart';
import '../../../shared/plate/plate_country_config.dart';
import '../../../shared/theme/carisma_design_tokens.dart';
import '../../../shared/widgets/carisma_background.dart';
import '../../../shared/widgets/carisma_blue_icon_box.dart';
import '../../../shared/widgets/carisma_country_selector_card.dart';
import '../../../shared/widgets/carisma_message_card.dart';
import '../../../shared/widgets/carisma_premium_license_plate_card.dart';
import '../../../shared/widgets/carisma_primary_button.dart';
import '../../../shared/widgets/carisma_region_identity_card.dart';
import '../../../shared/widgets/carisma_secondary_button.dart';
import '../../../shared/widgets/carisma_section_title.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../chats/data/chat_native_bridge.dart';
import '../data/report_repository.dart';
import '../domain/report_draft.dart';

enum _ReportCategory {
  vehicleOpen,
  lightsOrElectric,
  vehicleBlocked,
  visibleDamage,
  acuteDanger,
  policeOnSite,
}

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key, required this.userState});

  final AppUserState userState;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final ReportRepository _reportRepository = ReportRepository();
  final ChatNativeBridge _nativeBridge = ChatNativeBridge();

  final TextEditingController _regionController = TextEditingController();
  final TextEditingController _lettersController = TextEditingController();
  final TextEditingController _numbersController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  final FocusNode _regionFocusNode = FocusNode();
  final FocusNode _lettersFocusNode = FocusNode();
  final FocusNode _numbersFocusNode = FocusNode();

  late final Stream<List<ReportNotificationRecord>>
  _incomingReportNotifications;
  late final Stream<List<ReportNotificationRecord>> _sentReportNotifications;

  String _countryCode = 'DE';
  _ReportCategory? _selectedCategory;

  Position? _position;
  String? _gpsAddressLabel;
  XFile? _capturedPhoto;
  Timer? _successMessageTimer;

  bool _isLoadingLocation = false;
  bool _isSending = false;
  bool _useGpsLocation = true;

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

  AppFeatureDecision get _reportGateDecision {
    return AppFeatureGate.evaluate(
      userState: widget.userState,
      feature: AppFeature.anonymousReport,
    );
  }

  ReportDraftCategory? get _draftCategory {
    return switch (_selectedCategory) {
      _ReportCategory.vehicleOpen => ReportDraftCategory.vehicleOpen,
      _ReportCategory.lightsOrElectric => ReportDraftCategory.lightsOrElectric,
      _ReportCategory.vehicleBlocked => ReportDraftCategory.vehicleBlocked,
      _ReportCategory.visibleDamage => ReportDraftCategory.visibleDamage,
      _ReportCategory.acuteDanger => ReportDraftCategory.acuteDanger,
      _ReportCategory.policeOnSite => ReportDraftCategory.policeOnSite,
      null => null,
    };
  }

  ReportDraft get _reportDraft {
    return ReportDraft(
      senderUserId: widget.userState.userId,
      countryCode: _countryCode,
      region: _regionController.text.trim(),
      letters: _lettersController.text.trim(),
      numbers: _numbersController.text.trim(),
      category: _draftCategory,
      message: _noteController.text.trim(),
      useGpsLocation: _useGpsLocation,
      manualAddress: _addressController.text.trim(),
      latitude: _position?.latitude,
      longitude: _position?.longitude,
      gpsAddressLabel: _gpsAddressLabel,
      imageLocalPath: _capturedPhoto?.path,
    );
  }

  bool get _canSend {
    return _reportDraft.canSubmit &&
        _reportGateDecision.isAllowed &&
        !_isSending &&
        !_isLoadingLocation;
  }

  @override
  void initState() {
    super.initState();

    _regionController.addListener(_refresh);
    _lettersController.addListener(_refresh);
    _numbersController.addListener(_refresh);
    _addressController.addListener(_refresh);
    _noteController.addListener(_refresh);

    _incomingReportNotifications = _reportRepository.watchReportNotifications(
      userId: widget.userState.userId,
    );
    _sentReportNotifications = _reportRepository.watchSentReportNotifications(
      userId: widget.userState.userId,
    );

    _loadLocation();
  }

  @override
  void dispose() {
    _regionController.removeListener(_refresh);
    _lettersController.removeListener(_refresh);
    _numbersController.removeListener(_refresh);
    _addressController.removeListener(_refresh);
    _noteController.removeListener(_refresh);

    _regionController.dispose();
    _lettersController.dispose();
    _numbersController.dispose();
    _addressController.dispose();
    _noteController.dispose();

    _regionFocusNode.dispose();
    _lettersFocusNode.dispose();
    _numbersFocusNode.dispose();
    _successMessageTimer?.cancel();

    super.dispose();
  }

  void _refresh() {
    setState(() {});
  }

  void _clearMessages() {
    _successMessageTimer?.cancel();
    _errorMessage = null;
    _successMessage = null;
  }

  void _scheduleSuccessMessageClear() {
    _successMessageTimer?.cancel();
    _successMessageTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) {
        return;
      }

      setState(() {
        _successMessage = null;
      });
    });
  }

  void _selectCategory(_ReportCategory category) {
    setState(() {
      _selectedCategory = category;
      _clearMessages();
    });
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
      _clearMessages();
    });

    _regionFocusNode.requestFocus();
  }

  Future<void> _openRegionPicker() async {
    FocusScope.of(context).unfocus();
    final selectedRegion = await showCaRismaRegistrationRegionPicker(
      context,
      countryCode: _countryCode,
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
      _clearMessages();
    });

    if (_countryCode == 'CH' || _countryCode == 'AT') {
      _numbersFocusNode.requestFocus();
    } else {
      _lettersFocusNode.requestFocus();
    }
  }

  void _handleRegionChanged(String value) {
    _clearMessages();

    if (value.length >= _regionMaxLength) {
      if (_countryCode == 'CH' || _countryCode == 'AT') {
        _numbersFocusNode.requestFocus();
        return;
      }

      _lettersFocusNode.requestFocus();
    }
  }

  void _handleLettersChanged(String value) {
    _clearMessages();

    if (value.length >= _lettersMaxLength) {
      if (_countryCode == 'AT') {
        _lettersFocusNode.unfocus();
        return;
      }

      _numbersFocusNode.requestFocus();
    }
  }

  void _handleNumbersChanged(String value) {
    _clearMessages();

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

  Future<void> _loadLocation() async {
    if (_isLoadingLocation) {
      return;
    }

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
          _gpsAddressLabel = null;
          _locationError =
              'Standortdienste sind deaktiviert. Du kannst alternativ eine Adresse eingeben.';
          _isLoadingLocation = false;
          _useGpsLocation = false;
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
          _gpsAddressLabel = null;
          _locationError =
              'Standortberechtigung wurde verweigert. Du kannst alternativ eine Adresse eingeben.';
          _isLoadingLocation = false;
          _useGpsLocation = false;
        });
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) {
          return;
        }

        setState(() {
          _position = null;
          _gpsAddressLabel = null;
          _locationError =
              'Standortberechtigung wurde dauerhaft verweigert. Bitte nutze die manuelle Adresse.';
          _isLoadingLocation = false;
          _useGpsLocation = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 8));
      String? gpsAddressLabel;

      try {
        final places = await _nativeBridge
            .reverseGeocodeLocation(
              latitude: position.latitude,
              longitude: position.longitude,
            )
            .timeout(const Duration(seconds: 5));
        gpsAddressLabel = _bestGpsAddressLabel(places);
      } catch (_) {
        gpsAddressLabel = null;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _position = position;
        _gpsAddressLabel = gpsAddressLabel;
        _locationError = null;
        _isLoadingLocation = false;
        _useGpsLocation = true;
      });
    } on TimeoutException {
      if (!mounted) {
        return;
      }

      setState(() {
        _position = null;
        _gpsAddressLabel = null;
        _locationError =
            'Standort lädt zu lange. Bitte setze im Emulator einen Standort oder nutze die manuelle Adresse.';
        _isLoadingLocation = false;
        _useGpsLocation = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _position = null;
        _gpsAddressLabel = null;
        _locationError =
            'Standort konnte nicht geladen werden. Du kannst alternativ eine Adresse eingeben.';
        _isLoadingLocation = false;
        _useGpsLocation = false;
      });
    }
  }

  String? _bestGpsAddressLabel(List<ResolvedLocationPlace> places) {
    final labels = places
        .map(_formatGpsAddressLabel)
        .where((label) => label.isNotEmpty && !_looksLikeCoordinateLabel(label))
        .toList(growable: false);

    if (labels.isEmpty) {
      return null;
    }

    return labels.firstWhere(
      _looksLikeStreetAddressLabel,
      orElse: () => labels.first,
    );
  }

  String _formatGpsAddressLabel(ResolvedLocationPlace place) {
    final label = place.label.trim();
    if (label.isEmpty) {
      return label;
    }

    final parts = label
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    final city = place.city.trim();
    final streetIndex = parts.indexWhere(
      (part) => RegExp(
        r'\b(strasse|straße|str\.|weg|allee|platz|ring|damm|gasse|chaussee|ufer|markt)\b',
        caseSensitive: false,
      ).hasMatch(part),
    );
    final houseNumberIndex = parts.indexWhere(
      (part) => RegExp(r'^\d+[a-zA-Z]?$').hasMatch(part),
    );

    if (streetIndex == -1) {
      return label;
    }

    var streetLine = parts[streetIndex];
    if (houseNumberIndex != -1 && houseNumberIndex != streetIndex) {
      final houseNumber = parts[houseNumberIndex];
      if (!streetLine.contains(houseNumber)) {
        streetLine = '$streetLine $houseNumber';
      }
    }

    final location = city.isNotEmpty
        ? city
        : place.region.trim().isNotEmpty
        ? place.region.trim()
        : null;
    return [streetLine, ?location].join(', ');
  }

  bool _looksLikeStreetAddressLabel(String label) {
    final hasNumber = RegExp(r'\d').hasMatch(label);
    final hasStreetHint = RegExp(
      r'\b(strasse|straße|str\.|weg|allee|platz|ring|damm|gasse|chaussee|ufer|markt)\b',
      caseSensitive: false,
    ).hasMatch(label);

    return hasNumber && (hasStreetHint || label.contains(','));
  }

  bool _looksLikeCoordinateLabel(String label) {
    return RegExp(
      r'^-?\d{1,3}([.,]\d+)?\s*,\s*-?\d{1,3}([.,]\d+)?$',
    ).hasMatch(label.trim());
  }

  Future<void> _takePhoto() async {
    _clearMessages();

    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 82,
        maxWidth: 1600,
      );

      if (image == null) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _capturedPhoto = image;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage =
            'Kamera konnte nicht geöffnet werden. Bitte prüfe die Kameraberechtigung.';
      });
    }
  }

  void _removePhoto() {
    setState(() {
      _capturedPhoto = null;
    });
  }

  Future<void> _sendReport() async {
    final gateDecision = _reportGateDecision;

    if (!gateDecision.isAllowed) {
      setState(() {
        _errorMessage =
            gateDecision.reason ??
            'Anonyme Hinweise sind aktuell nicht verfügbar.';
        _successMessage = null;
      });
      return;
    }

    if (_isLoadingLocation) {
      setState(() {
        _errorMessage =
            'Standort wird noch geladen. Bitte warte kurz oder nutze die manuelle Adresse.';
        _successMessage = null;
      });
      return;
    }

    final reportDraft = _reportDraft;

    if (!reportDraft.canSubmit || _isSending) {
      setState(() {
        _errorMessage =
            'Bitte wähle einen Hinweis, gib ein Kennzeichen ein und füge einen Ort hinzu.';
        _successMessage = null;
      });
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSending = true;
      _clearMessages();
    });

    try {
      await _reportRepository.submitPlateHint(reportDraft);

      if (!mounted) {
        return;
      }

      final categoryLabel = reportDraft.categoryLabel;

      setState(() {
        _selectedCategory = null;
        _regionController.clear();
        _lettersController.clear();
        _numbersController.clear();
        _addressController.clear();
        _noteController.clear();
        _capturedPhoto = null;
        _isSending = false;
        _successMessage =
            'Dein Hinweis „$categoryLabel“ wurde sicher und anonym übermittelt.';
      });
      _scheduleSuccessMessageClear();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSending = false;
        _errorMessage = _mapReportError(error);
      });
    }
  }

  Future<void> _markNotificationRead(
    ReportNotificationRecord notification,
  ) async {
    if (!notification.isUnread) {
      return;
    }

    try {
      await _reportRepository.markReportNotificationRead(
        userId: widget.userState.userId,
        reportId: notification.reportId,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage =
            'Der Hinweis konnte gerade nicht als gelesen markiert werden.';
      });
    }
  }

  void _openNotificationDetails(ReportNotificationRecord notification) {
    if (notification.isUnread) {
      unawaited(_markNotificationRead(notification));
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (context) {
        return _ReportNotificationDetailsSheet(
          repository: _reportRepository,
          notification: notification,
        );
      },
    );
  }

  String _mapReportError(Object error) {
    final raw = error.toString();

    if (raw.contains('invalid-image')) {
      return 'Das Foto konnte nicht verwendet werden. Bitte nimm ein neues JPEG-Foto mit höchstens 10 MB auf.';
    }

    if (raw.contains('storage/unauthorized')) {
      return 'Das Foto darf nicht hochgeladen werden. Bitte versuche es erneut.';
    }

    if (raw.contains('not-found')) {
      return 'Für dieses Kennzeichen wurde kein aktiver Nutzer gefunden.';
    }

    if (raw.contains('unauthenticated')) {
      return 'Bitte melde dich an, um einen Hinweis zu senden.';
    }

    if (raw.contains('invalid-argument')) {
      return 'Bitte prüfe Kennzeichen, Kategorie und Ort.';
    }

    if (raw.contains('permission-denied')) {
      return 'Dieser Hinweis darf nicht gesendet werden.';
    }

    if (raw.contains('unavailable') || raw.contains('network')) {
      return 'Die Verbindung ist gerade nicht verfügbar. Bitte versuche es erneut.';
    }

    return 'Der Hinweis konnte nicht gesendet werden. Bitte versuche es erneut.';
  }

  @override
  Widget build(BuildContext context) {
    final regionPresentation = registrationRegionPresentationFor(
      countryCode: _countryCode,
      plateCode: _regionController.text,
    );

    return CaRismaBackground(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 84),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 84,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _IncomingReportNotificationsSection(
                      stream: _incomingReportNotifications,
                      onOpen: _openNotificationDetails,
                      onMarkRead: _markNotificationRead,
                    ),
                    const SizedBox(height: 8),
                    const CaRismaSectionTitle(
                      number: '1',
                      title: 'Was möchtest du melden?',
                    ),
                    const SizedBox(height: 10),
                    _CategoryGrid(
                      selectedCategory: _selectedCategory,
                      onSelected: _selectCategory,
                    ),
                    const SizedBox(height: 18),
                    const CaRismaSectionTitle(
                      number: '2',
                      title: 'Kennzeichen',
                    ),
                    const SizedBox(height: 10),
                    CaRismaCountrySelectorCard(
                      selectedCountryCode: _countryCode,
                      onChanged: _changeCountry,
                    ),
                    const SizedBox(height: 12),
                    CaRismaRegionIdentityCard(
                      region: regionPresentation,
                      onTap: _openRegionPicker,
                    ),
                    const SizedBox(height: 12),
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
                      isSubmitEnabled: false,
                      isSubmitting: false,
                      onSubmit: _sendReport,
                      showSubmit: false,
                    ),
                    const SizedBox(height: 18),
                    const CaRismaSectionTitle(
                      number: '3',
                      title: 'Ort des Hinweises',
                    ),
                    const SizedBox(height: 10),
                    _LocationCard(
                      useGpsLocation: _useGpsLocation,
                      isLoadingLocation: _isLoadingLocation,
                      position: _position,
                      gpsAddressLabel: _gpsAddressLabel,
                      locationError: _locationError,
                      addressController: _addressController,
                      onUseGpsChanged: (value) {
                        setState(() {
                          _useGpsLocation = value;
                          _clearMessages();
                        });

                        if (value && _position == null) {
                          _loadLocation();
                        }
                      },
                      onRetryLocation: _loadLocation,
                    ),
                    const SizedBox(height: 18),
                    const CaRismaSectionTitle(
                      number: '4',
                      title: 'Foto aufnehmen',
                      optional: true,
                    ),
                    const SizedBox(height: 10),
                    _PhotoCard(
                      capturedPhoto: _capturedPhoto,
                      onTakePhoto: _takePhoto,
                      onRemovePhoto: _removePhoto,
                    ),
                    const SizedBox(height: 18),
                    const CaRismaSectionTitle(
                      number: '5',
                      title: 'Kurzer Hinweis',
                      optional: true,
                    ),
                    const SizedBox(height: 10),
                    _NoteCard(controller: _noteController),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 14),
                      CaRismaMessageCard(
                        icon: Icons.error_outline_rounded,
                        message: _errorMessage!,
                      ),
                    ],
                    if (_successMessage != null) ...[
                      const SizedBox(height: 14),
                      CaRismaMessageCard(
                        icon: Icons.check_circle_outline_rounded,
                        message: _successMessage!,
                      ),
                    ],
                    const SizedBox(height: 18),
                    _SendReportButton(
                      isEnabled: _canSend,
                      isLoading: _isSending,
                      onPressed: _sendReport,
                    ),
                    const SizedBox(height: 22),
                    _SentReportNotificationsSection(
                      stream: _sentReportNotifications,
                      onOpen: _openNotificationDetails,
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

class _IncomingReportNotificationsSection extends StatelessWidget {
  const _IncomingReportNotificationsSection({
    required this.stream,
    required this.onOpen,
    required this.onMarkRead,
  });

  final Stream<List<ReportNotificationRecord>> stream;
  final ValueChanged<ReportNotificationRecord> onOpen;
  final ValueChanged<ReportNotificationRecord> onMarkRead;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ReportNotificationRecord>>(
      stream: stream,
      builder: (context, snapshot) {
        final notifications = snapshot.data ?? const [];

        if (snapshot.hasError) {
          return const _IncomingReportsStatusCard(
            icon: Icons.error_outline_rounded,
            title: 'Hinweise konnten nicht geladen werden',
            subtitle: 'Bitte versuche es später erneut.',
          );
        }

        if (notifications.isEmpty &&
            snapshot.connectionState == ConnectionState.waiting) {
          return const _IncomingReportsStatusCard(
            icon: Icons.notifications_active_outlined,
            title: 'Hinweise werden geladen',
            subtitle: 'Einen Moment bitte.',
          );
        }

        if (notifications.isEmpty) {
          return const SizedBox.shrink();
        }

        final unreadCount = notifications
            .where((notification) => notification.isUnread)
            .length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Empfangene Hinweise',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (unreadCount > 0) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: CaRismaDesignTokens.bluePrimary.withValues(
                        alpha: 0.25,
                      ),
                      border: Border.all(
                        color: CaRismaDesignTokens.bluePrimary.withValues(
                          alpha: 0.45,
                        ),
                      ),
                    ),
                    child: Text(
                      unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            ...notifications.map((notification) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _IncomingReportNotificationCard(
                  notification: notification,
                  onOpen: () => onOpen(notification),
                  onMarkRead: () => onMarkRead(notification),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _IncomingReportsStatusCard extends StatelessWidget {
  const _IncomingReportsStatusCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CaRismaBlueIconBox(icon: icon, size: 46, iconSize: 23),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontWeight: FontWeight.w700,
                    height: 1.25,
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

class _SentReportNotificationsSection extends StatelessWidget {
  const _SentReportNotificationsSection({
    required this.stream,
    required this.onOpen,
  });

  final Stream<List<ReportNotificationRecord>> stream;
  final ValueChanged<ReportNotificationRecord> onOpen;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ReportNotificationRecord>>(
      stream: stream,
      builder: (context, snapshot) {
        final notifications = snapshot.data ?? const [];

        if (snapshot.hasError) {
          return const _IncomingReportsStatusCard(
            icon: Icons.error_outline_rounded,
            title: 'Gesendete Hinweise konnten nicht geladen werden',
            subtitle: 'Bitte versuche es später erneut.',
          );
        }

        if (notifications.isEmpty &&
            snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        if (notifications.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gesendete Hinweise',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            ...notifications.map((notification) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SentReportNotificationCard(
                  notification: notification,
                  onOpen: () => onOpen(notification),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _SentReportNotificationCard extends StatelessWidget {
  const _SentReportNotificationCard({
    required this.notification,
    required this.onOpen,
  });

  final ReportNotificationRecord notification;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final categoryLabel = _IncomingReportNotificationCard._reportCategoryLabel(
      notification.category,
    );
    final createdLabel = _IncomingReportNotificationCard._createdAtLabel(
      notification.createdAt,
    );

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(22),
        child: Row(
          children: [
            CaRismaBlueIconBox(
              icon: Icons.outbox_rounded,
              size: 48,
              iconSize: 24,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    categoryLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.formattedPlate,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (createdLabel.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Gesendet am $createdLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.52),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: CaRismaDesignTokens.bluePrimary,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}

class _IncomingReportNotificationCard extends StatelessWidget {
  const _IncomingReportNotificationCard({
    required this.notification,
    required this.onOpen,
    required this.onMarkRead,
  });

  final ReportNotificationRecord notification;
  final VoidCallback onOpen;
  final VoidCallback onMarkRead;

  @override
  Widget build(BuildContext context) {
    final categoryLabel = _reportCategoryLabel(notification.category);
    final createdLabel = _createdAtLabel(notification.createdAt);

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CaRismaBlueIconBox(
                  icon: _reportCategoryIcon(notification.category),
                  size: 48,
                  iconSize: 24,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              categoryLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ),
                          if (notification.isUnread)
                            Container(
                              width: 9,
                              height: 9,
                              decoration: const BoxDecoration(
                                color: Color(0xFF2DF58D),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.formattedPlate,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Text(
              notification.message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.84),
                fontWeight: FontWeight.w800,
                height: 1.28,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _IncomingReportChip(
                  icon: Icons.place_rounded,
                  label: notification.locationLabel,
                ),
                if (createdLabel.isNotEmpty)
                  _IncomingReportChip(
                    icon: Icons.schedule_rounded,
                    label: createdLabel,
                  ),
                if (notification.hasImage)
                  const _IncomingReportChip(
                    icon: Icons.photo_camera_rounded,
                    label: 'Foto vorhanden',
                  ),
              ],
            ),
            if (notification.isUnread) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onMarkRead,
                  icon: const Icon(Icons.done_all_rounded, size: 18),
                  label: const Text('Als gelesen markieren'),
                  style: TextButton.styleFrom(
                    foregroundColor: CaRismaDesignTokens.bluePrimary,
                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _reportCategoryLabel(String category) {
    return switch (category) {
      'vehicleOpen' => 'Fahrzeug offen',
      'lightsOrElectric' => 'Licht / Elektrik',
      'vehicleBlocked' => 'Blockiert',
      'visibleDamage' => 'Schaden',
      'acuteDanger' => 'Akute Gefahr',
      'policeOnSite' => 'Polizei vor Ort',
      _ => 'Hinweis',
    };
  }

  static IconData _reportCategoryIcon(String category) {
    return switch (category) {
      'vehicleOpen' => Icons.sensor_door_outlined,
      'lightsOrElectric' => Icons.lightbulb_outline_rounded,
      'vehicleBlocked' => Icons.block_rounded,
      'visibleDamage' => Icons.car_crash_outlined,
      'acuteDanger' => Icons.warning_amber_rounded,
      'policeOnSite' => Icons.local_police_outlined,
      _ => Icons.report_outlined,
    };
  }

  static String _createdAtLabel(DateTime? createdAt) {
    if (createdAt == null) {
      return '';
    }

    final local = createdAt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.$year um $hour:$minute Uhr';
  }
}

class _IncomingReportChip extends StatelessWidget {
  const _IncomingReportChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: CaRismaDesignTokens.controlSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: CaRismaDesignTokens.bluePrimary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.78),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportNotificationDetailsSheet extends StatelessWidget {
  const _ReportNotificationDetailsSheet({
    required this.repository,
    required this.notification,
  });

  final ReportRepository repository;
  final ReportNotificationRecord notification;

  @override
  Widget build(BuildContext context) {
    final categoryLabel = _IncomingReportNotificationCard._reportCategoryLabel(
      notification.category,
    );
    final categoryIcon = _IncomingReportNotificationCard._reportCategoryIcon(
      notification.category,
    );
    final createdLabel = _detailDateLabel(notification.createdAt);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          14,
          0,
          14,
          14 + MediaQuery.of(context).padding.bottom,
        ),
        child: GlassCard(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CaRismaBlueIconBox(
                      icon: categoryIcon,
                      size: 54,
                      iconSize: 27,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            categoryLabel,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  height: 1.05,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            notification.formattedPlate,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.70),
                                  fontWeight: FontWeight.w800,
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
                const SizedBox(height: 18),
                _ReportDetailBlock(
                  title: 'Hinweis',
                  child: Text(
                    notification.message,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.86),
                      fontWeight: FontWeight.w800,
                      height: 1.32,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _ReportDetailBlock(
                  title: 'Ort',
                  child: _IncomingReportChip(
                    icon: Icons.place_rounded,
                    label: notification.locationLabel,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (createdLabel.isNotEmpty)
                      _IncomingReportChip(
                        icon: Icons.schedule_rounded,
                        label: createdLabel,
                      ),
                    if (notification.hasImage)
                      const _IncomingReportChip(
                        icon: Icons.photo_camera_rounded,
                        label: 'Foto sicher gespeichert',
                      ),
                  ],
                ),
                if (notification.imagePath != null) ...[
                  const SizedBox(height: 12),
                  _ReportDetailBlock(
                    title: 'Foto',
                    child: _ReportEvidenceImagePreview(
                      repository: repository,
                      notification: notification,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _detailDateLabel(DateTime? createdAt) {
    if (createdAt == null) {
      return '';
    }

    final local = createdAt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.$year um $hour:$minute Uhr';
  }
}

class _ReportDetailBlock extends StatelessWidget {
  const _ReportDetailBlock({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: CaRismaDesignTokens.controlSurface,
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: CaRismaDesignTokens.bluePrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _ReportEvidenceImagePreview extends StatelessWidget {
  const _ReportEvidenceImagePreview({
    required this.repository,
    required this.notification,
  });

  final ReportRepository repository;
  final ReportNotificationRecord notification;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: repository.reportEvidenceDownloadUrl(notification),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _ReportEvidencePlaceholder(
            icon: Icons.photo_camera_rounded,
            label: 'Foto wird geladen',
          );
        }

        final downloadUrl = snapshot.data;
        if (snapshot.hasError || downloadUrl == null || downloadUrl.isEmpty) {
          return const _ReportEvidencePlaceholder(
            icon: Icons.lock_outline_rounded,
            label: 'Foto kann gerade nicht geladen werden',
          );
        }

        return GestureDetector(
          onTap: () {
            showDialog<void>(
              context: context,
              barrierColor: Colors.black.withValues(alpha: 0.88),
              builder: (context) {
                return _ReportEvidenceImageDialog(downloadUrl: downloadUrl);
              },
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.network(
              downloadUrl,
              width: double.infinity,
              height: 220,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  return child;
                }

                return const _ReportEvidencePlaceholder(
                  icon: Icons.photo_camera_rounded,
                  label: 'Foto wird geladen',
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return const _ReportEvidencePlaceholder(
                  icon: Icons.broken_image_rounded,
                  label: 'Foto kann gerade nicht angezeigt werden',
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _ReportEvidencePlaceholder extends StatelessWidget {
  const _ReportEvidencePlaceholder({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 148,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.black.withValues(alpha: 0.18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: CaRismaDesignTokens.bluePrimary, size: 32),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.76),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportEvidenceImageDialog extends StatelessWidget {
  const _ReportEvidenceImageDialog({required this.downloadUrl});

  final String downloadUrl;

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: Image.network(downloadUrl, fit: BoxFit.contain),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: IconButton.filled(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.selectedCategory,
    required this.onSelected,
  });

  final _ReportCategory? selectedCategory;
  final ValueChanged<_ReportCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    final items = [
      _CategoryItem(
        category: _ReportCategory.vehicleOpen,
        icon: Icons.sensor_window_rounded,
        title: 'Fahrzeug offen',
        subtitle: 'Fenster, Tür oder Kofferraum',
      ),
      _CategoryItem(
        category: _ReportCategory.lightsOrElectric,
        icon: Icons.lightbulb_outline_rounded,
        title: 'Licht / Elektrik',
        subtitle: 'Licht, Warnblinker oder Alarm',
      ),
      _CategoryItem(
        category: _ReportCategory.vehicleBlocked,
        icon: Icons.block_rounded,
        title: 'Blockiert',
        subtitle: 'Einfahrt, Ladezone oder Weg',
      ),
      _CategoryItem(
        category: _ReportCategory.visibleDamage,
        icon: Icons.car_crash_rounded,
        title: 'Schaden',
        subtitle: 'Schaden oder auffälliger Zustand',
      ),
      _CategoryItem(
        category: _ReportCategory.acuteDanger,
        icon: Icons.warning_amber_rounded,
        title: 'Akute Gefahr',
        subtitle: 'Kind, Tier oder Gefahrensituation',
      ),
      _CategoryItem(
        category: _ReportCategory.policeOnSite,
        icon: Icons.policy_outlined,
        title: 'Polizei vor Ort',
        subtitle: 'Polizei, Ordnungsamt oder Abschleppdienst',
      ),
    ];

    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: 150,
      ),
      itemBuilder: (context, index) {
        final item = items[index];

        return _CategoryCard(
          item: item,
          isSelected: selectedCategory == item.category,
          onTap: () => onSelected(item.category),
        );
      },
    );
  }
}

class _CategoryItem {
  const _CategoryItem({
    required this.category,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final _ReportCategory category;
  final IconData icon;
  final String title;
  final String subtitle;
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final _CategoryItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: isSelected ? CaRismaDesignTokens.blueGradient : null,
              border: Border.all(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.16)
                    : Colors.transparent,
                width: isSelected ? 1.5 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: CaRismaDesignTokens.bluePrimary.withValues(
                          alpha: 0.30,
                        ),
                        blurRadius: 24,
                        spreadRadius: 1,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CaRismaBlueIconBox(icon: item.icon, size: 42, iconSize: 23),
                const SizedBox(height: 10),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w700,
                    height: 1.2,
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

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.useGpsLocation,
    required this.isLoadingLocation,
    required this.position,
    required this.gpsAddressLabel,
    required this.locationError,
    required this.addressController,
    required this.onUseGpsChanged,
    required this.onRetryLocation,
  });

  final bool useGpsLocation;
  final bool isLoadingLocation;
  final Position? position;
  final String? gpsAddressLabel;
  final String? locationError;
  final TextEditingController addressController;
  final ValueChanged<bool> onUseGpsChanged;
  final VoidCallback onRetryLocation;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _LocationModeButton(
                  label: 'GPS',
                  icon: Icons.my_location_rounded,
                  isSelected: useGpsLocation,
                  onTap: () => onUseGpsChanged(true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LocationModeButton(
                  label: 'Adresse',
                  icon: Icons.edit_location_alt_rounded,
                  isSelected: !useGpsLocation,
                  onTap: () => onUseGpsChanged(false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (useGpsLocation)
            _GpsStatusBox(
              isLoading: isLoadingLocation,
              position: position,
              gpsAddressLabel: gpsAddressLabel,
              locationError: locationError,
              onRetry: onRetryLocation,
            )
          else
            Column(
              children: [
                if (locationError != null) ...[
                  _InlineStatusBox(
                    icon: Icons.location_off_rounded,
                    text: locationError!,
                  ),
                  const SizedBox(height: 10),
                ],
                TextField(
                  controller: addressController,
                  textInputAction: TextInputAction.done,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Adresse + Hausnummer, PLZ u. Ort',
                    hintMaxLines: 1,
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.50),
                      fontWeight: FontWeight.w700,
                    ),
                    filled: true,
                    fillColor: CaRismaDesignTokens.controlSurface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 17,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                        color: CaRismaDesignTokens.bluePrimary.withValues(
                          alpha: 0.90,
                        ),
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _LocationModeButton extends StatelessWidget {
  const _LocationModeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: isSelected
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      CaRismaDesignTokens.bluePrimary,
                      CaRismaDesignTokens.bluePrimary,
                      CaRismaDesignTokens.bluePrimary,
                    ],
                  )
                : null,
            color: isSelected ? null : CaRismaDesignTokens.controlSurface,
            border: Border.all(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.22)
                  : Colors.white.withValues(alpha: 0.10),
            ),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 22),
                  const SizedBox(width: 9),
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: isSelected
                          ? FontWeight.w900
                          : FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GpsStatusBox extends StatelessWidget {
  const _GpsStatusBox({
    required this.isLoading,
    required this.position,
    required this.gpsAddressLabel,
    required this.locationError,
    required this.onRetry,
  });

  final bool isLoading;
  final Position? position;
  final String? gpsAddressLabel;
  final String? locationError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const _InlineStatusBox(
        icon: Icons.hourglass_top_rounded,
        text: 'Standort wird geladen...',
      );
    }

    if (position != null) {
      final label = gpsAddressLabel?.trim();

      return _InlineStatusBox(
        icon: Icons.check_circle_outline_rounded,
        text: label == null || label.isEmpty ? 'GPS-Standort erfasst.' : label,
      );
    }

    return Column(
      children: [
        _InlineStatusBox(
          icon: Icons.location_off_rounded,
          text: locationError ?? 'Standort konnte nicht geladen werden.',
        ),
        const SizedBox(height: 10),
        _SmallActionButton(
          label: 'Erneut versuchen',
          icon: Icons.refresh_rounded,
          onTap: onRetry,
        ),
      ],
    );
  }
}

class _InlineStatusBox extends StatelessWidget {
  const _InlineStatusBox({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: CaRismaDesignTokens.controlSurface,
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.78),
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallActionButton extends StatelessWidget {
  const _SmallActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CaRismaSecondaryButton(
      label: label,
      icon: icon,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      borderRadius: 18,
      onPressed: onTap,
    );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({
    required this.capturedPhoto,
    required this.onTakePhoto,
    required this.onRemovePhoto,
  });

  final XFile? capturedPhoto;
  final VoidCallback onTakePhoto;
  final VoidCallback onRemovePhoto;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: capturedPhoto == null
          ? Column(
              children: [
                const _InlineStatusBox(
                  icon: Icons.no_photography_outlined,
                  text:
                      'Aus Datenschutzgründen kannst du hier nur ein neues Foto aufnehmen. Galerie-Uploads sind nicht erlaubt.',
                ),
                const SizedBox(height: 12),
                _PrimaryActionButton(
                  label: 'Foto aufnehmen',
                  icon: Icons.photo_camera_rounded,
                  onTap: onTakePhoto,
                ),
              ],
            )
          : Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.file(
                    File(capturedPhoto!.path),
                    width: double.infinity,
                    height: 190,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _SmallActionButton(
                        label: 'Entfernen',
                        icon: Icons.delete_outline_rounded,
                        onTap: onRemovePhoto,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PrimaryActionButton(
                        label: 'Neu aufnehmen',
                        icon: Icons.photo_camera_rounded,
                        onTap: onTakePhoto,
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: CaRismaDesignTokens.bluePrimary.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(22)),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  CaRismaDesignTokens.bluePrimary,
                  CaRismaDesignTokens.bluePrimary,
                  CaRismaDesignTokens.bluePrimary,
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: TextField(
        controller: controller,
        maxLength: 160,
        maxLines: 4,
        textInputAction: TextInputAction.newline,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          hintText:
              'Kurzer sachlicher Hinweis - Dieser Bereich ist nur für echte Hinweise gedacht. Missbrauch kann zur Sperrung deines Kontos führen.',
          hintMaxLines: 4,
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.48),
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
          counterStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.50),
            fontWeight: FontWeight.w700,
          ),
          filled: true,
          fillColor: CaRismaDesignTokens.controlSurface,
          contentPadding: const EdgeInsets.all(16),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(
              color: CaRismaDesignTokens.bluePrimary.withValues(alpha: 0.90),
              width: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _SendReportButton extends StatelessWidget {
  const _SendReportButton({
    required this.isEnabled,
    required this.isLoading,
    required this.onPressed,
  });

  final bool isEnabled;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CaRismaPrimaryButton(
      label: 'Anonym senden',
      loadingLabel: 'Wird gesendet...',
      icon: Icons.send_rounded,
      iconSize: 27,
      fontSize: 19,
      isEnabled: isEnabled,
      isLoading: isLoading,
      onPressed: onPressed,
    );
  }
}
