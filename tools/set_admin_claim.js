const admin = require('firebase-admin');

const uid = process.argv[2];
const shouldBeAdmin = process.argv[3] !== 'false';

if (!uid) {
  console.error('Bitte UID angeben: node tools/set_admin_claim.js USER_UID');
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
});

admin
  .auth()
  .setCustomUserClaims(uid, { admin: shouldBeAdmin })
  .then(() => {
    const state = shouldBeAdmin ? 'gesetzt' : 'entfernt';
    console.log(`Admin-Claim ${state} für UID: ${uid}`);
    console.log('Bitte danach in der App abmelden/anmelden oder die App neu starten.');
    process.exit(0);
  })
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });