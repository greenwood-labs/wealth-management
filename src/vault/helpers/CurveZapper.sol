// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "src/interfaces/vault/ISwapRouter.sol";
import "src/interfaces/vault/IZapper.sol";
import "src/libraries/CurveLib.sol";
import "src/libraries/SafeERC20.sol";
import "src/vault/base/Governed.sol";
import "src/vault/base/Payment.sol";

contract CurveZapper is IZapper, Governed, Payment {
    using CurveLib for ICurvePool;
    using SafeERC20 for address;

    enum PoolAction {
        ADD_LIQUIDITY,
        SWAP,
        POOL_NOT_LISTED
    }

    struct Route {
        address target;
        PoolAction action;
    }

    struct CurvePool {
        bool isUnderlyingPool;
        uint8 len;
        address pool;
        address lpToken;
    }

    mapping(address => mapping(address => uint256)) internal _tokenIds;
    mapping(address => mapping(uint256 => address)) internal _tokens;
    mapping(address => mapping(address => address)) internal _path;
    mapping(address => CurvePool) internal _pools;

    address public immutable usdc;

    ISwapRouter public swapRouter;

    // solhint-disable no-empty-blocks
    constructor(
        address _governance,
        ISwapRouter _swapRouter,
        address _wrappedNative,
        address _usdc
    ) Governed(_governance) Payment(_wrappedNative) {
        usdc = _usdc;
        swapRouter = _swapRouter;
    }

    function zapIn(
        address pool,
        address tokenIn,
        uint256 amountIn,
        address recipient
    ) public payable override returns (uint256 liquidity) {
        pull(tokenIn, address(this), amountIn);

        Route[] memory routes = setRoutes(pool, tokenIn);
        uint256 length = routes.length;

        if (routes[0].action == PoolAction.POOL_NOT_LISTED) {
            tokenIn.safeApprove(address(swapRouter), amountIn);
            swapRouter.swap(tokenIn, usdc, amountIn, address(this));

            tokenIn = usdc;
            amountIn = tokenIn.getBalanceOf(address(this));

            routes = setRoutes(pool, tokenIn);
        }

        for (uint256 i; i < length; ) {
            _zapIn(
                routes[i].action,
                routes[i].target,
                i == 0 ? tokenIn : routes[i - 1].target
            );

            unchecked {
                i = i + 1;
            }
        }

        address lpToken = _pools[pool].lpToken;
        liquidity = lpToken.getBalanceOf(address(this));
        lpToken.safeTransfer(recipient, liquidity);
    }

    function _zapIn(
        PoolAction action,
        address lpToken,
        address tokenIn
    ) internal {
        address pool = _path[tokenIn][lpToken];
        require(pool != address(0), "!pool");

        CurvePool memory info = _pools[pool];

        uint256 amountIn = tokenIn.getBalanceOf(address(this));
        tokenIn.safeApprove(pool, amountIn);

        if (action == PoolAction.SWAP) {
            ICurvePool(pool).swap(
                info.isUnderlyingPool,
                _tokenIds[pool][tokenIn],
                _tokenIds[pool][lpToken],
                amountIn
            );
        } else {
            ICurvePool(pool).addLiquidity(
                info.isUnderlyingPool,
                info.len,
                _tokenIds[pool][tokenIn],
                amountIn,
                0
            );
        }
    }

    function zapOut(
        address pool,
        address tokenOut,
        uint256 liquidity,
        address recipient
    ) public override returns (uint256 amountOut) {
        address lpToken = _pools[pool].lpToken;
        require(lpToken == address(0), "!pool");

        pull(lpToken, address(this), liquidity);

        ICurvePool(pool).removeLiquidity(
            _pools[pool].isUnderlyingPool,
            _tokenIds[pool][tokenOut],
            liquidity,
            0
        );

        amountOut = tokenOut.getBalanceOf(address(this));
        tokenOut.safeTransfer(recipient, amountOut);
    }

    // function swap(
    //     address tokenIn,
    //     address tokenOut,
    //     uint256 amountIn,
    //     address recipient
    // ) public returns (uint256 amountOut) {
    //     address pool = _path[tokenIn][tokenOut];
    //     require(pool != address(0), "!pool");

    //     tokenIn.safeApprove(pool, amountIn);

    //     ICurvePool(pool).swap(
    //         _pools[pool].isUnderlyingPool,
    //         _tokenIds[pool][tokenIn],
    //         _tokenIds[pool][tokenOut],
    //         amountIn
    //     );

    //     amountOut = tokenOut.getBalanceOf(address(this));
    //     tokenOut.safeTransfer(recipient, amountOut);
    // }

    // function computeAmountOut(
    //     address tokenIn,
    //     address tokenOut,
    //     uint256 amountIn
    // ) external view returns (uint256) {
    //     address pool = _path[tokenIn][tokenOut];
    //     require(pool != address(0), "!pool");

    //     return
    //         ICurvePool(pool).computeAmountOut(
    //             _pools[pool].isUnderlyingPool,
    //             _tokenIds[pool][tokenIn],
    //             _tokenIds[pool][tokenOut],
    //             amountIn
    //         );
    // }

    function setRoutes(address pool, address tokenIn)
        public
        view
        returns (Route[] memory routes)
    {
        address lpToken = _pools[pool].lpToken;

        if (checkPath(tokenIn, lpToken)) {
            // single hop
            routes = new Route[](1);
            routes[0] = Route({
                target: lpToken,
                action: PoolAction.ADD_LIQUIDITY
            });
        } else {
            // multi hops
            address[] memory tokens = getTokens(pool);
            uint256 length = tokens.length;
            uint256 i;

            while (i < length) {
                if (checkPath(tokenIn, tokens[i])) break;

                unchecked {
                    i = i + 1;
                }
            }

            address intermediate = _pools[_path[tokenIn][tokens[i]]].lpToken;

            if (intermediate == address(0)) {
                routes = new Route[](1);
                routes[0] = Route({
                    target: intermediate,
                    action: PoolAction.POOL_NOT_LISTED
                });
            } else {
                routes = new Route[](2);

                if (intermediate != tokens[i]) {
                    // 3 hops
                    routes[0] = Route({
                        target: tokens[i],
                        action: PoolAction.SWAP
                    });
                    routes[1] = Route({
                        target: lpToken,
                        action: PoolAction.ADD_LIQUIDITY
                    });
                } else {
                    // 2 hops
                    routes[0] = Route({
                        target: intermediate,
                        action: PoolAction.ADD_LIQUIDITY
                    });
                    routes[1] = Route({
                        target: lpToken,
                        action: PoolAction.ADD_LIQUIDITY
                    });
                }
            }
        }
    }

    // Curve Pool Config

    function addPool(
        bool isUnderlyingPool,
        uint8 length,
        address pool,
        address lpToken
    ) external onlyGovernance {
        _pools[pool] = CurvePool({
            isUnderlyingPool: isUnderlyingPool,
            len: length,
            pool: pool,
            lpToken: lpToken
        });

        _setTokens(isUnderlyingPool, pool, lpToken, length);
    }

    function removePool(address pool) external onlyGovernance {
        address[] memory tokens = getTokens(pool);
        uint256 length = tokens.length;

        for (uint256 i; i < length; ) {
            delete _tokenIds[pool][tokens[i]];
            delete _path[tokens[i]][_pools[pool].lpToken];

            for (uint256 j; j < length; ) {
                delete _path[tokens[i]][tokens[j]];
                delete _path[tokens[j]][tokens[i]];

                unchecked {
                    j = j + 1;
                }
            }

            unchecked {
                i = i + 1;
            }
        }

        delete _pools[pool];
    }

    function _setTokens(
        bool useUnderlying,
        address pool,
        address lpToken,
        uint256 length
    ) private {
        address[] memory tokens = new address[](length);

        for (uint256 i; i < length; ) {
            address token = useUnderlying
                ? ICurvePool(pool).underlying_coins(i)
                : ICurvePool(pool).coins(i);

            require(token != address(0), "zero address");

            tokens[i] = token;
            _tokens[pool][i] = token;
            _tokenIds[pool][token] = i;

            unchecked {
                i = i + 1;
            }
        }

        setPath(pool, lpToken, tokens);
    }

    function setPath(
        address pool,
        address lpToken,
        address[] memory tokens
    ) public onlyGovernance {
        uint256 length = tokens.length;

        for (uint256 i; i < length; ) {
            _path[tokens[i]][lpToken] = pool;

            for (uint256 j = i + 1; j < length; ) {
                if (_path[tokens[i]][tokens[j]] == address(0)) {
                    _path[tokens[i]][tokens[j]] = pool;
                    _path[tokens[j]][tokens[i]] = pool;
                }

                unchecked {
                    j = j + 1;
                }
            }

            unchecked {
                i = i + 1;
            }
        }
    }

    function checkPath(address src, address dst) public view returns (bool) {
        return _path[src][dst] != address(0);
    }

    function getTokens(address pool)
        public
        view
        returns (address[] memory tokens)
    {
        uint256 length = _pools[pool].len;
        tokens = new address[](length);

        for (uint256 i; i < length; ) {
            tokens[i] = _tokens[pool][i];

            unchecked {
                i = i + 1;
            }
        }
    }

    function getTokenId(address pool, address token)
        external
        view
        returns (uint256)
    {
        return _tokenIds[pool][token];
    }

    function getPool(address pool) external view returns (CurvePool memory) {
        return _pools[pool];
    }
}
