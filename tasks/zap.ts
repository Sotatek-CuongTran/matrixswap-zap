import { QUICKSWAP } from "./../test/utils/constants";
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
