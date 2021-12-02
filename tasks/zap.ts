import { APESWAP, QUICKSWAP, SUSHISWAP } from "./../test/utils/constants";
import { task } from "hardhat/config";
import { ZapMiniV2__factory } from "../typechain";

task("add-intermediate-token", "Add intermediate token")
  .addOptionalParam("token0")
  .addOptionalParam("token1")
  .addOptionalParam("intermediate")
  .setAction(async function ({ token0, token1, intermediate }, hre) {
    const { deployments, ethers } = hre;
    const [deployer] = await ethers.getSigners();

    const zapContract = await deployments.get("ZapMiniV2");
    console.log("\x1b[36m%s\x1b[0m", "token0", token0);
    console.log("\x1b[36m%s\x1b[0m", "token1", token1);
    console.log("\x1b[36m%s\x1b[0m", "intermediate", intermediate);
    console.log(
      "\x1b[36m%s\x1b[0m",
      "zapContract.address",
      zapContract.address,
    );

    const zapInstance = await ZapMiniV2__factory.connect(
      zapContract.address,
      deployer,
    );
    const tx = await zapInstance.addIntermediateToken(
      QUICKSWAP, // change me
      token0,
      token1,
      intermediate,
    );
    console.log("\x1b[36m%s\x1b[0m", "tx", tx);
  });

task("set-router-factory", "set protocol router and factory").setAction(
  async function (_, hre) {
    const { deployments, ethers } = hre;
    const [deployer] = await ethers.getSigners();

    const zapContract = await deployments.get("ZapMiniV2");

    const zapInstance = await ZapMiniV2__factory.connect(
      zapContract.address,
      deployer,
    );

    // const tx = await zapInstance.setFactoryAndRouter(
    //   QUICKSWAP, // change me
    //   "0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32",
    //   "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff",
    // );
    // console.log("\x1b[36m%s\x1b[0m", "tx", tx);

    // const tx2 = await zapInstance.setFactoryAndRouter(
    //   SUSHISWAP, // change me
    //   "0xc35dadb65012ec5796536bd9864ed8773abc74c4",
    //   "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506",
    // );
    // console.log("\x1b[36m%s\x1b[0m", "tx2", tx2);

    const tx3 = await zapInstance.setFactoryAndRouter(
      APESWAP, // change me
      "0xCf083Be4164828f00cAE704EC15a36D711491284",
      "0xC0788A3aD43d79aa53B09c2EaCc313A787d1d607",
    );
    console.log("\x1b[36m%s\x1b[0m", "tx3", tx3);
  },
);

task("testxxx", "set protocol router and factory").setAction(async function (
  _,
  hre,
) {
  const { deployments, ethers } = hre;
  const [deployer] = await ethers.getSigners();

  const zapContract = await deployments.get("ZapMiniV2");

  const zapInstance = await ZapMiniV2__factory.connect(
    zapContract.address,
    deployer,
  );

  const tx = await zapInstance.callStatic.zapInTokenCurve(
    {
      from: "0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063",
      amount: "100000000000000000",
      curvePool: "0xac974e619888342dada8b50b3ad02f0d04cee6db",
      poolLength: "3",
      to: "0xac974e619888342dada8b50b3ad02f0d04cee6db",
      use_underlying: false,
      depositToken: "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174",
      depositTokenIndex: "1",
    },
    {
      gasLimit: 1300000,
    },
  );
  console.log("\x1b[36m%s\x1b[0m", "tx", tx);

  // const abi = ["function add_liquidity(uint256[5],uint256)"];
  // const curvePool = new ethers.Contract(
  //   "0x1d8b86e3d88cdb2d34688e87e72f388cb541b7c8",
  //   abi,
  //   deployer,
  // );

  // await curvePool.callStatic.add_liquidity(
  //   ["100000000000000", "0", "0", "0", "0"],
  //   0,
  // );
});
