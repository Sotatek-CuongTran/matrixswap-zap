// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.4;

contract MockCurve {
    constructor(address _token) {
        token = _token;
    }

    address token;
    mapping(address => uint256) public amounts;

    function add_liquidity(
        uint256[3] calldata _amounts,
        uint256 _min_mint_amount
    ) external {
        amounts[msg.sender] += _amounts[0];
    }

    function underlying_coins(uint256) external view returns (address) {
        return token;
    }

    function lp_token() external view returns (address) {
        return address(this);
    }

    function transfer(address _from, uint256 _amount) external {
        require(
            balanceOf(msg.sender) >= _amount,
            "MockCurve: balanceOf(msg.sender) >= _amount"
        );
        amounts[msg.sender] -= _amount;
        amounts[_from] += _amount;
    }

    function balanceOf(address _user) public view returns (uint256) {
        return amounts[_user];
    }
}
