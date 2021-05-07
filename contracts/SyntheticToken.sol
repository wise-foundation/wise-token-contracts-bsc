// SPDX-License-Identifier: -- 🦉 % 🥞 --

pragma solidity =0.7.5;

import "./BEP20.sol";
import "./SyntheticHelper.sol";
import "./SyntheticEvents.sol";

// @notice Use this contract for data views available
// @dev main functionality for arbitrage and fees colletion

// Syllabus:
    // -- EXTERNAL-VIEW FUNCTIONS
    // -- INTERNAL-FEES FUNCTIONS
    // -- INTERNAL-LIQUIDITY FUNCTIONS
    // -- INTERNAL-VIEW FUNCTIONS
    // -- INTERNAL-ARBITRAGE FUNCTIONS
    // -- INTERNAL-SUPPORT FUNCTIONS

abstract contract SyntheticToken is BEP20, SyntheticHelper, SyntheticEvents  {

    using SafeMath for uint256;

    address payable public masterAddress;
    uint256 public currentEvaluation;

    IWiseToken public WISE_CONTRACT;
    ITransferHelper public TRANSFER_HELPER;

    bool public tokenDefined;
    bool public allowDeposit;
    bool public helperDefined;
    bool public bypassEnabled;

    PancakeSwapRouterV2 public constant PANCAKE_ROUTER = PancakeSwapRouterV2(
        0x10ED43C718714eb63d5aA57B78B54704E256024E
    );

    PancakeSwapV2Factory public constant PANCAKE_FACTORY = PancakeSwapV2Factory(
        0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73
    );

    PancakeSwapV2Pair public PANCAKE_PAIR;

    IWrappedBNB public constant WBNB = IWrappedBNB(
        0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c
    );

    // -----------------------
    // EXTERNAL-VIEW FUNCTIONS
    // -----------------------

    function getTradingFeeAmount(
        uint256 _previousEvaluation,
        uint256 _currentEvaluation
    )
        external
        view
        returns (uint256)
    {
        return _getTradingFeeAmount(
            _previousEvaluation,
            _currentEvaluation
        );
    }

    function getAmountPayout(
        uint256 _amount
    )
        external
        view
        returns (uint256)
    {
        return _getAmountPayout(_amount);
    }

    function getWrappedBalance()
        external
        view
        returns (uint256)
    {
        return _getWrappedBalance();
    }

    function getSyntheticBalance()
        external
        view
        returns (uint256)
    {
        return _getSyntheticBalance();
    }

    function getPairBalances()
        external
        view
        returns (
            uint256 wrappedBalance,
            uint256 syntheticBalance
        )
    {
        wrappedBalance = _getWrappedBalance();
        syntheticBalance = _getSyntheticBalance();
    }

    function getEvaluation()
        external
        view
        returns (uint256)
    {
        return _getEvaluation();
    }

    function getLpTokenBalance()
        external
        view
        returns (uint256)
    {
      return _getLpTokenBalance();
    }

    function getLiquidityPercent()
        external
        view
        returns (uint256)
    {
        return _getLiquidityPercent();
    }

    // -----------------------
    // INTERNAL-FEES FUNCTIONS
    // -----------------------

    function _feesDecision()
        internal
    {
        uint256 previousEvaluation = currentEvaluation;
        uint256 newEvaluation = _getEvaluation();

        uint256 previousCondition = previousEvaluation
            .mul(TRADING_FEE_CONDITION);

        uint256 newCondition = newEvaluation
            .mul(EQUALIZE_SIZE_VALUE);

        if (newCondition > previousCondition) {
            _extractAndSendFees(
                previousEvaluation,
                newEvaluation
            );
        }
    }

    function _extractAndSendFees(
        uint256 _previousEvaluation,
        uint256 _currentEvaluation
    )
        internal
    {
        (
            uint256 amountWBNB,
            uint256 amountSBNB
        ) =

        _removeLiquidity(
            _getTradingFeeAmount(
                _previousEvaluation,
                _currentEvaluation
            )
        );

        emit LiquidityRemoved(
            amountWBNB,
            amountSBNB
        );

        _unwrap(
            amountWBNB
        );

        _profit(
            amountWBNB
        );

        _burn(
            address(this),
            amountSBNB
        );

        emit SendFeesToMaster(
            amountWBNB,
            masterAddress
        );
    }

    // ----------------------------
    // INTERNAL-LIQUIDITY FUNCTIONS
    // ----------------------------

    function _swapExactTokensForTokens(
        uint256 _amount,
        uint256 _amountOutMin,
        address _fromTokenAddress,
        address _toTokenAddress
    )
        internal
        returns (uint256)
    {
        return PANCAKE_ROUTER.swapExactTokensForTokens(
            _amount,
            _amountOutMin,
            _preparePath(
                _fromTokenAddress,
                _toTokenAddress
            ),
            address(TRANSFER_HELPER),
            block.timestamp + 2 hours
        )[1];
    }

    function _addLiquidity(
        uint256 _amountWBNB,
        uint256 _amountSBNB
    )
        internal
        returns (uint256, uint256)
    {
        WBNB.approve(
            address(PANCAKE_ROUTER),
            _amountWBNB
        );

        _approve(
            address(this),
            address(PANCAKE_ROUTER),
            _amountSBNB
        );

        (
            uint256 amountWBNB,
            uint256 amountSBNB,
            uint256 liquidity
        ) =

        PANCAKE_ROUTER.addLiquidity(
            address(WBNB),
            address(this),
            _amountWBNB,
            _amountSBNB,
            0,
            0,
            address(this),
            block.timestamp + 2 hours
        );

        emit LiquidityAdded(
            amountWBNB,
            amountSBNB,
            liquidity
        );

        return (amountWBNB, amountSBNB);
    }

    function _removeLiquidity(
        uint256 _amount
    )
        internal
        returns (uint256, uint256)
    {
        PANCAKE_PAIR.approve(
            address(PANCAKE_ROUTER),
            _amount
        );

        (
            uint256 amountWBNB,
            uint256 amountSBNB
        ) =

        PANCAKE_ROUTER.removeLiquidity(
            address(WBNB),
            address(this),
            _amount,
            0,
            0,
            address(this),
            block.timestamp + 2 hours
        );

        return (amountWBNB, amountSBNB);
    }

    // -----------------------
    // INTERNAL-VIEW FUNCTIONS
    // -----------------------

    function _getTradingFeeAmount(
        uint256 _previousEvaluation,
        uint256 _currentEvaluation
    )
        internal
        view
        returns (uint256)
    {
        uint256 ratioAmount = _previousEvaluation
            .mul(PRECISION_POINTS_POWER4)
            .div(_currentEvaluation);

        uint256 rezipientAmount = _getSyntheticBalance()
            .mul(PRECISION_POINTS_POWER2)
            .div(_getWrappedBalance());

        uint256 difference = PRECISION_POINTS_POWER2
            .sub(_squareRoot(ratioAmount))
            .mul(_squareRoot(rezipientAmount))
            .mul(_getLpTokenBalance())
            .div(_getLiquidityPercent());

        return difference
            .div(PRECISION_POINTS);
    }

    function _getAmountPayout(
        uint256 _amount
    )
        internal
        view
        returns (uint256)
    {
        uint256 product = _amount
            .mul(_getLiquidityPercent())
            .mul(PRECISION_POINTS);

        uint256 quotient = product
            .mul(_getLpTokenBalance())
            .div(_getWrappedBalance());

        return quotient
            .div(PRECISION_POINTS_POWER3);
    }

    function _getWrappedBalance()
        internal
        view
        returns (uint256)
    {
        return _getBalanceOf(
            address(WBNB),
            address(PANCAKE_PAIR)
        );
    }

    function _getSyntheticBalance()
        internal
        view
        returns (uint256)
    {
        return _getBalanceOf(
            address(this),
            address(PANCAKE_PAIR)
        );
    }

    function _getEvaluation()
        internal
        view
        returns (uint256)
    {
        uint256 liquidityPercent = _getLiquidityPercent();
        uint256 liquidityPercentSquared = liquidityPercent
            .mul(liquidityPercent);

        return _getWrappedBalance()
            .mul(PRECISION_POINTS_POWER4)
            .mul(_getSyntheticBalance())
            .div(liquidityPercentSquared);
    }

    function _profitArbitrageRemove()
        internal
        view
        returns (uint256)
    {
        uint256 wrappedBalance = _getWrappedBalance();
        uint256 syntheticBalance = _getSyntheticBalance();

        uint256 product = wrappedBalance
            .mul(syntheticBalance);

        uint256 difference = wrappedBalance
            .add(syntheticBalance)
            .sub(_getDoubleRoot(product))
            .mul(_getLpTokenBalance());

        return difference
            .mul(_getLiquidityPercent())
            .div(wrappedBalance)
            .mul(LIQUIDITY_PERCENTAGE_CORRECTION)
            .div(PRECISION_POINTS_POWER3);
    }

    function _toRemoveBNB()
        internal
        view
        returns (uint256)
    {
        uint256 wrappedBalance = _getWrappedBalance();

        uint256 productA = _squareRoot(wrappedBalance)
            .mul(PRECISION_DIFF);

        uint256 productB = _getSyntheticBalance()
            .mul(PRECISION_POINTS_POWER4);

        uint256 difference = _squareRoot(productB)
            .sub(productA);

        uint256 quotient = _squareRoot(wrappedBalance)
            .mul(PRECISION_PROD)
            .div(difference);

        return PRECISION_POINTS_POWER2
            .sub(quotient)
            .mul(_getLiquidityPercent())
            .mul(_getLpTokenBalance())
            .mul(LIQUIDITY_PERCENTAGE_CORRECTION)
            .div(PRECISION_POINTS_POWER5);
    }

    function _getLpTokenBalance()
        internal
        view
        returns (uint256)
    {
        return _getBalanceOf(
                address(PANCAKE_PAIR),
                address(address(this)
            )
        );
    }

    function _getLiquidityPercent()
        internal
        view
        returns (uint256)
    {
        return PANCAKE_PAIR.totalSupply()
            .mul(PRECISION_POINTS_POWER2)
            .div(_getLpTokenBalance());
    }

    function _swapAmountArbitrageSBNB()
        internal
        view
        returns (uint256)
    {
        uint256 product = _getSyntheticBalance()
            .mul(_getWrappedBalance());

        uint256 difference = _squareRoot(product)
            .sub(_getSyntheticBalance());

        return difference
            .mul(PRECISION_FEES_PROD)
            .div(PRECISION_POINTS_POWER3);
    }

    // ----------------------------
    // INTERNAL-ARBITRAGE FUNCTIONS
    // ----------------------------

    function _arbitrageDecision()
        internal
    {
        uint256 wrappedBalance = _getWrappedBalance();
        uint256 syntheticBalance = _getSyntheticBalance();

        if (wrappedBalance < syntheticBalance) _arbitrageBNB(
            wrappedBalance, syntheticBalance
        );

        if (wrappedBalance > syntheticBalance) _arbitrageSBNB(
            wrappedBalance, syntheticBalance
        );
    }

    function _arbitrageSBNB(
        uint256 _wrappedBalance,
        uint256 _syntheticBalance
    )
        internal
    {
        uint256 conditionWBNB = _wrappedBalance
            .mul(PRECISION_POINTS);

        uint256 conditionSBNB = _syntheticBalance
            .mul(ARBITRAGE_CONDITION);

        if (conditionWBNB <= conditionSBNB) return;

        (
            uint256 amountWBNB,
            uint256 amountSBNB
        ) =

        _removeLiquidity(
            _profitArbitrageRemove()
        );

        emit LiquidityRemoved(
            amountWBNB,
            amountSBNB
        );

        _unwrap(
            amountWBNB
        );

        _profit(
            amountWBNB
        );

        _mint(
            address(this),
            LIMIT_AMOUNT
        );

        uint256 swapAmount = _swapAmountArbitrageSBNB();

        _approve(
            address(this),
            address(PANCAKE_ROUTER),
            swapAmount
        );

        WBNB.approve(
            address(PANCAKE_ROUTER),
            swapAmount
        );

        uint256 amountOutReceivedWBNB =

        _swapExactTokensForTokens(
            swapAmount,
            0,
            address(this),
            address(WBNB)
        );

        TRANSFER_HELPER.forwardFunds(
            address(WBNB),
            amountOutReceivedWBNB
        );

        _addLiquidity(
            amountOutReceivedWBNB,
            _getBalanceOf(
                address(this),
                address(this)
            )
        );

        _selfBurn();

        emit SendArbitrageProfitToMaster(
            amountWBNB,
            masterAddress
        );
    }

    function _arbitrageBNB(
        uint256 _wrappedBalance,
        uint256 _syntheticBalance
    )
        internal
    {
        uint256 conditionWBNB = _wrappedBalance
            .mul(ARBITRAGE_CONDITION);

        uint256 conditionSBNB = _syntheticBalance
            .mul(PRECISION_POINTS);

        if (conditionWBNB >= conditionSBNB) return;

        (
            uint256 amountWBNB,
            uint256 amountSBNB
        ) =

        _removeLiquidity(
            _profitArbitrageRemove()
        );

        emit LiquidityRemoved(
            amountWBNB,
            amountSBNB
        );

        _unwrap(
            amountWBNB
        );

        _profit(
            amountWBNB
        );

        (
            amountWBNB,
            amountSBNB
        ) =

        _removeLiquidity(
            _toRemoveBNB()
        );

        emit LiquidityRemoved(
            amountWBNB,
            amountSBNB
        );

         _approve(
            address(this),
            address(PANCAKE_ROUTER),
            LIMIT_AMOUNT
        );

        WBNB.approve(
            address(PANCAKE_ROUTER),
            amountWBNB
        );

        uint256 amountOutReceivedSBNB =

        _swapExactTokensForTokens(
            amountWBNB,
            0,
            address(WBNB),
            address(this)
        );

        TRANSFER_HELPER.forwardFunds(
            address(this),
            amountOutReceivedSBNB
        );

        _selfBurn();

        emit SendArbitrageProfitToMaster(
            amountWBNB,
            masterAddress
        );
    }

    // ----------------------------
    // INTERNAL-SUPPORT FUNCTIONS
    // ----------------------------

    function _selfBurn()
        internal
    {
        _burn(
            address(this),
            _getBalanceOf(
                address(this),
                address(this)
            )
        );
    }

    function _cleanUp(
        uint256 _depositAmount
    )
        internal
    {
        _skimPair();

        _selfBurn();

        _profit(
            _getBalanceDiff(
                _depositAmount
            )
        );
    }

    function _unwrap(
        uint256 _amountWBNB
    )
        internal
    {
        bypassEnabled = true;

        WBNB.withdraw(
            _amountWBNB
        );

        bypassEnabled = false;
    }

    function _profit(
        uint256 _amountWBNB
    )
        internal
    {
        masterAddress.transfer(
            _amountWBNB
        );

        emit MasterProfit(
            _amountWBNB,
            masterAddress
        );
    }

    function _updateEvaluation()
        internal
    {
        currentEvaluation = _getEvaluation();
    }

    function _skimPair()
        internal
    {
        PANCAKE_PAIR.skim(
            masterAddress
        );
    }
}
