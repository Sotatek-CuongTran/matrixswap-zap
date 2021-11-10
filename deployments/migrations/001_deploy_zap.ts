import { DeployFunction } from "hardhat-deploy/dist/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const func: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment,
): Promise<void> {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const zap = await deploy("Zap", {
    from: deployer,
    log: true,
    // args: [],
    proxy: {
      proxyContract: "OptimizedTransparentProxy",
      execute: {
        methodName: "initialize",
        args: [
          "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff",
          "0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32",
        ], // [router, factory]
      },
    },
  });
};

func.tags = ["Zap"];
export default func;
