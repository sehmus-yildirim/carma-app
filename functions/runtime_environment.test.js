const assert = require("node:assert/strict");
const test = require("node:test");

const {
  isFirebaseFunctionsEmulator,
} = require("./runtime_environment");

test("detects the Firebase Functions emulator explicitly", () => {
  assert.equal(
    isFirebaseFunctionsEmulator({FUNCTIONS_EMULATOR: "true"}),
    true,
  );
});

test("does not treat production or unset environments as emulators", () => {
  assert.equal(
    isFirebaseFunctionsEmulator({FUNCTIONS_EMULATOR: "false"}),
    false,
  );
  assert.equal(isFirebaseFunctionsEmulator({}), false);
});
