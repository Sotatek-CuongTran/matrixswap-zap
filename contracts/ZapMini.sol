// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IWMATIC.sol";

contract ZapMini is OwnableUpgradeable {
    using SafeERC20 for IERC20;

    /* ========== CONSTANT VARIABLES ========== */

    address public USDT;
    address public DAI;
    address public WMATIC;
    address public USDC;
    address public WETH;

    // solhint-disable-next-line
    IUniswapV2Router02 public ROUTER;
    // solhint-disable-next-line
    IUniswapV2Factory public FACTORY;

    /* ========== STATE VARIABLES ========== */

    mapping(address => address) private routePairAddresses; // WMATIC vs token
    mapping(bytes32 => address) private intermediateTokens;

    event ZapIn(
        address indexed token,
        address indexed lpToken,
        uint256 indexed amount
    );

    /* ========== INITIALIZER ========== */

    function initialize(
        address _router,
        address _factory,
        address _USDT,
        address _DAI,
        address _WMATIC,
        address _USDC,
        address _WETH
    ) external initializer {
        __Ownable_init();
        require(owner() != address(0), "ZapETH: owner must be set");

        ROUTER = IUniswapV2Router02(_router);
        FACTORY = IUniswapV2Factory(_factory);

        USDC = _USDC;
        USDT = _USDT;
        WMATIC = _WMATIC;
        WETH = _WETH;
        DAI = _DAI;
    }

    // solhint-disable-next-line
    receive() external payable {}

    /* ========== View Functions ========== */
    function routePair(address _address) external view returns (address) {
        return routePairAddresses[_address];
    }

    /// @notice in V1, token will convert to ETH, then ETH => token0, token1 => LP
    /// but in this version, we do not convert to ETH, A => token0, token1 => LP
    function zapInToken(
        address _from,
        uint256 _amount,
        address _to,
        address _receiver
    ) public returns (uint256 liquidity) {
        IERC20(_from).safeTransferFrom(msg.sender, address(this), _amount);
        _approveTokenIfNeeded(address(ROUTER), _from);

        IUniswapV2Pair pair = IUniswapV2Pair(_to);
        address token0 = pair.token0();
        address token1 = pair.token1();

        if (_from == token0 || _from == token1) {
            // swap half amount for other
            address other = _from == token0 ? token1 : token0;
            _approveTokenIfNeeded(address(ROUTER), other);
            uint256 sellAmount = _amount / 2;
            uint256 otherAmount = _swap(
                _from,
                sellAmount,
                other,
                address(this)
            );
            (, , liquidity) = ROUTER.addLiquidity(
                _from,
                other,
                _amount - sellAmount,
                otherAmount,
                0,
                0,
                _receiver,
                block.timestamp
            );
        } else {
            uint256 sellAmount = _amount / 2;
            uint256 token0Amount = _swap(
                _from,
                sellAmount,
                token0,
                address(this)
            );
            uint256 token1Amount = _swap(
                _from,
                _amount - sellAmount,
                token1,
                address(this)
            );

            _approveTokenIfNeeded(address(ROUTER), token0);
            _approveTokenIfNeeded(address(ROUTER), token1);

            (, , liquidity) = ROUTER.addLiquidity(
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

        emit ZapIn(_from, _to, _amount);

        // send excess amount to msg.sender
        _transferExcessBalance(token0, msg.sender);
        _transferExcessBalance(token1, msg.sender);
    }

    /// @notice in V1, token will convert to ETH, then ETH => token0, token1 => LP
    /// but in this version, we do not convert to ETH, A => token0, token1 => LP
    function zapInTokenV2(
        address _from,
        uint256 _amount,
        address _to,
        address[] calldata _path1,
        address[] calldata _path2,
        address _receiver
    ) public returns (uint256 liquidity) {
        IERC20(_from).safeTransferFrom(msg.sender, address(this), _amount);
        _approveTokenIfNeeded(address(ROUTER), _from);

        IUniswapV2Pair pair = IUniswapV2Pair(_to);
        address token0 = pair.token0();
        address token1 = pair.token1();

        if (_from == token0 || _from == token1) {
            address from;
            address receiver;
            uint256 amount;
            {
                from = _from;
                amount = _amount;
                receiver = _receiver;
            }
            // swap half amount for other
            address other = from == token0 ? token1 : token0;
            address[] memory path = from == token0 ? _path1 : _path2;

            _approveTokenIfNeeded(address(ROUTER), other);
            uint256 sellAmount = amount / 2;
            uint256 otherAmount = _swapByPath(sellAmount, path, address(this));

            (, , liquidity) = ROUTER.addLiquidity(
                from,
                other,
                amount - sellAmount,
                otherAmount,
                0,
                0,
                receiver,
                block.timestamp
            );
        } else {
            uint256 sellAmount = _amount / 2;
            uint256 token0Amount = _swapByPath(
                sellAmount,
                _path1,
                address(this)
            );
            uint256 token1Amount = _swapByPath(
                _amount - sellAmount,
                _path2,
                address(this)
            );

            _approveTokenIfNeeded(address(ROUTER), token0);
            _approveTokenIfNeeded(address(ROUTER), token1);

            (, , liquidity) = ROUTER.addLiquidity(
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

        emit ZapIn(_from, _to, _amount);

        // send excess amount to msg.sender
        _transferExcessBalance(token0, msg.sender);
        _transferExcessBalance(token1, msg.sender);
    }

    function zapIn(address _to, address _receiver) external payable {
        _swapETHToLP(_to, msg.value, _receiver);
        emit ZapIn(WMATIC, _to, msg.value);
    }

    function zapOut(
        address _from,
        uint256 amount,
        address _receiver
    ) external {
        IERC20(_from).safeTransferFrom(_receiver, address(this), amount);
        _approveTokenIfNeeded(address(ROUTER), _from);

        IUniswapV2Pair pair = IUniswapV2Pair(_from);
        address token0 = pair.token0();
        address token1 = pair.token1();
        if (token0 == WMATIC || token1 == WMATIC) {
            ROUTER.removeLiquidityETH(
                token0 != WMATIC ? token0 : token1,
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

    /* ========== RESTRICTED FUNCTIONS ========== */

    function setRoutePairAddress(address _asset, address _route)
        external
        onlyOwner
    {
        routePairAddresses[_asset] = _route;
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

    /* ========== Private Functions ========== */

    /// @notice ETH is MATIC in polygon
    function _swapETHToLP(
        address _lp,
        uint256 _amount,
        address _receiver
    ) private {
        IUniswapV2Pair pair = IUniswapV2Pair(_lp);
        address token0 = pair.token0();
        address token1 = pair.token1();
        if (token0 == WMATIC || token1 == WMATIC) {
            address token = token0 == WMATIC ? token1 : token0;
            uint256 swapValue = _amount / 2;
            uint256 tokenAmount = _swapETHForToken(
                token,
                swapValue,
                address(this)
            );

            _approveTokenIfNeeded(address(ROUTER), token);
            ROUTER.addLiquidityETH{ value: _amount - swapValue }(
                token,
                tokenAmount,
                0,
                0,
                _receiver,
                block.timestamp
            );
        } else {
            uint256 swapValue = _amount - 2;
            uint256 token0Amount = _swapETHForToken(
                token0,
                swapValue,
                address(this)
            );
            uint256 token1Amount = _swapETHForToken(
                token1,
                _amount - swapValue,
                address(this)
            );

            _approveTokenIfNeeded(address(ROUTER), token0);
            _approveTokenIfNeeded(address(ROUTER), token1);
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

    /// @notice ETH is MATIC in polygon
    function _swapETHForToken(
        address _token,
        uint256 _value,
        address _receiver
    ) private returns (uint256) {
        address[] memory path;

        if (routePairAddresses[_token] != address(0)) {
            path = new address[](3);
            path[0] = WMATIC;
            path[1] = routePairAddresses[_token];
            path[2] = _token;
        } else {
            path = new address[](2);
            path[0] = WMATIC;
            path[1] = _token;
        }

        uint256[] memory amounts = ROUTER.swapExactETHForTokens{
            value: _value
        }(0, path, _receiver, block.timestamp);
        return amounts[amounts.length - 1];
    }

    /// @notice ETH is MATIC in polygon
    function _swapTokenForETH(
        address _token,
        uint256 _amount,
        address _receiver
    ) private returns (uint256) {
        address[] memory path;
        if (routePairAddresses[_token] != address(0)) {
            path = new address[](3);
            path[0] = _token;
            path[1] = routePairAddresses[_token];
            path[2] = WMATIC;
        } else {
            path = new address[](2);
            path[0] = _token;
            path[1] = WMATIC;
        }

        uint256[] memory amounts = ROUTER.swapExactTokensForETH(
            _amount,
            0,
            path,
            _receiver,
            block.timestamp
        );
        return amounts[amounts.length - 1];
    }

    function _swap(
        address _from,
        uint256 _amount,
        address _to,
        address _receiver
    ) private returns (uint256) {
        // get pair of two token
        address pair = FACTORY.getPair(_from, _to);
        address[] memory path;

        if (pair != address(0)) {
            path = new address[](2);
            path[0] = _from;
            path[1] = _to;
        } else {
            path = new address[](3);
            path[0] = _from;
            path[2] = _to;

            if (pair == address(0)) {
                path[1] = intermediateTokens[_getBytes32Key(_from, _to)];
            } else if (_hasPair(_from, WETH) && _hasPair(WETH, _to)) {
                path[1] = WETH;
            } else if (_hasPair(_from, USDC) && _hasPair(USDC, _to)) {
                path[1] = USDC;
            } else if (_hasPair(_from, DAI) && _hasPair(DAI, _to)) {
                path[1] = DAI;
            } else if (_hasPair(_from, USDT) && _hasPair(USDT, _to)) {
                path[1] = USDT;
            } else {
                revert("ZAP: NEP"); // not exist path
            }
        }

        uint256[] memory amounts = ROUTER.swapExactTokensForTokens(
            _amount,
            0,
            path,
            _receiver,
            block.timestamp
        );
        return amounts[amounts.length - 1];
    }

    function _swapByPath(
        uint256 _amount,
        address[] memory _path,
        address _receiver
    ) private returns (uint256) {
        uint256[] memory amounts = ROUTER.swapExactTokensForTokens(
            _amount,
            0,
            _path,
            _receiver,
            block.timestamp
        );
        return amounts[amounts.length - 1];
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

    function _approveTokenIfNeeded(address _spender, address _token) private {
        if (IERC20(_token).allowance(address(this), address(_spender)) == 0) {
            IERC20(_token).safeApprove(address(_spender), type(uint256).max);
        }
    }

    function _hasPair(address _token0, address _token1)
        private
        view
        returns (bool)
    {
        return FACTORY.getPair(_token0, _token1) != address(0);
    }

    function _transferExcessBalance(address _token, address _user) private {
        uint256 amount = IERC20(_token).balanceOf(address(this));
        if (amount > 0) {
            IERC20(_token).transfer(_user, amount);
        }
    }
}
