import 'dart:io';
import 'dart:math' as math;

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
    return ImageQualityResult(
      width: originalWidth,
      height: originalHeight,
      averageLuminance: average,
      contrast: contrast,
      sharpness: sharpness,
      failures: failures,
    );
  }
}
