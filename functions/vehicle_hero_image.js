const sharp = require("sharp");

const outputWidth = 1672;
const outputHeight = 940;
const vehicleBounds = Object.freeze({
  left: 68,
  top: 71,
  width: 1547,
  height: 779,
});
const maxInputPixels = 20 * 1024 * 1024;

class VehicleHeroImageError extends Error {
  constructor(message, diagnostics = null) {
    super(message);
    this.name = "VehicleHeroImageError";
    this.diagnostics = diagnostics;
  }
}

async function processVehicleHeroImage(inputBuffer) {
  if (!Buffer.isBuffer(inputBuffer) || inputBuffer.length === 0) {
    throw new VehicleHeroImageError("Das Fahrzeugbild ist leer.");
  }

  let decoded;
  try {
    decoded = await sharp(inputBuffer, {
      failOn: "error",
      limitInputPixels: maxInputPixels,
    })
      .rotate()
      .ensureAlpha()
      .toColourspace("srgb")
      .raw()
      .toBuffer({resolveWithObject: true});
  } catch (_) {
    throw new VehicleHeroImageError(
      "Das Fahrzeugbild konnte nicht sicher verarbeitet werden.",
    );
  }

  const {width, height, channels} = decoded.info;
  if (width < 256 || height < 256 || channels !== 4) {
    throw new VehicleHeroImageError(
      "Das Fahrzeugbild hat keine ausreichende Aufloesung.",
    );
  }

  const pixels = Buffer.from(decoded.data);
  const alphaStats = alphaStatistics(pixels, width, height);
  let backgroundKind = null;
  if (alphaStats.transparentRatio < 0.01) {
    backgroundKind = removeConnectedUniformBackground(pixels, width, height);
  }

  let bounds = foregroundBounds(pixels, width, height);
  validateForeground(pixels, width, height, bounds);
  const removedLightFloor = removeBroadLightFloor(pixels, width, bounds);
  if (removedLightFloor && backgroundKind != null) {
    // Ground may have enclosed key-colour pockets underneath the chassis.
    removeConnectedUniformBackground(pixels, width, height);
  }
  removeChromaSpill(pixels, backgroundKind);
  bounds = foregroundBounds(pixels, width, height);
  removeBroadOpaqueFloor(pixels, width, bounds);
  bounds = foregroundBounds(pixels, width, height);
  validateForeground(pixels, width, height, bounds);
  validateNoOpaqueFloor(pixels, width, bounds);

  const extracted = await sharp(pixels, {
    raw: {width, height, channels: 4},
  })
    .extract({
      left: bounds.left,
      top: bounds.top,
      width: bounds.width,
      height: bounds.height,
    })
    .resize({
      width: vehicleBounds.width,
      height: vehicleBounds.height,
      fit: "contain",
      background: {r: 0, g: 0, b: 0, alpha: 0},
      kernel: sharp.kernel.lanczos3,
    })
    .png({compressionLevel: 9, adaptiveFiltering: true})
    .toBuffer();

  return sharp({
    create: {
      width: outputWidth,
      height: outputHeight,
      channels: 4,
      background: {r: 0, g: 0, b: 0, alpha: 0},
    },
  })
    .composite([{
      input: extracted,
      left: vehicleBounds.left,
      top: vehicleBounds.top,
    }])
    .png({compressionLevel: 9, adaptiveFiltering: true})
    .toBuffer();
}

function alphaStatistics(pixels, width, height) {
  const pixelCount = width * height;
  let transparent = 0;
  for (let index = 3; index < pixels.length; index += 4) {
    if (pixels[index] < 245) transparent += 1;
  }
  return {transparentRatio: transparent / pixelCount};
}

function removeConnectedUniformBackground(pixels, width, height) {
  const background = borderMedianColour(pixels, width, height);
  const backgroundKind = supportedBackgroundKind(background);
  const uniformityRatio = borderUniformityRatio(
    pixels,
    width,
    height,
    background,
  );
  const hasSafeBorder = backgroundKind != null && hasSafeBorderBackground(
    pixels,
    width,
    height,
    background,
    backgroundKind,
  );
  if (!hasSafeBorder) {
    throw new VehicleHeroImageError(
      "Die Fahrzeugdarstellung enthaelt einen ungeeigneten Hintergrund.",
      {
        background,
        backgroundKind,
        uniformityRatio: Number(uniformityRatio.toFixed(3)),
      },
    );
  }

  const count = width * height;
  const connected = new Uint8Array(count);
  const queue = new Int32Array(count);
  let head = 0;
  let tail = 0;

  const enqueue = (pixelIndex) => {
    if (connected[pixelIndex] !== 0 ||
        !isBackgroundPixel(pixels, pixelIndex, background, backgroundKind)) {
      return;
    }
    connected[pixelIndex] = 1;
    queue[tail] = pixelIndex;
    tail += 1;
  };

  for (let x = 0; x < width; x += 1) {
    enqueue(x);
    enqueue((height - 1) * width + x);
  }
  for (let y = 1; y < height - 1; y += 1) {
    enqueue(y * width);
    enqueue(y * width + width - 1);
  }

  while (head < tail) {
    const pixelIndex = queue[head];
    head += 1;
    const x = pixelIndex % width;
    const y = Math.floor(pixelIndex / width);
    if (x > 0) enqueue(pixelIndex - 1);
    if (x + 1 < width) enqueue(pixelIndex + 1);
    if (y > 0) enqueue(pixelIndex - width);
    if (y + 1 < height) enqueue(pixelIndex + width);
  }

  if (tail / count < 0.08) {
    throw new VehicleHeroImageError(
      "Der Hintergrund der Fahrzeugdarstellung konnte nicht freigestellt werden.",
    );
  }

  for (let pixelIndex = 0; pixelIndex < count; pixelIndex += 1) {
    if (connected[pixelIndex] !== 0) {
      pixels[pixelIndex * 4 + 3] = 0;
    }
  }
  softenForegroundEdge(pixels, connected, width, height, background);
  return backgroundKind;
}

function borderMedianColour(pixels, width, height) {
  const red = [];
  const green = [];
  const blue = [];
  const sample = (x, y) => {
    const offset = (y * width + x) * 4;
    red.push(pixels[offset]);
    green.push(pixels[offset + 1]);
    blue.push(pixels[offset + 2]);
  };
  const xStep = Math.max(1, Math.floor(width / 256));
  const yStep = Math.max(1, Math.floor(height / 256));
  for (let x = 0; x < width; x += xStep) {
    sample(x, 0);
    sample(x, height - 1);
  }
  for (let y = yStep; y < height - 1; y += yStep) {
    sample(0, y);
    sample(width - 1, y);
  }
  return {
    r: median(red),
    g: median(green),
    b: median(blue),
  };
}

function median(values) {
  values.sort((left, right) => left - right);
  return values[Math.floor(values.length / 2)];
}

function supportedBackgroundKind(background) {
  const minimum = Math.min(background.r, background.g, background.b);
  const chroma = Math.max(background.r, background.g, background.b) - minimum;
  if (minimum >= 218 && chroma <= 38) return "light";
  if (background.g >= 120 &&
      background.g - background.r >= 25 &&
      background.g - background.b >= 25) {
    return "green";
  }
  if (background.r >= 120 &&
      background.b >= 120 &&
      Math.min(background.r, background.b) - background.g >= 25) {
    return "magenta";
  }
  return null;
}

function borderUniformityRatio(pixels, width, height, background) {
  let samples = 0;
  let matching = 0;
  const inspect = (x, y) => {
    const offset = (y * width + x) * 4;
    samples += 1;
    if (colourDistance(
      pixels[offset],
      pixels[offset + 1],
      pixels[offset + 2],
      background,
    ) <= 68) {
      matching += 1;
    }
  };
  const xStep = Math.max(1, Math.floor(width / 256));
  const yStep = Math.max(1, Math.floor(height / 256));
  for (let x = 0; x < width; x += xStep) {
    inspect(x, 0);
    inspect(x, height - 1);
  }
  for (let y = yStep; y < height - 1; y += yStep) {
    inspect(0, y);
    inspect(width - 1, y);
  }
  return matching / samples;
}

function hasSafeBorderBackground(
  pixels,
  width,
  height,
  background,
  backgroundKind,
) {
  if (backgroundKind === "light") {
    return borderUniformityRatio(pixels, width, height, background) >= 0.82;
  }

  let samples = 0;
  let matching = 0;
  const inspect = (x, y) => {
    const offset = (y * width + x) * 4;
    samples += 1;
    if (isChromaScreenColour(
      pixels[offset],
      pixels[offset + 1],
      pixels[offset + 2],
      background,
      backgroundKind,
    )) {
      matching += 1;
    }
  };
  const xStep = Math.max(1, Math.floor(width / 256));
  const yStep = Math.max(1, Math.floor(height / 256));
  for (let x = 0; x < width; x += xStep) {
    inspect(x, 0);
    inspect(x, height - 1);
  }
  for (let y = yStep; y < height - 1; y += yStep) {
    inspect(0, y);
    inspect(width - 1, y);
  }
  return matching / samples >= 0.9;
}

function isBackgroundPixel(pixels, pixelIndex, background, backgroundKind) {
  const offset = pixelIndex * 4;
  if (pixels[offset + 3] <= 8) return true;
  const red = pixels[offset];
  const green = pixels[offset + 1];
  const blue = pixels[offset + 2];
  const distance = colourDistance(red, green, blue, background);
  if (backgroundKind === "green" || backgroundKind === "magenta") {
    return isChromaScreenColour(
      red,
      green,
      blue,
      background,
      backgroundKind,
    );
  }
  const minimum = Math.min(red, green, blue);
  const chroma = Math.max(red, green, blue) - minimum;
  return minimum >= 185 && chroma <= 58 && distance <= 82;
}

function isChromaScreenColour(red, green, blue, background, backgroundKind) {
  const distance = colourDistance(red, green, blue, background);
  // A soft neutral floor mixed with the key can be far from the border's RGB
  // value while still lying on the same green/magenta-to-neutral colour axis.
  const neutralKeyMixture = Math.abs(red - blue) <= 24;
  if (backgroundKind === "green") {
    return green >= 45 && green - red >= 22 && green - blue >= 22 &&
      (distance <= 155 || neutralKeyMixture);
  }
  return red >= 45 && blue >= 45 &&
    Math.min(red, blue) - green >= 22 &&
    (distance <= 155 || neutralKeyMixture);
}

function removeChromaSpill(pixels, backgroundKind) {
  if (backgroundKind !== "green" && backgroundKind !== "magenta") return;
  for (let offset = 0; offset < pixels.length; offset += 4) {
    if (pixels[offset + 3] <= 8) continue;
    const red = pixels[offset];
    const green = pixels[offset + 1];
    const blue = pixels[offset + 2];
    if (backgroundKind === "green") {
      const neutralGreen = Math.max(red, blue);
      const spill = green - neutralGreen;
      if (spill > 6) {
        pixels[offset + 1] = Math.max(
          neutralGreen,
          Math.round(green - (spill - 3) * 0.88),
        );
      }
      continue;
    }
    const spill = Math.min(red, blue) - green;
    if (spill > 6) {
      const reduction = Math.round((spill - 3) * 0.88);
      pixels[offset] = Math.max(green, red - reduction);
      pixels[offset + 2] = Math.max(green, blue - reduction);
    }
  }
}

function colourDistance(red, green, blue, background) {
  return Math.sqrt(
    Math.pow(red - background.r, 2) +
    Math.pow(green - background.g, 2) +
    Math.pow(blue - background.b, 2),
  );
}

function softenForegroundEdge(pixels, connected, width, height, background) {
  const nextAlpha = new Uint8Array(width * height);
  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      const pixelIndex = y * width + x;
      const offset = pixelIndex * 4;
      nextAlpha[pixelIndex] = pixels[offset + 3];
      if (connected[pixelIndex] !== 0 ||
          !touchesBackground(connected, x, y, width, height)) {
        continue;
      }
      const distance = colourDistance(
        pixels[offset],
        pixels[offset + 1],
        pixels[offset + 2],
        background,
      );
      if (distance < 120) {
        nextAlpha[pixelIndex] = Math.max(
          0,
          Math.min(255, Math.round(((distance - 18) / 92) * 255)),
        );
      }
    }
  }
  for (let pixelIndex = 0; pixelIndex < nextAlpha.length; pixelIndex += 1) {
    pixels[pixelIndex * 4 + 3] = nextAlpha[pixelIndex];
  }
}

function touchesBackground(connected, x, y, width, height) {
  for (let offsetY = -1; offsetY <= 1; offsetY += 1) {
    for (let offsetX = -1; offsetX <= 1; offsetX += 1) {
      if (offsetX === 0 && offsetY === 0) continue;
      const nextX = x + offsetX;
      const nextY = y + offsetY;
      if (nextX < 0 || nextX >= width || nextY < 0 || nextY >= height) {
        continue;
      }
      if (connected[nextY * width + nextX] !== 0) return true;
    }
  }
  return false;
}

function foregroundBounds(pixels, width, height) {
  let left = width;
  let top = height;
  let right = -1;
  let bottom = -1;
  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      if (pixels[(y * width + x) * 4 + 3] <= 8) continue;
      left = Math.min(left, x);
      top = Math.min(top, y);
      right = Math.max(right, x);
      bottom = Math.max(bottom, y);
    }
  }
  if (right < left || bottom < top) {
    throw new VehicleHeroImageError(
      "Auf der Fahrzeugdarstellung wurde kein Fahrzeug erkannt.",
    );
  }
  return {
    left,
    top,
    width: right - left + 1,
    height: bottom - top + 1,
  };
}

function validateForeground(pixels, width, height, bounds) {
  const coverage = (bounds.width * bounds.height) / (width * height);
  if (coverage < 0.025 || coverage > 0.9) {
    throw new VehicleHeroImageError(
      "Die Fahrzeugdarstellung konnte nicht sicher zugeschnitten werden.",
    );
  }

  let transparentBorder = 0;
  let borderCount = 0;
  const inspect = (x, y) => {
    borderCount += 1;
    if (pixels[(y * width + x) * 4 + 3] <= 8) {
      transparentBorder += 1;
    }
  };
  for (let x = 0; x < width; x += 1) {
    inspect(x, 0);
    inspect(x, height - 1);
  }
  for (let y = 1; y < height - 1; y += 1) {
    inspect(0, y);
    inspect(width - 1, y);
  }
  if (transparentBorder / borderCount < 0.95) {
    throw new VehicleHeroImageError(
      "Die Fahrzeugdarstellung ist am Bildrand nicht transparent.",
    );
  }
}

function validateNoOpaqueFloor(pixels, width, bounds) {
  const diagnostics = opaqueFloorDiagnostics(pixels, width, bounds);
  if (diagnostics == null) return;
  if (diagnostics.opaqueRatio > 0.28 &&
      diagnostics.averageLuminance < 75) {
    throw new VehicleHeroImageError(
      "Die Fahrzeugdarstellung enthaelt eine unzulaessige Bodenflaeche.",
      {
        averageLuminance: Number(
          diagnostics.averageLuminance.toFixed(1),
        ),
        floorWidthRatio: Number(diagnostics.opaqueRatio.toFixed(3)),
      },
    );
  }
}

function opaqueFloorDiagnostics(pixels, width, bounds) {
  const probeOffset = Math.max(8, Math.round(bounds.height * 0.04));
  const y = Math.max(bounds.top, bounds.top + bounds.height - 1 - probeOffset);
  let opaquePixels = 0;
  let luminanceTotal = 0;
  for (let x = bounds.left; x < bounds.left + bounds.width; x += 1) {
    const offset = (y * width + x) * 4;
    if (pixels[offset + 3] <= 8) continue;
    opaquePixels += 1;
    luminanceTotal += (
      pixels[offset] + pixels[offset + 1] + pixels[offset + 2]
    ) / 3;
  }
  if (opaquePixels === 0) return null;
  return {
    y,
    opaqueRatio: opaquePixels / bounds.width,
    averageLuminance: luminanceTotal / opaquePixels,
  };
}

function removeBroadLightFloor(pixels, width, bounds) {
  // Keying removes the backdrop, but generated white/grey ground can remain
  // connected to the tires. Only remove shallow, broad ground components;
  // anything continuing upward into the body or wheels is left untouched.
  const top = bounds.top + Math.floor(bounds.height * 0.7);
  const bottom = bounds.top + bounds.height - 1;
  const regionHeight = bottom - top + 1;
  const count = bounds.width * regionHeight;
  const visited = new Uint8Array(count);
  const queue = new Int32Array(count);
  let removed = false;
  const isLightGround = (index) => {
    const x = bounds.left + index % bounds.width;
    const y = top + Math.floor(index / bounds.width);
    const offset = (y * width + x) * 4;
    if (pixels[offset + 3] <= 8) return false;
    const minimum = Math.min(
      pixels[offset], pixels[offset + 1], pixels[offset + 2],
    );
    const maximum = Math.max(
      pixels[offset], pixels[offset + 1], pixels[offset + 2],
    );
    return minimum >= 110 && maximum - minimum <= 40;
  };

  for (let seed = 0; seed < count; seed += 1) {
    if (visited[seed]) continue;
    visited[seed] = 1;
    if (!isLightGround(seed)) continue;
    let head = 0;
    let tail = 1;
    queue[0] = seed;
    let left = bounds.width;
    let right = -1;
    let firstRow = regionHeight;
    let lastRow = -1;
    const enqueue = (index) => {
      if (visited[index]) return;
      visited[index] = 1;
      if (isLightGround(index)) queue[tail++] = index;
    };
    while (head < tail) {
      const index = queue[head++];
      const x = index % bounds.width;
      const y = Math.floor(index / bounds.width);
      left = Math.min(left, x);
      right = Math.max(right, x);
      firstRow = Math.min(firstRow, y);
      lastRow = Math.max(lastRow, y);
      if (x > 0) enqueue(index - 1);
      if (x + 1 < bounds.width) enqueue(index + 1);
      if (y > 0) enqueue(index - bounds.width);
      if (y + 1 < regionHeight) enqueue(index + bounds.width);
    }

    const componentWidth = right - left + 1;
    const componentHeight = lastRow - firstRow + 1;
    if (firstRow === 0 ||
        lastRow < regionHeight - 1 - Math.max(2, bounds.height * 0.02) ||
        componentWidth < bounds.width * 0.48 ||
        componentHeight > bounds.height * 0.24 ||
        componentWidth / componentHeight < 4 ||
        tail < componentWidth * componentHeight * 0.2) {
      continue;
    }
    for (let index = 0; index < tail; index += 1) {
      const x = bounds.left + queue[index] % bounds.width;
      const y = top + Math.floor(queue[index] / bounds.width);
      pixels[(y * width + x) * 4 + 3] = 0;
    }
    removed = true;
  }
  return removed;
}

function removeBroadOpaqueFloor(pixels, width, bounds) {
  const diagnostics = opaqueFloorDiagnostics(pixels, width, bounds);
  if (diagnostics == null ||
      diagnostics.opaqueRatio <= 0.28 ||
      diagnostics.averageLuminance >= 75) {
    return;
  }

  const bottom = bounds.top + bounds.height - 1;
  const cleanupTop = bounds.top + Math.round(bounds.height * 0.84);
  const anchorSearchTop = Math.max(
    bounds.top,
    cleanupTop - Math.round(bounds.height * 0.24),
  );
  const anchorSpan = Math.max(24, Math.round(bounds.height * 0.11));
  const minimumAnchorSamples = Math.max(4, Math.round(anchorSpan * 0.075));
  const anchorBottom = new Int32Array(bounds.width);
  anchorBottom.fill(-1);

  for (let x = bounds.left; x < bounds.left + bounds.width; x += 1) {
    const column = x - bounds.left;
    const recentAnchors = [];
    let recentHead = 0;
    for (let y = anchorSearchTop; y <= bottom; y += 1) {
      const offset = (y * width + x) * 4;
      if (pixels[offset + 3] <= 40) continue;
      const red = pixels[offset];
      const green = pixels[offset + 1];
      const blue = pixels[offset + 2];
      const luminance = (red + green + blue) / 3;
      const chroma = Math.max(red, green, blue) - Math.min(red, green, blue);
      if (luminance >= 52 || chroma >= 30) {
        recentAnchors.push(y);
        while (recentAnchors[recentHead] < y - anchorSpan) {
          recentHead += 1;
        }
        if (recentAnchors.length - recentHead >= minimumAnchorSamples) {
          anchorBottom[column] = y;
        }
      }
    }
  }

  const wheelColumns = detectWheelColumns(anchorBottom, bounds, cleanupTop);

  const transitionHeight = Math.max(8, Math.round(bounds.height * 0.025));
  for (let y = cleanupTop; y <= bottom; y += 1) {
    for (let x = bounds.left; x < bounds.left + bounds.width; x += 1) {
      const offset = (y * width + x) * 4;
      const alpha = pixels[offset + 3];
      if (alpha <= 8) continue;

      const wheelStrength = wheelColumns[x - bounds.left];
      const removalStart = cleanupTop + Math.round(
        (bottom - cleanupTop) * wheelStrength,
      );
      if (y <= removalStart) continue;

      const verticalStrength = Math.min(
        1,
        (y - removalStart) / transitionHeight,
      );
      pixels[offset + 3] = Math.round(alpha * (1 - verticalStrength));
    }
  }
}

function detectWheelColumns(anchorBottom, bounds, cleanupTop) {
  const wheelColumns = new Float32Array(bounds.width);
  const threshold = cleanupTop + Math.max(
    28,
    Math.round(bounds.height * 0.065),
  );
  const minimumWidth = Math.max(18, Math.round(bounds.height * 0.045));
  const padding = Math.max(24, Math.round(bounds.height * 0.12));
  let start = -1;

  const markGroup = (end) => {
    if (start < 0 || end - start < minimumWidth) return;
    wheelColumns.fill(1, start, end);
    for (let distance = 1; distance <= padding; distance += 1) {
      const strength = 1 - distance / (padding + 1);
      const left = start - distance;
      const right = end - 1 + distance;
      if (left >= 0) wheelColumns[left] = Math.max(wheelColumns[left], strength);
      if (right < bounds.width) {
        wheelColumns[right] = Math.max(wheelColumns[right], strength);
      }
    }
  };

  for (let column = 0; column <= bounds.width; column += 1) {
    if (column < bounds.width && anchorBottom[column] >= threshold) {
      if (start < 0) start = column;
      continue;
    }
    markGroup(column);
    start = -1;
  }
  return wheelColumns;
}

module.exports = {
  VehicleHeroImageError,
  outputHeight,
  outputWidth,
  processVehicleHeroImage,
  vehicleBounds,
};
