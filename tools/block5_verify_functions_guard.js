const assert = require("node:assert/strict");

const projectId = process.env.GCLOUD_PROJECT || "carma-a84e4";
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST || "127.0.0.1:9099";
const functionsHost = process.env.FUNCTIONS_EMULATOR_HOST || "127.0.0.1:5001";
const email = `block5-guard-${Date.now()}@example.test`;
const password = "Block5-Guard-Only-2026";

async function main() {
  const signUpResponse = await fetch(
    `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key`,
    {
      method: "POST",
      headers: {"content-type": "application/json"},
      body: JSON.stringify({email, password, returnSecureToken: true}),
    },
  );
  const signUpPayload = await signUpResponse.json();
  assert.equal(signUpResponse.ok, true, JSON.stringify(signUpPayload));
  const {idToken} = signUpPayload;
  assert.equal(typeof idToken, "string");

  const callableResponse = await fetch(
    `http://${functionsHost}/${projectId}/europe-west3/requestVehicleHeroImage`,
    {
      method: "POST",
      headers: {
        authorization: `Bearer ${idToken}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({data: {vehicleId: "block5-guard"}}),
    },
  );
  const payload = await callableResponse.json();
  assert.equal(callableResponse.status, 501, JSON.stringify(payload));
  assert.equal(payload.error?.status, "UNIMPLEMENTED");
  assert.match(payload.error?.message ?? "", /lokalen Testbetrieb/);
  console.log("PASS: local vehicle hero generation is blocked before external access");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
