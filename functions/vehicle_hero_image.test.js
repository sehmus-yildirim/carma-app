const assert = require("node:assert/strict");
const test = require("node:test");
const path = require("node:path");
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
