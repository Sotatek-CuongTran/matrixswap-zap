#!/bin/sh

yarn hardhat compile
yarn hardhat deploy --network polygon
yarn hardhat --network polygon etherscan-verify --api-key TNJ7SSWY1NRNAEAK4XKJ1UHPSATX2ENNW3
yarn hardhat add-intermediate-token --token0 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063 --token1 0xac51C4c48Dc3116487eD4BC16542e27B5694Da1b --intermediate 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619 --network polygon
yarn hardhat add-intermediate-token --token0 0xc2132d05d31c914a87c6611c10748aeb04b58e8f --token1 0xac51C4c48Dc3116487eD4BC16542e27B5694Da1b --intermediate 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619 --network polygon
yarn hardhat add-intermediate-token --token0 0xc2132d05d31c914a87c6611c10748aeb04b58e8f --token1 0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270 --intermediate 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619 --network polygon