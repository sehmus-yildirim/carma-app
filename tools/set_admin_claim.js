const {randomUUID} = require('node:crypto');
const admin = require('firebase-admin');

const grantConfirmation = 'ADMINRECHT VERGEBEN';
const revokeConfirmation = 'ADMINRECHT ENTFERNEN';
const allowedActions = new Set(['status', 'grant', 'revoke']);

async function main() {
  const [action, targetUserId, confirmation] = process.argv.slice(2);
  const operatorUserId = safeString(process.env.CARISMA_ADMIN_OPERATOR_UID);

  if (!allowedActions.has(action) || !isUid(targetUserId)) {
    printUsage();
    process.exitCode = 1;
    return;
  }
  if (action !== 'status' && !isUid(operatorUserId)) {
    throw new Error(
      'CARISMA_ADMIN_OPERATOR_UID muss die interne UID der handelnden Person enthalten.',
    );
  }
  if (action === 'grant' && confirmation !== grantConfirmation) {
    throw new Error(`Exakte Bestätigung erforderlich: ${grantConfirmation}`);
  }
  if (action === 'revoke' && confirmation !== revokeConfirmation) {
    throw new Error(`Exakte Bestätigung erforderlich: ${revokeConfirmation}`);
  }

  admin.initializeApp({credential: admin.credential.applicationDefault()});
  const auth = admin.auth();
  const user = await auth.getUser(targetUserId);
  const existingClaims = user.customClaims ?? {};

  if (action === 'status') {
    console.log(`Admin-Claim: ${existingClaims.admin === true ? 'aktiv' : 'nicht aktiv'}`);
    return;
  }

  const shouldBeAdmin = action === 'grant';
  const claims = {...existingClaims};
  if (shouldBeAdmin) {
    claims.admin = true;
  } else {
    delete claims.admin;
  }
  await auth.setCustomUserClaims(targetUserId, claims);

  await admin.firestore().collection('admin_claim_audit').doc(randomUUID()).set({
    action: shouldBeAdmin ? 'admin_claim_granted' : 'admin_claim_revoked',
    actorUserId: operatorUserId,
    targetUserId,
    occurredAt: admin.firestore.FieldValue.serverTimestamp(),
    source: 'trusted-admin-sdk-tool',
  });

  console.log(`Admin-Claim ${shouldBeAdmin ? 'vergeben' : 'entfernt'}.`);
  console.log(
    'Der betroffene Admin muss sich vollständig abmelden und neu anmelden, damit ein neues Token geladen wird.',
  );
}

function printUsage() {
  console.log('Verwendung:');
  console.log('  node tools/set_admin_claim.js status <UID>');
  console.log(
    `  node tools/set_admin_claim.js grant <UID> "${grantConfirmation}"`,
  );
  console.log(
    `  node tools/set_admin_claim.js revoke <UID> "${revokeConfirmation}"`,
  );
  console.log(
    'Für grant/revoke muss CARISMA_ADMIN_OPERATOR_UID gesetzt sein.',
  );
}

function isUid(value) {
  return /^[A-Za-z0-9:_-]{6,128}$/.test(safeString(value));
}

function safeString(value) {
  return typeof value === 'string' ? value.trim() : '';
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : 'Admin-Aktion fehlgeschlagen.');
  process.exitCode = 1;
});
