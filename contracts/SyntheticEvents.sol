// SPDX-License-Identifier: -- 🦉 % 🥞 --

pragma solidity =0.7.5;

abstract contract SyntheticEvents  {

    event Deposit(
        address indexed fromAddress,
        uint256 indexed tokenAmount
    );

    event Withdrawal(
        address indexed fromAddress,
        uint256 indexed tokenAmount
    );

    event DepositedLiquidity(
        uint256 indexed depositAmount,
        address indexed transformerAddress
    );

    event FormedLiquidity(
        uint256 coverAmount,
        uint256 amountTokenA,
        uint256 amountTokenB,
        uint256 liquidity
    );

    event MasterTransfer(
        address indexed masterAddress,
        uint256 indexed transferBalance
    );

    event LiquidityAdded(
        uint256 amountTokenA,
        uint256 amountTokenB,
        uint256 liquidity
    );

    event LiquidityRemoved(
        uint256 amountTokenA,
        uint256 amountTokenB
    );

    event SendFeesToMaster(
        uint256 sendAmount,
        address indexed receiver
    );

    event SendArbitrageProfitToMaster(
        uint256 sendAmount,
        address indexed receiver
    );

    event MasterProfit(
        uint256 amount,
        address indexed receiver
    );
}
