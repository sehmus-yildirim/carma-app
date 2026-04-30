import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/domain/app_feature_gate.dart';
import '../../../shared/models/carma_models.dart';
import '../../../shared/plate/plate_country_config.dart';
import '../domain/profile_document_mapper.dart';
import '../domain/profile_draft.dart';
import '../../../shared/widgets/carma_background.dart';
import '../../../shared/widgets/carma_blue_icon_box.dart';
import '../../../shared/widgets/carma_country_selector_card.dart';
import '../../../shared/widgets/carma_message_card.dart';
import '../../../shared/widgets/carma_page_header.dart';
import '../../../shared/widgets/carma_plate_input_card.dart';
import '../../../shared/widgets/carma_primary_button.dart';
import '../../../shared/widgets/carma_secondary_button.dart';
import '../../../shared/widgets/carma_section_title.dart';
import '../../../shared/widgets/carma_sub_page_header.dart';
import '../../../shared/widgets/carma_switch_row.dart';
import '../../../shared/widgets/glass_card.dart';

const Color _carmaBlue = Color(0xFF139CFF);
const Color _carmaBlueLight = Color(0xFF63D5FF);
const Color _carmaBlueDark = Color(0xFF0A76FF);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.userState,
  });

  final AppUserState userState;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();

  final TextEditingController _regionController = TextEditingController();
  final TextEditingController _lettersController = TextEditingController();
  final TextEditingController _numbersController = TextEditingController();

  final FocusNode _regionFocusNode = FocusNode();
  final FocusNode _lettersFocusNode = FocusNode();
  final FocusNode _numbersFocusNode = FocusNode();

  XFile? _profilePhoto;

  String _countryCode = 'DE';
  String _selectedBrand = 'BMW';
  String _selectedModel = '1er';
  String _selectedColor = 'Schwarz';

  bool _allowContactRequests = true;
  bool _allowAnonymousReports = true;
  bool _hasUnsavedChanges = false;
  bool _isSaving = false;

  bool _isSubmittedForVerification = false;
  bool _isVerified = false;

  final Map<String, XFile?> _documentFiles = {
    'Ausweis Vorderseite': null,
    'Ausweis Rückseite': null,
    'Führerschein Vorderseite': null,
    'Führerschein Rückseite': null,
    'Fahrzeugschein Vorderseite': null,
    'Fahrzeugschein Rückseite': null,
  };

  static const Map<String, List<String>> _vehicleModelsByBrand = {
    'Volkswagen': [
      'Golf',
      'Polo',
      'Passat',
      'Tiguan',
      'T-Roc',
      'ID.3',
      'ID.4',
      'Arteon',
      'Touran',
    ],
    'BMW': [
      '1er',
      '2er',
      '3er',
      '4er',
      '5er',
      'X1',
      'X3',
      'X5',
      'i3',
      'i4',
    ],
    'Mercedes-Benz': [
      'A-Klasse',
      'B-Klasse',
      'C-Klasse',
      'E-Klasse',
      'S-Klasse',
      'CLA',
      'GLA',
      'GLC',
      'GLE',
      'EQE',
    ],
    'Audi': [
      'A1',
      'A3',
      'A4',
      'A5',
      'A6',
      'Q2',
      'Q3',
      'Q5',
      'Q7',
      'e-tron',
    ],
    'Opel': [
      'Corsa',
      'Astra',
      'Insignia',
      'Mokka',
      'Grandland',
      'Crossland',
      'Zafira',
    ],
    'Ford': [
      'Fiesta',
      'Focus',
      'Mondeo',
      'Kuga',
      'Puma',
      'Mustang',
      'Explorer',
      'Transit',
    ],
    'Toyota': [
      'Yaris',
      'Corolla',
      'C-HR',
      'RAV4',
      'Prius',
      'Aygo',
      'Camry',
      'Land Cruiser',
    ],
    'Hyundai': [
      'i10',
      'i20',
      'i30',
      'Kona',
      'Tucson',
      'Santa Fe',
      'IONIQ 5',
      'IONIQ 6',
    ],
    'Kia': [
      'Picanto',
      'Rio',
      'Ceed',
      'Sportage',
      'Sorento',
      'Niro',
      'EV6',
      'Stonic',
    ],
    'Tesla': [
      'Model 3',
      'Model Y',
      'Model S',
      'Model X',
    ],
    'Skoda': [
      'Fabia',
      'Octavia',
      'Superb',
      'Kamiq',
      'Karoq',
      'Kodiaq',
      'Enyaq',
    ],
    'Seat': [
      'Ibiza',
      'Leon',
      'Arona',
      'Ateca',
      'Tarraco',
      'Alhambra',
    ],
    'Renault': [
      'Clio',
      'Megane',
      'Captur',
      'Kadjar',
      'Scenic',
      'Twingo',
      'Zoe',
    ],
    'Peugeot': [
      '208',
      '308',
      '508',
      '2008',
      '3008',
      '5008',
      'Rifter',
    ],
    'Fiat': [
      '500',
      'Panda',
      'Tipo',
      'Punto',
      'Doblo',
      'Ducato',
    ],
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
    return _documentFiles.values.every((file) => file != null);
  }

  int get _uploadedDocumentCount {
    return _documentFiles.values.where((file) => file != null).length;
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
      return 'Carma Nutzer';
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

  @override
  void initState() {
    super.initState();

    _firstNameController.addListener(_markUnsaved);
    _lastNameController.addListener(_markUnsaved);
    _regionController.addListener(_markUnsaved);
    _lettersController.addListener(_markUnsaved);
    _numbersController.addListener(_markUnsaved);
  }

  @override
  void dispose() {
    _firstNameController.removeListener(_markUnsaved);
    _lastNameController.removeListener(_markUnsaved);
    _regionController.removeListener(_markUnsaved);
    _lettersController.removeListener(_markUnsaved);
    _numbersController.removeListener(_markUnsaved);

    _firstNameController.dispose();
    _lastNameController.dispose();
    _regionController.dispose();
    _lettersController.dispose();
    _numbersController.dispose();

    _regionFocusNode.dispose();
    _lettersFocusNode.dispose();
    _numbersFocusNode.dispose();

    super.dispose();
  }

  void _markUnsaved() {
    if (_isProfileLocked) {
      return;
    }

    setState(() {
      _hasUnsavedChanges = true;
    });
  }

  void _clearVehicleVerificationDocuments() {
    _documentFiles['Fahrzeugschein Vorderseite'] = null;
    _documentFiles['Fahrzeugschein Rückseite'] = null;
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
                  if (_profilePhoto != null) ...[
                    const SizedBox(height: 10),
                    _SheetSecondaryActionButton(
                      label: 'Profilbild entfernen',
                      onTap: () {
                        Navigator.of(context).pop();
                        setState(() {
                          _profilePhoto = null;
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

      setState(() {
        _profilePhoto = image;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profilbild wurde ausgewählt.'),
        ),
      );
    } catch (_) {
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

    final models = _vehicleModelsByBrand[brand] ?? const <String>[];

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

  Future<void> _saveProfile() async {
    if (_isProfileLocked) {
      return;
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
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSaving = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 650));

    if (!mounted) {
      return;
    }

    final userProfile = _profileDraft.toUserProfile();
    final canSubmit = userProfile.canSubmitForVerification;

    setState(() {
      _isSaving = false;
      _hasUnsavedChanges = false;

      if (canSubmit) {
        _isSubmittedForVerification = true;
        _isVerified = false;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          canSubmit
              ? 'Profil wurde gespeichert. Deine Verifizierung ist jetzt ausstehend.'
              : 'Profil wurde vorbereitet. Für die Freigabe müssen Name, Fahrzeug und alle Dokumente vollständig sein.',
        ),
      ),
    );
  }

  void _openVerificationScreen() {
    final gateDecision = _verificationGateDecision;

    if (!gateDecision.isAllowed && !_isProfileLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            gateDecision.reason ??
                'Die Profil-Verifizierung ist aktuell nicht verfügbar.',
          ),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _VerificationScreen(
          imagePicker: _imagePicker,
          documentFiles: _documentFiles,
          displayName: _displayName,
          displayPlate: _displayPlate,
          selectedBrand: _selectedBrand,
          selectedModel: _selectedModel,
          selectedColor: _selectedColor,
          hasPlateInput: _hasPlateInput,
          isLocked: _isProfileLocked,
          onDocumentUpload: (documentName, file) {
            if (_isProfileLocked) {
              return;
            }

            setState(() {
              _documentFiles[documentName] = file;
              _hasUnsavedChanges = true;
            });
          },
          onDocumentRemove: (documentName) {
            if (_isProfileLocked) {
              return;
            }

            setState(() {
              _documentFiles[documentName] = null;
              _hasUnsavedChanges = true;
            });
          },
        ),
      ),
    );
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
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
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
                  color: _carmaBlueLight,
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
      }

      _isSubmittedForVerification = false;
      _isVerified = false;
      _hasUnsavedChanges = false;
      _isSaving = false;
    });

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Neues Profil wurde vorbereitet. Bitte fülle alle Daten erneut aus.',
        ),
      ),
    );
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
              padding: EdgeInsets.fromLTRB(
                20,
                18,
                20,
                112 + keyboardInset,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 112,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CarmaPageHeader(
                      icon: Icons.person_rounded,
                      title: 'Profil',
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Verwalte deine Identität, dein Fahrzeug und deine Sichtbarkeit.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
                      isSubmittedForVerification: _isSubmittedForVerification,
                      isVerified: _isVerified,
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
                      isSubmittedForVerification: _isSubmittedForVerification,
                      isVerified: _isVerified,
                      isSaving: _isSaving,
                      onOpenVerification: _openVerificationScreen,
                      onSaveProfile: _saveProfile,
                    ),
                    if (_isProfileLocked) ...[
                      const SizedBox(height: 14),
                      _LockedProfileCard(
                        isVerified: _isVerified,
                        onCreateNewProfile: _confirmNewProfile,
                      ),
                    ],
                    const SizedBox(height: 18),
                    const CarmaSectionTitle(
                      number: '1',
                      title: 'Persönliche Daten',
                    ),
                    const SizedBox(height: 10),
                    _NameCard(
                      firstNameController: _firstNameController,
                      lastNameController: _lastNameController,
                      isLocked: _isProfileLocked,
                    ),
                    const SizedBox(height: 18),
                    const CarmaSectionTitle(
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
                    const CarmaSectionTitle(
                      number: '3',
                      title: 'Mein Fahrzeug',
                    ),
                    const SizedBox(height: 10),
                    CarmaCountrySelectorCard(
                      selectedCountryCode: _countryCode,
                      isLocked: _isProfileLocked,
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
                      brands: _vehicleModelsByBrand.keys.toList(),
                      models: _vehicleModelsByBrand[_selectedBrand] ?? const [],
                      vehicleColors: _vehicleColors,
                      isLocked: _isProfileLocked,
                      onBrandChanged: _onBrandChanged,
                      onModelChanged: _onModelChanged,
                      onColorChanged: _onColorChanged,
                    ),
                    const SizedBox(height: 18),
                    const CarmaSectionTitle(
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
                        });
                      },
                      onAnonymousReportsChanged: (value) {
                        setState(() {
                          _allowAnonymousReports = value;
                        });
                      },
                    ),
                    const SizedBox(height: 18),
                    if (!_isProfileLocked)
                      _SaveProfileButton(
                        isEnabled: _hasUnsavedChanges && !_isSaving,
                        isLoading: _isSaving,
                        onPressed: _saveProfile,
                      )
                    else
                      _NewProfileButton(
                        onPressed: _confirmNewProfile,
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

class _ProfileNextStepCard extends StatelessWidget {
  const _ProfileNextStepCard({
    required this.hasNameInput,
    required this.hasPlateInput,
    required this.allDocumentsUploaded,
    required this.canSubmitProfileForVerification,
    required this.isSubmittedForVerification,
    required this.isVerified,
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

    if (!hasNameInput) {
      return 'Trage unten Vorname und Nachname ein. Nach der Verifizierung werden diese Daten geschützt gesperrt.';
    }

    if (!hasPlateInput) {
      return 'Ergänze dein Kennzeichen und die Fahrzeugdaten, damit dein Fahrzeug eindeutig zugeordnet werden kann.';
    }

    if (!allDocumentsUploaded) {
      return 'Lade Ausweis, Führerschein und Fahrzeugschein hoch, damit dein Profil vorbereitet werden kann.';
    }

    return 'Alle Pflichtdaten sind vorhanden. Speichere dein Profil, um die lokale Verifizierung auf ausstehend zu setzen.';
  }

  IconData get _icon {
    if (isVerified) {
      return Icons.verified_rounded;
    }

    if (isSubmittedForVerification) {
      return Icons.pending_actions_rounded;
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
        !allDocumentsUploaded;
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
              CarmaBlueIconBox(
                icon: _icon,
                size: 48,
                iconSize: 24,
              ),
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
            CarmaPrimaryButton(
              label: 'Dokumente hochladen',
              icon: Icons.arrow_forward_rounded,
              onPressed: onOpenVerification,
            ),
          ],
          if (_showSubmitButton) ...[
            const SizedBox(height: 14),
            CarmaPrimaryButton(
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
          CarmaSwitchRow(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Kontaktanfragen erlauben',
            description:
            'Andere können dich über dein Kennzeichen geschützt kontaktieren.',
            value: allowContactRequests,
            enabled: true,
            onChanged: onContactRequestsChanged,
          ),
          const SizedBox(height: 10),
          CarmaSwitchRow(
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
    required this.displayName,
    required this.displayPlate,
    required this.selectedBrand,
    required this.selectedModel,
    required this.selectedColor,
    required this.hasPlateInput,
    required this.isLocked,
    required this.onDocumentUpload,
    required this.onDocumentRemove,
  });

  final ImagePicker imagePicker;
  final Map<String, XFile?> documentFiles;
  final String displayName;
  final String displayPlate;
  final String selectedBrand;
  final String selectedModel;
  final String selectedColor;
  final bool hasPlateInput;
  final bool isLocked;
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
    return widget.documentFiles.values.where((file) => file != null).length;
  }

  bool get _allDocumentsUploaded {
    return widget.documentFiles.values.every((file) => file != null);
  }

  double get _verificationProgress {
    return _uploadedDocumentCount / widget.documentFiles.length;
  }

  void _clearMessages() {
    _errorMessage = null;
    _successMessage = null;
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
        SnackBar(
          content: Text(
            '$documentName wurde hochgeladen.',
          ),
        ),
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

    await Future<void>.delayed(const Duration(milliseconds: 700));

    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
      _successMessage =
      'Deine Dokumente wurden vorbereitet. Speichere jetzt dein Profil, damit die Verifizierung ausstehend gesetzt wird.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return CarmaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              20,
              18,
              20,
              28 + keyboardInset,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CarmaSubPageHeader(
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
                const CarmaSectionTitle(
                  number: '1',
                  title: 'Pflichtdokumente',
                ),
                const SizedBox(height: 10),
                _DocumentUploadCard(
                  documentFiles: widget.documentFiles,
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
                  CarmaMessageCard(
                    icon: Icons.error_outline_rounded,
                    message: _errorMessage!,
                  ),
                ],
                if (_successMessage != null) ...[
                  const SizedBox(height: 14),
                  CarmaMessageCard(
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
    required this.isSubmittedForVerification,
    required this.isVerified,
    required this.uploadedDocumentCount,
    required this.totalDocumentCount,
    required this.onProfilePhotoTap,
  });

  final String displayName;
  final XFile? profilePhoto;
  final bool isSubmittedForVerification;
  final bool isVerified;
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

    return 'Verifizierung nicht eingereicht';
  }

  Color get _statusColor {
    if (isVerified) {
      return _carmaBlueLight;
    }

    if (isSubmittedForVerification) {
      return const Color(0xFFFFD58A);
    }

    return Colors.white70;
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          _ProfilePhotoButton(
            size: 64,
            profilePhoto: profilePhoto,
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
                const SizedBox(height: 4),
                Text(
                  '$uploadedDocumentCount von $totalDocumentCount Dokumenten vorbereitet',
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
    required this.onTap,
  });

  final double size;
  final XFile? profilePhoto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final image = profilePhoto;

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: image == null
                    ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _carmaBlueDark,
                    _carmaBlueLight,
                  ],
                )
                    : null,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.22),
                ),
                image: image == null
                    ? null
                    : DecorationImage(
                  image: FileImage(File(image.path)),
                  fit: BoxFit.cover,
                ),
              ),
              child: image == null
                  ? Icon(
                Icons.person_rounded,
                color: Colors.white,
                size: size * 0.56,
              )
                  : null,
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 25,
                height: 25,
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
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                ),
                child: const Icon(
                  Icons.photo_camera_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ],
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

class _NameCard extends StatelessWidget {
  const _NameCard({
    required this.firstNameController,
    required this.lastNameController,
    required this.isLocked,
  });

  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          _ProfileTextField(
            controller: firstNameController,
            hintText: 'Vorname',
            icon: Icons.badge_outlined,
            textCapitalization: TextCapitalization.words,
            enabled: !isLocked,
          ),
          const SizedBox(height: 12),
          _ProfileTextField(
            controller: lastNameController,
            hintText: 'Nachname',
            icon: Icons.badge_outlined,
            textCapitalization: TextCapitalization.words,
            enabled: !isLocked,
          ),
          const SizedBox(height: 12),
          const _InlineStatusBox(
            icon: Icons.info_outline_rounded,
            text:
            'Vorname und Nachname können nur einmal angegeben werden. In Carma wird später nur der Vorname mit Initiale angezeigt, z. B. Max M.',
          ),
        ],
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
              CarmaBlueIconBox(
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
                          ? 'Dokumente vorbereitet'
                          : 'Dokumente fehlen',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18.5,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$uploadedDocumentCount von $totalDocumentCount Dokumenten hochgeladen',
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
            child: LinearProgressIndicator(
              value: verificationProgress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.10),
              valueColor: const AlwaysStoppedAnimation<Color>(_carmaBlueLight),
            ),
          ),
          const SizedBox(height: 14),
          const _InlineStatusBox(
            icon: Icons.fact_check_outlined,
            text:
            'Der Fahrzeugschein wird mit deinen Fahrzeugdaten abgeglichen. Ein anderes Fahrzeug führt später zur Ablehnung der Verifizierung.',
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
          _ProfileDropdown(
            label: 'Marke',
            value: selectedBrand,
            items: brands,
            enabled: !isLocked,
            onChanged: onBrandChanged,
          ),
          const SizedBox(height: 12),
          _ProfileDropdown(
            label: 'Modell',
            value: selectedModel,
            items: models,
            enabled: !isLocked,
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
          _VerificationInfoRow(
            label: 'Kennzeichen',
            value: displayPlate,
          ),
          const SizedBox(height: 9),
          _VerificationInfoRow(
            label: 'Fahrzeug',
            value: '$selectedColor $selectedBrand $selectedModel',
          ),
          const SizedBox(height: 14),
          const _InlineStatusBox(
            icon: Icons.warning_amber_rounded,
            text:
            'Der Fahrzeugschein muss exakt zu diesem Fahrzeug passen. Beispiel: Mercedes-Fahrzeugschein und BMW-Profilangabe wird später abgelehnt.',
          ),
        ],
      ),
    );
  }
}

class _VerificationInfoRow extends StatelessWidget {
  const _VerificationInfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
        ),
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
    required this.uploadedDocumentCount,
    required this.totalDocumentCount,
    required this.verificationProgress,
    required this.isLocked,
    required this.onDocumentTap,
    required this.onDocumentRemove,
  });

  final Map<String, XFile?> documentFiles;
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
            '$uploadedDocumentCount von $totalDocumentCount Pflichtdokumenten vorbereitet.',
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: verificationProgress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.10),
              valueColor: const AlwaysStoppedAnimation<Color>(_carmaBlueLight),
            ),
          ),
          const SizedBox(height: 14),
          ...documentFiles.entries.map(
                (entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DocumentUploadTile(
                  title: entry.key,
                  file: entry.value,
                  isLocked: isLocked,
                  onTap: () => onDocumentTap(entry.key),
                  onRemove: () => onDocumentRemove(entry.key),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DocumentUploadTile extends StatelessWidget {
  const _DocumentUploadTile({
    required this.title,
    required this.file,
    required this.isLocked,
    required this.onTap,
    required this.onRemove,
  });

  final String title;
  final XFile? file;
  final bool isLocked;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  bool get _isUploaded {
    return file != null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withValues(alpha: _isUploaded ? 0.09 : 0.06),
        border: Border.all(
          color: _isUploaded
              ? _carmaBlueLight.withValues(alpha: 0.42)
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
                    CarmaBlueIconBox(
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
                      _isUploaded ? 'bereit' : 'hochladen',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _isUploaded
                            ? _carmaBlueLight
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
                child: Image.file(
                  File(file!.path),
                  width: double.infinity,
                  height: 150,
                  fit: BoxFit.cover,
                ),
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

class _ProfileTextField extends StatelessWidget {
  const _ProfileTextField({
    required this.controller,
    required this.hintText,
    required this.icon,
    required this.textCapitalization,
    required this.enabled,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final TextCapitalization textCapitalization;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.56,
      child: TextField(
        controller: controller,
        enabled: enabled,
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
          prefixIcon: Icon(
            icon,
            color: Colors.white.withValues(alpha: 0.78),
          ),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.08),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 17,
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
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(
              color: _carmaBlueLight.withValues(alpha: 0.90),
              width: 1.4,
            ),
          ),
        ),
      ),
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
          fillColor: Colors.white.withValues(alpha: 0.08),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 17,
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
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(
              color: _carmaBlueLight.withValues(alpha: 0.90),
              width: 1.4,
            ),
          ),
        ),
        items: items.map((item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(
              item,
              overflow: TextOverflow.ellipsis,
            ),
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
  const _UserAvatarPlaceholder({
    required this.size,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _carmaBlueDark,
            _carmaBlueLight,
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.20),
        ),
      ),
      child: Icon(
        Icons.person_rounded,
        color: Colors.white,
        size: size * 0.56,
      ),
    );
  }
}

class _InlineStatusBox extends StatelessWidget {
  const _InlineStatusBox({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 22,
          ),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(20)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _carmaBlueDark,
                _carmaBlue,
                _carmaBlueLight,
              ],
            ),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color: Colors.white,
                    size: 22,
                  ),
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
    return CarmaSecondaryButton(
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
    return _PrimaryActionButton(
      label: label,
      icon: icon,
      onTap: onTap,
    );
  }
}

class _SheetSecondaryActionButton extends StatelessWidget {
  const _SheetSecondaryActionButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CarmaSecondaryButton(
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
    required this.onPressed,
  });

  final bool isEnabled;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CarmaPrimaryButton(
      label: 'Profil speichern',
      loadingLabel: 'Wird gespeichert...',
      icon: Icons.save_rounded,
      iconSize: 27,
      fontSize: 19,
      isEnabled: isEnabled,
      isLoading: isLoading,
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
    return CarmaPrimaryButton(
      label: allDocumentsUploaded
          ? 'Dokumente vorbereitet'
          : 'Dokumente vollständig hochladen',
      loadingLabel: 'Wird vorbereitet...',
      icon: Icons.verified_user_rounded,
      iconSize: 27,
      fontSize: 19,
      isEnabled: isEnabled,
      isLoading: isLoading,
      onPressed: onPressed,
    );
  }
}

class _NewProfileButton extends StatelessWidget {
  const _NewProfileButton({
    required this.onPressed,
  });

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