// SPDX-License-Identifier: -- 🦉 % 🥞 --

pragma solidity =0.7.5;

import "./SyntheticToken.sol";

// @title Synthetic-BNB System
// Support: WiseToken (WISE-WISB)
// Purpose: Arbitrage (PANCAKESWAP)

// @co-author Vitally Marinchenko
// @co-author Christoph Krpoun
// @co-author René Hochmuth

// @notice Use this contract to wrap and unwrap from SBNB to BNB
// @dev Entry point with deposit-withdraw functionality WBNB style

// Syllabus:
    // -- INTERNAL-SETTLEMENT FUNCTIONS
    // -- ONLY-TRANSFORMER FUNCTIONS
    // -- ONLY-MASTER FUNCTIONS

contract SBNB is SyntheticToken {

    constructor() BEP20(
        "Synthetic BNB",
        "SBNB"
    )
        payable
    {
        masterAddress = msg.sender;
    }

    modifier onlyMaster() {
        require(
            msg.sender == masterAddress,
            "SBNB: invalid address"
        );
        _;
    }

    modifier onlyTransformer() {
        require(
            msg.sender == WISE_CONTRACT
            .getLiquidityTransformer(),
            'SBNB: invalid call detected'
        );
        _;
    }

    receive()
        external
        payable
    {
        require(
            allowDeposit == true,
            'SBNB: deposit disabled'
        );

        if (bypassEnabled == false) {
            deposit();
        }
    }

    function deposit()
        public
        payable
    {
        require(
            allowDeposit == true,
            'SBNB: invalid deposit'
        );

        uint256 depositAmount = msg.value;

        _cleanUp(
            depositAmount
        );

        _feesDecision();
        _arbitrageDecision();

        _settleSBNB(
            depositAmount
        );

        _updateEvaluation();

        emit Deposit(
            msg.sender,
            depositAmount
        );
    }

    function withdraw(
        uint256 _tokenAmount
    )
        external
    {
        _cleanUp(0);

        _feesDecision();
        _arbitrageDecision();

        _settleBNB(
            _tokenAmount
        );

        _updateEvaluation();

        emit Withdrawal(
            msg.sender,
            _tokenAmount
        );
    }

    // -----------------------------
    // INTERNAL-SETTLEMENT FUNCTIONS
    // -----------------------------

    function _settleBNB(
        uint256 _amountWithdraw
    )
        internal
    {
        (
            uint256 amountWBNB,
            uint256 amountSBNB
        ) =

        _removeLiquidity(
            _getAmountPayout(
                _amountWithdraw
            )
        );

        _unwrap(
            amountWBNB
        );

        msg.sender.transfer(
            amountWBNB
        );

        _burn(
            msg.sender,
            _amountWithdraw
        );

        _burn(
            address(this),
            amountSBNB
        );
    }

    function _settleSBNB(
        uint256 _amountWithdraw
    )
        internal
    {
        _mint(
            msg.sender,
            _amountWithdraw
        );

        _mint(
            address(this),
            LIMIT_AMOUNT
        );

        WBNB.deposit{
            value: _amountWithdraw
        }();

        _addLiquidity(
            _amountWithdraw,
            LIMIT_AMOUNT
        );

        _selfBurn();
    }

    // --------------------------
    // ONLY-TRANSFORMER FUNCTIONS
    // --------------------------

    function liquidityDeposit()
        external
        onlyTransformer
        payable
    {
        require(
            allowDeposit == false,
            'SBNB: invalid deposit'
        );

        _mint(
            msg.sender,
            msg.value
        );

        emit DepositedLiquidity(
            msg.value,
            msg.sender
        );
    }

    function formLiquidity()
        external
        onlyTransformer
        returns (
            uint256 coverAmount
        )
    {
        require(
            allowDeposit == false,
            'SBNB: invalid state'
        );

        allowDeposit = true;
        coverAmount = _getBalanceHalf();

        _mint(
            address(this),
            coverAmount
        );

        _approve(
            address(this),
            address(PANCAKE_ROUTER),
            coverAmount
        );

        WBNB.deposit{
            value: coverAmount
        }();

        WBNB.approve(
            address(PANCAKE_ROUTER),
            coverAmount
        );

        (
            uint256 amountTokenA,
            uint256 amountTokenB,
            uint256 liquidity
        ) =

        PANCAKE_ROUTER.addLiquidity(
            address(WBNB),
            address(this),
            coverAmount,
            coverAmount,
            0,
            0,
            address(this),
            block.timestamp + 2 hours
        );

        emit FormedLiquidity(
            coverAmount,
            amountTokenA,
            amountTokenB,
            liquidity
        );

        uint256 remainingBalance = address(this)
            .balance;

        _profit(
            remainingBalance
        );

        _updateEvaluation();
    }

    // ------------------------
    // ONLY-MASTER FUNCTIONS
    // ------------------------

    function renounceOwnership()
        external
        onlyMaster
    {
        masterAddress = address(0x0);
    }

    function forwardOwnership(
        address payable _newMaster
    )
        external
        onlyMaster
    {
        masterAddress = _newMaster;
    }

    function defineToken(
        address _wiseToken
    )
        external
        onlyMaster
        returns (
            address syntheticBNB
        )
    {
        require(
            tokenDefined == false,
            'defineToken: already defined'
        );

        WISE_CONTRACT = IWiseToken(
            _wiseToken
        );

        syntheticBNB = WISE_CONTRACT
            .getSyntheticTokenAddress();

        require(
            syntheticBNB == address(this),
            'SBNB: invalid WISE_CONTRACT address'
        );

        tokenDefined = true;
    }

    function defineHelper(
        address _transferHelper
    )
        external
        onlyMaster
        returns (
            address transferInvoker
        )
    {
        require(
            helperDefined == false,
            'defineTransferHelper: already defined'
        );

        TRANSFER_HELPER = ITransferHelper(
            _transferHelper
        );

        transferInvoker = TRANSFER_HELPER
            .getTransferInvokerAddress();

        require(
            transferInvoker == address(this),
            'SBNB: invalid TRANSFER_HELPER address'
        );

        helperDefined = true;
    }

    function createPair()
        external
        onlyMaster
    {
        PANCAKE_PAIR = PancakeSwapV2Pair(
            PANCAKE_FACTORY.createPair(
                address(WBNB),
                address(this)
            )
        );
    }
}
