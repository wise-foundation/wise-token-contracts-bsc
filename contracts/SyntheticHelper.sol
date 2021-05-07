// SPDX-License-Identifier: -- 🦉 % 🥞 --

pragma solidity =0.7.5;

import "./Babylonian.sol";
import "./SyntheticInterfaces.sol";

// Syllabus:
    // -- INTERNAL-PURE FUNCTIONS
    // -- INTERNAL-VIEW FUNCTIONS
    // -- INTERNAL-CONSTANT VALUES

abstract contract SyntheticHelper  {

    // -----------------------
    // INTERNAL-PURE FUNCTIONS
    // -----------------------

    function _squareRoot(
        uint256 num
    )
        internal
        pure
        returns (uint256)
    {
        return Babylonian.sqrt(num);
    }

    function _preparePath(
        address _tokenFrom,
        address _tokenTo
    )
        internal
        pure
        returns (address[] memory _path)
    {
        _path = new address[](2);
        _path[0] = _tokenFrom;
        _path[1] = _tokenTo;
    }

    function _getDoubleRoot(
        uint256 _amount
    )
        internal
        pure
        returns (uint256)
    {
        return _squareRoot(_amount) * 2;
    }

    // -----------------------
    // INTERNAL-VIEW FUNCTIONS
    // -----------------------

    function _getBalanceHalf()
        internal
        view
        returns (uint256)
    {
        return address(this).balance / 2;
    }

    function _getBalanceDiff(
        uint256 _amount
    )
        internal
        view
        returns (uint256)
    {
        return
            address(this).balance > _amount ?
            address(this).balance - _amount : 0;
    }

    function _getBalanceOf(
        address _token,
        address _owner
    )
        internal
        view
        returns (uint256)
    {
        IGenericToken token = IGenericToken(
            _token
        );

        return token.balanceOf(
            _owner
        );
    }

    // ------------------------
    // INTERNAL-CONSTANT VALUES
    // ------------------------

    uint256 constant _decimals = 18;
    uint256 constant LIMIT_AMOUNT = 10 ** 50;

    uint256 constant TRADING_FEE = 997500000000;
    uint256 constant TRADING_FEE_QUOTIENT = 1002506265664;

    uint256 constant EQUALIZE_SIZE_VALUE = 100000000;
    uint256 constant ARBITRAGE_CONDITION = 1000001;
    uint256 constant TRADING_FEE_CONDITION = 100000001;
    uint256 constant LIQUIDITY_PERCENTAGE_CORRECTION = 995000;

    uint256 constant PRECISION_POINTS = 1000000;
    uint256 constant PRECISION_POINTS_POWER2 = PRECISION_POINTS * PRECISION_POINTS;
    uint256 constant PRECISION_POINTS_POWER3 = PRECISION_POINTS_POWER2 * PRECISION_POINTS;
    uint256 constant PRECISION_POINTS_POWER4 = PRECISION_POINTS_POWER3 * PRECISION_POINTS;
    uint256 constant PRECISION_POINTS_POWER5 = PRECISION_POINTS_POWER4 * PRECISION_POINTS;

    uint256 constant PRECISION_DIFF = PRECISION_POINTS_POWER2 - TRADING_FEE;
    uint256 constant PRECISION_PROD = PRECISION_POINTS_POWER2 * TRADING_FEE;

    uint256 constant PRECISION_FEES_PROD = TRADING_FEE_QUOTIENT * LIQUIDITY_PERCENTAGE_CORRECTION;
}
