import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

import '../../../shared/domain/app_feature_gate.dart';
import '../../../shared/models/carisma_models.dart';
import '../../../shared/plate/plate_country_config.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/data/mfa_service.dart';
import '../../auth/presentation/mfa_screens.dart';
import '../domain/profile_document_mapper.dart';
import '../domain/profile_draft.dart';
import '../data/profile_media_storage.dart';
import '../data/profile_repository.dart';
import '../data/profile_vehicle_repository.dart';
import '../data/plate_repository.dart';
import '../data/user_profile.dart' as firestore_profile;
import '../data/vehicle_catalog.dart';
import 'profile_verification_screen.dart';
import 'widgets/profile_photo_crop_screen.dart';
import '../../../shared/widgets/carisma_background.dart';
import '../../../shared/widgets/carisma_blue_icon_box.dart';
import '../../../shared/widgets/carisma_country_selector_card.dart';
import '../../../shared/widgets/carisma_message_card.dart';
import '../../../shared/widgets/carisma_page_header.dart';
import '../../../shared/widgets/carisma_plate_input_card.dart';
import '../../../shared/widgets/carisma_primary_button.dart';
import '../../../shared/widgets/carisma_secondary_button.dart';
import '../../../shared/widgets/carisma_section_title.dart';
import '../../../shared/widgets/carisma_sub_page_header.dart';
import '../../../shared/widgets/carisma_switch_row.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/theme/carisma_design_tokens.dart';

enum ProfileEditorEntry { overview, personalData, documents }

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.userState,
    this.initialEntry = ProfileEditorEntry.personalData,
  });

  final AppUserState userState;
  final ProfileEditorEntry initialEntry;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _personalDataSectionKey = GlobalKey();
  final ImagePicker _imagePicker = ImagePicker();
  final ProfileMediaStorage _profileMediaStorage = ProfileMediaStorage();
  final ProfileRepository _profileRepository = ProfileRepository();
  final ProfileVehicleRepository _profileVehicleRepository =
      ProfileVehicleRepository();
  final PlateRepository _plateRepository = PlateRepository();
  final AuthService _authService = AuthService();
  final FirebaseMfaService _mfaService = FirebaseMfaService();
  late final Widget _documentsEntryChild;

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _publicBioController = TextEditingController();
  final TextEditingController _publicRegionController = TextEditingController();

  final TextEditingController _regionController = TextEditingController();
  final TextEditingController _lettersController = TextEditingController();
  final TextEditingController _numbersController = TextEditingController();

  final FocusNode _regionFocusNode = FocusNode();
  final FocusNode _lettersFocusNode = FocusNode();
  final FocusNode _numbersFocusNode = FocusNode();

  XFile? _profilePhoto;
  String? _profilePhotoUrl;
  bool _profilePhotoRemoved = false;

  String _countryCode = 'DE';
  String _selectedBrand = 'BMW';
  String _selectedModel = '1er';
  String _selectedColor = 'Schwarz';

  bool _allowContactRequests = true;
  bool _allowAnonymousReports = true;
  bool _hasUnsavedChanges = false;
  bool _isSaving = false;
  bool _isLoadingProfile = true;
  bool _isApplyingSavedProfile = false;
  bool _initialEntryHandled = false;
  String? _profileLoadError;
  MfaStatusSnapshot? _mfaStatus;
  bool _isLoadingMfaStatus = true;
  String? _mfaStatusError;
  String? _birthDateError;

  bool _isSubmittedForVerification = false;
  bool _isVerified = false;
  bool _isVerificationRejected = false;
  DateTime? _verificationSubmittedAt;
  DateTime? _verificationReviewedAt;
  String? _verificationRejectionReason;
  DateTime? _birthDate;
  firestore_profile.UserProfile? _loadedProfile;

  final Map<String, XFile?> _documentFiles = {
    'Ausweis Vorderseite': null,
    'Ausweis Rückseite': null,
    'Führerschein Vorderseite': null,
    'Führerschein Rückseite': null,
    'Fahrzeugschein Vorderseite': null,
    'Fahrzeugschein Rückseite': null,
  };

  final Map<String, String?> _documentRemoteUrlsByTitle = {
    'Ausweis Vorderseite': null,
    'Ausweis Rückseite': null,
    'Führerschein Vorderseite': null,
    'Führerschein Rückseite': null,
    'Fahrzeugschein Vorderseite': null,
    'Fahrzeugschein Rückseite': null,
  };

  static const List<String> _vehicleColors = [
    'Schwarz',
    'Weiß',
    'Silber',
    'Grau',
    'Blau',
    'Rot',
    'Grün',
    'Braun',
    'Beige',
    'Gelb',
  ];

  bool get _isProfileLocked {
    return _isSubmittedForVerification || _isVerified;
  }

  bool get _isPersonalDataLocked {
    return _loadedProfile?.personalDataLocked ?? false;
  }

  String get _entryTitle => switch (widget.initialEntry) {
    ProfileEditorEntry.personalData => 'Persönliche Daten',
    ProfileEditorEntry.documents => 'Dokumente hochladen',
    ProfileEditorEntry.overview => 'Persönliche Daten',
  };

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

  AppFeatureDecision get _verificationGateDecision {
    return AppFeatureGate.evaluate(
      userState: widget.userState,
      feature: AppFeature.profileVerification,
    );
  }

  bool get _hasNameInput {
    return _firstNameController.text.trim().isNotEmpty &&
        _lastNameController.text.trim().isNotEmpty;
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

  bool get _allDocumentsUploaded {
    return _documentFiles.keys.every(_isDocumentUploaded);
  }

  int get _uploadedDocumentCount {
    return _documentFiles.keys.where(_isDocumentUploaded).length;
  }

  bool _isDocumentUploaded(String title) {
    final remoteUrl = _documentRemoteUrlsByTitle[title]?.trim();

    return _documentFiles[title] != null ||
        (remoteUrl != null && remoteUrl.isNotEmpty);
  }

  double get _verificationProgress {
    return _uploadedDocumentCount / _documentFiles.length;
  }

  bool get _canSubmitProfileForVerification {
    return _hasNameInput && _hasPlateInput && _allDocumentsUploaded;
  }

  Map<String, String?> get _documentLocalPathsByTitle {
    return _documentFiles.map((title, file) {
      return MapEntry(title, file?.path);
    });
  }

  ProfileDraft get _profileDraft {
    return ProfileDraft(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      countryCode: _countryCode,
      region: _regionController.text.trim(),
      letters: _lettersController.text.trim(),
      numbers: _numbersController.text.trim(),
      brand: _selectedBrand,
      model: _selectedModel,
      color: _selectedColor,
      allowContactRequests: _allowContactRequests,
      allowAnonymousReports: _allowAnonymousReports,
      documentLocalPaths: ProfileDocumentMapper.toDocumentLocalPaths(
        _documentLocalPathsByTitle,
      ),
      profilePhotoLocalPath: _profilePhoto?.path,
      isSubmittedForVerification: _isSubmittedForVerification,
      isVerified: _isVerified,
    );
  }

  String get _displayName {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();

    if (firstName.isEmpty && lastName.isEmpty) {
      return 'plaqa Nutzer';
    }

    if (firstName.isEmpty) {
      return '${lastName.substring(0, 1).toUpperCase()}.';
    }

    if (lastName.isEmpty) {
      return firstName;
    }

    return '$firstName ${lastName.substring(0, 1).toUpperCase()}.';
  }

  String get _displayPlate {
    final displayPlate = formatDisplayPlate(
      countryCode: _countryCode,
      region: _regionController.text,
      letters: _lettersController.text,
      numbers: _numbersController.text,
    );

    return displayPlate.isEmpty ? 'Noch kein Kennzeichen' : displayPlate;
  }

  String get _mfaPhoneLabel {
    if (_isLoadingMfaStatus) return 'Zwei-Faktor-Status wird geladen ...';
    if (_mfaStatusError != null) return 'Status derzeit nicht verfügbar';
    final factors = _mfaStatus?.factors ?? const <MfaFactorSnapshot>[];
    if (factors.isEmpty) return 'Telefonnummer hinterlegen';
    return factors.first.maskedPhoneNumber;
  }

  bool get _hasMfaPhone {
    return (_mfaStatus?.factors.isNotEmpty ?? false) && _mfaStatusError == null;
  }

  @override
  void initState() {
    super.initState();

    _documentsEntryChild = ProfileVerificationScreen(
      key: const PageStorageKey<String>('direct-profile-verification'),
      userId: widget.userState.userId,
    );

    _firstNameController.addListener(_markUnsaved);
    _lastNameController.addListener(_markUnsaved);
    _phoneNumberController.addListener(_markUnsaved);
    _birthDateController.addListener(_markUnsaved);
    _publicBioController.addListener(_markPublicProfileUnsaved);
    _publicRegionController.addListener(_markPublicProfileUnsaved);
    _regionController.addListener(_markUnsaved);
    _lettersController.addListener(_markUnsaved);
    _numbersController.addListener(_markUnsaved);

    _loadSavedProfile();
    _loadMfaStatus();
  }

  Future<void> _loadSavedProfile() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser == null) {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
          _profileLoadError =
              'Bitte melde dich erneut an, um deine Profildaten zu laden.';
        });
      }
      return;
    }

    firestore_profile.UserProfile? profile;
    try {
      profile = await _profileRepository.getProfile(firebaseUser.uid);
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
          _profileLoadError =
              'Deine Profildaten konnten gerade nicht geladen werden.';
        });
      }
      return;
    }

    if (!mounted || _hasUnsavedChanges) {
      return;
    }

    if (profile == null) {
      setState(() {
        _isLoadingProfile = false;
        _profileLoadError = null;
      });
      _handleInitialEntry();
      return;
    }
    final loadedProfile = profile;

    final documentFiles = Map<String, XFile?>.from(_documentFiles);
    final documentRemoteUrls = Map<String, String?>.from(
      _documentRemoteUrlsByTitle,
    );

    for (final entry in loadedProfile.documentLocalPaths.entries) {
      final title = _documentTitleForStoredType(entry.key);
      final path = entry.value?.trim();

      if (title == null || path == null || path.isEmpty) {
        continue;
      }

      documentFiles[title] = File(path).existsSync() ? XFile(path) : null;
    }

    for (final entry in loadedProfile.documentRemoteUrls.entries) {
      final title = _documentTitleForStoredType(entry.key);
      final remoteUrl = entry.value?.trim();

      if (title == null || remoteUrl == null || remoteUrl.isEmpty) {
        continue;
      }

      documentRemoteUrls[title] = remoteUrl;
    }

    final localProfilePhotoPath = loadedProfile.profilePhotoLocalPath?.trim();
    final localProfilePhoto =
        localProfilePhotoPath != null &&
            localProfilePhotoPath.isNotEmpty &&
            File(localProfilePhotoPath).existsSync()
        ? XFile(localProfilePhotoPath)
        : null;
    final vehicleModels =
        VehicleCatalog.modelsByBrand[loadedProfile.vehicleBrand] ??
        const <String>[];
    final normalizedModel = loadedProfile.vehicleModel?.trim();

    _isApplyingSavedProfile = true;

    try {
      setState(() {
        _loadedProfile = loadedProfile;
        _isLoadingProfile = false;
        _profileLoadError = null;
        _firstNameController.text = loadedProfile.firstName;
        _lastNameController.text = loadedProfile.lastName;
        _phoneNumberController.text = loadedProfile.phoneNumber ?? '';
        _birthDateController.text = _formatBirthDate(loadedProfile.birthDate);
        _publicBioController.text = loadedProfile.publicBio ?? '';
        _publicRegionController.text = loadedProfile.publicRegion ?? '';
        _birthDate = loadedProfile.birthDate;
        _countryCode = _normalizedCountryCode(loadedProfile);
        _regionController.text = loadedProfile.plateRegion ?? '';
        _lettersController.text = loadedProfile.plateLetters ?? '';
        _numbersController.text = loadedProfile.plateNumbers ?? '';
        _selectedBrand = loadedProfile.vehicleBrand?.trim().isNotEmpty == true
            ? loadedProfile.vehicleBrand!.trim()
            : _selectedBrand;
        _selectedModel = normalizedModel?.isNotEmpty == true
            ? normalizedModel!
            : vehicleModels.isNotEmpty
            ? vehicleModels.first
            : _selectedModel;
        _selectedColor = loadedProfile.vehicleColor?.trim().isNotEmpty == true
            ? loadedProfile.vehicleColor!.trim()
            : _selectedColor;
        _allowContactRequests = loadedProfile.allowContactRequests;
        _allowAnonymousReports = loadedProfile.allowAnonymousReports;
        _profilePhoto = localProfilePhoto;
        _profilePhotoUrl = loadedProfile.photoUrl?.trim().isNotEmpty == true
            ? loadedProfile.photoUrl!.trim()
            : null;
        _profilePhotoRemoved = false;

        for (final entry in documentFiles.entries) {
          _documentFiles[entry.key] = entry.value;
        }

        for (final entry in documentRemoteUrls.entries) {
          _documentRemoteUrlsByTitle[entry.key] = entry.value;
        }

        _isSubmittedForVerification =
            loadedProfile.verificationStatus == 'pending';
        _isVerified = loadedProfile.verificationStatus == 'verified';
        _isVerificationRejected =
            loadedProfile.verificationStatus == 'rejected';
        _verificationSubmittedAt = loadedProfile.verificationSubmittedAt;
        _verificationReviewedAt = loadedProfile.verificationReviewedAt;
        _verificationRejectionReason =
            loadedProfile.verificationRejectionReason?.trim().isNotEmpty == true
            ? loadedProfile.verificationRejectionReason!.trim()
            : null;
        _hasUnsavedChanges = false;
      });
    } finally {
      _isApplyingSavedProfile = false;
    }

    _handleInitialEntry();
  }

  void _handleInitialEntry() {
    if (_initialEntryHandled || !mounted) {
      return;
    }
    _initialEntryHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switch (widget.initialEntry) {
        case ProfileEditorEntry.documents:
          break;
        case ProfileEditorEntry.personalData:
          break;
        case ProfileEditorEntry.overview:
          break;
      }
    });
  }

  Future<void> _loadMfaStatus() async {
    if (FirebaseAuth.instance.currentUser == null) {
      if (mounted) {
        setState(() {
          _isLoadingMfaStatus = false;
          _mfaStatusError = 'Nicht angemeldet';
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingMfaStatus = true;
        _mfaStatusError = null;
      });
    }

    try {
      final status = await _mfaService.loadStatus();
      if (!mounted) return;
      setState(() {
        _mfaStatus = status;
        _isLoadingMfaStatus = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _mfaStatus = null;
        _isLoadingMfaStatus = false;
        _mfaStatusError = 'Status konnte nicht geladen werden';
      });
    }
  }

  Future<void> _openMfaManagement() async {
    try {
      final account = await _authService.loadCurrentAccount();
      if (!mounted) return;
      if (account == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Deine Kontodaten konnten nicht geladen werden.'),
          ),
        );
        return;
      }

      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => MfaManagementScreen(
            initialAccount: account,
            accountGateway: _authService,
          ),
        ),
      );
      if (mounted) await _loadMfaStatus();
    } on FirebaseAuthException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Deine Kontodaten konnten gerade nicht geladen werden.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Der Zwei-Faktor-Schutz konnte nicht geöffnet werden.'),
        ),
      );
    }
  }

  String _formatBirthDate(DateTime? value) {
    if (value == null) return '';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day.$month.${value.year}';
  }

  DateTime? _parseBirthDate(String value) {
    final match = RegExp(
      r'^(\d{2})\.(\d{2})\.(\d{4})$',
    ).firstMatch(value.trim());
    if (match == null) return null;

    final day = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final year = int.parse(match.group(3)!);
    if (year < 1900 || month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }

    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  }

  String? _validateBirthDate(String value) {
    if (value.trim().isEmpty) return 'Bitte gib dein Geburtsdatum ein.';
    final birthDate = _parseBirthDate(value);
    if (birthDate == null) return 'Bitte verwende das Format TT.MM.JJJJ.';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (birthDate.isAfter(today)) {
      return 'Das Geburtsdatum darf nicht in der Zukunft liegen.';
    }
    final latestAllowed = DateTime(now.year - 16, now.month, now.day);
    if (birthDate.isAfter(latestAllowed)) {
      return 'Du musst mindestens 16 Jahre alt sein.';
    }
    return null;
  }

  void _handleBirthDateChanged(String value) {
    final validation = value.length == 10 ? _validateBirthDate(value) : null;
    setState(() {
      _birthDate = _parseBirthDate(value);
      _birthDateError = validation;
    });
  }

  String? _documentTitleForStoredType(String typeName) {
    for (final type in VerificationDocumentType.values) {
      if (type.name == typeName) {
        return ProfileDocumentMapper.titleForType(type);
      }
    }

    return null;
  }

  String _normalizedCountryCode(firestore_profile.UserProfile profile) {
    final countryCode = profile.countryCode?.trim().toUpperCase();

    if (countryCode == 'DE' || countryCode == 'AT' || countryCode == 'CH') {
      return countryCode!;
    }

    final country = profile.country.trim().toLowerCase();

    return switch (country) {
      'österreich' || 'austria' => 'AT',
      'schweiz' || 'switzerland' => 'CH',
      _ => 'DE',
    };
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _firstNameController.removeListener(_markUnsaved);
    _lastNameController.removeListener(_markUnsaved);
    _phoneNumberController.removeListener(_markUnsaved);
    _birthDateController.removeListener(_markUnsaved);
    _publicBioController.removeListener(_markPublicProfileUnsaved);
    _publicRegionController.removeListener(_markPublicProfileUnsaved);
    _regionController.removeListener(_markUnsaved);
    _lettersController.removeListener(_markUnsaved);
    _numbersController.removeListener(_markUnsaved);

    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneNumberController.dispose();
    _birthDateController.dispose();
    _publicBioController.dispose();
    _publicRegionController.dispose();
    _regionController.dispose();
    _lettersController.dispose();
    _numbersController.dispose();

    _regionFocusNode.dispose();
    _lettersFocusNode.dispose();
    _numbersFocusNode.dispose();

    super.dispose();
  }

  void _markUnsaved() {
    if (_isProfileLocked || _isApplyingSavedProfile) {
      return;
    }

    setState(() {
      _hasUnsavedChanges = true;
    });
  }

  void _markPublicProfileUnsaved() {
    if (_isApplyingSavedProfile) return;
    setState(() => _hasUnsavedChanges = true);
  }

  Future<bool> _confirmDiscardChanges() async {
    if (!_hasUnsavedChanges) return true;

    FocusManager.instance.primaryFocus?.unfocus();
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: CaRismaDesignTokens.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
        title: const Text(
          'Änderungen verwerfen?',
          style: TextStyle(
            color: CaRismaDesignTokens.textPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: const Text(
          'Deine Änderungen wurden noch nicht gespeichert.',
          style: TextStyle(color: CaRismaDesignTokens.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Weiter bearbeiten'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Verwerfen',
              style: TextStyle(color: CaRismaDesignTokens.danger),
            ),
          ),
        ],
      ),
    );
    return shouldLeave == true;
  }

  Future<void> _handleBack() async {
    if (!await _confirmDiscardChanges() || !mounted) return;
    Navigator.of(context).pop();
  }

  void _clearVehicleVerificationDocuments() {
    _documentFiles['Fahrzeugschein Vorderseite'] = null;
    _documentFiles['Fahrzeugschein Rückseite'] = null;
    _documentRemoteUrlsByTitle['Fahrzeugschein Vorderseite'] = null;
    _documentRemoteUrlsByTitle['Fahrzeugschein Rückseite'] = null;
  }

  Future<bool> _savePersonalData() async {
    final lockedProfile = _isPersonalDataLocked ? _loadedProfile : null;
    final firstName = lockedProfile?.firstName.trim().isNotEmpty == true
        ? lockedProfile!.firstName.trim()
        : _firstNameController.text.trim();
    final lastName = lockedProfile?.lastName.trim().isNotEmpty == true
        ? lockedProfile!.lastName.trim()
        : _lastNameController.text.trim();
    final birthDate =
        lockedProfile?.birthDate ?? _parseBirthDate(_birthDateController.text);
    final birthDateError = lockedProfile != null
        ? null
        : _validateBirthDate(_birthDateController.text);

    if (firstName.isEmpty || lastName.isEmpty || birthDateError != null) {
      setState(() => _birthDateError = birthDateError);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            firstName.isEmpty || lastName.isEmpty
                ? 'Bitte gib Vorname und Nachname vollständig ein.'
                : birthDateError!,
          ),
        ),
      );
      return false;
    }

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null || birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bitte melde dich erneut an, um deine Daten zu speichern.',
          ),
        ),
      );
      return false;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    try {
      var profilePhotoUrl = _profilePhotoRemoved
          ? null
          : (_profilePhotoUrl ?? firebaseUser.photoURL);

      if (_profilePhotoRemoved) {
        await _profileMediaStorage.deleteProfilePhoto(userId: firebaseUser.uid);
      }
      if (_profilePhoto != null) {
        final upload = await _profileMediaStorage.uploadProfilePhoto(
          userId: firebaseUser.uid,
          file: File(_profilePhoto!.path),
        );
        profilePhotoUrl = upload.url;
      }

      final updatedProfile = await _profileRepository.updatePersonalData(
        uid: firebaseUser.uid,
        firstName: firstName,
        lastName: lastName,
        displayName: _displayName,
        birthDate: birthDate,
        photoUrl: profilePhotoUrl,
      );
      await _syncFirebaseUserProfile(
        firebaseUser,
        displayName: _displayName,
        photoUrl: profilePhotoUrl,
      );

      if (!mounted) return false;
      setState(() {
        _loadedProfile = updatedProfile ?? _loadedProfile;
        _birthDate = birthDate;
        _birthDateError = null;
        _profilePhoto = null;
        _profilePhotoUrl = profilePhotoUrl;
        _profilePhotoRemoved = false;
        _hasUnsavedChanges = false;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lockedProfile == null
                ? 'Persönliche Daten wurden verbindlich gespeichert.'
                : 'Profilbild wurde gespeichert.',
          ),
        ),
      );
      return true;
    } catch (error) {
      if (!mounted) return false;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_profileSaveErrorMessage(error))));
      return false;
    }
  }

  Future<bool> _confirmPersonalDataLock() async {
    if (_isPersonalDataLocked) return true;

    FocusManager.instance.primaryFocus?.unfocus();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: CaRismaDesignTokens.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: CaRismaDesignTokens.danger.withValues(alpha: 0.90),
            width: 1.4,
          ),
        ),
        title: const Text(
          'WICHTIGER HINWEIS !',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: CaRismaDesignTokens.textPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: const Text(
          'Vorname, Nachname und Geburtsdatum können danach nicht mehr geändert werden, da sie mit deinen Fahrzeug- und Verifizierungsdaten übereinstimmen müssen. Profilbild, E-Mail Adresse und Telefonnummer bleiben weiterhin änderbar. In der App wird nur die Initiale deines Nachnamens angezeigt.',
          style: TextStyle(
            color: CaRismaDesignTokens.textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(
              'Nochmal bearbeiten',
              style: TextStyle(
                color: CaRismaDesignTokens.bluePrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Verbindlich speichern',
              style: TextStyle(
                color: CaRismaDesignTokens.danger,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
    return confirmed == true && mounted;
  }

  Future<void> _handlePersonalDataSave() async {
    if (!await _confirmPersonalDataLock()) return;
    await _savePersonalData();
  }

  Future<void> _showProfilePhotoSourceSheet() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: GlassCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SheetActionButton(
                    label: 'Foto aus Aufnahmen wählen',
                    icon: Icons.photo_library_rounded,
                    onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                  ),
                  const SizedBox(height: 10),
                  _SheetActionButton(
                    label: 'Kamera öffnen',
                    icon: Icons.photo_camera_rounded,
                    onTap: () => Navigator.of(context).pop(ImageSource.camera),
                  ),
                  if (_profilePhoto != null || _profilePhotoUrl != null) ...[
                    const SizedBox(height: 10),
                    _SheetSecondaryActionButton(
                      label: 'Profilbild entfernen',
                      onTap: () {
                        Navigator.of(context).pop();
                        setState(() {
                          _profilePhoto = null;
                          _profilePhotoUrl = null;
                          _profilePhotoRemoved = true;
                          _hasUnsavedChanges = true;
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: 10),
                  _SheetSecondaryActionButton(
                    label: 'Abbrechen',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (source == null) {
      return;
    }

    await _pickProfilePhoto(source);
  }

  Future<void> _pickProfilePhoto(ImageSource source) async {
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 86,
        maxWidth: 1400,
      );

      if (image == null) {
        return;
      }

      if (!mounted) {
        return;
      }

      final croppedImage = await Navigator.of(context).push<XFile>(
        MaterialPageRoute<XFile>(
          builder: (_) => ProfilePhotoCropScreen(sourceFile: image),
        ),
      );
      if (croppedImage == null || !mounted) {
        return;
      }

      setState(() {
        _profilePhoto = croppedImage;
        _profilePhotoUrl = null;
        _profilePhotoRemoved = false;
        _hasUnsavedChanges = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profilbild wurde zugeschnitten.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Profilbild konnte nicht geladen werden. Bitte prüfe Kamera- oder Fotoberechtigung.',
          ),
        ),
      );
    }
  }

  void _changeCountry(String countryCode) {
    if (_isProfileLocked || _countryCode == countryCode) {
      return;
    }

    setState(() {
      _countryCode = countryCode;
      _regionController.clear();
      _lettersController.clear();
      _numbersController.clear();
      _clearVehicleVerificationDocuments();
      _hasUnsavedChanges = true;
    });

    _regionFocusNode.requestFocus();
  }

  void _handleRegionChanged(String value) {
    if (_isProfileLocked) {
      return;
    }

    if (value.length >= _regionMaxLength) {
      if (_countryCode == 'CH' || _countryCode == 'AT') {
        _numbersFocusNode.requestFocus();
        return;
      }

      _lettersFocusNode.requestFocus();
    }
  }

  void _handleLettersChanged(String value) {
    if (_isProfileLocked) {
      return;
    }

    if (value.length >= _lettersMaxLength) {
      if (_countryCode == 'AT') {
        _lettersFocusNode.unfocus();
        return;
      }

      _numbersFocusNode.requestFocus();
    }
  }

  void _handleNumbersChanged(String value) {
    if (_isProfileLocked) {
      return;
    }

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

  void _onBrandChanged(String brand) {
    if (_isProfileLocked) {
      return;
    }

    final models = VehicleCatalog.modelsByBrand[brand] ?? const <String>[];

    setState(() {
      _selectedBrand = brand;
      _selectedModel = models.isNotEmpty ? models.first : '';
      _clearVehicleVerificationDocuments();
      _hasUnsavedChanges = true;
    });
  }

  void _onModelChanged(String model) {
    if (_isProfileLocked) {
      return;
    }

    setState(() {
      _selectedModel = model;
      _clearVehicleVerificationDocuments();
      _hasUnsavedChanges = true;
    });
  }

  void _onColorChanged(String color) {
    if (_isProfileLocked) {
      return;
    }

    setState(() {
      _selectedColor = color;
      _clearVehicleVerificationDocuments();
      _hasUnsavedChanges = true;
    });
  }

  Future<Position?> _loadPlatePositionForSave() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        return null;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 8));
    } catch (error) {
      return null;
    }
  }

  Future<bool> _saveProfile() async {
    if (_isProfileLocked) {
      return _saveLockedProfilePreferences();
    }

    if (!await _confirmPersonalDataLock()) {
      return false;
    }
    if (!mounted) {
      return false;
    }

    final gateDecision = _verificationGateDecision;

    if (!gateDecision.isAllowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            gateDecision.reason ??
                'Die Profil-Verifizierung ist aktuell nicht verfügbar.',
          ),
        ),
      );
      return false;
    }

    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bitte melde dich erneut an, um dein Profil zu speichern.',
          ),
        ),
      );
      return false;
    }

    FocusScope.of(context).unfocus();

    final platePosition = await _loadPlatePositionForSave();
    final draft = _profileDraft;
    setState(() {
      _isSaving = true;
    });

    try {
      var profilePhotoUrl = _profilePhotoRemoved
          ? null
          : (_profilePhotoUrl ?? firebaseUser.photoURL);

      if (_profilePhotoRemoved) {
        await _profileMediaStorage.deleteProfilePhoto(userId: firebaseUser.uid);
      }

      if (_profilePhoto != null) {
        final upload = await _profileMediaStorage.uploadProfilePhoto(
          userId: firebaseUser.uid,
          file: File(_profilePhoto!.path),
        );
        profilePhotoUrl = upload.url;
      }

      final profile = firestore_profile.UserProfile(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        firstName: draft.firstName,
        lastName: draft.lastName,
        displayName: _displayName,
        country: draft.countryCode,
        countryCode: draft.countryCode,
        plateRegion: draft.region,
        plateLetters: draft.letters,
        plateNumbers: draft.numbers,
        vehicleBrand: draft.brand,
        vehicleModel: draft.model,
        vehicleColor: draft.color,
        allowContactRequests: draft.allowContactRequests,
        allowAnonymousReports: draft.allowAnonymousReports,
        phoneNumber: _phoneNumberController.text.trim(),
        birthDate: _birthDate,
        photoUrl: profilePhotoUrl,
        profilePhotoLocalPath: null,
        publicBio: _publicBioController.text.trim(),
        publicRegion: _publicRegionController.text.trim(),
        personalDataLocked: true,
        showVehicleOnPublicProfile:
            _loadedProfile?.showVehicleOnPublicProfile ?? false,
        showPlateOnPublicProfile:
            _loadedProfile?.showPlateOnPublicProfile ?? false,
        isPrivateProfile: _loadedProfile?.isPrivateProfile ?? true,
        profileAccessEnabled: _loadedProfile?.profileAccessEnabled ?? true,
        followersVisibility: _loadedProfile?.followersVisibility ?? 'contacts',
        followingVisibility: _loadedProfile?.followingVisibility ?? 'contacts',
        primaryVehicleId: _loadedProfile?.primaryVehicleId,
        documentLocalPaths:
            _loadedProfile?.documentLocalPaths ?? const <String, String?>{},
        documentRemoteUrls:
            _loadedProfile?.documentRemoteUrls ?? const <String, String?>{},
        verificationStatus: _loadedProfile?.verificationStatus ?? 'draft',
        verificationSubmittedAt: _loadedProfile?.verificationSubmittedAt,
        verificationReviewedAt: _loadedProfile?.verificationReviewedAt,
        verificationRejectionReason:
            _loadedProfile?.verificationRejectionReason,
      );

      await _profileRepository.saveProfile(profile);
      await _plateRepository.registerPlateForProfile(
        profile,
        latitude: platePosition?.latitude,
        longitude: platePosition?.longitude,
      );
      await _profileVehicleRepository.ensureLegacyPrimaryVehicle(profile);
      await _syncFirebaseUserProfile(
        firebaseUser,
        displayName: _displayName,
        photoUrl: profilePhotoUrl,
      );

      if (!mounted) {
        return false;
      }

      setState(() {
        _isSaving = false;
        _hasUnsavedChanges = false;
        _loadedProfile = profile;
        _profilePhoto = null;
        _profilePhotoUrl = profilePhotoUrl;
        _profilePhotoRemoved = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Persönliche Daten wurden gespeichert.')),
      );
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_profileSaveErrorMessage(error))));
      return false;
    }
  }

  Future<bool> _saveLockedProfilePreferences() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bitte melde dich erneut an, um dein Profil zu speichern.',
          ),
        ),
      );
      return false;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      var profilePhotoUrl = _profilePhotoRemoved
          ? null
          : (_profilePhotoUrl ?? firebaseUser.photoURL);

      if (_profilePhotoRemoved) {
        await _profileMediaStorage.deleteProfilePhoto(userId: firebaseUser.uid);
      }

      if (_profilePhoto != null) {
        final upload = await _profileMediaStorage.uploadProfilePhoto(
          userId: firebaseUser.uid,
          file: File(_profilePhoto!.path),
        );
        profilePhotoUrl = upload.url;
      }

      await _profileRepository.updateProfilePreferences(
        uid: firebaseUser.uid,
        photoUrl: profilePhotoUrl,
        allowContactRequests: _allowContactRequests,
        allowAnonymousReports: _allowAnonymousReports,
      );
      final loadedProfile = _loadedProfile;
      if (loadedProfile != null) {
        await _profileRepository.updatePublicProfile(
          profile: loadedProfile,
          displayName: loadedProfile.displayName,
          publicBio: _publicBioController.text,
          publicRegion: _publicRegionController.text,
          showVehicleOnPublicProfile: loadedProfile.showVehicleOnPublicProfile,
          showPlateOnPublicProfile: loadedProfile.showPlateOnPublicProfile,
          isPrivateProfile: loadedProfile.isPrivateProfile,
          profileAccessEnabled: loadedProfile.profileAccessEnabled,
          followersVisibility: loadedProfile.followersVisibility,
          followingVisibility: loadedProfile.followingVisibility,
        );
      }
      final draft = _profileDraft;
      await _plateRepository.updatePlateProfileVisibility(
        profile: firestore_profile.UserProfile(
          uid: firebaseUser.uid,
          email: firebaseUser.email ?? '',
          firstName: draft.firstName,
          lastName: draft.lastName,
          displayName: _displayName,
          country: draft.countryCode,
          countryCode: draft.countryCode,
          plateRegion: draft.region,
          plateLetters: draft.letters,
          plateNumbers: draft.numbers,
          vehicleBrand: draft.brand,
          vehicleModel: draft.model,
          vehicleColor: draft.color,
          allowContactRequests: _allowContactRequests,
          allowAnonymousReports: _allowAnonymousReports,
          photoUrl: profilePhotoUrl,
          verificationStatus: _isVerified
              ? 'verified'
              : _isSubmittedForVerification
              ? 'pending'
              : _isVerificationRejected
              ? 'rejected'
              : 'draft',
        ),
      );
      await _syncFirebaseUserProfile(
        firebaseUser,
        displayName: null,
        photoUrl: profilePhotoUrl,
      );

      if (!mounted) {
        return false;
      }

      setState(() {
        _isSaving = false;
        _hasUnsavedChanges = false;
        _profilePhoto = null;
        _profilePhotoUrl = profilePhotoUrl;
        _profilePhotoRemoved = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profilbild und Sichtbarkeit wurden gespeichert.'),
        ),
      );
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_profileSaveErrorMessage(error))));
      return false;
    }
  }

  String _profileSaveErrorMessage(Object error) {
    if (error is ProfileMediaStorageException) {
      return error.message;
    }

    return 'Profil konnte gerade nicht gespeichert werden. Bitte prüfe deine Verbindung und Berechtigungen.';
  }

  Future<void> _syncFirebaseUserProfile(
    User firebaseUser, {
    required String? displayName,
    required String? photoUrl,
  }) async {
    final nextDisplayName = displayName?.trim();
    final nextPhotoUrl = photoUrl?.trim();
    final currentDisplayName = firebaseUser.displayName?.trim();
    final currentPhotoUrl = firebaseUser.photoURL?.trim();

    if (currentPhotoUrl != null && currentPhotoUrl.isNotEmpty) {
      await NetworkImage(currentPhotoUrl).evict();
    }

    if (nextDisplayName != null &&
        nextDisplayName.isNotEmpty &&
        nextDisplayName != currentDisplayName) {
      await firebaseUser.updateDisplayName(nextDisplayName);
    }

    if (nextPhotoUrl != currentPhotoUrl) {
      await firebaseUser.updatePhotoURL(
        nextPhotoUrl == null || nextPhotoUrl.isEmpty ? null : nextPhotoUrl,
      );
    }

    if (nextPhotoUrl != null && nextPhotoUrl.isNotEmpty) {
      await NetworkImage(nextPhotoUrl).evict();
    }
  }

  // Legacy widget kept temporarily for migration-only state rendering.
  // ignore: unused_element
  Widget _buildVerificationEditor() {
    return _VerificationScreen(
      imagePicker: _imagePicker,
      documentFiles: _documentFiles,
      documentRemoteUrls: _documentRemoteUrlsByTitle,
      displayName: _displayName,
      displayPlate: _displayPlate,
      selectedBrand: _selectedBrand,
      selectedModel: _selectedModel,
      selectedColor: _selectedColor,
      hasPlateInput: _hasPlateInput,
      isLocked: _isProfileLocked,
      onSubmitVerification: _saveProfile,
      onDocumentUpload: (documentName, file) {
        if (_isProfileLocked) return;
        setState(() {
          _documentFiles[documentName] = file;
          _documentRemoteUrlsByTitle[documentName] = null;
          _hasUnsavedChanges = true;
        });
      },
      onDocumentRemove: (documentName) {
        if (_isProfileLocked) return;
        setState(() {
          _documentFiles[documentName] = null;
          _documentRemoteUrlsByTitle[documentName] = null;
          _hasUnsavedChanges = true;
        });
      },
    );
  }

  Future<void> _openVerificationScreen() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            ProfileVerificationScreen(userId: widget.userState.userId),
      ),
    );
  }

  Widget _buildDirectPersonalDataEntry() {
    final loadError = _profileLoadError;
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleBack();
      },
      child: CaRismaBackground(
        child: Material(
          color: Colors.transparent,
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
                return SingleChildScrollView(
                  controller: _scrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + keyboardInset),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 28,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CaRismaSubPageHeader(
                          icon: Icons.badge_outlined,
                          title: 'Persönliche Daten',
                          onBack: _handleBack,
                        ),
                        const SizedBox(height: 10),
                        if (_isLoadingProfile)
                          const GlassCard(
                            padding: EdgeInsets.all(28),
                            child: Center(
                              child: SizedBox.square(
                                dimension: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          )
                        else if (loadError != null)
                          CaRismaMessageCard(
                            icon: Icons.error_outline_rounded,
                            message: loadError,
                          )
                        else ...[
                          _PersonalProfilePhotoCard(
                            displayName: _displayName,
                            profilePhoto: _profilePhoto,
                            profilePhotoUrl: _profilePhotoUrl,
                            onTap: _showProfilePhotoSourceSheet,
                          ),
                          const SizedBox(height: 10),
                          _NameCard(
                            firstNameController: _firstNameController,
                            lastNameController: _lastNameController,
                            birthDateController: _birthDateController,
                            birthDateError: _birthDateError,
                            accountEmail:
                                FirebaseAuth.instance.currentUser?.email ??
                                'Keine E-Mail hinterlegt',
                            mfaPhoneLabel: _mfaPhoneLabel,
                            isMfaLoading: _isLoadingMfaStatus,
                            isLocked: _isPersonalDataLocked || _isProfileLocked,
                            hasMfaPhone: _hasMfaPhone,
                            onBirthDateChanged: _handleBirthDateChanged,
                            onManageMfa: _openMfaManagement,
                          ),
                          const SizedBox(height: 12),
                          _SaveProfileButton(
                            isEnabled: _hasUnsavedChanges && !_isSaving,
                            isLoading: _isSaving,
                            canSubmitProfileForVerification: false,
                            onPressed: _handlePersonalDataSave,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDirectDocumentsEntry() {
    return _documentsEntryChild;
  }

  Future<void> _confirmNewProfile() async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF101827),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Neues Profil hinzufügen?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          content: const Text(
            'Wenn du ein neues Profil hinzufügst, wird dein altes Profil gelöscht. Dein neues Profil muss anschließend erneut verifiziert werden.',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Abbrechen',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Neues Profil',
                style: TextStyle(
                  color: CaRismaDesignTokens.bluePrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldReset != true) {
      return;
    }

    setState(() {
      _firstNameController.clear();
      _lastNameController.clear();
      _phoneNumberController.clear();
      _birthDate = null;

      _regionController.clear();
      _lettersController.clear();
      _numbersController.clear();

      _countryCode = 'DE';
      _selectedBrand = 'BMW';
      _selectedModel = '1er';
      _selectedColor = 'Schwarz';

      _allowContactRequests = true;
      _allowAnonymousReports = true;

      for (final key in _documentFiles.keys.toList()) {
        _documentFiles[key] = null;
        _documentRemoteUrlsByTitle[key] = null;
      }

      _isSubmittedForVerification = false;
      _isVerified = false;
      _isVerificationRejected = false;
      _verificationSubmittedAt = null;
      _verificationReviewedAt = null;
      _verificationRejectionReason = null;
      _hasUnsavedChanges = false;
      _isSaving = false;
    });

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Neues Profil angelegt. Bitte fülle alle Daten aus.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.initialEntry == ProfileEditorEntry.personalData ||
        widget.initialEntry == ProfileEditorEntry.overview) {
      return _buildDirectPersonalDataEntry();
    }
    if (widget.initialEntry == ProfileEditorEntry.documents) {
      return _buildDirectDocumentsEntry();
    }

    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomSpacing = widget.initialEntry == ProfileEditorEntry.overview
        ? 112.0
        : 28.0;

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleBack();
      },
      child: CaRismaBackground(
        child: Material(
          color: Colors.transparent,
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  controller: _scrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    20,
                    18,
                    20,
                    bottomSpacing + keyboardInset,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - bottomSpacing,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.initialEntry == ProfileEditorEntry.overview)
                          const CaRismaPageHeader(
                            icon: Icons.person_rounded,
                            title: 'Profil',
                          )
                        else
                          CaRismaSubPageHeader(
                            icon:
                                widget.initialEntry ==
                                    ProfileEditorEntry.documents
                                ? Icons.upload_file_rounded
                                : Icons.badge_outlined,
                            title: _entryTitle,
                            onBack: _handleBack,
                          ),
                        const SizedBox(height: 14),
                        Text(
                          'Verwalte deine Identität, dein Fahrzeug und deine Sichtbarkeit.',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.78),
                                fontWeight: FontWeight.w700,
                                fontSize: 16.5,
                                height: 1.35,
                              ),
                        ),
                        const SizedBox(height: 16),
                        _ProfileStatusCard(
                          displayName: _displayName,
                          profilePhoto: _profilePhoto,
                          profilePhotoUrl: _profilePhotoUrl,
                          isSubmittedForVerification:
                              _isSubmittedForVerification,
                          isVerified: _isVerified,
                          isVerificationRejected: _isVerificationRejected,
                          verificationSubmittedAt: _verificationSubmittedAt,
                          verificationReviewedAt: _verificationReviewedAt,
                          verificationRejectionReason:
                              _verificationRejectionReason,
                          uploadedDocumentCount: _uploadedDocumentCount,
                          totalDocumentCount: _documentFiles.length,
                          onProfilePhotoTap: _showProfilePhotoSourceSheet,
                        ),
                        const SizedBox(height: 14),
                        _ProfileNextStepCard(
                          hasNameInput: _hasNameInput,
                          hasPlateInput: _hasPlateInput,
                          allDocumentsUploaded: _allDocumentsUploaded,
                          canSubmitProfileForVerification:
                              _canSubmitProfileForVerification,
                          isSubmittedForVerification:
                              _isSubmittedForVerification,
                          isVerified: _isVerified,
                          isVerificationRejected: _isVerificationRejected,
                          isSaving: _isSaving,
                          onOpenVerification: _openVerificationScreen,
                          onSaveProfile: _saveProfile,
                        ),
                        if (_isVerificationRejected) ...[
                          const SizedBox(height: 14),
                          _RejectedVerificationActionCard(
                            rejectionReason: _verificationRejectionReason,
                            reviewedAt: _verificationReviewedAt,
                            canSubmitProfileForVerification:
                                _canSubmitProfileForVerification,
                            isSaving: _isSaving,
                            onOpenVerification: _openVerificationScreen,
                            onSaveProfile: _saveProfile,
                            onCreateNewProfile: _confirmNewProfile,
                          ),
                        ],
                        if (_isProfileLocked) ...[
                          const SizedBox(height: 14),
                          _LockedProfileCard(
                            isVerified: _isVerified,
                            onCreateNewProfile: _confirmNewProfile,
                          ),
                        ],
                        const SizedBox(height: 18),
                        KeyedSubtree(
                          key: _personalDataSectionKey,
                          child: const CaRismaSectionTitle(
                            number: '1',
                            title: 'Persönliche Daten',
                          ),
                        ),
                        const SizedBox(height: 10),
                        _NameCard(
                          firstNameController: _firstNameController,
                          lastNameController: _lastNameController,
                          birthDateController: _birthDateController,
                          birthDateError: _birthDateError,
                          accountEmail:
                              FirebaseAuth.instance.currentUser?.email ??
                              'Keine E-Mail hinterlegt',
                          mfaPhoneLabel: _mfaPhoneLabel,
                          isMfaLoading: _isLoadingMfaStatus,
                          isLocked: _isPersonalDataLocked || _isProfileLocked,
                          hasMfaPhone: _hasMfaPhone,
                          onBirthDateChanged: _handleBirthDateChanged,
                          onManageMfa: _openMfaManagement,
                        ),
                        const SizedBox(height: 18),
                        const CaRismaSectionTitle(
                          number: '2',
                          title: 'Verifizierung',
                        ),
                        const SizedBox(height: 10),
                        _VerificationSummaryCard(
                          uploadedDocumentCount: _uploadedDocumentCount,
                          totalDocumentCount: _documentFiles.length,
                          verificationProgress: _verificationProgress,
                          allDocumentsUploaded: _allDocumentsUploaded,
                          onOpenVerification: _openVerificationScreen,
                        ),
                        const SizedBox(height: 18),
                        const CaRismaSectionTitle(
                          number: '3',
                          title: 'Mein Fahrzeug',
                        ),
                        const SizedBox(height: 10),
                        CaRismaCountrySelectorCard(
                          selectedCountryCode: _countryCode,
                          isLocked: _isProfileLocked,
                          onChanged: _changeCountry,
                        ),
                        const SizedBox(height: 12),
                        CaRismaPlateInputCard(
                          countryCode: _countryCode,
                          regionController: _regionController,
                          lettersController: _lettersController,
                          numbersController: _numbersController,
                          regionFocusNode: _regionFocusNode,
                          lettersFocusNode: _lettersFocusNode,
                          numbersFocusNode: _numbersFocusNode,
                          isLocked: _isProfileLocked,
                          onRegionChanged: _handleRegionChanged,
                          onLettersChanged: _handleLettersChanged,
                          onNumbersChanged: _handleNumbersChanged,
                        ),
                        const SizedBox(height: 12),
                        _VehicleDataCard(
                          selectedBrand: _selectedBrand,
                          selectedModel: _selectedModel,
                          selectedColor: _selectedColor,
                          brands: VehicleCatalog.brands,
                          models:
                              VehicleCatalog.modelsByBrand[_selectedBrand] ??
                              const [],
                          vehicleColors: _vehicleColors,
                          isLocked: _isProfileLocked,
                          onBrandChanged: _onBrandChanged,
                          onModelChanged: _onModelChanged,
                          onColorChanged: _onColorChanged,
                        ),
                        const SizedBox(height: 18),
                        const CaRismaSectionTitle(
                          number: '4',
                          title: 'Sichtbarkeit',
                        ),
                        const SizedBox(height: 10),
                        _VisibilityCard(
                          allowContactRequests: _allowContactRequests,
                          allowAnonymousReports: _allowAnonymousReports,
                          onContactRequestsChanged: (value) {
                            setState(() {
                              _allowContactRequests = value;
                              _hasUnsavedChanges = true;
                            });
                          },
                          onAnonymousReportsChanged: (value) {
                            setState(() {
                              _allowAnonymousReports = value;
                              _hasUnsavedChanges = true;
                            });
                          },
                        ),
                        const SizedBox(height: 18),
                        if (!_isProfileLocked || _hasUnsavedChanges) ...[
                          _SaveProfileButton(
                            isEnabled: _hasUnsavedChanges && !_isSaving,
                            isLoading: _isSaving,
                            canSubmitProfileForVerification:
                                !_isProfileLocked &&
                                _canSubmitProfileForVerification,
                            onPressed: _saveProfile,
                          ),
                          if (_isProfileLocked) const SizedBox(height: 12),
                        ],
                        if (_isProfileLocked)
                          _NewProfileButton(onPressed: _confirmNewProfile),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileNextStepCard extends StatelessWidget {
  const _ProfileNextStepCard({
    required this.hasNameInput,
    required this.hasPlateInput,
    required this.allDocumentsUploaded,
    required this.canSubmitProfileForVerification,
    required this.isSubmittedForVerification,
    required this.isVerified,
    required this.isVerificationRejected,
    required this.isSaving,
    required this.onOpenVerification,
    required this.onSaveProfile,
  });

  final bool hasNameInput;
  final bool hasPlateInput;
  final bool allDocumentsUploaded;
  final bool canSubmitProfileForVerification;
  final bool isSubmittedForVerification;
  final bool isVerified;
  final bool isVerificationRejected;
  final bool isSaving;
  final VoidCallback onOpenVerification;
  final VoidCallback onSaveProfile;

  String get _title {
    if (isVerified) {
      return 'Profil vollständig verifiziert';
    }

    if (isSubmittedForVerification) {
      return 'Verifizierung wird geprüft';
    }

    if (isVerificationRejected) {
      return 'Verifizierung korrigieren';
    }

    if (!hasNameInput) {
      return 'Persönliche Daten ergänzen';
    }

    if (!hasPlateInput) {
      return 'Fahrzeug und Kennzeichen ergänzen';
    }

    if (!allDocumentsUploaded) {
      return 'Dokumente hochladen';
    }

    return 'Profil einreichen';
  }

  String get _description {
    if (isVerified) {
      return 'Dein Profil ist freigeschaltet. Profilbild und Sichtbarkeit kannst du weiterhin ändern.';
    }

    if (isSubmittedForVerification) {
      return 'Name, Fahrzeugdaten und Dokumente sind jetzt gesperrt, bis die Prüfung abgeschlossen ist.';
    }

    if (isVerificationRejected) {
      return 'Prüfe deine Angaben und lade bei Bedarf neue Dokumente hoch. Danach kannst du dein Profil erneut einreichen.';
    }

    if (!hasNameInput) {
      return 'Trage unten Vorname und Nachname ein. Nach der Verifizierung werden diese Daten geschützt gesperrt.';
    }

    if (!hasPlateInput) {
      return 'Ergänze dein Kennzeichen und die Fahrzeugdaten, damit dein Fahrzeug eindeutig zugeordnet werden kann.';
    }

    if (!allDocumentsUploaded) {
      return 'Lade Ausweis, Führerschein und Fahrzeugschein hoch, damit du dein Profil einreichen kannst.';
    }

    return 'Alle Pflichtdaten sind vorhanden. Speichere dein Profil, um die Verifizierung einzureichen.';
  }

  IconData get _icon {
    if (isVerified) {
      return Icons.verified_rounded;
    }

    if (isSubmittedForVerification) {
      return Icons.pending_actions_rounded;
    }

    if (isVerificationRejected) {
      return Icons.edit_document;
    }

    if (!hasNameInput) {
      return Icons.badge_outlined;
    }

    if (!hasPlateInput) {
      return Icons.directions_car_outlined;
    }

    if (!allDocumentsUploaded) {
      return Icons.upload_file_rounded;
    }

    return Icons.check_circle_outline_rounded;
  }

  bool get _showDocumentButton {
    return !isVerified &&
        !isSubmittedForVerification &&
        hasNameInput &&
        hasPlateInput &&
        (!allDocumentsUploaded || isVerificationRejected);
  }

  bool get _showSubmitButton {
    return !isVerified &&
        !isSubmittedForVerification &&
        canSubmitProfileForVerification;
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CaRismaBlueIconBox(icon: _icon, size: 48, iconSize: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontWeight: FontWeight.w700,
                        height: 1.34,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_showDocumentButton) ...[
            const SizedBox(height: 14),
            CaRismaPrimaryButton(
              label: 'Dokumente hochladen',
              icon: Icons.arrow_forward_rounded,
              onPressed: onOpenVerification,
            ),
          ],
          if (_showSubmitButton) ...[
            const SizedBox(height: 14),
            CaRismaPrimaryButton(
              label: 'Profil speichern und einreichen',
              loadingLabel: 'Wird gespeichert...',
              icon: Icons.verified_user_rounded,
              isLoading: isSaving,
              onPressed: onSaveProfile,
            ),
          ],
        ],
      ),
    );
  }
}

class _RejectedVerificationActionCard extends StatelessWidget {
  const _RejectedVerificationActionCard({
    required this.rejectionReason,
    required this.reviewedAt,
    required this.canSubmitProfileForVerification,
    required this.isSaving,
    required this.onOpenVerification,
    required this.onSaveProfile,
    required this.onCreateNewProfile,
  });

  final String? rejectionReason;
  final DateTime? reviewedAt;
  final bool canSubmitProfileForVerification;
  final bool isSaving;
  final VoidCallback onOpenVerification;
  final VoidCallback onSaveProfile;
  final VoidCallback onCreateNewProfile;

  String get _reasonText {
    final reason = rejectionReason?.trim();

    if (reason == null || reason.isEmpty) {
      return 'Bitte prüfe deine Angaben und lade die betroffenen Dokumente erneut hoch.';
    }

    return reason;
  }

  String? get _reviewText {
    if (reviewedAt == null) {
      return null;
    }

    final localValue = reviewedAt!.toLocal();
    final day = localValue.day.toString().padLeft(2, '0');
    final month = localValue.month.toString().padLeft(2, '0');
    final year = localValue.year.toString();
    final hour = localValue.hour.toString().padLeft(2, '0');
    final minute = localValue.minute.toString().padLeft(2, '0');

    return 'Geprüft am $day.$month.$year um $hour:$minute Uhr';
  }

  @override
  Widget build(BuildContext context) {
    final reviewText = _reviewText;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CaRismaBlueIconBox(
                icon: Icons.error_outline_rounded,
                size: 46,
                iconSize: 24,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verifizierung erneut einreichen',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    if (reviewText != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        reviewText,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.56),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: const Color(0xFFFF7D7D).withValues(alpha: 0.10),
              border: Border.all(
                color: const Color(0xFFFF7D7D).withValues(alpha: 0.28),
              ),
            ),
            child: Text(
              _reasonText,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.82),
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _RejectedVerificationStep(
            icon: Icons.edit_rounded,
            text: 'Korrigiere Name, Kennzeichen oder Fahrzeugdaten.',
          ),
          const SizedBox(height: 8),
          _RejectedVerificationStep(
            icon: Icons.upload_file_rounded,
            text: 'Ersetze unlesbare oder falsche Dokumente.',
          ),
          const SizedBox(height: 8),
          _RejectedVerificationStep(
            icon: Icons.verified_user_rounded,
            text: 'Reiche dein Profil danach erneut zur Prüfung ein.',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: CaRismaSecondaryButton(
                  label: 'Dokumente prüfen',
                  icon: Icons.folder_open_rounded,
                  onPressed: onOpenVerification,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CaRismaPrimaryButton(
                  label: 'Erneut einreichen',
                  loadingLabel: 'Wird eingereicht...',
                  icon: Icons.send_rounded,
                  isLoading: isSaving,
                  isEnabled: canSubmitProfileForVerification,
                  onPressed: onSaveProfile,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          CaRismaSecondaryButton(
            label: 'Neues Profil starten',
            icon: Icons.person_add_alt_1_rounded,
            onPressed: onCreateNewProfile,
          ),
        ],
      ),
    );
  }
}

class _RejectedVerificationStep extends StatelessWidget {
  const _RejectedVerificationStep({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: CaRismaDesignTokens.bluePrimary, size: 19),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.72),
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}

class _VisibilityCard extends StatelessWidget {
  const _VisibilityCard({
    required this.allowContactRequests,
    required this.allowAnonymousReports,
    required this.onContactRequestsChanged,
    required this.onAnonymousReportsChanged,
  });

  final bool allowContactRequests;
  final bool allowAnonymousReports;
  final ValueChanged<bool> onContactRequestsChanged;
  final ValueChanged<bool> onAnonymousReportsChanged;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          CaRismaSwitchRow(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Kontaktanfragen erlauben',
            description:
                'Andere können dich über dein Kennzeichen geschützt kontaktieren.',
            value: allowContactRequests,
            enabled: true,
            onChanged: onContactRequestsChanged,
          ),
          const SizedBox(height: 10),
          CaRismaSwitchRow(
            icon: Icons.report_outlined,
            title: 'Anonyme Hinweise erlauben',
            description:
                'Andere können dir sachliche Hinweise zu deinem Fahrzeug senden.',
            value: allowAnonymousReports,
            enabled: true,
            onChanged: onAnonymousReportsChanged,
          ),
        ],
      ),
    );
  }
}

class _VerificationScreen extends StatefulWidget {
  const _VerificationScreen({
    required this.imagePicker,
    required this.documentFiles,
    required this.documentRemoteUrls,
    required this.displayName,
    required this.displayPlate,
    required this.selectedBrand,
    required this.selectedModel,
    required this.selectedColor,
    required this.hasPlateInput,
    required this.isLocked,
    required this.onSubmitVerification,
    required this.onDocumentUpload,
    required this.onDocumentRemove,
  });

  final ImagePicker imagePicker;
  final Map<String, XFile?> documentFiles;
  final Map<String, String?> documentRemoteUrls;
  final String displayName;
  final String displayPlate;
  final String selectedBrand;
  final String selectedModel;
  final String selectedColor;
  final bool hasPlateInput;
  final bool isLocked;
  final Future<bool> Function() onSubmitVerification;
  final void Function(String documentName, XFile file) onDocumentUpload;
  final ValueChanged<String> onDocumentRemove;

  @override
  State<_VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<_VerificationScreen> {
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;

  int get _uploadedDocumentCount {
    return widget.documentFiles.keys.where(_isDocumentUploaded).length;
  }

  bool get _allDocumentsUploaded {
    return widget.documentFiles.keys.every(_isDocumentUploaded);
  }

  double get _verificationProgress {
    return _uploadedDocumentCount / widget.documentFiles.length;
  }

  void _clearMessages() {
    _errorMessage = null;
    _successMessage = null;
  }

  bool _isDocumentUploaded(String title) {
    final remoteUrl = widget.documentRemoteUrls[title]?.trim();

    return widget.documentFiles[title] != null ||
        (remoteUrl != null && remoteUrl.isNotEmpty);
  }

  Future<void> _showUploadSourceSheet(String documentName) async {
    if (widget.isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Dieses Profil ist gesperrt. Erstelle ein neues Profil, um Dokumente erneut hochzuladen.',
          ),
        ),
      );
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: GlassCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SheetActionButton(
                    label: 'Foto aus Aufnahmen wählen',
                    icon: Icons.photo_library_rounded,
                    onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                  ),
                  const SizedBox(height: 10),
                  _SheetActionButton(
                    label: 'Kamera öffnen',
                    icon: Icons.photo_camera_rounded,
                    onTap: () => Navigator.of(context).pop(ImageSource.camera),
                  ),
                  const SizedBox(height: 10),
                  _SheetSecondaryActionButton(
                    label: 'Abbrechen',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (source == null) {
      return;
    }

    await _pickDocumentImage(documentName, source);
  }

  Future<void> _pickDocumentImage(
    String documentName,
    ImageSource source,
  ) async {
    setState(() {
      _clearMessages();
    });

    try {
      final image = await widget.imagePicker.pickImage(
        source: source,
        imageQuality: 86,
        maxWidth: 1800,
      );

      if (image == null) {
        return;
      }

      widget.onDocumentUpload(documentName, image);

      if (!mounted) {
        return;
      }

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$documentName wurde ausgewählt.')),
      );
    } catch (_) {
      setState(() {
        _errorMessage =
            'Bild konnte nicht geladen werden. Bitte prüfe Kamera- oder Fotoberechtigung.';
        _successMessage = null;
      });
    }
  }

  Future<void> _submitVerification() async {
    if (!_allDocumentsUploaded) {
      setState(() {
        _errorMessage = 'Bitte lade zuerst alle Pflichtdokumente hoch.';
        _successMessage = null;
      });
      return;
    }

    if (!widget.hasPlateInput) {
      setState(() {
        _errorMessage =
            'Bitte gib im Profil zuerst ein vollständiges Kennzeichen an.';
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _clearMessages();
    });

    final submitted = await widget.onSubmitVerification();

    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
      if (!submitted) {
        _errorMessage =
            'Verifizierung konnte nicht eingereicht werden. Bitte prüfe die Angaben und versuche es erneut.';
      }
    });

    if (submitted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return CaRismaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(20, 18, 20, 28 + keyboardInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CaRismaSubPageHeader(
                  icon: Icons.verified_user_rounded,
                  title: 'Verifizierung',
                  onBack: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 18),
                Text(
                  'Lade deine Dokumente hoch. Dein Konto und dein Fahrzeug werden erst nach Prüfung freigegeben.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w700,
                    fontSize: 16.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                _VerificationVehicleCard(
                  displayName: widget.displayName,
                  displayPlate: widget.displayPlate,
                  selectedBrand: widget.selectedBrand,
                  selectedModel: widget.selectedModel,
                  selectedColor: widget.selectedColor,
                ),
                const SizedBox(height: 18),
                const CaRismaSectionTitle(
                  number: '1',
                  title: 'Pflichtdokumente',
                ),
                const SizedBox(height: 10),
                _DocumentUploadCard(
                  documentFiles: widget.documentFiles,
                  documentRemoteUrls: widget.documentRemoteUrls,
                  uploadedDocumentCount: _uploadedDocumentCount,
                  totalDocumentCount: widget.documentFiles.length,
                  verificationProgress: _verificationProgress,
                  isLocked: widget.isLocked,
                  onDocumentTap: _showUploadSourceSheet,
                  onDocumentRemove: (documentName) {
                    widget.onDocumentRemove(documentName);
                    setState(() {});
                  },
                ),
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
                if (!widget.isLocked)
                  _SubmitVerificationButton(
                    isEnabled: !_isSubmitting,
                    isLoading: _isSubmitting,
                    allDocumentsUploaded: _allDocumentsUploaded,
                    onPressed: _submitVerification,
                  )
                else
                  const _InlineStatusBox(
                    icon: Icons.lock_outline_rounded,
                    text:
                        'Diese Dokumente sind gesperrt, solange die Verifizierung aussteht oder abgeschlossen ist.',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileStatusCard extends StatelessWidget {
  const _ProfileStatusCard({
    required this.displayName,
    required this.profilePhoto,
    required this.profilePhotoUrl,
    required this.isSubmittedForVerification,
    required this.isVerified,
    required this.isVerificationRejected,
    required this.verificationSubmittedAt,
    required this.verificationReviewedAt,
    required this.verificationRejectionReason,
    required this.uploadedDocumentCount,
    required this.totalDocumentCount,
    required this.onProfilePhotoTap,
  });

  final String displayName;
  final XFile? profilePhoto;
  final String? profilePhotoUrl;
  final bool isSubmittedForVerification;
  final bool isVerified;
  final bool isVerificationRejected;
  final DateTime? verificationSubmittedAt;
  final DateTime? verificationReviewedAt;
  final String? verificationRejectionReason;
  final int uploadedDocumentCount;
  final int totalDocumentCount;
  final VoidCallback onProfilePhotoTap;

  String get _statusText {
    if (isVerified) {
      return 'Verifiziert';
    }

    if (isSubmittedForVerification) {
      return 'Verifizierung ausstehend';
    }

    if (isVerificationRejected) {
      return 'Verifizierung abgelehnt';
    }

    return 'Verifizierung nicht eingereicht';
  }

  Color get _statusColor {
    if (isVerified) {
      return CaRismaDesignTokens.bluePrimary;
    }

    if (isSubmittedForVerification) {
      return const Color(0xFFFFD58A);
    }

    if (isVerificationRejected) {
      return const Color(0xFFFF7D7D);
    }

    return Colors.white70;
  }

  String? get _rejectionText {
    final reason = verificationRejectionReason?.trim();

    if (!isVerificationRejected || reason == null || reason.isEmpty) {
      return isVerificationRejected
          ? 'Bitte prüfe deine Angaben und reiche die Verifizierung erneut ein.'
          : null;
    }

    return reason;
  }

  String? get _submittedAtText {
    if (!isSubmittedForVerification || verificationSubmittedAt == null) {
      return null;
    }

    return 'Eingereicht am ${_formatDateTime(verificationSubmittedAt!)}';
  }

  String? get _reviewedAtText {
    if ((!isVerified && !isVerificationRejected) ||
        verificationReviewedAt == null) {
      return null;
    }

    final prefix = isVerified ? 'Verifiziert am' : 'Geprüft am';

    return '$prefix ${_formatDateTime(verificationReviewedAt!)}';
  }

  String _formatDateTime(DateTime value) {
    final localValue = value.toLocal();
    final day = localValue.day.toString().padLeft(2, '0');
    final month = localValue.month.toString().padLeft(2, '0');
    final year = localValue.year.toString();
    final hour = localValue.hour.toString().padLeft(2, '0');
    final minute = localValue.minute.toString().padLeft(2, '0');

    return '$day.$month.$year um $hour:$minute Uhr';
  }

  @override
  Widget build(BuildContext context) {
    final submittedAtText = _submittedAtText;
    final reviewedAtText = _reviewedAtText;
    final rejectionText = _rejectionText;

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          _ProfilePhotoButton(
            size: 64,
            profilePhoto: profilePhoto,
            profilePhotoUrl: profilePhotoUrl,
            onTap: onProfilePhotoTap,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  _statusText,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _statusColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (submittedAtText != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    submittedAtText,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (reviewedAtText != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    reviewedAtText,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (rejectionText != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    rejectionText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  '$uploadedDocumentCount von $totalDocumentCount Dokumenten ausgewählt',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.56),
                    fontWeight: FontWeight.w700,
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

class _ProfilePhotoButton extends StatelessWidget {
  const _ProfilePhotoButton({
    required this.size,
    required this.profilePhoto,
    required this.profilePhotoUrl,
    required this.onTap,
  });

  final double size;
  final XFile? profilePhoto;
  final String? profilePhotoUrl;
  final VoidCallback onTap;

  Widget _placeholder() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: Icon(
            Icons.person_rounded,
            color: CaRismaDesignTokens.bluePrimary,
            size: size * 0.50,
          ),
        ),
        Positioned(
          right: size * 0.08,
          bottom: size * 0.08,
          child: Container(
            width: size * 0.27,
            height: size * 0.27,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: CaRismaDesignTokens.bluePrimary,
              border: Border.all(
                color: CaRismaDesignTokens.surface2,
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.add_rounded,
              color: Colors.white,
              size: size * 0.19,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final image = profilePhoto;
    final imageUrl = profilePhotoUrl?.trim();
    final radius = size * 0.30;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Semantics(
        button: true,
        label: 'Profilbild hinzufügen oder ändern',
        child: Container(
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
            child: image != null
                ? Image.file(
                    File(image.path),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _placeholder();
                    },
                  )
                : imageUrl != null && imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _placeholder();
                    },
                  )
                : _placeholder(),
          ),
        ),
      ),
    );
  }
}

class _LockedProfileCard extends StatelessWidget {
  const _LockedProfileCard({
    required this.isVerified,
    required this.onCreateNewProfile,
  });

  final bool isVerified;
  final VoidCallback onCreateNewProfile;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _InlineStatusBox(
            icon: Icons.lock_outline_rounded,
            text: isVerified
                ? 'Dieses Profil ist verifiziert und kann nicht mehr geändert werden. Profilbild und Sichtbarkeit kannst du weiterhin ändern.'
                : 'Deine Verifizierung ist ausstehend. Name, Fahrzeugdaten und Dokumente sind gesperrt. Profilbild und Sichtbarkeit kannst du weiterhin ändern.',
          ),
          const SizedBox(height: 12),
          _SecondaryFullWidthButton(
            label: 'Neues Profil hinzufügen',
            icon: Icons.person_add_alt_1_rounded,
            onTap: onCreateNewProfile,
          ),
        ],
      ),
    );
  }
}

class _PersonalProfilePhotoCard extends StatelessWidget {
  const _PersonalProfilePhotoCard({
    required this.displayName,
    required this.profilePhoto,
    required this.profilePhotoUrl,
    required this.onTap,
  });

  final String displayName;
  final XFile? profilePhoto;
  final String? profilePhotoUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          _ProfilePhotoButton(
            size: 52,
            profilePhoto: profilePhoto,
            profilePhotoUrl: profilePhotoUrl,
            onTap: onTap,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: CaRismaDesignTokens.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NameCard extends StatelessWidget {
  const _NameCard({
    required this.firstNameController,
    required this.lastNameController,
    required this.birthDateController,
    required this.birthDateError,
    required this.accountEmail,
    required this.mfaPhoneLabel,
    required this.isMfaLoading,
    required this.isLocked,
    required this.hasMfaPhone,
    required this.onBirthDateChanged,
    required this.onManageMfa,
  });

  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController birthDateController;
  final String? birthDateError;
  final String accountEmail;
  final String mfaPhoneLabel;
  final bool isMfaLoading;
  final bool isLocked;
  final bool hasMfaPhone;
  final ValueChanged<String> onBirthDateChanged;
  final VoidCallback onManageMfa;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _ProfileTextField(
            controller: firstNameController,
            hintText: 'Vorname',
            icon: Icons.badge_outlined,
            textCapitalization: TextCapitalization.words,
            enabled: !isLocked,
            showLockIcon: isLocked,
          ),
          const SizedBox(height: 9),
          _ProfileTextField(
            controller: lastNameController,
            hintText: 'Nachname',
            icon: Icons.badge_outlined,
            textCapitalization: TextCapitalization.words,
            enabled: !isLocked,
            showLockIcon: isLocked,
          ),
          const SizedBox(height: 9),
          _ProfileTextField(
            controller: birthDateController,
            hintText: 'TT.MM.JJJJ',
            icon: Icons.cake_outlined,
            textCapitalization: TextCapitalization.none,
            keyboardType: TextInputType.number,
            enabled: !isLocked,
            showLockIcon: isLocked,
            inputFormatters: const [_BirthDateInputFormatter()],
            onChanged: onBirthDateChanged,
            errorText: birthDateError,
            helperText: 'Mindestalter: 16 Jahre',
          ),
          const SizedBox(height: 9),
          _MfaPhoneField(
            value: mfaPhoneLabel,
            isLoading: isMfaLoading,
            isRegistered: hasMfaPhone,
            onTap: onManageMfa,
          ),
          const SizedBox(height: 9),
          _ReadOnlyProfileField(
            icon: Icons.alternate_email_rounded,
            label: 'E-Mail Adresse',
            value: accountEmail,
          ),
          const SizedBox(height: 9),
          const _InlineStatusBox(
            icon: Icons.info_outline_rounded,
            text:
                'Geburtsdatum, Telefonnummer und\nE-Mail Adresse bleiben privat.',
            fixedLines: [
              'Geburtsdatum, Telefonnummer und',
              'E-Mail Adresse bleiben privat.',
            ],
          ),
        ],
      ),
    );
  }
}

class _MfaPhoneField extends StatelessWidget {
  const _MfaPhoneField({
    required this.value,
    required this.isLoading,
    required this.isRegistered,
    required this.onTap,
  });

  final String value;
  final bool isLoading;
  final bool isRegistered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isLoading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: CaRismaDesignTokens.controlSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 24,
              child: Center(
                child: isLoading
                    ? const SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(strokeWidth: 1.8),
                      )
                    : Icon(
                        Icons.phone_iphone_rounded,
                        color: Colors.white.withValues(alpha: 0.66),
                        size: 23,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Telefonnummer',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: CaRismaDesignTokens.textMuted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: CaRismaDesignTokens.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Im Zwei-Faktor-Schutz verwalten',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: CaRismaDesignTokens.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isRegistered
                  ? Icons.lock_outline_rounded
                  : Icons.chevron_right_rounded,
              color: CaRismaDesignTokens.textMuted,
              size: isRegistered ? 19 : 21,
            ),
          ],
        ),
      ),
    );
  }
}

class _VerificationSummaryCard extends StatelessWidget {
  const _VerificationSummaryCard({
    required this.uploadedDocumentCount,
    required this.totalDocumentCount,
    required this.verificationProgress,
    required this.allDocumentsUploaded,
    required this.onOpenVerification,
  });

  final int uploadedDocumentCount;
  final int totalDocumentCount;
  final double verificationProgress;
  final bool allDocumentsUploaded;
  final VoidCallback onOpenVerification;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              CaRismaBlueIconBox(
                icon: allDocumentsUploaded
                    ? Icons.verified_rounded
                    : Icons.pending_actions_rounded,
                size: 48,
                iconSize: 24,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      allDocumentsUploaded
                          ? 'Dokumente vollständig'
                          : 'Dokumente fehlen',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18.5,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$uploadedDocumentCount von $totalDocumentCount Dokumenten ausgewählt',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.68),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(
              children: [
                LinearProgressIndicator(
                  value: verificationProgress,
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.10),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    CaRismaDesignTokens.bluePrimary,
                  ),
                ),
                if (verificationProgress > 0)
                  Positioned.fill(
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: verificationProgress,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              CaRismaDesignTokens.bluePrimary,
                              CaRismaDesignTokens.bluePrimary,
                              CaRismaDesignTokens.bluePrimary,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: CaRismaDesignTokens.bluePrimary.withValues(
                                alpha: 0.55,
                              ),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const _InlineStatusBox(
            icon: Icons.fact_check_outlined,
            text:
                'Der Fahrzeugschein wird mit deinen Fahrzeugdaten abgeglichen. Ein anderes Fahrzeug führt zur Ablehnung der Verifizierung.',
          ),
          const SizedBox(height: 12),
          _PrimaryActionButton(
            label: allDocumentsUploaded
                ? 'Verifizierung ansehen'
                : 'Dokumente hochladen',
            icon: Icons.arrow_forward_rounded,
            onTap: onOpenVerification,
          ),
        ],
      ),
    );
  }
}

class _VehicleDataCard extends StatelessWidget {
  const _VehicleDataCard({
    required this.selectedBrand,
    required this.selectedModel,
    required this.selectedColor,
    required this.brands,
    required this.models,
    required this.vehicleColors,
    required this.isLocked,
    required this.onBrandChanged,
    required this.onModelChanged,
    required this.onColorChanged,
  });

  final String selectedBrand;
  final String selectedModel;
  final String selectedColor;
  final List<String> brands;
  final List<String> models;
  final List<String> vehicleColors;
  final bool isLocked;
  final ValueChanged<String> onBrandChanged;
  final ValueChanged<String> onModelChanged;
  final ValueChanged<String> onColorChanged;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          _VehiclePickerField(
            label: 'Marke',
            value: selectedBrand,
            items: brands,
            enabled: !isLocked,
            customActionLabel: 'Marke selbst eintragen',
            emptyText: 'Marke auswählen',
            onChanged: onBrandChanged,
          ),
          const SizedBox(height: 12),
          _VehiclePickerField(
            label: 'Modell',
            value: selectedModel,
            items: models.contains(selectedModel) || selectedModel.isEmpty
                ? models
                : [selectedModel, ...models],
            enabled: !isLocked,
            customActionLabel: 'Modell selbst eintragen',
            emptyText: 'Modell auswählen',
            onChanged: onModelChanged,
          ),
          const SizedBox(height: 12),
          _ProfileDropdown(
            label: 'Farbe',
            value: selectedColor,
            items: vehicleColors,
            enabled: !isLocked,
            onChanged: onColorChanged,
          ),
          const SizedBox(height: 12),
          const _InlineStatusBox(
            icon: Icons.verified_user_outlined,
            text:
                'Diese Angaben müssen mit dem Fahrzeugschein übereinstimmen. Änderungen am Fahrzeug setzen die Fahrzeugdokumente zur erneuten Prüfung zurück.',
          ),
        ],
      ),
    );
  }
}

class _VehiclePickerField extends StatelessWidget {
  const _VehiclePickerField({
    required this.label,
    required this.value,
    required this.items,
    required this.enabled,
    required this.customActionLabel,
    required this.emptyText,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> items;
  final bool enabled;
  final String customActionLabel;
  final String emptyText;
  final ValueChanged<String> onChanged;

  Future<void> _openPicker(BuildContext context) async {
    if (!enabled) {
      return;
    }

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _VehiclePickerSheet(
          title: label,
          selectedValue: value,
          items: items,
          customActionLabel: customActionLabel,
          emptyText: emptyText,
        );
      },
    );

    final normalizedResult = result?.trim();
    if (normalizedResult == null || normalizedResult.isEmpty) {
      return;
    }

    onChanged(normalizedResult);
  }

  @override
  Widget build(BuildContext context) {
    final displayValue = value.trim().isNotEmpty ? value.trim() : emptyText;

    return Opacity(
      opacity: enabled ? 1 : 0.56,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openPicker(context),
          borderRadius: BorderRadius.circular(20),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.70),
                fontWeight: FontWeight.w800,
              ),
              filled: true,
              fillColor: CaRismaDesignTokens.controlSurface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 15,
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    displayValue,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: value.trim().isNotEmpty
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.48),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Icon(
                  Icons.search_rounded,
                  color: enabled
                      ? Colors.white.withValues(alpha: 0.78)
                      : Colors.white.withValues(alpha: 0.40),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VehiclePickerSheet extends StatefulWidget {
  const _VehiclePickerSheet({
    required this.title,
    required this.selectedValue,
    required this.items,
    required this.customActionLabel,
    required this.emptyText,
  });

  final String title;
  final String selectedValue;
  final List<String> items;
  final String customActionLabel;
  final String emptyText;

  @override
  State<_VehiclePickerSheet> createState() => _VehiclePickerSheetState();
}

class _VehiclePickerSheetState extends State<_VehiclePickerSheet> {
  late final TextEditingController _searchController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _filteredItems {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return widget.items;
    }

    return widget.items.where((item) {
      return item.toLowerCase().contains(query);
    }).toList();
  }

  bool get _canUseCustomValue {
    final query = _query.trim();
    if (query.isEmpty) {
      return false;
    }

    return !widget.items.any(
      (item) => item.toLowerCase() == query.toLowerCase(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final filteredItems = _filteredItems;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF0C1322),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 52,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (value) {
                    setState(() {
                      _query = value;
                    });
                  },
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: InputDecoration(
                    hintText: '${widget.title} suchen oder eingeben',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.44),
                      fontWeight: FontWeight.w800,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: Colors.white.withValues(alpha: 0.56),
                    ),
                    filled: true,
                    fillColor: CaRismaDesignTokens.controlSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
                  itemBuilder: (context, index) {
                    if (_canUseCustomValue && index == 0) {
                      final customValue = _query.trim();

                      return _VehiclePickerTile(
                        title: customValue,
                        subtitle: widget.customActionLabel,
                        icon: Icons.edit_rounded,
                        isSelected: false,
                        onTap: () => Navigator.of(context).pop(customValue),
                      );
                    }

                    final itemIndex = _canUseCustomValue ? index - 1 : index;

                    if (filteredItems.isEmpty) {
                      return _VehiclePickerTile(
                        title: widget.emptyText,
                        subtitle: 'Nutze die Eingabe oben als eigenen Wert.',
                        icon: Icons.info_outline_rounded,
                        isSelected: false,
                        onTap: null,
                      );
                    }

                    final item = filteredItems[itemIndex];
                    final isSelected = item == widget.selectedValue;

                    return _VehiclePickerTile(
                      title: item,
                      subtitle: isSelected ? 'Aktuell ausgewählt' : null,
                      icon: isSelected
                          ? Icons.check_circle_rounded
                          : Icons.directions_car_rounded,
                      isSelected: isSelected,
                      onTap: () => Navigator.of(context).pop(item),
                    );
                  },
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemCount:
                      filteredItems.length +
                      (_canUseCustomValue ? 1 : 0) +
                      (filteredItems.isEmpty && !_canUseCustomValue ? 1 : 0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VehiclePickerTile extends StatelessWidget {
  const _VehiclePickerTile({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accentColor = isSelected
        ? CaRismaDesignTokens.bluePrimary
        : Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: CaRismaDesignTokens.controlSurface,
            border: Border.all(
              color: isSelected
                  ? CaRismaDesignTokens.bluePrimary.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              CaRismaBlueIconBox(icon: icon, size: 42, iconSize: 22),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.58),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.42),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerificationVehicleCard extends StatelessWidget {
  const _VerificationVehicleCard({
    required this.displayName,
    required this.displayPlate,
    required this.selectedBrand,
    required this.selectedModel,
    required this.selectedColor,
  });

  final String displayName;
  final String displayPlate;
  final String selectedBrand;
  final String selectedModel;
  final String selectedColor;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _UserAvatarPlaceholder(size: 54),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _VerificationInfoRow(label: 'Kennzeichen', value: displayPlate),
          const SizedBox(height: 9),
          _VerificationInfoRow(
            label: 'Fahrzeug',
            value: '$selectedColor $selectedBrand $selectedModel',
          ),
          const SizedBox(height: 14),
          const _InlineStatusBox(
            icon: Icons.warning_amber_rounded,
            text:
                'Der Fahrzeugschein muss exakt zu diesem Fahrzeug passen. Beispiel: Mercedes-Fahrzeugschein und BMW-Profilangabe wird abgelehnt.',
          ),
        ],
      ),
    );
  }
}

class _VerificationInfoRow extends StatelessWidget {
  const _VerificationInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: CaRismaDesignTokens.controlSurface,
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 106,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.62),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentUploadCard extends StatelessWidget {
  const _DocumentUploadCard({
    required this.documentFiles,
    required this.documentRemoteUrls,
    required this.uploadedDocumentCount,
    required this.totalDocumentCount,
    required this.verificationProgress,
    required this.isLocked,
    required this.onDocumentTap,
    required this.onDocumentRemove,
  });

  final Map<String, XFile?> documentFiles;
  final Map<String, String?> documentRemoteUrls;
  final int uploadedDocumentCount;
  final int totalDocumentCount;
  final double verificationProgress;
  final bool isLocked;
  final ValueChanged<String> onDocumentTap;
  final ValueChanged<String> onDocumentRemove;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          _InlineStatusBox(
            icon: Icons.upload_file_rounded,
            text:
                '$uploadedDocumentCount von $totalDocumentCount Pflichtdokumenten ausgewählt.',
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: verificationProgress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.10),
              valueColor: const AlwaysStoppedAnimation<Color>(
                CaRismaDesignTokens.bluePrimary,
              ),
            ),
          ),
          const SizedBox(height: 14),
          ...documentFiles.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DocumentUploadTile(
                title: entry.key,
                file: entry.value,
                remoteUrl: documentRemoteUrls[entry.key],
                isLocked: isLocked,
                onTap: () => onDocumentTap(entry.key),
                onRemove: () => onDocumentRemove(entry.key),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _DocumentUploadTile extends StatelessWidget {
  const _DocumentUploadTile({
    required this.title,
    required this.file,
    required this.remoteUrl,
    required this.isLocked,
    required this.onTap,
    required this.onRemove,
  });

  final String title;
  final XFile? file;
  final String? remoteUrl;
  final bool isLocked;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  bool get _isUploaded {
    final url = remoteUrl?.trim();

    return file != null || (url != null && url.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withValues(alpha: _isUploaded ? 0.09 : 0.06),
        border: Border.all(
          color: _isUploaded
              ? CaRismaDesignTokens.bluePrimary.withValues(alpha: 0.42)
              : Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isLocked ? null : onTap,
              borderRadius: BorderRadius.circular(22),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    CaRismaBlueIconBox(
                      icon: _isUploaded
                          ? Icons.check_circle_rounded
                          : Icons.upload_file_rounded,
                      size: 44,
                      iconSize: 23,
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 15.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _isUploaded ? 'ausgewählt' : 'auswählen',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _isUploaded
                            ? CaRismaDesignTokens.bluePrimary
                            : Colors.white.withValues(alpha: 0.68),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isUploaded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: file != null
                    ? Image.file(
                        File(file!.path),
                        width: double.infinity,
                        height: 150,
                        fit: BoxFit.cover,
                      )
                    : _RemoteDocumentPreview(remoteUrl: remoteUrl),
              ),
            ),
            if (!isLocked)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: _SheetSecondaryActionButton(
                  label: 'Dokument entfernen',
                  onTap: onRemove,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _RemoteDocumentPreview extends StatelessWidget {
  const _RemoteDocumentPreview({required this.remoteUrl});

  final String? remoteUrl;

  @override
  Widget build(BuildContext context) {
    final url = remoteUrl?.trim();

    if (url == null || url.isEmpty) {
      return const SizedBox.shrink();
    }

    return Image.network(
      url,
      width: double.infinity,
      height: 150,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: double.infinity,
          height: 150,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: CaRismaDesignTokens.controlSurface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            'Dokument gespeichert',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.72),
              fontWeight: FontWeight.w800,
            ),
          ),
        );
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }

        return Container(
          width: double.infinity,
          height: 150,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: CaRismaDesignTokens.controlSurface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
    );
  }
}

class _ReadOnlyProfileField extends StatelessWidget {
  const _ReadOnlyProfileField({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: CaRismaDesignTokens.controlSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox.square(
            dimension: 24,
            child: Center(
              child: Icon(
                icon,
                color: Colors.white.withValues(alpha: 0.66),
                size: 23,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: CaRismaDesignTokens.textMuted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: CaRismaDesignTokens.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Änderungen unter Konto & Sicherheit',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: CaRismaDesignTokens.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.lock_outline_rounded,
            color: CaRismaDesignTokens.textMuted,
            size: 19,
          ),
        ],
      ),
    );
  }
}

class _ProfileTextField extends StatelessWidget {
  const _ProfileTextField({
    required this.controller,
    required this.hintText,
    required this.icon,
    required this.textCapitalization,
    required this.enabled,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.onChanged,
    this.errorText,
    this.helperText,
    this.showLockIcon = false,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final TextCapitalization textCapitalization;
  final bool enabled;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final String? errorText;
  final String? helperText;
  final bool showLockIcon;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.56,
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        maxLines: 1,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        textCapitalization: textCapitalization,
        textInputAction: TextInputAction.next,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.50),
            fontWeight: FontWeight.w700,
          ),
          prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.78)),
          suffixIcon: showLockIcon
              ? const Icon(
                  Icons.lock_outline_rounded,
                  color: CaRismaDesignTokens.textMuted,
                  size: 19,
                )
              : null,
          errorText: errorText,
          helperText: helperText,
          helperStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: CaRismaDesignTokens.textMuted,
            fontWeight: FontWeight.w700,
          ),
          filled: true,
          fillColor: CaRismaDesignTokens.controlSurface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 17,
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
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

class _BirthDateInputFormatter extends TextInputFormatter {
  const _BirthDateInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 8) digits = digits.substring(0, 8);

    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index == 2 || index == 4) buffer.write('.');
      buffer.write(digits[index]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _ProfileDropdown extends StatelessWidget {
  const _ProfileDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> items;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final safeValue = items.contains(value)
        ? value
        : items.isNotEmpty
        ? items.first
        : null;

    return Opacity(
      opacity: enabled ? 1 : 0.56,
      child: DropdownButtonFormField<String>(
        initialValue: safeValue,
        dropdownColor: const Color(0xFF101827),
        iconEnabledColor: Colors.white,
        iconDisabledColor: Colors.white.withValues(alpha: 0.48),
        isExpanded: true,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.70),
            fontWeight: FontWeight.w800,
          ),
          filled: true,
          fillColor: CaRismaDesignTokens.controlSurface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 17,
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
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
        items: items.map((item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item, overflow: TextOverflow.ellipsis),
          );
        }).toList(),
        onChanged: enabled
            ? (newValue) {
                if (newValue == null) {
                  return;
                }

                onChanged(newValue);
              }
            : null,
      ),
    );
  }
}

class _UserAvatarPlaceholder extends StatelessWidget {
  const _UserAvatarPlaceholder({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.30;
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
      child: Icon(
        Icons.person_rounded,
        color: CaRismaDesignTokens.bluePrimary,
        size: size * 0.56,
      ),
    );
  }
}

class _InlineStatusBox extends StatelessWidget {
  const _InlineStatusBox({
    required this.icon,
    required this.text,
    this.fixedLines,
  });

  final IconData icon;
  final String text;
  final List<String>? fixedLines;

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
            child: fixedLines == null
                ? Text(text, style: _textStyle(context))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: fixedLines!
                        .map(
                          (line) => FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              line,
                              maxLines: 1,
                              softWrap: false,
                              style: _textStyle(context),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
          ),
        ],
      ),
    );
  }

  TextStyle? _textStyle(BuildContext context) {
    return Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Colors.white.withValues(alpha: 0.78),
      fontWeight: FontWeight.w700,
      height: 1.3,
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
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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

class _SecondaryFullWidthButton extends StatelessWidget {
  const _SecondaryFullWidthButton({
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
      borderRadius: 20,
      onPressed: onTap,
    );
  }
}

class _SheetActionButton extends StatelessWidget {
  const _SheetActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _PrimaryActionButton(label: label, icon: icon, onTap: onTap);
  }
}

class _SheetSecondaryActionButton extends StatelessWidget {
  const _SheetSecondaryActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CaRismaSecondaryButton(
      label: label,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      onPressed: onTap,
    );
  }
}

class _SaveProfileButton extends StatelessWidget {
  const _SaveProfileButton({
    required this.isEnabled,
    required this.isLoading,
    required this.canSubmitProfileForVerification,
    required this.onPressed,
  });

  final bool isEnabled;
  final bool isLoading;
  final bool canSubmitProfileForVerification;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CaRismaPrimaryButton(
      label: canSubmitProfileForVerification
          ? 'Zur Prüfung einreichen'
          : 'Profil speichern',
      loadingLabel: canSubmitProfileForVerification
          ? 'Wird eingereicht...'
          : 'Wird gespeichert...',
      icon: canSubmitProfileForVerification
          ? Icons.verified_user_rounded
          : Icons.save_rounded,
      iconSize: 27,
      fontSize: 19,
      isEnabled: isEnabled,
      isLoading: isLoading,
      surfaceOutlined: true,
      onPressed: onPressed,
    );
  }
}

class _SubmitVerificationButton extends StatelessWidget {
  const _SubmitVerificationButton({
    required this.isEnabled,
    required this.isLoading,
    required this.allDocumentsUploaded,
    required this.onPressed,
  });

  final bool isEnabled;
  final bool isLoading;
  final bool allDocumentsUploaded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CaRismaPrimaryButton(
      label: allDocumentsUploaded
          ? 'Auswahl übernehmen'
          : 'Dokumente vollständig auswählen',
      loadingLabel: 'Wird übernommen...',
      icon: Icons.verified_user_rounded,
      iconSize: 27,
      fontSize: 19,
      isEnabled: isEnabled,
      isLoading: isLoading,
      surfaceOutlined: true,
      onPressed: onPressed,
    );
  }
}

class _NewProfileButton extends StatelessWidget {
  const _NewProfileButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _SecondaryFullWidthButton(
      label: 'Neues Profil hinzufügen',
      icon: Icons.person_add_alt_1_rounded,
      onTap: onPressed,
    );
  }
}
