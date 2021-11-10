import { IERC20 } from "../typechain/IERC20";
import { fixtureV2 } from "./utils/fixture";
import { ethers, waffle } from "hardhat";
import { Wallet } from "ethers";
import web3 from "web3";
import {
  IStakingRewards,
  IUniswapV2Factory,
  IUniswapV2Router02,
  ZapMini,
} from "../typechain";

describe("AutoCompounder", () => {
  let wallets: Wallet[];
  let zap: ZapMini;
  let token0: IERC20;
  let token1: IERC20;
  let token2: IERC20;
  let token3: IERC20;
  let token4: IERC20;
  let pair01: IERC20;
  let factory: IUniswapV2Factory;
  let router: IUniswapV2Router02;
  let farmingPool01: IStakingRewards;
  let deployer: Wallet;

  let loadFixture: ReturnType<typeof waffle.createFixtureLoader>;

  before("create fixture loader", async () => {
    wallets = await (ethers as any).getSigners();
    deployer = wallets[0];
  });

  beforeEach(async () => {
    loadFixture = waffle.createFixtureLoader(wallets as any);

    ({
      factory,
      router,
      token0,
      token1,
      token2,
      token3,
      pair01,
      farmingPool01,
      token4,
    } = await loadFixture(fixtureV2));

    const zapDeployer = await ethers.getContractFactory("ZapMini");
    zap = (await zapDeployer.deploy()) as ZapMini;
    await zap.initialize(
      router.address,
      factory.address,
      token4.address,
      token4.address,
      token4.address,
      token1.address,
      token1.address,
    );
    await zap.addIntermediateToken(
      token3.address,
      token0.address,
      token2.address,
    );

    console.log("ZAP: ", zap.address);
  });

  it("zap and farm", async () => {
    await token3.approve(zap.address, ethers.constants.MaxUint256);
    const result = await zap.callStatic.zapInToken(
      token3.address,
      ethers.utils.parseEther("10"),
      pair01.address,
      deployer.address,
    );
    console.log(
      "\x1b[36m%s\x1b[0m",
      "result.toString()",
      web3.utils.fromWei(result.toString()),
    );
    await zap.zapInToken(
      token3.address,
      ethers.utils.parseEther("10"),
      pair01.address,
      deployer.address,
    );

    const pair01LP = await pair01.balanceOf(deployer.address);
    console.log(ethers.utils.formatEther(pair01LP.toString()));
    const balanceFarmingPool = await farmingPool01.balanceOf(deployer.address);
    console.log("balance: ", balanceFarmingPool.toString());
  });
});
