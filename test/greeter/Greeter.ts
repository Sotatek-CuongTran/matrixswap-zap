import { fixtureV2 } from "../utils/fixture";
import { ethers, waffle } from "hardhat";
import { Wallet } from "ethers";
import { Zap } from "../../typechain";

describe("AutoCompounder", () => {
  let wallets: Wallet[];
  let zap: Zap;

  let loadFixture: ReturnType<typeof waffle.createFixtureLoader>;

  before("create fixture loader", async () => {
    wallets = await (ethers as any).getSigners();
  });

  beforeEach(async () => {
    loadFixture = waffle.createFixtureLoader(wallets as any);

    const { factory, router } = await loadFixture(fixtureV2);

    const zapDeployer = await ethers.getContractFactory("Zap");
    zap = (await zapDeployer.deploy()) as Zap;
    await zap.initialize(router.address, factory.address);

    console.log("ZAP: ", zap.address);
  });

  it("token0 - token1", async () => {});
});
