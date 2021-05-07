// SPDX-License-Identifier: -- 🦉 % 🥞 --

pragma solidity =0.7.5;

interface IWiseTokenLT {

    function currentWiseDay()
        external view
        returns (uint64);

    function approve(
        address _spender,
        uint256 _value
    ) external returns (bool success);

    function mintSupply(
        address _investorAddress,
        uint256 _amount
    ) external;

    function giveStatus(
        address _referrer
    ) external;
}

interface ISyntheticBNBToken {

    function approve(
        address _spender,
        uint256 _value
    )
        external
        returns (bool success);

    function liquidityDeposit()
        external
        payable;

    function formLiquidity()
        external
        returns (uint256 coverAmount);
}

interface PancakeSwapRouterLT {

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

    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) external pure returns (
        uint256 amountB
    );

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (
        uint256[] memory amounts
    );
}

interface PancakeSwapV2PairLT {

    function getReserves() external view returns (
        uint112 reserve0,
        uint112 reserve1,
        uint32 blockTimestampLast
    );

    function token1() external view returns (address);
}

interface IBEP20TokenLT {

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    )  external returns (
        bool success
    );

    function approve(
        address _spender,
        uint256 _value
    )  external returns (
        bool success
    );
}