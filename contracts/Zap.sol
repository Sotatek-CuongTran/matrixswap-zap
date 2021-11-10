// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IStakingReward.sol";
import "./interfaces/IWETH.sol";

contract Zap is OwnableUpgradeable {
    using SafeERC20 for IERC20;

    /* ========== CONSTANT VARIABLES ========== */

    address public constant USDT = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F; // polygon
    address public constant DAI = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063; // polygon
    address public constant WETH = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270; // polygon WMATIC

    // solhint-disable-next-line
    IUniswapV2Router02 public ROUTER;
    // solhint-disable-next-line
    IUniswapV2Factory public FACTORY;

    /* ========== STATE VARIABLES ========== */

    mapping(address => bool) private notLP;
    mapping(address => address) private routePairAddresses;
    mapping(bytes32 => address) private intermediateTokens;
    // mapping(address => address) public stakingRewards; // LP => farming pool address
    address[] public tokens;

    /* ========== INITIALIZER ========== */

    function initialize(address _router, address _factory)
        external
        initializer
    {
        __Ownable_init();
        require(owner() != address(0), "ZapETH: owner must be set");

        ROUTER = IUniswapV2Router02(_router);
        FACTORY = IUniswapV2Factory(_factory);

        setNotLP(WETH);
        setNotLP(USDT);
        setNotLP(DAI);
    }

    // solhint-disable-next-line
    receive() external payable {}

    /* ========== View Functions ========== */

    function isLP(address _address) public view returns (bool) {
        return !notLP[_address];
    }

    function routePair(address _address) external view returns (address) {
        return routePairAddresses[_address];
    }

    /* ========== External Functions ========== */

    function zapAndFarmToken(
        address _from,
        uint256 amount,
        address _to,
        address _farmingPool,
        address _receiver
    ) external {
        require(isLP(_to), "ZAP: NLP"); // not an LP
        // require(stakingRewards[_to] != address(0), "ZAP: NFP"); // no farming pool

        _approveTokenIfNeeded(_from);
        zapInToken(_from, amount, _to, address(this));
        _approveTokenIfNeeded(_farmingPool, _to);

        IStakingRewards(_farmingPool).stake(
            IERC20(_to).balanceOf(address(this))
        );
        IERC20(_farmingPool).transfer(
            _receiver,
            IERC20(_farmingPool).balanceOf(address(this))
        );
    }

    /// @notice use zapInTokenV2
    function zapAndFarmTokenV2(
        address _from,
        uint256 amount,
        address _to,
        address _farmingPool,
        address _receiver
    ) external {
        require(isLP(_to), "ZAP: NLP");

        _approveTokenIfNeeded(_from);
        zapInTokenV2(_from, amount, _to, address(this));

        _approveTokenIfNeeded(_farmingPool, _to);
        IStakingRewards(_farmingPool).stake(
            IERC20(_to).balanceOf(address(this))
        );

        IERC20(_farmingPool).safeTransfer(
            _receiver,
            IERC20(_farmingPool).balanceOf(address(this))
        );
    }

    function zapAndFarm(
        address _to,
        address _farmingPool,
        address _receiver
    ) external payable {
        require(isLP(_to), "ZAP: NLP");

        // has 1 risk: excess one token amount => need to send to user

        _swapETHToLP(_to, msg.value, address(this));

        IStakingRewards(_farmingPool).stake(
            IERC20(_to).balanceOf(address(this))
        );
        IERC20(_farmingPool).transfer(
            _receiver,
            IERC20(_farmingPool).balanceOf(address(this))
        );
    }

    function zapInToken(
        address _from,
        uint256 amount,
        address _to,
        address _receiver
    ) public {
        IERC20(_from).safeTransferFrom(msg.sender, address(this), amount);
        _approveTokenIfNeeded(_from);

        if (isLP(_to)) {
            IUniswapV2Pair pair = IUniswapV2Pair(_to);
            address token0 = pair.token0();
            address token1 = pair.token1();
            if (_from == token0 || _from == token1) {
                // swap half amount for other
                address other = _from == token0 ? token1 : token0;
                _approveTokenIfNeeded(other);
                uint256 sellAmount = amount / 2;
                uint256 otherAmount = _swap(
                    _from,
                    sellAmount,
                    other,
                    address(this)
                );
                ROUTER.addLiquidity(
                    _from,
                    other,
                    amount - sellAmount,
                    otherAmount,
                    0,
                    0,
                    _receiver,
                    block.timestamp
                );
            } else {
                // solhint-disable-next-line
                uint256 ETHAmount = _swapTokenForETH(
                    _from,
                    amount,
                    address(this)
                );
                _swapETHToLP(_to, ETHAmount, _receiver);
            }
        } else {
            _swap(_from, amount, _to, _receiver);
        }
    }

    /// @notice in V1, token will convert to ETH, then ETH => token0, token1 => LP
    /// but in V2, we do not convert to ETH, A => token0, token1 => LP
    function zapInTokenV2(
        address _from,
        uint256 amount,
        address _to,
        address _receiver
    ) public {
        require(isLP(_to), "ZAP: NLP");

        IERC20(_from).safeTransferFrom(msg.sender, address(this), amount);
        _approveTokenIfNeeded(_from);

        IUniswapV2Pair pair = IUniswapV2Pair(_to);
        address token0 = pair.token0();
        address token1 = pair.token1();
        if (_from == token0 || _from == token1) {
            // swap half amount for other
            address other = _from == token0 ? token1 : token0;
            _approveTokenIfNeeded(other);
            uint256 sellAmount = amount / 2;
            uint256 otherAmount = _swapV2(
                _from,
                sellAmount,
                other,
                address(this)
            );
            ROUTER.addLiquidity(
                _from,
                other,
                amount - sellAmount,
                otherAmount,
                0,
                0,
                _receiver,
                block.timestamp
            );
        } else {
            uint256 sellAmount = amount / 2;
            uint256 token0Amount = _swapV2(
                _from,
                sellAmount,
                token0,
                address(this)
            );
            uint256 token1Amount = _swapV2(
                _from,
                amount - sellAmount,
                token1,
                address(this)
            );

            _approveTokenIfNeeded(token0);
            _approveTokenIfNeeded(token1);

            ROUTER.addLiquidity(
                token0,
                token1,
                token0Amount,
                token1Amount,
                0,
                0,
                _receiver,
                block.timestamp
            );
        }
    }

    function zapIn(address _to, address _receiver) external payable {
        _swapETHToLP(_to, msg.value, _receiver);
    }

    function zapOut(
        address _from,
        uint256 amount,
        address _receiver
    ) external {
        IERC20(_from).safeTransferFrom(_receiver, address(this), amount);
        _approveTokenIfNeeded(_from);

        if (!isLP(_from)) {
            _swapTokenForETH(_from, amount, _receiver);
        } else {
            IUniswapV2Pair pair = IUniswapV2Pair(_from);
            address token0 = pair.token0();
            address token1 = pair.token1();
            if (token0 == WETH || token1 == WETH) {
                ROUTER.removeLiquidityETH(
                    token0 != WETH ? token0 : token1,
                    amount,
                    0,
                    0,
                    _receiver,
                    block.timestamp
                );
            } else {
                ROUTER.removeLiquidity(
                    token0,
                    token1,
                    amount,
                    0,
                    0,
                    _receiver,
                    block.timestamp
                );
            }
        }
    }

    /* ========== Private Functions ========== */

    function _approveTokenIfNeeded(address token) private {
        if (IERC20(token).allowance(address(this), address(ROUTER)) == 0) {
            IERC20(token).safeApprove(address(ROUTER), type(uint256).max);
        }
    }

    function _approveTokenIfNeeded(address spender, address token) private {
        if (IERC20(token).allowance(address(this), address(spender)) == 0) {
            IERC20(token).approve(address(spender), type(uint256).max);
        }
    }

    function _swapETHToLP(
        address lp,
        uint256 amount,
        address receiver
    ) private {
        if (!isLP(lp)) {
            _swapETHForToken(lp, amount, receiver);
        } else {
            // lp
            IUniswapV2Pair pair = IUniswapV2Pair(lp);
            address token0 = pair.token0();
            address token1 = pair.token1();
            if (token0 == WETH || token1 == WETH) {
                address token = token0 == WETH ? token1 : token0;
                uint256 swapValue = amount / 2;
                uint256 tokenAmount = _swapETHForToken(
                    token,
                    swapValue,
                    address(this)
                );

                _approveTokenIfNeeded(token);
                ROUTER.addLiquidityETH{ value: amount - swapValue }(
                    token,
                    tokenAmount,
                    0,
                    0,
                    receiver,
                    block.timestamp
                );
            } else {
                uint256 swapValue = amount - 2;
                uint256 token0Amount = _swapETHForToken(
                    token0,
                    swapValue,
                    address(this)
                );
                uint256 token1Amount = _swapETHForToken(
                    token1,
                    amount - swapValue,
                    address(this)
                );

                _approveTokenIfNeeded(token0);
                _approveTokenIfNeeded(token1);
                ROUTER.addLiquidity(
                    token0,
                    token1,
                    token0Amount,
                    token1Amount,
                    0,
                    0,
                    receiver,
                    block.timestamp
                );
            }
        }
    }

    function _swapETHForToken(
        address token,
        uint256 value,
        address receiver
    ) private returns (uint256) {
        address[] memory path;

        if (routePairAddresses[token] != address(0)) {
            path = new address[](3);
            path[0] = WETH;
            path[1] = routePairAddresses[token];
            path[2] = token;
        } else {
            path = new address[](2);
            path[0] = WETH;
            path[1] = token;
        }

        uint256[] memory amounts = ROUTER.swapExactETHForTokens{ value: value }(
            0,
            path,
            receiver,
            block.timestamp
        );
        return amounts[amounts.length - 1];
    }

    function _swapTokenForETH(
        address token,
        uint256 amount,
        address receiver
    ) private returns (uint256) {
        address[] memory path;
        if (routePairAddresses[token] != address(0)) {
            path = new address[](3);
            path[0] = token;
            path[1] = routePairAddresses[token];
            path[2] = WETH;
        } else {
            path = new address[](2);
            path[0] = token;
            path[1] = WETH;
        }

        uint256[] memory amounts = ROUTER.swapExactTokensForETH(
            amount,
            0,
            path,
            receiver,
            block.timestamp
        );
        return amounts[amounts.length - 1];
    }

    function _swapV2(
        address _from,
        uint256 amount,
        address _to,
        address receiver
    ) private returns (uint256) {
        // get pair of two token
        address pair = FACTORY.getPair(_from, _to);
        address[] memory path;

        if (pair == address(0)) {
            address intermediate = intermediateTokens[
                _getBytes32Key(_from, _to)
            ];
            require(intermediate != address(0), "ZAP: NEP"); // not exist path

            path = new address[](3);
            path[0] = _from;
            path[1] = intermediate;
            path[2] = _to;
        } else {
            path = new address[](2);
            path[0] = _from;
            path[1] = _to;
        }

        uint256[] memory amounts = ROUTER.swapExactTokensForTokens(
            amount,
            0,
            path,
            receiver,
            block.timestamp
        );
        return amounts[amounts.length - 1];
    }

    // solhint-disable-next-line
    function _swap(
        address _from,
        uint256 amount,
        address _to,
        address receiver
    ) private returns (uint256) {
        address intermediate = routePairAddresses[_from];
        if (intermediate == address(0)) {
            intermediate = routePairAddresses[_to];
        }

        address[] memory path;
        if (intermediate != address(0) && (_from == WETH || _to == WETH)) {
            // [WETH, BUSD, VAI] or [VAI, BUSD, WETH]
            path = new address[](3);
            path[0] = _from;
            path[1] = intermediate;
            path[2] = _to;
        } else if (
            intermediate != address(0) &&
            (_from == intermediate || _to == intermediate)
        ) {
            // [VAI, BUSD] or [BUSD, VAI]
            path = new address[](2);
            path[0] = _from;
            path[1] = _to;
        } else if (
            intermediate != address(0) &&
            routePairAddresses[_from] == routePairAddresses[_to]
        ) {
            // [VAI, DAI] or [VAI, USDC]
            path = new address[](3);
            path[0] = _from;
            path[1] = intermediate;
            path[2] = _to;
        } else if (
            routePairAddresses[_from] != address(0) &&
            routePairAddresses[_to] != address(0) &&
            routePairAddresses[_from] != routePairAddresses[_to]
        ) {
            // routePairAddresses[xToken] = xRoute
            // [VAI, BUSD, WETH, xRoute, xToken]
            path = new address[](5);
            path[0] = _from;
            path[1] = routePairAddresses[_from];
            path[2] = WETH;
            path[3] = routePairAddresses[_to];
            path[4] = _to;
        } else if (
            intermediate != address(0) &&
            routePairAddresses[_from] != address(0)
        ) {
            // [VAI, BUSD, WETH, BUNNY]
            path = new address[](4);
            path[0] = _from;
            path[1] = intermediate;
            path[2] = WETH;
            path[3] = _to;
        } else if (
            intermediate != address(0) && routePairAddresses[_to] != address(0)
        ) {
            // [BUNNY, WETH, BUSD, VAI]
            path = new address[](4);
            path[0] = _from;
            path[1] = WETH;
            path[2] = intermediate;
            path[3] = _to;
        } else if (_from == WETH || _to == WETH) {
            // [WETH, BUNNY] or [BUNNY, WETH]
            path = new address[](2);
            path[0] = _from;
            path[1] = _to;
        } else {
            // [USDT, BUNNY] or [BUNNY, USDT]
            path = new address[](3);
            path[0] = _from;
            path[1] = WETH;
            path[2] = _to;
        }

        uint256[] memory amounts = ROUTER.swapExactTokensForTokens(
            amount,
            0,
            path,
            receiver,
            block.timestamp
        );
        return amounts[amounts.length - 1];
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function setRoutePairAddress(address asset, address route)
        external
        onlyOwner
    {
        routePairAddresses[asset] = route;
    }

    function setNotLP(address token) public onlyOwner {
        bool needPush = notLP[token] == false;
        notLP[token] = true;
        if (needPush) {
            tokens.push(token);
        }
    }

    function removeToken(uint256 i) external onlyOwner {
        address token = tokens[i];
        notLP[token] = false;
        tokens[i] = tokens[tokens.length - 1];
        tokens.pop();
    }

    // withdraw all token that contract hold to ETH
    function sweep() external onlyOwner {
        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            if (token == address(0)) continue;
            uint256 amount = IERC20(token).balanceOf(address(this));
            if (amount > 0) {
                if (token == WETH) {
                    IWETH(token).withdraw(amount);
                } else {
                    _swapTokenForETH(token, amount, owner());
                }
            }
        }

        uint256 balance = address(this).balance;
        if (balance > 0) {
            payable(owner()).transfer(balance);
        }
    }

    function withdraw(address token) external onlyOwner {
        if (token == address(0)) {
            payable(owner()).transfer(address(this).balance);
            return;
        }

        IERC20(token).transfer(owner(), IERC20(token).balanceOf(address(this)));
    }

    function addIntermediateToken(
        address _token0,
        address _token1,
        address _intermediateAddress
    ) external {
        bytes32 key = _getBytes32Key(_token0, _token1);
        intermediateTokens[key] = _intermediateAddress;
    }

    function removeIntermediateToken(address _token0, address _token1)
        external
    {
        bytes32 key = _getBytes32Key(_token0, _token1);
        intermediateTokens[key] = address(0);
    }

    function _getBytes32Key(address _token0, address _token1)
        private
        pure
        returns (bytes32)
    {
        (_token0, _token1) = _token0 < _token1
            ? (_token0, _token1)
            : (_token1, _token0);
        return keccak256(abi.encodePacked(_token0, _token1));
    }
}
