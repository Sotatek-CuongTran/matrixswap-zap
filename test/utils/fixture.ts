import { StakingRewards } from "./../../typechain/StakingRewards.d";
import { deployContract, Fixture } from "ethereum-waffle";
import { Contract, ethers } from "ethers";
import web3 from "web3";
import {
  abi as weth9abi,
  bytecode as weth9bytecode,
} from "../../artifacts/contracts/mocks/MockWETH.sol/MockWETH.json";
import {
  abi as univ2FactoryAbi,
  bytecode as univ2FactoryBytecode,
} from "@uniswap/v2-periphery/build/UniswapV2Router02.json";
import IUniswapV2Pair from "@uniswap/v2-core/build/IUniswapV2Pair.json";
import UniswapV2Factory from "@uniswap/v2-core/build/UniswapV2Factory.json";
import ERC20 from "@uniswap/v2-core/build/ERC20.json";
import StakingRewardABI from "../../artifacts/contracts/mocks/staking/StakingRewards.sol/StakingRewards.json";
import { MockWETH } from "../../typechain";
import { IUniswapV2Router02 } from "../../typechain/IUniswapV2Router02";
import { IERC20 } from "../../typechain/IERC20";

interface ContractFixture {
  token0: IERC20;
  token1: IERC20;
  WETH: MockWETH;
  WETHPartner: Contract;
  factoryV2: Contract;
  router02: IUniswapV2Router02;
  router: IUniswapV2Router02;
  pair: Contract;
  WETHPair: Contract;
  farmingPool01: StakingRewards;
}

const overrides = {
  gasLimit: 9999999,
};
const { toWei } = web3.utils;

export const fixture: Fixture<ContractFixture | any> = async (
  [wallet],
  provider,
) => {
  // deploy tokens
  const tokenA = (await deployContract(wallet as any, ERC20, [
    toWei("100000000"),
  ])) as unknown as IERC20;

  const tokenB = (await deployContract(wallet as any, ERC20, [
    toWei("100000000"),
  ])) as unknown as IERC20;
  const WETH = (await deployContract(wallet as any, {
    abi: weth9abi,
    bytecode: weth9bytecode,
  })) as unknown as MockWETH;
  const WETHPartner = await deployContract(wallet as any, ERC20, [
    toWei("10000"),
  ]);

  // deploy V2
  const factoryV2 = await deployContract(wallet as any, UniswapV2Factory, [
    wallet.address,
  ]);

  const router02 = (await deployContract(
    wallet as any,
    {
      abi: univ2FactoryAbi,
      bytecode: univ2FactoryBytecode,
    },
    [factoryV2.address, WETH.address],
    overrides,
  )) as unknown as IUniswapV2Router02;

  // initialize V2
  await factoryV2.createPair(tokenA.address, tokenB.address);
  const pairAddress = await factoryV2.getPair(tokenA.address, tokenB.address);
  const pair = new Contract(
    pairAddress,
    JSON.stringify(IUniswapV2Pair.abi),
    provider as any,
  ).connect(wallet as any);

  const token0Address = await pair.token0();
  const token0 = tokenA.address === token0Address ? tokenA : tokenB;
  const token1 = tokenA.address === token0Address ? tokenB : tokenA;

  await factoryV2.createPair(WETH.address, WETHPartner.address);
  const WETHPairAddress = await factoryV2.getPair(
    WETH.address,
    WETHPartner.address,
  );
  const WETHPair = new Contract(
    WETHPairAddress,
    JSON.stringify(IUniswapV2Pair.abi),
    provider as any,
  ).connect(wallet as any);

  await factoryV2.createPair(WETH.address, WETHPartner.address);

  // args: [_rewardDistribution, _rewardsToken, _stakingToken]
  const farmingPool01 = (await deployContract(wallet as any, StakingRewardABI, [
    token0.address,
    WETH.address,
    pair.address,
  ])) as StakingRewards;

  return {
    token0,
    token1,
    WETH,
    WETHPartner,
    factoryV2,
    router02,
    router: router02, // the default router, 01 had a minor bug
    pair,
    WETHPair,
    farmingPool01, // farming pool for token0 - token1 pair
  };
};

interface ContractFixtureV2 {
  token0: IERC20;
  token1: IERC20;
  token2: IERC20;
  token3: IERC20;
  token4: IERC20;
  pair01: Contract;
  pair02: Contract;
  pair23: Contract;
  pair13: Contract;
  pair04: Contract;
  pair14: Contract;
  factory: Contract;
  router: IUniswapV2Router02;
  farmingPool01: StakingRewards;
  WETH: MockWETH;
}

export const fixtureV2: Fixture<ContractFixtureV2 | any> = async (
  [wallet],
  provider,
) => {
  // deploy tokens
  const token0 = (await deployContract(wallet as any, ERC20, [
    toWei("100000000000"),
  ])) as unknown as IERC20;
  const token1 = (await deployContract(wallet as any, ERC20, [
    toWei("100000000000"),
  ])) as unknown as IERC20;
  const token2 = (await deployContract(wallet as any, ERC20, [
    toWei("100000000000"),
  ])) as unknown as IERC20;
  const token3 = (await deployContract(wallet as any, ERC20, [
    toWei("100000000000"),
  ])) as unknown as IERC20;
  const token4 = (await deployContract(wallet as any, ERC20, [
    toWei("100000000000"),
  ])) as unknown as IERC20;

  const WETH = (await deployContract(wallet as any, {
    abi: weth9abi,
    bytecode: weth9bytecode,
  })) as unknown as MockWETH;

  // deploy V2
  const factory = await deployContract(wallet as any, UniswapV2Factory, [
    wallet.address,
  ]);

  const router = (await deployContract(
    wallet as any,
    {
      abi: univ2FactoryAbi,
      bytecode: univ2FactoryBytecode,
    },
    [factory.address, WETH.address],
    overrides,
  )) as unknown as IUniswapV2Router02;

  const user = "0xB1B11E04348f4271B163dB51138704F3Dec0c128";
  await wallet.sendTransaction({
    from: await wallet.getAddress(),
    to: user,
    value: "0x56BC75E2D63100000",
  });

  for (const token of [token0, token1, token2, token3, token4]) {
    // approve for router and pair
    await token.approve(router.address, ethers.constants.MaxUint256);
    await token.approve(factory.address, ethers.constants.MaxUint256);

    // tranfer to test
    await token.transfer(user, toWei("10000"));
  }

  await factory.createPair(token0.address, token1.address);
  await factory.createPair(token0.address, token2.address);
  await factory.createPair(token2.address, token3.address);
  await factory.createPair(token1.address, token3.address);
  await factory.createPair(token0.address, token4.address);
  await factory.createPair(token1.address, token4.address);

  const getPairContract = async (tokenA: IERC20, tokenB: IERC20) => {
    const pairAddress = await factory.getPair(tokenA.address, tokenB.address);
    const pair = new Contract(
      pairAddress,
      JSON.stringify(IUniswapV2Pair.abi),
      provider as any,
    ).connect(wallet as any);

    await router.addLiquidity(
      tokenA.address,
      tokenB.address,
      toWei("1000000"),
      toWei("1000000"),
      toWei("100"),
      toWei("100"),
      wallet.address,
      1726756514, // deadline
    );
    return pair;
  };

  const pair01 = await getPairContract(token0, token1);
  const pair02 = await getPairContract(token0, token2);
  const pair23 = await getPairContract(token2, token3);
  const pair13 = await getPairContract(token1, token3);
  const pair04 = await getPairContract(token0, token4);
  const pair14 = await getPairContract(token1, token4);

  // args: [_rewardDistribution, _rewardsToken, _stakingToken]
  const farmingPool01 = (await deployContract(wallet as any, StakingRewardABI, [
    token0.address,
    WETH.address,
    pair01.address,
  ])) as StakingRewards;

  console.log("token0: ", token0.address);
  console.log("token1: ", token1.address);
  console.log("token2: ", token2.address);
  console.log("token3: ", token3.address);
  console.log("token4: ", token4.address);
  console.log("pair01: ", pair01.address);
  console.log("pair02: ", pair02.address);
  console.log("pair23: ", pair23.address);
  console.log("pair13: ", pair13.address);
  console.log("pair04: ", pair04.address);
  console.log("pair14: ", pair14.address);
  console.log("router: ", router.address);
  console.log("factory: ", factory.address);
  console.log("farmingPool01: ", farmingPool01.address);

  return {
    token0,
    token1,
    token2,
    token3,
    token4,
    pair01,
    pair02,
    pair23,
    pair13,
    pair04,
    pair14,
    farmingPool01,
    router,
    factory,
  };
};
