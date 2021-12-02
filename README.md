# Solidity Template

My favourite setup for writing Solidity smart contracts.

- [Hardhat](https://github.com/nomiclabs/hardhat): compile and run the smart contracts on a local development network
- [TypeChain](https://github.com/ethereum-ts/TypeChain): generate TypeScript types for smart contracts
- [Ethers](https://github.com/ethers-io/ethers.js/): renowned Ethereum library and wallet implementation
- [Waffle](https://github.com/EthWorks/Waffle): tooling for writing comprehensive smart contract tests
- [Solhint](https://github.com/protofire/solhint): linter
- [Solcover](https://github.com/sc-forks/solidity-coverage): code coverage
- [Prettier Plugin Solidity](https://github.com/prettier-solidity/prettier-plugin-solidity): code formatter

This is a GitHub template, which means you can reuse it as many times as you want. You can do that by clicking the "Use this
template" button at the top of the page.

## List supported pool

```
    {
      "0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063",
        "100000000000000000",
        "0x1d8b86e3d88cdb2d34688e87e72f388cb541b7c8",
        "5",
        "0xdad97f7713ae9437fa9249920ec8507e5fbb23d3",
        false,
    }
   {
      from: "0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063",
      amount: "100000000000000000",
      curvePool: "0xb731e7ced547a636f7cd3eee3972eb32b0402893",
      poolLength: "4",
      to: "0xb731e7ced547a636f7cd3eee3972eb32b0402893",
      use_underlying: false,
      depositToken: "0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270",
      depositTokenIndex: "3",
    },
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
```

### Pre Requisites

- Yarn >= v1.22.15
- Node.js >= v12.22.6

```sh
cp .env.example .env
```

Then, proceed with installing dependencies:

```sh
yarn install
```

### Compile

Compile the smart contracts with Hardhat:

```sh
$ yarn compile
```

### TypeChain

Compile the smart contracts and generate TypeChain artifacts:

```sh
$ yarn typechain
```

### Lint Solidity

Lint the Solidity code:

```sh
$ yarn lint:sol
```

### Lint TypeScript

Lint the TypeScript code:

```sh
$ yarn lint:ts
```

### Test

Run the Mocha tests:

```sh
$ yarn test
```

### Coverage

Generate the code coverage report:

```sh
$ yarn coverage
```

### Report Gas

See the gas usage per unit test and average gas per method call:

```sh
$ REPORT_GAS=true yarn test
```

### Clean

Delete the smart contract artifacts, the coverage reports and the Hardhat cache:

```sh
$ yarn clean
```

### Deploy

Deploy the contracts to Hardhat Network:

```sh
$ yarn hardhat --network hardhat deploy
```

## Syntax Highlighting

If you use VSCode, you can enjoy syntax highlighting for your Solidity code via the
[vscode-solidity](https://github.com/juanfranblanco/vscode-solidity) extension. The recommended approach to set the
compiler version is to add the following fields to your VSCode user settings:

```json
{
  "solidity.compileUsingRemoteVersion": "v0.8.7+commit.e28d00a7",
  "solidity.defaultCompiler": "remote"
}
```

Where of course `v0.8.7+commit.e28d00a7` can be replaced with any other version.
