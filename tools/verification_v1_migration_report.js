#!/usr/bin/env node

const {initializeApp, applicationDefault} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");

const projectId = argumentValue("--project");
if (projectId.length === 0) {
  fail("Usage: node tools/verification_v1_migration_report.js --project <id>");
}
if (process.argv.includes("--apply") || process.argv.includes("--delete")) {
  fail("This report is intentionally read-only and never accepts write flags.");
}

initializeApp({credential: applicationDefault(), projectId});

async function main() {
  const firestore = getFirestore();
  const snapshot = await firestore.collection("verification_requests").get();
  const report = {
    schemaVersion: 1,
    generatedAt: new Date().toISOString(),
    projectId,
    mode: "dry-run-read-only",
    totals: {
      legacyRequests: snapshot.size,
      withIdentityFront: 0,
      withIdentityBack: 0,
      withVehicleFront: 0,
      withVehicleBack: 0,
      withDriverLicense: 0,
      verified: 0,
      pending: 0,
    },
    candidates: [],
  };
  for (const document of snapshot.docs) {
    const data = document.data() ?? {};
    const paths = data.documentStoragePaths ?? {};
    const statuses = data.documentStatuses ?? {};
    report.totals.withIdentityFront += Number(Boolean(paths.identityFront));
    report.totals.withIdentityBack += Number(Boolean(paths.identityBack));
    report.totals.withVehicleFront += Number(Boolean(paths.vehicleFront));
    report.totals.withVehicleBack += Number(Boolean(paths.vehicleBack));
    report.totals.withDriverLicense += Number(
      Boolean(paths.driverLicenseFront || paths.driverLicenseBack),
    );
    report.totals.verified += Number(data.status === "verified");
    report.totals.pending += Number(data.status === "pending");
    report.candidates.push({
      requestIdHash: shortHash(document.id),
      status: safeStatus(data.status),
      vehicleIdPresent: typeof data.vehicleId === "string" &&
        data.vehicleId.length > 0,
      documentGroups: Object.keys(statuses)
        .map(groupForDocument)
        .filter((value, index, values) => value != null &&
          values.indexOf(value) === index),
      requiresFreshV1Verification: true,
    });
  }
  process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
}

function groupForDocument(value) {
  if (value.startsWith("identity")) return "identity";
  if (value.startsWith("vehicle")) return "vehicle";
  if (value.startsWith("driverLicense")) return "driverLicense";
  return null;
}

function safeStatus(value) {
  return ["draft", "pending", "verified", "rejected", "expired"]
    .includes(value) ? value : "unknown";
}

function argumentValue(name) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? String(process.argv[index + 1] ?? "").trim() : "";
}

function shortHash(value) {
  return require("node:crypto").createHash("sha256")
    .update(value).digest("hex").slice(0, 16);
}

function fail(message) {
  process.stderr.write(`${message}\n`);
  process.exit(2);
}

main().catch((error) => {
  process.stderr.write(`Migration report failed: ${error?.message ?? error}\n`);
  process.exitCode = 1;
});
