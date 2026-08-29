function isFirebaseFunctionsEmulator(environment = process.env) {
  return environment.FUNCTIONS_EMULATOR === "true";
}

module.exports = {
  isFirebaseFunctionsEmulator,
};
