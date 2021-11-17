import { QUICKSWAP, SUSHISWAP } from "./../test/utils/constants";
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

    const tx = await zapInstance.setFactoryAndRouter(
      QUICKSWAP, // change me
      "0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32",
      "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff",
    );
    console.log("\x1b[36m%s\x1b[0m", "tx", tx);

    const tx2 = await zapInstance.setFactoryAndRouter(
      SUSHISWAP, // change me
      "0xc35dadb65012ec5796536bd9864ed8773abc74c4",
      "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506",
    );
    console.log("\x1b[36m%s\x1b[0m", "tx2", tx2);
  },
);
