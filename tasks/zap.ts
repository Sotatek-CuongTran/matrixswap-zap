import { task } from "hardhat/config";
import { Zap__factory } from "../typechain";

task("add-intermediate-token", "Add intermediate token")
  .addOptionalParam("token0")
  .addOptionalParam("token1")
  .addOptionalParam("intermediate")
  .setAction(async function ({ token0, token1, intermediate }, hre) {
    const { deployments, ethers } = hre;
    const [deployer] = await ethers.getSigners();

    const zapContract = await deployments.get("Zap");
    console.log("\x1b[36m%s\x1b[0m", "token0", token0);
    console.log("\x1b[36m%s\x1b[0m", "token1", token1);
    console.log("\x1b[36m%s\x1b[0m", "intermediate", intermediate);
    console.log(
      "\x1b[36m%s\x1b[0m",
      "zapContract.address",
      zapContract.address,
    );

    const zapInstance = await Zap__factory.connect(
      zapContract.address,
      deployer,
    );
    const tx = await zapInstance.addIntermediateToken(
      token0,
      token1,
      intermediate,
    );
    console.log("\x1b[36m%s\x1b[0m", "tx", tx);
  });
