// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

interface IZap {
    function tokens() external view returns (address[] memory);

    function isLP(address _address) external view returns (bool);

    function routePair(address _address) external view returns (address);

    /* ========== External Functions ========== */

    function zapAndFarmToken(
        address _from,
        uint256 amount,
        address _to,
        address _farmingPool,
        address _receiver
    ) external;

    /// @notice use zapInTokenV2
    function zapAndFarmTokenV2(
        address _from,
        uint256 amount,
        address _to,
        address _farmingPool,
        address _receiver
    ) external;

    function zapAndFarm(
        address _to,
        address _farmingPool,
        address _receiver
    ) external payable;

    function zapInToken(
        address _from,
        uint256 amount,
        address _to,
        address _receiver
    ) external;

    /// @notice in V1, token will convert to ETH, then ETH => token0, token1 => LP
    /// but in V2, we do not convert to ETH, A => token0, token1 => LP
    function zapInTokenV2(
        address _from,
        uint256 amount,
        address _to,
        address _receiver
    ) external;

    function zapIn(address _to, address _receiver) external payable;

    function zapOut(
        address _from,
        uint256 amount,
        address _receiver
    ) external;

    /* ========== RESTRICTED FUNCTIONS ========== */

    function setRoutePairAddress(address asset, address route) external;

    function setNotLP(address token) external;

    function removeToken(uint256 i) external;

    // withdraw all token that contract hold to ETH
    function sweep() external;

    function withdraw(address token) external;
}
