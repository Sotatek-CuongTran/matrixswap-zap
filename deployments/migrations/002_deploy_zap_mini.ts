import { DeployFunction } from "hardhat-deploy/dist/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const func: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment,
): Promise<void> {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy("ZapMini", {
    from: deployer,
    log: true,
    proxy: {
      proxyContract: "OptimizedTransparentProxy",
      execute: {
        methodName: "initialize",
        args: [
          "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff",
          "0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32",
          "0xc2132D05D31c914a87C6611C10748AEb04B58e8F",
          "0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063",
          "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270",
          "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174",
          "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619",
        ], // [router, factory, USDT, DAI, WMATIC, USDC, WETH]
      },
    },
  });
};

func.tags = ["Zap"];
export default func;
