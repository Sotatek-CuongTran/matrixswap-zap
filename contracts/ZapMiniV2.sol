// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IWMATIC.sol";

contract ZapMiniV2 is OwnableUpgradeable {
    using SafeERC20 for IERC20;

    struct ProtocolStats {
        mapping(bytes32 => address) intermediateTokens;
        mapping(address => address) routePairAddresses;
        address router;
        address factory;
    }

    struct ZapInForm {
        bytes32 protocolType;
        address from;
        uint256 amount;
        address to;
        address receiver;
    }

    /* ========== CONSTANT VARIABLES ========== */

    address public USDT;
    address public DAI;
    address public WMATIC;
    address public USDC;
    address public WETH;

    /* ========== STATE VARIABLES ========== */

    mapping(bytes32 => ProtocolStats) public protocols; // ex protocol: quickswap, sushiswap

    event ZapIn(
        address indexed token,
        address indexed lpToken,
        uint256 indexed amount,
        bytes32 protocol
    );

    /* ========== INITIALIZER ========== */

    function initialize(
        address _USDT,
        address _DAI,
        address _WMATIC,
        address _USDC,
        address _WETH
    ) external initializer {
        __Ownable_init();
        require(owner() != address(0), "ZapETH: owner must be set");

        USDC = _USDC;
        USDT = _USDT;
        WMATIC = _WMATIC;
        WETH = _WETH;
        DAI = _DAI;
    }

    // solhint-disable-next-line
    receive() external payable {}

    /* ========== View Functions ========== */

    /// @notice get router pair address for protocol
    /// @param _type protocol type
    /// @param _address pair address
    /// @return address
    function routePair(bytes32 _type, address _address)
        external
        view
        returns (address)
    {
        return protocols[_type].routePairAddresses[_address];
    }

    /// @notice get router pair address for protocol
    /// @param _type protocol type
    /// @param _pair pair - bytes32
    /// @return address
    function getIntermediateToken(bytes32 _type, bytes32 _pair)
        external
        view
        returns (address)
    {
        return protocols[_type].intermediateTokens[_pair];
    }

    /// @notice zap in for token ERC20
    /// @dev in V1, token will convert to ETH, then ETH => token0, token1 => LP
    /// but in this version, we do not convert to ETH, A => token0, token1 => LP
    /// @param _params zapIn params
    function zapInToken(ZapInForm calldata _params)
        public
        returns (uint256 liquidity)
    {
        IERC20(_params.from).safeTransferFrom(
            msg.sender,
            address(this),
            _params.amount
        );
        address router = protocols[_params.protocolType].router;

        _approveTokenIfNeeded(router, _params.from);

        IUniswapV2Pair pair = IUniswapV2Pair(_params.to);
        address token0 = pair.token0();
        address token1 = pair.token1();

        liquidity = _convertToLP(_params, router, token0, token1);

        // send excess amount to msg.sender
        _transferExcessBalance(token0, msg.sender);
        _transferExcessBalance(token1, msg.sender);
    }

    /// @notice zap in token with custom route
    /// @dev in V1, token will convert to ETH, then ETH => token0, token1 => LP
    /// but in this version, we do not convert to ETH, A => token0, token1 => LP
    /// @param _params zapIn params
    /// @param _path1 path1
    /// @param _path2 path2
    function zapInTokenV2(
        ZapInForm memory _params,
        address[] calldata _path1,
        address[] calldata _path2
    ) public returns (uint256 liquidity) {
        IERC20(_params.from).safeTransferFrom(
            msg.sender,
            address(this),
            _params.amount
        );
        address router = protocols[_params.protocolType].router;
        _approveTokenIfNeeded(router, _params.from);

        IUniswapV2Pair pair = IUniswapV2Pair(_params.to);
        address token0 = pair.token0();
        address token1 = pair.token1();
        liquidity = _convertToLPByPath(
            _params,
            router,
            token0,
            token1,
            _path1,
            _path2
        );

        // send excess amount to msg.sender
        _transferExcessBalance(token0, msg.sender);
        _transferExcessBalance(token1, msg.sender);
    }

    /// @notice zap in ETH to LP
    /// @param _type protocol type
    /// @param _to lp token out
    /// @param _receiver receiver address
    function zapIn(
        bytes32 _type,
        address _to,
        address _receiver
    ) external payable {
        _swapETHToLP(_type, _to, msg.value, _receiver);

        // send excess amount to msg.sender
        IUniswapV2Pair pair = IUniswapV2Pair(_to);
        address token0 = pair.token0();
        address token1 = pair.token1();

        _transferExcessBalance(token0, msg.sender);
        _transferExcessBalance(token1, msg.sender);

        emit ZapIn(WMATIC, _to, msg.value, _type);
    }

    // @notice zap out LP to token
    /// @param _router protocol type
    /// @param _from lp token in
    /// @param _amount amount LP in
    /// @param _receiver receiver address
    function zapOut(
        address _router,
        address _from,
        uint256 _amount,
        address _receiver
    ) external {
        IERC20(_from).safeTransferFrom(_receiver, address(this), _amount);
        _approveTokenIfNeeded(_router, _from);

        IUniswapV2Pair pair = IUniswapV2Pair(_from);
        address token0 = pair.token0();
        address token1 = pair.token1();
        if (token0 == WMATIC || token1 == WMATIC) {
            IUniswapV2Router02(_router).removeLiquidityETH(
                token0 != WMATIC ? token0 : token1,
                _amount,
                0,
                0,
                _receiver,
                block.timestamp
            );
        } else {
            IUniswapV2Router02(_router).removeLiquidity(
                token0,
                token1,
                _amount,
                0,
                0,
                _receiver,
                block.timestamp
            );
        }
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    // @notice set router pair address
    /// @param _type protocol type
    /// @param _asset token address
    /// @param _route route address
    function setRoutePairAddress(
        bytes32 _type,
        address _asset,
        address _route
    ) external onlyOwner {
        protocols[_type].routePairAddresses[_asset] = _route;
    }

    /// @notice withdraw token that contract hold
    /// @param _token token address
    function withdraw(address _token) external onlyOwner {
        if (_token == address(0)) {
            payable(owner()).transfer(address(this).balance);
            return;
        }

        IERC20(_token).transfer(
            owner(),
            IERC20(_token).balanceOf(address(this))
        );
    }

    // @notice set factory and router for protocol
    /// @param _type protocol type
    /// @param _factory factory address
    /// @param _router router address
    function setFactoryAndRouter(
        bytes32 _type,
        address _factory,
        address _router
    ) external onlyOwner {
        protocols[_type].router = _router;
        protocols[_type].factory = _factory;
    }

    /// @notice set intermediate token for  token0 - token1
    /// @param _type protocol type
    /// @param _token0 token0 address
    /// @param _token1 token1 address
    /// @param _intermediateAddress intermediate token address
    function addIntermediateToken(
        bytes32 _type,
        address _token0,
        address _token1,
        address _intermediateAddress
    ) external onlyOwner {
        bytes32 key = _getBytes32Key(_token0, _token1);
        protocols[_type].intermediateTokens[key] = _intermediateAddress;
    }

    /// @notice unset intermediate token for  token0 - token1
    /// @param _type protocol type
    /// @param _token0 token0 address
    /// @param _token1 token1 address
    function removeIntermediateToken(
        bytes32 _type,
        address _token0,
        address _token1
    ) external onlyOwner {
        bytes32 key = _getBytes32Key(_token0, _token1);
        protocols[_type].intermediateTokens[key] = address(0);
    }

    /* ========== Private Functions ========== */

    /// @notice swap ETH to LP token, ETH is MATIC in polygon
    /// @param _type protocol type
    /// @param _lp lp address
    /// @param _amount amount to swap
    /// @param _receiver receiver address
    function _swapETHToLP(
        bytes32 _type,
        address _lp,
        uint256 _amount,
        address _receiver
    ) private {
        IUniswapV2Pair pair = IUniswapV2Pair(_lp);
        address router = protocols[_type].router;
        address token0 = pair.token0();
        address token1 = pair.token1();
        if (token0 == WMATIC || token1 == WMATIC) {
            address token = token0 == WMATIC ? token1 : token0;
            uint256 swapValue = _amount / 2;
            uint256 tokenAmount = _swapETHForToken(
                _type,
                token,
                swapValue,
                address(this)
            );

            _approveTokenIfNeeded(router, token);
            IUniswapV2Router02(router).addLiquidityETH{
                value: _amount - swapValue
            }(token, tokenAmount, 0, 0, _receiver, block.timestamp);
        } else {
            uint256 swapValue = _amount - 2;
            uint256 token0Amount = _swapETHForToken(
                _type,
                token0,
                swapValue,
                address(this)
            );
            uint256 token1Amount = _swapETHForToken(
                _type,
                token1,
                _amount - swapValue,
                address(this)
            );

            _approveTokenIfNeeded(router, token0);
            _approveTokenIfNeeded(router, token1);
            IUniswapV2Router02(router).addLiquidity(
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

    /// @notice swap ETH to token, ETH is MATIC in polygon
    /// @param _type protocol type
    /// @param _token token address
    /// @param _value amount to swap
    /// @param _receiver receiver address
    function _swapETHForToken(
        bytes32 _type,
        address _token,
        uint256 _value,
        address _receiver
    ) private returns (uint256) {
        address[] memory path;

        if (protocols[_type].routePairAddresses[_token] != address(0)) {
            path = new address[](3);
            path[0] = WMATIC;
            path[1] = protocols[_type].routePairAddresses[_token];
            path[2] = _token;
        } else {
            path = new address[](2);
            path[0] = WMATIC;
            path[1] = _token;
        }

        uint256[] memory amounts = IUniswapV2Router02(protocols[_type].router)
            .swapExactETHForTokens{ value: _value }(
            0,
            path,
            _receiver,
            block.timestamp
        );
        return amounts[amounts.length - 1];
    }

    /// @notice swap token to token
    /// @param _type protocol type
    /// @param _from from token address
    /// @param _amount amount to swap
    /// @param _to to token address
    /// @param _receiver receiver address
    function _swap(
        bytes32 _type,
        address _from,
        uint256 _amount,
        address _to,
        address _receiver
    ) private returns (uint256) {
        // get pair of two token
        address factory = protocols[_type].factory;

        address pair = IUniswapV2Factory(factory).getPair(_from, _to);
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
                path[1] = protocols[_type].intermediateTokens[
                    _getBytes32Key(_from, _to)
                ];
            } else if (
                _hasPair(factory, _from, WETH) && _hasPair(factory, WETH, _to)
            ) {
                path[1] = WETH;
            } else if (
                _hasPair(factory, _from, USDC) && _hasPair(factory, USDC, _to)
            ) {
                path[1] = USDC;
            } else if (
                _hasPair(factory, _from, DAI) && _hasPair(factory, DAI, _to)
            ) {
                path[1] = DAI;
            } else if (
                _hasPair(factory, _from, USDT) && _hasPair(factory, USDT, _to)
            ) {
                path[1] = USDT;
            } else {
                revert("ZAP: NEP"); // not exist path
            }
        }

        uint256[] memory amounts = IUniswapV2Router02(protocols[_type].router)
            .swapExactTokensForTokens(
                _amount,
                0,
                path,
                _receiver,
                block.timestamp
            );
        return amounts[amounts.length - 1];
    }

    /// @notice swap token to token with custom route
    /// @param _router router address
    /// @param _amount amount to swap
    /// @param _path route path
    /// @param _receiver receiver address
    function _swapByPath(
        address _router,
        uint256 _amount,
        address[] memory _path,
        address _receiver
    ) private returns (uint256) {
        uint256[] memory amounts = IUniswapV2Router02(_router)
            .swapExactTokensForTokens(
                _amount,
                0,
                _path,
                _receiver,
                block.timestamp
            );
        return amounts[amounts.length - 1];
    }

    /// @notice get key for pair token0 - token1 with key(token0, token1) === key(token1, token0)
    /// @param _token0 token0
    /// @param _token1 token1
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

    /// @notice approve if needed
    /// @param _spender spender address
    /// @param _token token to approve
    function _approveTokenIfNeeded(address _spender, address _token) private {
        if (IERC20(_token).allowance(address(this), address(_spender)) == 0) {
            IERC20(_token).safeApprove(address(_spender), type(uint256).max);
        }
    }

    /// @notice check is has pair of token0 - token1
    /// @param _factory factory address
    /// @param _token0 token0 address
    /// @param _token1 token1 address
    function _hasPair(
        address _factory,
        address _token0,
        address _token1
    ) private view returns (bool) {
        return
            IUniswapV2Factory(_factory).getPair(_token0, _token1) != address(0);
    }

    /// @notice transfer excess balance to user, when user call zap func
    /// @param _token token to transfer
    /// @param _user receiver
    function _transferExcessBalance(address _token, address _user) private {
        uint256 amount = IERC20(_token).balanceOf(address(this));
        if (amount > 0) {
            IERC20(_token).transfer(_user, amount);
        }
    }

    /// @notice convert token to LP
    /// @param _params convert params
    /// @param _router protocol router address
    /// @param _token0 token0
    /// @param _token1 token1
    function _convertToLP(
        ZapInForm memory _params,
        address _router,
        address _token0,
        address _token1
    ) private returns (uint256 liquidity) {
        if (_params.from == _token0 || _params.from == _token1) {
            // swap half amount for other
            address other = _params.from == _token0 ? _token1 : _token0;
            _approveTokenIfNeeded(_router, other);
            uint256 sellAmount = _params.amount / 2;
            uint256 otherAmount = _swap(
                _params.protocolType,
                _params.from,
                sellAmount,
                other,
                address(this)
            );
            (, , liquidity) = IUniswapV2Router02(_router).addLiquidity(
                _params.from,
                other,
                _params.amount - sellAmount,
                otherAmount,
                0,
                0,
                _params.receiver,
                block.timestamp
            );
        } else {
            uint256 sellAmount = _params.amount / 2;
            uint256 token0Amount = _swap(
                _params.protocolType,
                _params.from,
                sellAmount,
                _token0,
                address(this)
            );
            uint256 token1Amount = _swap(
                _params.protocolType,
                _params.from,
                _params.amount - sellAmount,
                _token1,
                address(this)
            );

            _approveTokenIfNeeded(_router, _token0);
            _approveTokenIfNeeded(_router, _token1);
            {
                (, , liquidity) = IUniswapV2Router02(_router).addLiquidity(
                    _token0,
                    _token1,
                    token0Amount,
                    token1Amount,
                    0,
                    0,
                    _params.receiver,
                    block.timestamp
                );
            }
        }
        emit ZapIn(
            _params.from,
            _params.to,
            _params.amount,
            _params.protocolType
        );
    }

    /// @notice convert token to LP with custom path
    /// @param _params convert params
    /// @param _router protocol router address
    /// @param _token0 token0
    /// @param _token1 token1
    /// @param _path1 path1
    /// @param _path2 path2
    function _convertToLPByPath(
        ZapInForm memory _params,
        address _router,
        address _token0,
        address _token1,
        address[] memory _path1,
        address[] memory _path2
    ) private returns (uint256 liquidity) {
        ZapInForm memory tempParams; // to resolve stack too deep fault

        if (_params.from == _token0 || _params.from == _token1) {
            // swap half amount for other
            address other = _params.from == _token0 ? _token1 : _token0;
            address[] memory path = _params.from == _token0 ? _path1 : _path2;
            _approveTokenIfNeeded(_router, other);
            uint256 sellAmount = _params.amount / 2;
            uint256 otherAmount = _swapByPath(
                _router,
                sellAmount,
                path,
                address(this)
            );
            (, , liquidity) = IUniswapV2Router02(_router).addLiquidity(
                _params.from,
                other,
                tempParams.amount - sellAmount, // to resolve stack too deep fault
                otherAmount,
                0,
                0,
                tempParams.receiver, // to resolve stack too deep fault
                block.timestamp
            );
        } else {
            uint256 sellAmount = tempParams.amount / 2;
            uint256 token0Amount = _swapByPath(
                _router,
                sellAmount,
                _path1,
                address(this)
            );
            uint256 token1Amount = _swapByPath(
                _router,
                tempParams.amount - sellAmount,
                _path2,
                address(this)
            );
            _approveTokenIfNeeded(_router, _token0);
            _approveTokenIfNeeded(_router, _token1);
            (, , liquidity) = IUniswapV2Router02(_router).addLiquidity(
                _token0,
                _token1,
                token0Amount,
                token1Amount,
                0,
                0,
                tempParams.receiver,
                block.timestamp
            );
        }

        emit ZapIn(
            tempParams.from,
            tempParams.to,
            tempParams.amount,
            tempParams.protocolType
        );
    }
}
