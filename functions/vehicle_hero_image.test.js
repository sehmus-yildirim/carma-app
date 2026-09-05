const assert = require("node:assert/strict");
const test = require("node:test");
const path = require("node:path");
const fs = require("node:fs/promises");
const sharp = require("sharp");

const {
  VehicleHeroImageError,
  outputHeight,
  outputWidth,
  processVehicleHeroImage,
  vehicleBounds,
} = require("./vehicle_hero_image");

test("removes an edge-connected white background and normalizes the canvas", async () => {
  const input = await sharp({
    create: {
      width: 900,
      height: 600,
      channels: 4,
      background: {r: 255, g: 255, b: 255, alpha: 1},
    },
  })
    .composite([{
      input: {
        create: {
          width: 600,
          height: 260,
          channels: 4,
          background: {r: 24, g: 78, b: 150, alpha: 1},
        },
      },
      left: 150,
      top: 190,
    }])
    .png()
    .toBuffer();

  const output = await processVehicleHeroImage(input);
  const {data, info} = await sharp(output)
    .ensureAlpha()
    .raw()
    .toBuffer({resolveWithObject: true});

  assert.equal(info.width, outputWidth);
  assert.equal(info.height, outputHeight);
  assert.equal(data[3], 0);
  assert.equal(data[((outputHeight - 1) * outputWidth) * 4 + 3], 0);
  const centreOffset = (
    Math.floor(outputHeight / 2) * outputWidth +
    Math.floor(outputWidth / 2)
  ) * 4;
  assert.ok(data[centreOffset + 3] > 245);
});

test("removes chroma green without erasing a white vehicle", async () => {
  const width = 900;
  const height = 600;
  const greenGradient = Buffer.alloc(width * height * 4);
  for (let y = 0; y < height; y += 1) {
    const redBlue = 62 + Math.round((y / (height - 1)) * 105);
    const green = Math.min(255, redBlue + 58);
    for (let x = 0; x < width; x += 1) {
      const offset = (y * width + x) * 4;
      greenGradient[offset] = redBlue;
      greenGradient[offset + 1] = green;
      greenGradient[offset + 2] = redBlue;
      greenGradient[offset + 3] = 255;
    }
  }
  const input = await sharp(greenGradient, {
    raw: {width, height, channels: 4},
  })
    .composite([{
      input: {
        create: {
          width: 600,
          height: 260,
          channels: 4,
          background: {r: 248, g: 248, b: 248, alpha: 1},
        },
      },
      left: 150,
      top: 190,
    }])
    .png()
    .toBuffer();

  const output = await processVehicleHeroImage(input);
  const {data, info} = await sharp(output)
    .ensureAlpha()
    .raw()
    .toBuffer({resolveWithObject: true});
  const centreOffset = (
    Math.floor(info.height / 2) * info.width +
    Math.floor(info.width / 2)
  ) * 4;

  assert.equal(data[3], 0);
  assert.ok(data[centreOffset] >= 240);
  assert.ok(data[centreOffset + 1] >= 240);
  assert.ok(data[centreOffset + 2] >= 240);
  assert.ok(data[centreOffset + 3] > 245);
});

test("removes chroma magenta without erasing a green vehicle", async () => {
  const width = 900;
  const height = 600;
  const magentaGradient = Buffer.alloc(width * height * 4);
  for (let y = 0; y < height; y += 1) {
    const green = 58 + Math.round((y / (height - 1)) * 90);
    const redBlue = Math.min(255, green + 62);
    for (let x = 0; x < width; x += 1) {
      const offset = (y * width + x) * 4;
      magentaGradient[offset] = redBlue;
      magentaGradient[offset + 1] = green;
      magentaGradient[offset + 2] = redBlue;
      magentaGradient[offset + 3] = 255;
    }
  }
  const input = await sharp(magentaGradient, {
    raw: {width, height, channels: 4},
  })
    .composite([{
      input: {
        create: {
          width: 600,
          height: 260,
          channels: 4,
          background: {r: 34, g: 132, b: 76, alpha: 1},
        },
      },
      left: 150,
      top: 190,
    }])
    .png()
    .toBuffer();

  const output = await processVehicleHeroImage(input);
  const {data, info} = await sharp(output)
    .ensureAlpha()
    .raw()
    .toBuffer({resolveWithObject: true});
  const centreOffset = (
    Math.floor(info.height / 2) * info.width +
    Math.floor(info.width / 2)
  ) * 4;

  assert.equal(data[3], 0);
  assert.ok(data[centreOffset + 1] > data[centreOffset]);
  assert.ok(data[centreOffset + 1] > data[centreOffset + 2]);
  assert.ok(data[centreOffset + 3] > 245);
});

test("preserves and normalizes the transparent BMW X6 reference", async () => {
  const reference = path.join(
    __dirname,
    "..",
    "assets",
    "images",
    "debug_bmw_x6_m50d.png",
  );
  const output = await processVehicleHeroImage(await sharp(reference).toBuffer());
  const metadata = await sharp(output).metadata();
  assert.equal(metadata.width, outputWidth);
  assert.equal(metadata.height, outputHeight);
  assert.equal(metadata.hasAlpha, true);
  assert.deepEqual(vehicleBounds, {
    left: 68,
    top: 71,
    width: 1547,
    height: 779,
  });
});

test("rejects opaque screenshot-like backgrounds", async () => {
  const input = await sharp({
    create: {
      width: 800,
      height: 500,
      channels: 4,
      background: {r: 15, g: 28, b: 52, alpha: 1},
    },
  }).png().toBuffer();

  await assert.rejects(
    processVehicleHeroImage(input),
    (error) => error instanceof VehicleHeroImageError &&
      /Hintergrund/.test(error.message),
  );
});

test("removes a wide opaque floor shadow beneath the vehicle", async () => {
  const input = await sharp({
    create: {
      width: 900,
      height: 600,
      channels: 4,
      background: {r: 0, g: 0, b: 0, alpha: 0},
    },
  })
    .composite([
      {
        input: {
          create: {
            width: 560,
            height: 260,
            channels: 4,
            background: {r: 34, g: 94, b: 160, alpha: 1},
          },
        },
        left: 170,
        top: 170,
      },
      {
        input: {
          create: {
            width: 720,
            height: 52,
            channels: 4,
            background: {r: 12, g: 16, b: 18, alpha: 1},
          },
        },
        left: 90,
        top: 468,
      },
    ])
    .png()
    .toBuffer();

  const output = await processVehicleHeroImage(input);
  const {data, info} = await sharp(output)
    .ensureAlpha()
    .raw()
    .toBuffer({resolveWithObject: true});
  const probeY = vehicleBounds.top + vehicleBounds.height - 24;
  let opaquePixels = 0;
  for (let x = vehicleBounds.left;
    x < vehicleBounds.left + vehicleBounds.width;
    x += 1) {
    if (data[(probeY * info.width + x) * 4 + 3] > 8) opaquePixels += 1;
  }
  assert.ok(opaquePixels / vehicleBounds.width <= 0.34);
});

async function referenceWithFloor({
  colour, alpha = 1, background = null, ellipse = false,
}) {
  const reference = path.join(
    __dirname, "..", "assets", "images", "debug_bmw_x6_m50d.png",
  );
  const car = await sharp(reference).ensureAlpha().png().toBuffer();
  let floor = await sharp({
    create: {
      width: 1600,
      height: 100,
      channels: 4,
      background: {r: colour, g: colour, b: colour, alpha},
    },
  }).png().toBuffer();
  if (ellipse) {
    const pixels = Buffer.alloc(1600 * 100 * 4);
    for (let y = 0; y < 100; y += 1) {
      for (let x = 0; x < 1600; x += 1) {
        const radius = ((x - 800) / 800) ** 2 + ((y - 50) / 50) ** 2;
        const offset = (y * 1600 + x) * 4;
        const shade = Math.round(colour + (246 - colour) * Math.min(1, radius));
        pixels.fill(shade, offset, offset + 3);
        pixels[offset + 3] = Math.round(255 * alpha *
          Math.max(0, Math.min(1, (1 - radius) / 0.15)));
      }
    }
    floor = await sharp(pixels, {
      raw: {width: 1600, height: 100, channels: 4},
    }).png().toBuffer();
  }
  const input = await sharp({
    create: {
      width: outputWidth,
      height: outputHeight,
      channels: 4,
      background: background ?? {r: 0, g: 0, b: 0, alpha: 0},
    },
  }).composite([
    {input: floor, left: 36, top: 775},
    {input: car, left: 0, top: 0},
  ]).png().toBuffer();
  const cleanInput = background == null ? car : await sharp({
    create: {
      width: outputWidth, height: outputHeight, channels: 4, background,
    },
  }).composite([{input: car, left: 0, top: 0}]).png().toBuffer();
  return {input, cleanInput};
}

for (const [name, colour, alpha, background, ellipse] of [
  ["white", 246, 1, null],
  ["grey", 160, 1, null],
  ["translucent white", 246, 0.45, null],
  ["white on chroma green", 246, 1, {r: 0, g: 255, b: 0, alpha: 1}],
  ["white on chroma magenta", 246, 1, {r: 255, g: 0, b: 255, alpha: 1}],
  ["soft oval grey", 150, 1, null, true],
  ["soft oval on chroma", 150, 1, {r: 0, g: 255, b: 0, alpha: 1}, true],
]) {
  test(`removes a ${name} floor touching the BMW tires`, async () => {
    const {input, cleanInput} = await referenceWithFloor({
      colour, alpha, background, ellipse,
    });
    const output = await processVehicleHeroImage(input);
    const expected = await processVehicleHeroImage(cleanInput);
    if (process.env.VEHICLE_HERO_QA_DIR) {
      const directory = path.resolve(process.env.VEHICLE_HERO_QA_DIR);
      await fs.mkdir(directory, {recursive: true});
      for (const [stage, buffer] of [["before", input], ["after", output],
        ["reference", expected]]) {
        await sharp(buffer).flatten({background: "#132438"}).png().toFile(
          path.join(directory, `${name.replaceAll(" ", "-")}-${stage}.png`),
        );
      }
    }
    const actualPixels = await sharp(output).raw().toBuffer();
    const expectedPixels = await sharp(expected).raw().toBuffer();
    let extraAlpha = 0;
    let lostAlpha = 0;
    let vehiclePixels = 0;
    for (let offset = 3; offset < actualPixels.length; offset += 4) {
      if (expectedPixels[offset] > 128) vehiclePixels += 1;
      extraAlpha += Math.max(0, actualPixels[offset] - expectedPixels[offset]);
      lostAlpha += Math.max(0, expectedPixels[offset] - actualPixels[offset]);
    }
    // Compare the complete silhouette against the same backdrop without floor.
    assert.ok(extraAlpha / (255 * vehiclePixels) < 0.003,
      `Extra foreground: ${extraAlpha / (255 * vehiclePixels)}`);
    assert.ok(lostAlpha / (255 * vehiclePixels) < 0.003,
      `Lost vehicle foreground: ${lostAlpha / (255 * vehiclePixels)}`);
  });
}

for (const colour of ["#fafafa", "#a8a8a8"]) {
  test(`preserves a ${colour} vehicle body, low sill and tires`, async () => {
    const input = await sharp(Buffer.from(`<svg width="900" height="600"
      xmlns="http://www.w3.org/2000/svg">
      <path fill="${colour}" d="M150 430V280H250L340 180H540L630 280H750V430Z"/>
      <rect x="150" y="425" width="600" height="40" rx="8" fill="${colour}"/>
      <circle cx="280" cy="430" r="65" fill="#151515"/>
      <circle cx="630" cy="430" r="65" fill="#151515"/>
      <circle cx="280" cy="430" r="38" fill="#ccc"/>
      <circle cx="630" cy="430" r="38" fill="#ccc"/>
      </svg>`)).png().toBuffer();
    const trimmed = await sharp(input).trim({threshold: 0}).png().toBuffer();
    const expected = await sharp(trimmed).resize({
      width: vehicleBounds.width, height: vehicleBounds.height,
      fit: "contain", background: {r: 0, g: 0, b: 0, alpha: 0},
    }).raw().toBuffer();
    const output = await processVehicleHeroImage(input);
    const actual = await sharp(output).extract(vehicleBounds).raw().toBuffer();
    let alphaDifference = 0;
    for (let offset = 3; offset < actual.length; offset += 4) {
      alphaDifference += Math.abs(actual[offset] - expected[offset]);
    }
    assert.ok(alphaDifference / (255 * vehicleBounds.width * vehicleBounds.height)
      < 0.01, "Light vehicle parts must not be removed as ground.");
  });
}
