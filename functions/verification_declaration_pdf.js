const {createHash} = require("node:crypto");
const {readFile} = require("node:fs/promises");
const path = require("node:path");
const fontkit = require("@pdf-lib/fontkit");
const {PDFDocument, rgb} = require("pdf-lib");

const fontPath = path.join(__dirname, "assets", "fonts", "NotoSans.ttf");

async function createVehicleDeclarationPdf({
  declarationId,
  userReference,
  fullName,
  plate,
  relationLabel,
  declarationVersion,
  declarationText,
  declarationTextHash,
  acceptedAt,
  signature,
}) {
  const document = await PDFDocument.create();
  document.registerFontkit(fontkit);
  const fontBytes = await readFile(fontPath);
  const font = await document.embedFont(fontBytes, {subset: true});
  const page = document.addPage([595.28, 841.89]);
  const margin = 54;
  const contentWidth = page.getWidth() - margin * 2;
  let y = page.getHeight() - 62;

  page.drawText("Plaqa", {
    x: margin,
    y,
    size: 25,
    font,
    color: rgb(0.02, 0.42, 1),
  });
  y -= 42;
  y = drawWrappedText(page, {
    text: "Eigenerklärung zur Fahrzeugnutzungsberechtigung",
    x: margin,
    y,
    maxWidth: contentWidth,
    size: 17,
    lineHeight: 23,
    font,
    color: rgb(0.06, 0.08, 0.12),
  }) - 20;

  const metadata = [
    ["Declaration-ID", declarationId],
    ["Referenz", userReference],
    ["Name", fullName],
    ["Kennzeichen", plate],
    ["Fahrzeugzuordnung", relationLabel],
    ["Serverzeit", acceptedAt.toISOString()],
    ["Version", declarationVersion],
    ["Erklärungstext-SHA-256", declarationTextHash],
  ];
  for (const [label, value] of metadata) {
    page.drawText(`${label}:`, {
      x: margin,
      y,
      size: 9,
      font,
      color: rgb(0.33, 0.38, 0.46),
    });
    y = drawWrappedText(page, {
      text: value,
      x: margin + 132,
      y,
      maxWidth: contentWidth - 132,
      size: 9,
      lineHeight: 13,
      font,
      color: rgb(0.06, 0.08, 0.12),
    }) - 5;
  }

  y -= 12;
  y = drawWrappedText(page, {
    text: declarationText,
    x: margin,
    y,
    maxWidth: contentWidth,
    size: 10.5,
    lineHeight: 16,
    font,
    color: rgb(0.06, 0.08, 0.12),
  }) - 28;

  const signatureHeight = 94;
  const signatureWidth = contentWidth;
  if (y - signatureHeight < 54) {
    y = 160;
  }
  page.drawRectangle({
    x: margin,
    y: y - signatureHeight,
    width: signatureWidth,
    height: signatureHeight,
    borderWidth: 0.8,
    borderColor: rgb(0.66, 0.7, 0.76),
  });
  for (const stroke of signature.strokes) {
    for (let index = 1; index < stroke.length; index += 1) {
      const from = stroke[index - 1];
      const to = stroke[index];
      page.drawLine({
        start: {
          x: margin + from.x * signatureWidth,
          y: y - signatureHeight + (1 - from.y) * signatureHeight,
        },
        end: {
          x: margin + to.x * signatureWidth,
          y: y - signatureHeight + (1 - to.y) * signatureHeight,
        },
        thickness: 1.4,
        color: rgb(0.02, 0.15, 0.3),
      });
    }
  }
  page.drawText("Unterschrift", {
    x: margin,
    y: y - signatureHeight - 16,
    size: 8.5,
    font,
    color: rgb(0.33, 0.38, 0.46),
  });

  document.setTitle("Plaqa Eigenerklärung zur Fahrzeugnutzungsberechtigung");
  document.setSubject("Private Eigenerklärung");
  document.setProducer("Plaqa Verification V1");
  document.setCreationDate(acceptedAt);
  document.setModificationDate(acceptedAt);
  const bytes = Buffer.from(await document.save({useObjectStreams: false}));
  return {
    bytes,
    sha256: createHash("sha256").update(bytes).digest("hex"),
  };
}

function drawWrappedText(page, {
  text,
  x,
  y,
  maxWidth,
  size,
  lineHeight,
  font,
  color,
}) {
  const paragraphs = String(text).split("\n");
  let cursor = y;
  for (const paragraph of paragraphs) {
    if (paragraph.trim().length === 0) {
      cursor -= lineHeight;
      continue;
    }
    const words = paragraph.trim().split(/\s+/u);
    let line = "";
    for (const word of words) {
      const candidate = line.length === 0 ? word : `${line} ${word}`;
      if (font.widthOfTextAtSize(candidate, size) <= maxWidth) {
        line = candidate;
        continue;
      }
      if (line.length > 0) {
        page.drawText(line, {x, y: cursor, size, font, color});
        cursor -= lineHeight;
      }
      line = word;
    }
    if (line.length > 0) {
      page.drawText(line, {x, y: cursor, size, font, color});
      cursor -= lineHeight;
    }
  }
  return cursor;
}

module.exports = {
  createVehicleDeclarationPdf,
  drawWrappedText,
};
