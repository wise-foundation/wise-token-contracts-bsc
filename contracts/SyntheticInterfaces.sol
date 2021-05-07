// SPDX-License-Identifier: -- 🦉 % 🥞 --

pragma solidity =0.7.5;

interface IGenericToken {
    function balanceOf(
        address account
    )
        external
        view
        returns (uint256);
}

interface IWiseToken {

    function getLiquidityTransformer()
        external
        view
        returns(address);

    function getSyntheticTokenAddress()
        external
        pure
        returns (address);
}

interface PancakeSwapRouterV2 {

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (
        uint256 amountTokenA,
        uint256 amountTokenB,
        uint256 liquidity
    );

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (
        uint256 amountA,
        uint256 amountB
    );

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (
        uint[] memory amounts
    );

}

interface PancakeSwapV2Factory {

    function createPair(
        address tokenA,
        address tokenB
    ) external returns (
        address pair
    );
}

interface PancakeSwapV2Pair {

    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );

    function totalSupply()
        external
        view
        returns (uint);

    function skim(
        address to
    )
        external;

    function approve(
        address _spender,
        uint256 _value
    )  external returns (
        bool success
    );
}

interface IWrappedBNB {

    function approve(
        address _spender,
        uint256 _value
    )  external returns (
        bool success
    );

    function withdraw(
        uint256 _amount
    )
        external;

    function deposit()
        external
        payable;
}

interface ITransferHelper {

    function forwardFunds(
        address _tokenAddress,
        uint256 _forwardAmount
    )
        external
        returns (bool);

    function getTransferInvokerAddress()
        external
        view
        returns (address);
}
