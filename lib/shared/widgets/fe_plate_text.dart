import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Renders registration marks from public-domain FE-Schrift vector outlines.
///
/// Source and license details live next to the vector asset in
/// `assets/data/FE_SCHRIFT_NOTICE.txt`.
class FePlateText extends StatelessWidget {
  const FePlateText(
    this.value, {
    super.key,
    required this.fontSize,
    this.color = const Color(0xFF080808),
    this.embossed = true,
  });

  static final Future<_FeGlyphSet> _glyphSet = _FeGlyphSet.load();

  static Future<void> preload() async {
    await _glyphSet;
  }

  final String value;
  final double fontSize;
  final Color color;
  final bool embossed;

  @override
  Widget build(BuildContext context) {
    final normalized = value.trim().toUpperCase();
    if (normalized.isEmpty) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<_FeGlyphSet>(
      future: _glyphSet,
      builder: (context, snapshot) {
        final glyphs = snapshot.data;
        if (glyphs == null) {
          return SizedBox(height: fontSize);
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight = constraints.hasBoundedHeight
                ? constraints.maxHeight
                : fontSize;
            final height = math.min(fontSize, availableHeight);
            return SizedBox(
              width: constraints.hasBoundedWidth
                  ? constraints.maxWidth
                  : glyphs.idealWidth(normalized, height),
              height: height,
              child: CustomPaint(
                painter: _FePlateTextPainter(
                  value: normalized,
                  glyphs: glyphs,
                  color: color,
                  embossed: embossed,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _FePlateTextPainter extends CustomPainter {
  const _FePlateTextPainter({
    required this.value,
    required this.glyphs,
    required this.color,
    required this.embossed,
  });

  final String value;
  final _FeGlyphSet glyphs;
  final Color color;
  final bool embossed;

  @override
  void paint(Canvas canvas, Size size) {
    final paths = value
        .split('')
        .map(glyphs.pathFor)
        .whereType<Path>()
        .toList(growable: false);
    if (paths.isEmpty || size.isEmpty) {
      return;
    }

    var glyphHeight = size.height * 0.93;
    const normalSpacingRatio = 0.105;
    final naturalWidth = _totalWidth(
      paths,
      glyphHeight,
      horizontalScale: 1,
      spacingRatio: normalSpacingRatio,
    );

    // FE-Mittelschrift is preferred. Horizontal compression is used only if
    // the complete registration mark would otherwise not fit its plate zone.
    var horizontalScale = math.min(1.0, size.width / naturalWidth);
    if (horizontalScale < 0.82) {
      glyphHeight *= horizontalScale / 0.82;
      horizontalScale = 0.82;
    }

    final totalWidth = _totalWidth(
      paths,
      glyphHeight,
      horizontalScale: horizontalScale,
      spacingRatio: normalSpacingRatio,
    );
    var cursorX = math.max(0.0, (size.width - totalWidth) / 2);
    final top = (size.height - glyphHeight) / 2;

    final mainPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final shadowPaint = Paint()
      ..color = Color.fromRGBO(0, 0, 0, color.a == 0 ? 0 : 0.38)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.45);
    final highlightPaint = Paint()
      ..color = Color.fromRGBO(255, 255, 255, color.a == 0 ? 0 : 0.3)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    for (final sourcePath in paths) {
      final bounds = sourcePath.getBounds();
      final scaleY = glyphHeight / bounds.height;
      final scaleX = scaleY * horizontalScale;
      final glyphWidth = bounds.width * scaleX;
      final transformed = sourcePath.transform(
        Float64List.fromList(<double>[
          scaleX,
          0,
          0,
          0,
          0,
          scaleY,
          0,
          0,
          0,
          0,
          1,
          0,
          cursorX - (bounds.left * scaleX),
          top - (bounds.top * scaleY),
          0,
          1,
        ]),
      );

      if (embossed) {
        canvas.drawPath(
          transformed.shift(const Offset(-0.35, -0.45)),
          highlightPaint,
        );
        canvas.drawPath(
          transformed.shift(const Offset(0.75, 0.9)),
          shadowPaint,
        );
      }
      canvas.drawPath(transformed, mainPaint);
      cursorX += glyphWidth + (glyphHeight * normalSpacingRatio);
    }
  }

  double _totalWidth(
    List<Path> paths,
    double height, {
    required double horizontalScale,
    required double spacingRatio,
  }) {
    var width = 0.0;
    for (final path in paths) {
      final bounds = path.getBounds();
      width += bounds.width * (height / bounds.height) * horizontalScale;
    }
    if (paths.length > 1) {
      width += (paths.length - 1) * height * spacingRatio;
    }
    return width;
  }

  @override
  bool shouldRepaint(covariant _FePlateTextPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.glyphs != glyphs ||
        oldDelegate.color != color ||
        oldDelegate.embossed != embossed;
  }
}

class _FeGlyphSet {
  const _FeGlyphSet(this._paths);

  static const _characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789ÄÖÜ';

  final Map<String, Path> _paths;

  static Future<_FeGlyphSet> load() async {
    final source = await rootBundle.loadString('assets/data/fe_schrift.svg');
    final matches = RegExp(
      r'<path\b[^>]*\bd="([^"]+)"[^>]*/?>',
      dotAll: true,
    ).allMatches(source);
    final outlines = matches
        .map((match) => match.group(1))
        .whereType<String>()
        .take(_characters.length)
        .toList(growable: false);
    if (outlines.length != _characters.length) {
      throw const FormatException(
        'FE-Schrift-Vektorzeichen sind unvollständig.',
      );
    }

    return _FeGlyphSet(<String, Path>{
      for (var index = 0; index < _characters.length; index++)
        _characters[index]: _SvgPathParser(outlines[index]).parse(),
    });
  }

  Path? pathFor(String character) => _paths[character];

  double idealWidth(String value, double height) {
    final paths = value
        .split('')
        .map(pathFor)
        .whereType<Path>()
        .toList(growable: false);
    var width = 0.0;
    for (final path in paths) {
      final bounds = path.getBounds();
      width += bounds.width * (height / bounds.height);
    }
    return width + (math.max(0, paths.length - 1) * height * 0.105);
  }
}

class _SvgPathParser {
  _SvgPathParser(String source)
    : _tokens = RegExp(
        r'[MmLlHhVvCcZz]|[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?',
      ).allMatches(source).map((match) => match.group(0)!).toList();

  final List<String> _tokens;
  var _index = 0;
  var _command = '';
  var _x = 0.0;
  var _y = 0.0;
  var _subpathX = 0.0;
  var _subpathY = 0.0;

  Path parse() {
    final path = Path();
    while (_index < _tokens.length) {
      final token = _tokens[_index];
      if (_isCommand(token)) {
        _command = token;
        _index++;
        if (_command == 'z' || _command == 'Z') {
          path.close();
          _x = _subpathX;
          _y = _subpathY;
        }
        continue;
      }

      switch (_command) {
        case 'm':
        case 'M':
          final relative = _command == 'm';
          final nextX = _number();
          final nextY = _number();
          _x = relative ? _x + nextX : nextX;
          _y = relative ? _y + nextY : nextY;
          path.moveTo(_x, _y);
          _subpathX = _x;
          _subpathY = _y;
          _command = relative ? 'l' : 'L';
          continue;
        case 'l':
        case 'L':
          final relative = _command == 'l';
          final nextX = _number();
          final nextY = _number();
          _x = relative ? _x + nextX : nextX;
          _y = relative ? _y + nextY : nextY;
          path.lineTo(_x, _y);
          continue;
        case 'h':
        case 'H':
          final nextX = _number();
          _x = _command == 'h' ? _x + nextX : nextX;
          path.lineTo(_x, _y);
          continue;
        case 'v':
        case 'V':
          final nextY = _number();
          _y = _command == 'v' ? _y + nextY : nextY;
          path.lineTo(_x, _y);
          continue;
        case 'c':
        case 'C':
          final relative = _command == 'c';
          final control1X = _number();
          final control1Y = _number();
          final control2X = _number();
          final control2Y = _number();
          final endX = _number();
          final endY = _number();
          path.cubicTo(
            relative ? _x + control1X : control1X,
            relative ? _y + control1Y : control1Y,
            relative ? _x + control2X : control2X,
            relative ? _y + control2Y : control2Y,
            relative ? _x + endX : endX,
            relative ? _y + endY : endY,
          );
          _x = relative ? _x + endX : endX;
          _y = relative ? _y + endY : endY;
          continue;
        default:
          throw FormatException(
            'Nicht unterstütztes SVG-Pfadkommando: $_command',
          );
      }
    }
    return path;
  }

  bool _isCommand(String token) {
    return token.length == 1 && 'MmLlHhVvCcZz'.contains(token);
  }

  double _number() => double.parse(_tokens[_index++]);
}
