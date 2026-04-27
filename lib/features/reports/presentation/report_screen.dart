import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/widgets/carma_background.dart';
import '../../../shared/widgets/carma_message_card.dart';
import '../../../shared/widgets/carma_page_header.dart';
import '../../../shared/widgets/carma_primary_button.dart';
import '../../../shared/widgets/carma_secondary_button.dart';
import '../../../shared/widgets/carma_section_title.dart';
import '../../../shared/widgets/glass_card.dart';

const Color _carmaBlue = Color(0xFF139CFF);
const Color _carmaBlueLight = Color(0xFF63D5FF);
const Color _carmaBlueDark = Color(0xFF0A76FF);

enum _ReportCategory {
  vehicleOpen,
  lightsOrElectric,
  vehicleBlocked,
  visibleDamage,
  acuteDanger,
  policeOnSite,
}

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController _regionController = TextEditingController();
  final TextEditingController _lettersController = TextEditingController();
  final TextEditingController _numbersController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  final FocusNode _regionFocusNode = FocusNode();
  final FocusNode _lettersFocusNode = FocusNode();
  final FocusNode _numbersFocusNode = FocusNode();

  String _countryCode = 'DE';
  _ReportCategory? _selectedCategory;

  Position? _position;
  XFile? _capturedPhoto;

  bool _isLoadingLocation = false;
  bool _isSending = false;
  bool _useGpsLocation = true;

  String? _locationError;
  String? _errorMessage;
  String? _successMessage;

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
      case 'DE':
        return 5;
      case 'AT':
        return 5;
      case 'CH':
        return 6;
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

  bool get _hasLocation {
    if (_useGpsLocation) {
      return _position != null;
    }

    return _addressController.text.trim().isNotEmpty;
  }

  bool get _canSend {
    return _selectedCategory != null &&
        _hasPlateInput &&
        _hasLocation &&
        !_isSending;
  }

  @override
  void initState() {
    super.initState();

    _regionController.addListener(_refresh);
    _lettersController.addListener(_refresh);
    _numbersController.addListener(_refresh);
    _addressController.addListener(_refresh);
    _noteController.addListener(_refresh);

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

    super.dispose();
  }

  void _refresh() {
    setState(() {});
  }

  void _clearMessages() {
    _errorMessage = null;
    _successMessage = null;
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
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        setState(() {
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
        setState(() {
          _locationError =
          'Standortberechtigung wurde verweigert. Du kannst alternativ eine Adresse eingeben.';
          _isLoadingLocation = false;
          _useGpsLocation = false;
        });
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
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
      );

      setState(() {
        _position = position;
        _locationError = null;
        _isLoadingLocation = false;
      });
    } catch (_) {
      setState(() {
        _locationError =
        'Standort konnte nicht geladen werden. Du kannst alternativ eine Adresse eingeben.';
        _isLoadingLocation = false;
        _useGpsLocation = false;
      });
    }
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

      setState(() {
        _capturedPhoto = image;
      });
    } catch (_) {
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
    if (!_canSend) {
      setState(() {
        _errorMessage =
        'Bitte wähle einen Hinweis, gib ein Kennzeichen ein und füge einen Ort hinzu.';
      });
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSending = true;
      _clearMessages();
    });

    await Future<void>.delayed(const Duration(milliseconds: 700));

    if (!mounted) {
      return;
    }

    setState(() {
      _isSending = false;
      _successMessage =
      'Dein Hinweis wurde vorbereitet. Die echte anonyme Zustellung verbinden wir später mit Firebase.';
    });
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
                      icon: Icons.report_rounded,
                      title: 'Melden',
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Sende einen anonymen Hinweis an einen Fahrzeughalter.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontWeight: FontWeight.w700,
                        fontSize: 16.5,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const _MisuseWarningCard(),
                    const SizedBox(height: 16),
                    const CarmaSectionTitle(
                      number: '1',
                      title: 'Was möchtest du melden?',
                    ),
                    const SizedBox(height: 10),
                    _CategoryGrid(
                      selectedCategory: _selectedCategory,
                      onSelected: _selectCategory,
                    ),
                    const SizedBox(height: 18),
                    const CarmaSectionTitle(
                      number: '2',
                      title: 'Kennzeichen',
                    ),
                    const SizedBox(height: 10),
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
                    const SizedBox(height: 18),
                    const CarmaSectionTitle(
                      number: '3',
                      title: 'Ort des Hinweises',
                    ),
                    const SizedBox(height: 10),
                    _LocationCard(
                      useGpsLocation: _useGpsLocation,
                      isLoadingLocation: _isLoadingLocation,
                      position: _position,
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
                    const CarmaSectionTitle(
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
                    const CarmaSectionTitle(
                      number: '5',
                      title: 'Kurzer Hinweis',
                      optional: true,
                    ),
                    const SizedBox(height: 10),
                    _NoteCard(
                      controller: _noteController,
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
                    _SendReportButton(
                      isEnabled: _canSend,
                      isLoading: _isSending,
                      onPressed: _sendReport,
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

class _MisuseWarningCard extends StatelessWidget {
  const _MisuseWarningCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _carmaBlueDark,
                  _carmaBlue,
                  _carmaBlueLight,
                ],
              ),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: Colors.white,
              size: 23,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              'Dieser Bereich ist nur für echte Hinweise gedacht. Missbrauch, falsche Meldungen oder Belästigung können zur Sperrung deines Kontos führen.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.82),
                fontWeight: FontWeight.w700,
                height: 1.36,
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
        mainAxisExtent: 118,
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
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
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
              border: Border.all(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.22)
                    : Colors.transparent,
              ),
              boxShadow: isSelected
                  ? [
                BoxShadow(
                  color: _carmaBlue.withValues(alpha: 0.24),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  item.icon,
                  color: Colors.white,
                  size: 28,
                ),
                const Spacer(),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15.5,
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
          height: 56,
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
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w800,
                ),
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
              _GermanNumberWithOptionalEFormatter(),
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
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.96),
              fontWeight: FontWeight.w900,
              fontSize: 15.5,
            ),
          ),
        ),
        const SizedBox(height: 9),
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
            fontSize: 23,
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

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.useGpsLocation,
    required this.isLoadingLocation,
    required this.position,
    required this.locationError,
    required this.addressController,
    required this.onUseGpsChanged,
    required this.onRetryLocation,
  });

  final bool useGpsLocation;
  final bool isLoadingLocation;
  final Position? position;
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
              locationError: locationError,
              onRetry: onRetryLocation,
            )
          else
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
                fillColor: Colors.white.withValues(alpha: 0.08),
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
                    color: _carmaBlueLight.withValues(alpha: 0.90),
                    width: 1.4,
                  ),
                ),
              ),
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
                _carmaBlueDark,
                _carmaBlue,
                _carmaBlueLight,
              ],
            )
                : null,
            color: isSelected ? null : Colors.white.withValues(alpha: 0.05),
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
                  Icon(
                    icon,
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 9),
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight:
                      isSelected ? FontWeight.w900 : FontWeight.w800,
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
    required this.locationError,
    required this.onRetry,
  });

  final bool isLoading;
  final Position? position;
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
      return const _InlineStatusBox(
        icon: Icons.check_circle_outline_rounded,
        text: 'Standort wurde erfasst.',
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
    return CarmaSecondaryButton(
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

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.controller,
  });

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
          fillColor: Colors.white.withValues(alpha: 0.08),
          contentPadding: const EdgeInsets.all(16),
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
    return CarmaPrimaryButton(
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

class _GermanNumberWithOptionalEFormatter extends TextInputFormatter {
  const _GermanNumberWithOptionalEFormatter();

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final upper = newValue.text.toUpperCase();
    final buffer = StringBuffer();

    var digitCount = 0;
    var hasE = false;

    for (var i = 0; i < upper.length; i++) {
      final char = upper[i];

      if (RegExp(r'[0-9]').hasMatch(char)) {
        if (!hasE && digitCount < 4) {
          buffer.write(char);
          digitCount++;
        }
        continue;
      }

      if (char == 'E' && !hasE && digitCount > 0 && i == upper.length - 1) {
        buffer.write(char);
        hasE = true;
      }
    }

    final normalized = buffer.toString();

    return TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
  }
}