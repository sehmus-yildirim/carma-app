import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as image;

import '../domain/verification_models.dart';
import 'document_services.dart';

class LocalImageQualityService implements ImageQualityService {
  const LocalImageQualityService({
    this.minimumLongEdge = 1200,
    this.minimumShortEdge = 700,
    this.darkThreshold = 28,
    this.overexposedThreshold = 247,
    this.minimumSharpness = 2.2,
  });

  final int minimumLongEdge;
  final int minimumShortEdge;
  final double darkThreshold;
  final double overexposedThreshold;
  final double minimumSharpness;

  @override
  Future<ImageQualityResult> inspect(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    return Isolate.run(
      () => _inspectVerificationImage(
        bytes,
        minimumLongEdge: minimumLongEdge,
        minimumShortEdge: minimumShortEdge,
        darkThreshold: darkThreshold,
        overexposedThreshold: overexposedThreshold,
        minimumSharpness: minimumSharpness,
      ),
    );
  }
}

ImageQualityResult _inspectVerificationImage(
  Uint8List bytes, {
  required int minimumLongEdge,
  required int minimumShortEdge,
  required double darkThreshold,
  required double overexposedThreshold,
  required double minimumSharpness,
}) {
  final decoded = image.decodeImage(bytes);
  if (decoded == null) {
    return const ImageQualityResult(
      width: 0,
      height: 0,
      averageLuminance: 0,
      contrast: 0,
      sharpness: 0,
      failures: <ImageQualityFailure>[ImageQualityFailure.tooSmall],
    );
  }
  final originalWidth = decoded.width;
  final originalHeight = decoded.height;
  final sampled = decoded.width > 512
      ? image.copyResize(
          decoded,
          width: 512,
          interpolation: image.Interpolation.linear,
        )
      : decoded;
  final luminance = List<double>.filled(sampled.width * sampled.height, 0);
  var sum = 0.0;
  var index = 0;
  for (var y = 0; y < sampled.height; y += 1) {
    for (var x = 0; x < sampled.width; x += 1) {
      final pixel = sampled.getPixel(x, y);
      final value =
          0.2126 * pixel.r.toDouble() +
          0.7152 * pixel.g.toDouble() +
          0.0722 * pixel.b.toDouble();
      luminance[index++] = value;
      sum += value;
    }
  }
  final average = sum / luminance.length;
  var squared = 0.0;
  for (final value in luminance) {
    squared += math.pow(value - average, 2).toDouble();
  }
  final contrast = math.sqrt(squared / luminance.length);
  var laplacian = 0.0;
  var samples = 0;
  for (var y = 1; y < sampled.height - 1; y += 1) {
    for (var x = 1; x < sampled.width - 1; x += 1) {
      final center = luminance[y * sampled.width + x];
      final value =
          4 * center -
          luminance[(y - 1) * sampled.width + x] -
          luminance[(y + 1) * sampled.width + x] -
          luminance[y * sampled.width + x - 1] -
          luminance[y * sampled.width + x + 1];
      laplacian += value.abs();
      samples += 1;
    }
  }
  final sharpness = samples == 0 ? 0.0 : laplacian / samples;
  final failures = <ImageQualityFailure>[];
  final longEdge = math.max(originalWidth, originalHeight);
  final shortEdge = math.min(originalWidth, originalHeight);
  if (longEdge < minimumLongEdge || shortEdge < minimumShortEdge) {
    failures.add(ImageQualityFailure.tooSmall);
  }
  if (average < darkThreshold) failures.add(ImageQualityFailure.tooDark);
  if (average > overexposedThreshold) {
    failures.add(ImageQualityFailure.overexposed);
  }
  if (sharpness < minimumSharpness && contrast < 24) {
    failures.add(ImageQualityFailure.blurry);
  }
  final framingHints = _analyzeDocumentFrame(
    luminance,
    width: sampled.width,
    height: sampled.height,
  );
  return ImageQualityResult(
    width: originalWidth,
    height: originalHeight,
    averageLuminance: average,
    contrast: contrast,
    sharpness: sharpness,
    failures: failures,
    framingHints: framingHints,
  );
}

List<ImageQualityFailure> _analyzeDocumentFrame(
  List<double> luminance, {
  required int width,
  required int height,
}) {
  if (width < 40 || height < 40) return const [];
  final connectedCandidate = _connectedDocumentFrameFailures(
    luminance,
    width: width,
    height: height,
  );
  if (connectedCandidate != null) return connectedCandidate;
  final vertical = List<double>.filled(width, 0);
  final horizontal = List<double>.filled(height, 0);
  final yStart = math.max(1, (height * 0.04).round());
  final yEnd = math.min(height - 1, (height * 0.96).round());
  final xStart = math.max(1, (width * 0.04).round());
  final xEnd = math.min(width - 1, (width * 0.96).round());
  for (var x = 1; x < width; x += 1) {
    var sum = 0.0;
    for (var y = yStart; y < yEnd; y += 1) {
      sum += (luminance[y * width + x] - luminance[y * width + x - 1]).abs();
    }
    vertical[x] = sum / math.max(1, yEnd - yStart);
  }
  for (var y = 1; y < height; y += 1) {
    var sum = 0.0;
    for (var x = xStart; x < xEnd; x += 1) {
      sum += (luminance[y * width + x] - luminance[(y - 1) * width + x]).abs();
    }
    horizontal[y] = sum / math.max(1, xEnd - xStart);
  }

  final verticalBaseline = _projectionBaseline(vertical);
  final horizontalBaseline = _projectionBaseline(horizontal);
  final left = _strongestProjection(
    vertical,
    1,
    (width * 0.46).round(),
    verticalBaseline,
  );
  final right = _strongestProjection(
    vertical,
    (width * 0.54).round(),
    width - 1,
    verticalBaseline,
  );
  final top = _strongestProjection(
    horizontal,
    1,
    (height * 0.46).round(),
    horizontalBaseline,
  );
  final bottom = _strongestProjection(
    horizontal,
    (height * 0.54).round(),
    height - 1,
    horizontalBaseline,
  );
  final detected = [left, right, top, bottom].whereType<_EdgePeak>().length;
  if (detected == 3 &&
      _missingBoundaryLooksCropped(
        luminance,
        width: width,
        height: height,
        left: left,
        right: right,
        top: top,
        bottom: bottom,
      )) {
    return const [ImageQualityFailure.documentCropped];
  }
  if (left == null || right == null || top == null || bottom == null) {
    return const [];
  }

  final failures = <ImageQualityFailure>[];
  final documentWidth = right.index - left.index;
  final documentHeight = bottom.index - top.index;
  final widthRatio = documentWidth / width;
  final heightRatio = documentHeight / height;
  if (widthRatio < 0.42 || heightRatio < 0.28) {
    failures.add(ImageQualityFailure.documentTooSmall);
  }
  if (left.index <= width * 0.015 ||
      right.index >= width * 0.985 ||
      top.index <= height * 0.015 ||
      bottom.index >= height * 0.985) {
    failures.add(ImageQualityFailure.documentCropped);
  }

  final topSlope = _horizontalBoundarySlope(
    luminance,
    width: width,
    height: height,
    left: left.index,
    right: right.index,
    expectedY: top.index,
  );
  final bottomSlope = _horizontalBoundarySlope(
    luminance,
    width: width,
    height: height,
    left: left.index,
    right: right.index,
    expectedY: bottom.index,
  );
  if (topSlope != null && bottomSlope != null) {
    final averageSlope = (topSlope + bottomSlope) / 2;
    if (averageSlope.abs() > 0.18) {
      failures.add(ImageQualityFailure.documentRotated);
    }
    if ((topSlope - bottomSlope).abs() > 0.16) {
      failures.add(ImageQualityFailure.perspectiveDistortion);
    }
  }
  return failures;
}

List<ImageQualityFailure>? _connectedDocumentFrameFailures(
  List<double> luminance, {
  required int width,
  required int height,
}) {
  final patchWidth = math.max(2, (width * 0.04).round());
  final patchHeight = math.max(2, (height * 0.04).round());
  var backgroundSum = 0.0;
  var backgroundSamples = 0;
  for (final origin in [
    (x: 0, y: 0),
    (x: width - patchWidth, y: 0),
    (x: 0, y: height - patchHeight),
    (x: width - patchWidth, y: height - patchHeight),
  ]) {
    for (var y = origin.y; y < origin.y + patchHeight; y += 1) {
      for (var x = origin.x; x < origin.x + patchWidth; x += 1) {
        backgroundSum += luminance[y * width + x];
        backgroundSamples += 1;
      }
    }
  }
  final background = backgroundSum / backgroundSamples;
  final mask = Uint8List(width * height);
  for (var index = 0; index < luminance.length; index += 1) {
    if ((luminance[index] - background).abs() >= 34) mask[index] = 1;
  }
  final visited = Uint8List(mask.length);
  _ConnectedFrame? largest;
  for (var start = 0; start < mask.length; start += 1) {
    if (mask[start] == 0 || visited[start] != 0) continue;
    final queue = <int>[start];
    visited[start] = 1;
    var cursor = 0;
    var count = 0;
    var minX = width;
    var minY = height;
    var maxX = 0;
    var maxY = 0;
    final pixels = <int>[];
    while (cursor < queue.length) {
      final index = queue[cursor++];
      pixels.add(index);
      count += 1;
      final x = index % width;
      final y = index ~/ width;
      minX = math.min(minX, x);
      minY = math.min(minY, y);
      maxX = math.max(maxX, x);
      maxY = math.max(maxY, y);
      if (x > 0) _enqueueMask(index - 1, mask, visited, queue);
      if (x + 1 < width) _enqueueMask(index + 1, mask, visited, queue);
      if (y > 0) _enqueueMask(index - width, mask, visited, queue);
      if (y + 1 < height) {
        _enqueueMask(index + width, mask, visited, queue);
      }
    }
    if (largest == null || count > largest.count) {
      largest = _ConnectedFrame(
        pixels: pixels,
        count: count,
        minX: minX,
        minY: minY,
        maxX: maxX,
        maxY: maxY,
      );
    }
  }
  if (largest == null || largest.count < width * height * 0.05) return null;
  final boxWidth = largest.maxX - largest.minX + 1;
  final boxHeight = largest.maxY - largest.minY + 1;
  final density = largest.count / (boxWidth * boxHeight);
  if (density < 0.35) return null;

  final failures = <ImageQualityFailure>[];
  if (boxWidth / width < 0.42 || boxHeight / height < 0.28) {
    failures.add(ImageQualityFailure.documentTooSmall);
  }
  if (largest.minX <= width * 0.01 ||
      largest.maxX >= width * 0.99 ||
      largest.minY <= height * 0.01 ||
      largest.maxY >= height * 0.99) {
    failures.add(ImageQualityFailure.documentCropped);
  }

  final topByX = List<int>.filled(width, height);
  final bottomByX = List<int>.filled(width, -1);
  final leftByY = List<int>.filled(height, width);
  final rightByY = List<int>.filled(height, -1);
  for (final index in largest.pixels) {
    final x = index % width;
    final y = index ~/ width;
    topByX[x] = math.min(topByX[x], y);
    bottomByX[x] = math.max(bottomByX[x], y);
    leftByY[y] = math.min(leftByY[y], x);
    rightByY[y] = math.max(rightByY[y], x);
  }
  final topPoints = <math.Point<double>>[];
  final bottomPoints = <math.Point<double>>[];
  for (var x = largest.minX; x <= largest.maxX; x += 1) {
    if (topByX[x] < height) {
      topPoints.add(math.Point<double>(x.toDouble(), topByX[x].toDouble()));
    }
    if (bottomByX[x] >= 0) {
      bottomPoints.add(
        math.Point<double>(x.toDouble(), bottomByX[x].toDouble()),
      );
    }
  }
  final topSlope = _linearSlope(topPoints);
  final bottomSlope = _linearSlope(bottomPoints);
  if (topSlope != null && bottomSlope != null) {
    if (((topSlope + bottomSlope) / 2).abs() > 0.14) {
      failures.add(ImageQualityFailure.documentRotated);
    }
    if ((topSlope - bottomSlope).abs() > 0.16) {
      failures.add(ImageQualityFailure.perspectiveDistortion);
    }
  }
  final rowWidths = <int>[];
  for (var y = largest.minY; y <= largest.maxY; y += 1) {
    if (leftByY[y] < width && rightByY[y] >= 0) {
      rowWidths.add(rightByY[y] - leftByY[y] + 1);
    }
  }
  if (rowWidths.length >= 12) {
    final sample = math.max(3, rowWidths.length ~/ 5);
    final topWidth = rowWidths.take(sample).reduce((a, b) => a + b) / sample;
    final bottomWidth =
        rowWidths.reversed.take(sample).reduce((a, b) => a + b) / sample;
    if ((topWidth - bottomWidth).abs() / math.max(topWidth, bottomWidth) >
        0.2) {
      failures.add(ImageQualityFailure.perspectiveDistortion);
    }
  }
  return failures.toSet().toList(growable: false);
}

void _enqueueMask(
  int index,
  Uint8List mask,
  Uint8List visited,
  List<int> queue,
) {
  if (mask[index] == 0 || visited[index] != 0) return;
  visited[index] = 1;
  queue.add(index);
}

double? _linearSlope(List<math.Point<double>> points) {
  if (points.length < 8) return null;
  final meanX =
      points.map((point) => point.x).reduce((a, b) => a + b) / points.length;
  final meanY =
      points.map((point) => point.y).reduce((a, b) => a + b) / points.length;
  var numerator = 0.0;
  var denominator = 0.0;
  for (final point in points) {
    numerator += (point.x - meanX) * (point.y - meanY);
    denominator += math.pow(point.x - meanX, 2).toDouble();
  }
  return denominator == 0 ? null : numerator / denominator;
}

double _projectionBaseline(List<double> values) {
  final sorted = [...values]..sort();
  return sorted[sorted.length ~/ 2];
}

_EdgePeak? _strongestProjection(
  List<double> values,
  int start,
  int end,
  double baseline,
) {
  var bestIndex = start;
  var bestValue = 0.0;
  for (var index = start; index < end; index += 1) {
    if (values[index] > bestValue) {
      bestValue = values[index];
      bestIndex = index;
    }
  }
  final threshold = math.max(5.5, baseline * 2.4);
  return bestValue >= threshold ? _EdgePeak(index: bestIndex) : null;
}

bool _missingBoundaryLooksCropped(
  List<double> luminance, {
  required int width,
  required int height,
  required _EdgePeak? left,
  required _EdgePeak? right,
  required _EdgePeak? top,
  required _EdgePeak? bottom,
}) {
  final center = _patchMean(
    luminance,
    width: width,
    height: height,
    centerX: width ~/ 2,
    centerY: height ~/ 2,
  );
  if (left == null && right != null && top != null && bottom != null) {
    return (center -
                _patchMean(
                  luminance,
                  width: width,
                  height: height,
                  centerX: 1,
                  centerY: height ~/ 2,
                ))
            .abs() <
        20;
  }
  if (right == null && left != null && top != null && bottom != null) {
    return (center -
                _patchMean(
                  luminance,
                  width: width,
                  height: height,
                  centerX: width - 2,
                  centerY: height ~/ 2,
                ))
            .abs() <
        20;
  }
  if (top == null && left != null && right != null && bottom != null) {
    return (center -
                _patchMean(
                  luminance,
                  width: width,
                  height: height,
                  centerX: width ~/ 2,
                  centerY: 1,
                ))
            .abs() <
        20;
  }
  if (bottom == null && left != null && right != null && top != null) {
    return (center -
                _patchMean(
                  luminance,
                  width: width,
                  height: height,
                  centerX: width ~/ 2,
                  centerY: height - 2,
                ))
            .abs() <
        20;
  }
  return false;
}

double _patchMean(
  List<double> luminance, {
  required int width,
  required int height,
  required int centerX,
  required int centerY,
}) {
  var sum = 0.0;
  var count = 0;
  for (
    var y = math.max(0, centerY - 2);
    y <= math.min(height - 1, centerY + 2);
    y += 1
  ) {
    for (
      var x = math.max(0, centerX - 2);
      x <= math.min(width - 1, centerX + 2);
      x += 1
    ) {
      sum += luminance[y * width + x];
      count += 1;
    }
  }
  return sum / math.max(1, count);
}

double? _horizontalBoundarySlope(
  List<double> luminance, {
  required int width,
  required int height,
  required int left,
  required int right,
  required int expectedY,
}) {
  final points = <math.Point<double>>[];
  final radius = math.max(4, (height * 0.08).round());
  final step = math.max(4, (right - left) ~/ 10);
  for (var x = left + step; x < right - step; x += step) {
    var bestY = expectedY;
    var bestValue = 0.0;
    for (
      var y = math.max(1, expectedY - radius);
      y < math.min(height, expectedY + radius);
      y += 1
    ) {
      final value = (luminance[y * width + x] - luminance[(y - 1) * width + x])
          .abs();
      if (value > bestValue) {
        bestValue = value;
        bestY = y;
      }
    }
    if (bestValue >= 12) {
      points.add(math.Point<double>(x.toDouble(), bestY.toDouble()));
    }
  }
  if (points.length < 5) return null;
  final meanX =
      points.map((point) => point.x).reduce((a, b) => a + b) / points.length;
  final meanY =
      points.map((point) => point.y).reduce((a, b) => a + b) / points.length;
  var numerator = 0.0;
  var denominator = 0.0;
  for (final point in points) {
    numerator += (point.x - meanX) * (point.y - meanY);
    denominator += math.pow(point.x - meanX, 2).toDouble();
  }
  return denominator == 0 ? null : numerator / denominator;
}

class _EdgePeak {
  const _EdgePeak({required this.index});

  final int index;
}

class _ConnectedFrame {
  const _ConnectedFrame({
    required this.pixels,
    required this.count,
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });

  final List<int> pixels;
  final int count;
  final int minX;
  final int minY;
  final int maxX;
  final int maxY;
}
