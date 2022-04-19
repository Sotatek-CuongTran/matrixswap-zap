module.exports = {
  istanbulReporter: ["html", "lcov"],
  onCompileComplete: async function (_config) {
    await run("typechain");
  },
  onIstanbulComplete: async function (_config) {},
  providerOptions: {
    mnemonic: process.env.MNEMONIC,
  },
  skipFiles: ["mocks", "test", "Zap.sol", "ZapMini.sol"],
};
