import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../plate/dach_plate_presentation.dart';
import 'fe_plate_text.dart';

class CaRismaLicensePlatePreview extends StatelessWidget {
  const CaRismaLicensePlatePreview({
    super.key,
    required this.countryCode,
    required this.region,
    required this.letters,
    required this.numbers,
    required this.regionPresentation,
    this.regionController,
    this.lettersController,
    this.numbersController,
    this.regionFocusNode,
    this.lettersFocusNode,
    this.numbersFocusNode,
    this.onRegionChanged,
    this.onLettersChanged,
    this.onNumbersChanged,
  });

  final String countryCode;
  final String region;
  final String letters;
  final String numbers;
  final RegistrationRegionPresentationData regionPresentation;
  final TextEditingController? regionController;
  final TextEditingController? lettersController;
  final TextEditingController? numbersController;
  final FocusNode? regionFocusNode;
  final FocusNode? lettersFocusNode;
  final FocusNode? numbersFocusNode;
  final ValueChanged<String>? onRegionChanged;
  final ValueChanged<String>? onLettersChanged;
  final ValueChanged<String>? onNumbersChanged;

  @override
  Widget build(BuildContext context) {
    final normalizedRegion = region.trim().toUpperCase();
    final normalizedLetters = letters.trim().toUpperCase();
    final normalizedNumbers = numbers.trim().toUpperCase();
    if (countryCode == 'CH') {
      return _SwissPlate(
        region: normalizedRegion,
        numbers: normalizedNumbers,
        sealLabel: regionPresentation.displayName,
        sealAsset: regionPresentation.regionCoatAsset,
        showSeal:
            normalizedRegion.isNotEmpty && !regionPresentation.usesFallback,
      );
    }

    return _EuropeanPlate(
      countryCode: countryCode,
      region: normalizedRegion,
      letters: normalizedLetters,
      numbers: normalizedNumbers,
      sealLabel: regionPresentation.displayName,
      sealAsset: regionPresentation.plateSealAsset,
      showSeal: normalizedRegion.isNotEmpty && !regionPresentation.usesFallback,
    );
  }
}

class _EuropeanPlate extends StatelessWidget {
  const _EuropeanPlate({
    required this.countryCode,
    required this.region,
    required this.letters,
    required this.numbers,
    required this.sealLabel,
    required this.sealAsset,
    required this.showSeal,
  });

  final String countryCode;
  final String region;
  final String letters;
  final String numbers;
  final String sealLabel;
  final String sealAsset;
  final bool showSeal;

  @override
  Widget build(BuildContext context) {
    final country = countryPresentationFor(countryCode);
    final isAustria = countryCode == 'AT';

    return LayoutBuilder(
      builder: (context, constraints) {
        final plateHeight = (constraints.maxWidth / 4.5).clamp(74.0, 92.0);
        final euWidth = plateHeight * 0.38;
        final plateTextSize = (plateHeight * 0.57).clamp(40.0, 52.0);
        final sealSize = plateHeight * (isAustria ? 0.42 : 0.44);

        return SizedBox(
          width: double.infinity,
          height: plateHeight,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF303236), Color(0xFF090A0C)],
              ),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: const Color(0xFF050607), width: 1.4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.48),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.08),
                  blurRadius: 2,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFFFFF), Color(0xFFE8E9E5)],
                ),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF9A9B97), width: 0.8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Row(
                  children: [
                    SizedBox(
                      width: euWidth,
                      child: _EuropeanCountryBand(
                        vehicleMark: country.vehicleMark,
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(6, 3, 8, 3),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 19,
                              child: _PlateText(
                                region,
                                fontSize: plateTextSize,
                              ),
                            ),
                            const SizedBox(width: 5),
                            if (isAustria)
                              _PlateSeal(
                                label: sealLabel,
                                assetPath: sealAsset,
                                showAsset: showSeal,
                                size: sealSize,
                              )
                            else
                              _GermanRegistrationSeal(
                                label: sealLabel,
                                assetPath: sealAsset,
                                showAsset: showSeal,
                                size: sealSize,
                              ),
                            const SizedBox(width: 6),
                            if (isAustria) ...[
                              Expanded(
                                flex: 31,
                                child: _PlateText(
                                  numbers,
                                  fontSize: plateTextSize,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                flex: 18,
                                child: _PlateText(
                                  letters,
                                  fontSize: plateTextSize,
                                ),
                              ),
                            ] else ...[
                              Expanded(
                                flex: 21,
                                child: _PlateText(
                                  letters,
                                  fontSize: plateTextSize,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                flex: 39,
                                child: _PlateText(
                                  numbers,
                                  fontSize: plateTextSize,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SwissPlate extends StatelessWidget {
  const _SwissPlate({
    required this.region,
    required this.numbers,
    required this.sealLabel,
    required this.sealAsset,
    required this.showSeal,
  });

  final String region;
  final String numbers;
  final String sealLabel;
  final String sealAsset;
  final bool showSeal;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        aspectRatio: 4.5,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF303236), Color(0xFF090A0C)],
            ),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: const Color(0xFF050607), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.48),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFFFFF), Color(0xFFE8E9E5)],
              ),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF9A9B97), width: 0.8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  const _SwissShield(size: 36),
                  const SizedBox(width: 7),
                  SizedBox(width: 64, child: _PlateText(region, fontSize: 42)),
                  const SizedBox(width: 6),
                  Expanded(child: _PlateText(numbers, fontSize: 42)),
                  const SizedBox(width: 7),
                  _SwissCantonStamp(
                    size: 36,
                    label: sealLabel,
                    assetPath: sealAsset,
                    showAsset: showSeal,
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

class _PlateText extends StatelessWidget {
  const _PlateText(this.value, {required this.fontSize});

  final String value;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) {
      return const SizedBox.shrink();
    }
    return FePlateText(value, fontSize: fontSize);
  }
}

class _GermanRegistrationSeal extends StatelessWidget {
  const _GermanRegistrationSeal({
    required this.size,
    required this.label,
    required this.assetPath,
    required this.showAsset,
  });

  final double size;
  final String label;
  final String assetPath;
  final bool showAsset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 1.48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(top: 0, child: _InspectionSticker(size: size * 0.62)),
          Positioned(
            bottom: 0,
            child: _PlateSeal(
              size: size * 0.82,
              label: label,
              assetPath: assetPath,
              showAsset: showAsset,
            ),
          ),
        ],
      ),
    );
  }
}

class _InspectionSticker extends StatelessWidget {
  const _InspectionSticker({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: const _InspectionStickerPainter()),
    );
  }
}

class _InspectionStickerPainter extends CustomPainter {
  const _InspectionStickerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final shortestSide = math.min(size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = shortestSide / 2;
    final blue = Paint()
      ..color = const Color(0xFF14A5D3)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = const Color(0xFF090A0C)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    canvas.drawCircle(center, radius * 0.96, blue);
    stroke.strokeWidth = math.max(0.7, radius * 0.09);
    canvas.drawCircle(center, radius * 0.91, stroke);

    for (var index = 0; index < 12; index++) {
      final angle = (math.pi * 2 * index / 12) - math.pi / 2;
      final inner = Offset(
        center.dx + math.cos(angle) * radius * 0.69,
        center.dy + math.sin(angle) * radius * 0.69,
      );
      final outer = Offset(
        center.dx + math.cos(angle) * radius * 0.9,
        center.dy + math.sin(angle) * radius * 0.9,
      );
      stroke.strokeWidth = math.max(0.65, radius * 0.075);
      canvas.drawLine(inner, outer, stroke);
      _paintStickerText(
        canvas,
        text: index == 0 ? '12' : '$index',
        center: Offset(
          center.dx + math.cos(angle) * radius * 0.53,
          center.dy + math.sin(angle) * radius * 0.53,
        ),
        fontSize: radius * 0.27,
      );
    }

    stroke.strokeWidth = radius * 0.28;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.78),
      -math.pi * 0.84,
      math.pi * 0.68,
      false,
      stroke,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(center.dx, radius * 0.16),
        width: math.max(0.7, radius * 0.08),
        height: radius * 0.29,
      ),
      blue,
    );

    canvas.drawCircle(center, radius * 0.31, blue);
    stroke.strokeWidth = math.max(0.65, radius * 0.07);
    canvas.drawCircle(center, radius * 0.31, stroke);
    _paintStickerText(
      canvas,
      text: '26',
      center: center,
      fontSize: radius * 0.5,
      fontWeight: FontWeight.w800,
    );
  }

  void _paintStickerText(
    Canvas canvas, {
    required String text,
    required Offset center,
    required double fontSize,
    FontWeight fontWeight = FontWeight.w700,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: const Color(0xFF090A0C),
          fontSize: fontSize,
          height: 1,
          fontWeight: fontWeight,
          letterSpacing: 0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PlateSeal extends StatelessWidget {
  const _PlateSeal({
    this.size = 44,
    required this.label,
    required this.assetPath,
    required this.showAsset,
  });

  final double size;
  final String label;
  final String assetPath;
  final bool showAsset;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: showAsset ? 'Wappen für $label' : 'Neutraler Wappenplatz',
      image: true,
      child: SizedBox(
        width: size,
        height: size,
        child: Padding(
          padding: EdgeInsets.all(size * 0.035),
          child: showAsset
              ? Image.asset(
                  assetPath,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, _, _) => _NeutralSeal(size: size),
                )
              : _NeutralSeal(size: size),
        ),
      ),
    );
  }
}

class _SwissCantonStamp extends StatelessWidget {
  const _SwissCantonStamp({
    required this.size,
    required this.label,
    required this.assetPath,
    required this.showAsset,
  });

  final double size;
  final String label;
  final String assetPath;
  final bool showAsset;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: showAsset ? 'Kantonsplakette für $label' : 'Kantonsplakette',
      image: true,
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.13),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            colors: [Color(0xFFF4F4F0), Color(0xFFC5C7C4)],
            stops: [0.72, 1],
          ),
          border: Border.all(color: const Color(0xFF4C4D4B), width: 0.8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 1.2,
              offset: Offset(0.5, 0.7),
            ),
          ],
        ),
        child: showAsset
            ? Image.asset(
                assetPath,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, _, _) => _NeutralSeal(size: size),
              )
            : _NeutralSeal(size: size),
      ),
    );
  }
}

class _NeutralSeal extends StatelessWidget {
  const _NeutralSeal({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.shield_outlined,
      size: size * 0.48,
      color: const Color(0xFF9A9B97),
    );
  }
}

class _EuropeanCountryBand extends StatelessWidget {
  const _EuropeanCountryBand({required this.vehicleMark});

  final String vehicleMark;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final plateHeight = constraints.maxHeight;
        final starsDiameter = plateHeight * 0.22;
        final starsCenterY = plateHeight * 0.28;
        final countryLetterHeight = plateHeight * 0.20;
        final countryLetterCenterY = plateHeight * 0.76;

        return ColoredBox(
          color: const Color(0xFF003399),
          child: Stack(
            children: [
              Positioned(
                left: (constraints.maxWidth - starsDiameter) / 2,
                top: starsCenterY - (starsDiameter / 2),
                width: starsDiameter,
                height: starsDiameter,
                child: const _EuStars(),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: countryLetterCenterY - (countryLetterHeight / 2),
                height: countryLetterHeight,
                child: FePlateText(
                  vehicleMark,
                  fontSize: countryLetterHeight,
                  color: Colors.white,
                  embossed: false,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SwissShield extends StatelessWidget {
  const _SwissShield({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _ShieldClipper(),
      child: SizedBox(
        width: size,
        height: size,
        child: const ColoredBox(
          color: Color(0xFFD52B1E),
          child: Center(
            child: SizedBox(
              width: 21,
              height: 21,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 7,
                    height: 21,
                    child: ColoredBox(color: Colors.white),
                  ),
                  SizedBox(
                    width: 21,
                    height: 7,
                    child: ColoredBox(color: Colors.white),
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

class _ShieldClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width * 0.92, size.height * 0.72)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height,
        size.width * 0.08,
        size.height * 0.72,
      )
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _EuStars extends StatelessWidget {
  const _EuStars();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand(
      child: CustomPaint(painter: _EuStarsPainter()),
    );
  }
}

class _EuStarsPainter extends CustomPainter {
  const _EuStarsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFFFCC00);
    final diameter = math.min(size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = diameter * 0.38;
    final starRadius = diameter * 0.10;
    for (var index = 0; index < 12; index++) {
      final angle = (math.pi * 2 * index / 12) - math.pi / 2;
      final starCenter = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      canvas.drawPath(_starPath(starCenter, starRadius), paint);
    }
  }

  Path _starPath(Offset center, double outerRadius) {
    final path = Path();
    final innerRadius = outerRadius * 0.42;
    for (var point = 0; point < 10; point++) {
      final radius = point.isEven ? outerRadius : innerRadius;
      final angle = -math.pi / 2 + (math.pi * point / 5);
      final offset = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      if (point == 0) {
        path.moveTo(offset.dx, offset.dy);
      } else {
        path.lineTo(offset.dx, offset.dy);
      }
    }
    return path..close();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
