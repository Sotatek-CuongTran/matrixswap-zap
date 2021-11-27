import { QUICKSWAP, SUSHISWAP } from "./utils/constants";
import { IERC20 } from "../typechain/IERC20";
import { fixtureV2 } from "./utils/fixture";
import { ethers, waffle } from "hardhat";
import { Wallet } from "ethers";
import web3 from "web3";
import {
  IUniswapV2Factory,
  IUniswapV2Router02,
  MockCurve,
  ZapMiniV2,
} from "../typechain";
import { expect } from "chai";

const { toWei } = web3.utils;

describe("AutoCompounder", () => {
  let wallets: Wallet[];
  let zap: ZapMiniV2;
  let curvePool: MockCurve;
  let mockWETH: IERC20;
  let token0: IERC20;
  let token1: IERC20;
  let token2: IERC20;
  let token3: IERC20;
  let token4: IERC20;
  let pair01: IERC20;
  let pair0ETH: IERC20;
  let factory: IUniswapV2Factory;
  let router: IUniswapV2Router02;
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
      WETH: mockWETH,
      token4,
      pair0ETH,
    } = await loadFixture(fixtureV2));

    const zapDeployer = await ethers.getContractFactory("ZapMiniV2");
    zap = (await zapDeployer.deploy()) as ZapMiniV2;
    await zap.initialize(
      token4.address,
      token4.address,
      mockWETH.address,
      token1.address,
      token1.address,
    );
    await zap.setFactoryAndRouter(QUICKSWAP, factory.address, router.address);
    await zap.setFactoryAndRouter(SUSHISWAP, factory.address, router.address);

    await zap.addIntermediateToken(
      QUICKSWAP,
      token3.address,
      token0.address,
      token2.address,
    );

    // console.log("ZAP: ", zap.address);

    // mock curve pool
    const CurvePool = await ethers.getContractFactory("MockCurve");
    curvePool = (await CurvePool.deploy(token4.address)) as MockCurve;
  });

  context("Zap In", () => {
    beforeEach(async () => {
      await token3.approve(zap.address, ethers.constants.MaxUint256);
      await token4.approve(zap.address, ethers.constants.MaxUint256);
    });

    it("zap in", async () => {
      const beforeBalance = await pair01.balanceOf(deployer.address);
      await zap.zapIn(QUICKSWAP, pair01.address, deployer.address, {
        value: toWei("5"),
      });
      const afterBalance = await pair01.balanceOf(deployer.address);
      expect(afterBalance).to.be.gt(beforeBalance);
    });

    it("zap in token", async () => {
      const params = {
        protocolType: QUICKSWAP,
        from: token3.address,
        amount: ethers.utils.parseEther("10"),
        to: pair01.address,
        receiver: deployer.address,
      };
      const beforeBalance = await pair01.balanceOf(deployer.address);

      const liquidity = await zap.callStatic.zapInToken(params);
      await zap.zapInToken(params);

      const afterBalance = await pair01.balanceOf(deployer.address);
      expect(afterBalance.sub(beforeBalance)).to.be.eq(liquidity);
    });

    it("zap in multiple token", async () => {
      const params = {
        protocolType: QUICKSWAP,
        from: [token3.address, token4.address],
        amount: [ethers.utils.parseEther("10"), ethers.utils.parseEther("10")],
        to: pair01.address,
        receiver: deployer.address,
      };
      const beforeBalance = await pair01.balanceOf(deployer.address);

      const liquidity = await zap.callStatic.zapInMultiToken(params);
      await zap.zapInMultiToken(params);

      const afterBalance = await pair01.balanceOf(deployer.address);

      expect(afterBalance.sub(beforeBalance)).to.be.eq(liquidity);
    });

    it("Zap in curve lp token", async () => {
      await zap.zapInTokenCurve(token4.address, toWei("5"), curvePool.address);
      await zap.zapInTokenCurve(token3.address, toWei("5"), curvePool.address);
    });
  });

  context("Zap Out", () => {
    beforeEach(async () => {
      await token3.approve(zap.address, ethers.constants.MaxUint256);
      await zap.zapIn(QUICKSWAP, pair01.address, deployer.address, {
        value: toWei("5"),
      });

      await zap.zapIn(QUICKSWAP, pair0ETH.address, deployer.address, {
        value: toWei("5"),
      });
    });

    it("zap out", async () => {
      const beforeToken0Balance = await token0.balanceOf(deployer.address);
      const beforeToken1Balance = await token1.balanceOf(deployer.address);

      await pair01.approve(zap.address, ethers.constants.MaxUint256);
      await zap.zapOut(
        QUICKSWAP,
        pair01.address,
        await pair01.balanceOf(deployer.address),
        deployer.address,
      );
      const afterToken0Balance = await token0.balanceOf(deployer.address);
      const afterToken1Balance = await token1.balanceOf(deployer.address);

      expect(afterToken0Balance).to.be.gt(beforeToken0Balance);
      expect(afterToken1Balance).to.be.gt(beforeToken1Balance);
    });

    it("zap out - ETH pair", async () => {
      const beforeToken0Balance = await token0.balanceOf(deployer.address);
      const beforeETHBalance = await deployer.getBalance();

      await pair0ETH.approve(zap.address, ethers.constants.MaxUint256);
      await zap.zapOut(
        QUICKSWAP,
        pair0ETH.address,
        await pair0ETH.balanceOf(deployer.address),
        deployer.address,
      );
      const afterToken0Balance = await token0.balanceOf(deployer.address);
      const afterETHBalance = await deployer.getBalance();

      expect(afterToken0Balance).to.be.gt(beforeToken0Balance);
      expect(afterETHBalance).to.be.gt(beforeETHBalance);
    });
  });

  context("Another function", () => {
    it("intermediate token", async () => {
      expect(
        await zap.getIntermediateToken(
          QUICKSWAP,
          token0.address,
          token1.address,
        ),
      ).to.be.eq(ethers.constants.AddressZero);

      await zap.addIntermediateToken(
        QUICKSWAP,
        token0.address,
        token1.address,
        token2.address,
      );

      expect(
        await zap.getIntermediateToken(
          QUICKSWAP,
          token0.address,
          token1.address,
        ),
      ).to.be.eq(token2.address);

      await zap.removeIntermediateToken(
        QUICKSWAP,
        token0.address,
        token1.address,
      );

      expect(
        await zap.getIntermediateToken(
          QUICKSWAP,
          token0.address,
          token1.address,
        ),
      ).to.be.eq(ethers.constants.AddressZero);
    });

    it("set router and factory", async () => {
      await zap.setFactoryAndRouter(QUICKSWAP, token0.address, token1.address);
      const protocolInfo = await zap.protocols(QUICKSWAP);

      expect(protocolInfo.factory).to.be.eq(token0.address);
      expect(protocolInfo.router).to.be.eq(token1.address);
    });

    it("withdraw", async () => {
      await token0.transfer(zap.address, toWei("100"));
      await deployer.sendTransaction({
        from: deployer.address,
        to: zap.address,
        value: "0x56BC75E2D63100000",
      });

      const beforeToken0Balance = await token0.balanceOf(deployer.address);
      await zap.withdraw(token0.address);
      const afterToken0Balance = await token0.balanceOf(deployer.address);

      expect(afterToken0Balance).to.be.eq(
        beforeToken0Balance.add(toWei("100")),
      );

      const beforeETHBalance = await deployer.getBalance();
      await zap.withdraw(ethers.constants.AddressZero);
      const afterETHBalance = await deployer.getBalance();
      expect(afterETHBalance).to.be.gt(beforeETHBalance);
    });
  });
});
