// SPDX-License-Identifier: -- 🦉 % 🥞 --

pragma solidity =0.7.5;

interface IPancakeSwapRouterV2 {

    function getAmountsOut(
        uint amountIn,
        address[] calldata path
    ) external view returns (
        uint[] memory amounts
    );
}

contract BUSDEquivalent {

    uint256 constant _decimals = 18;
    uint256 constant YODAS_PER_WISE = 10 ** _decimals;

    address public constant WISE = 0x843B0D4316A042F177db7B2319CACd1a4fE2f055;
    address public constant SBNB = 0x1C22dBB53104f3CaCb05e18F2D9ce4E75DC45885;
    address public constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address public constant BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;

    IPancakeSwapRouterV2 public constant PANCAKE_ROUTER = IPancakeSwapRouterV2(
        0x10ED43C718714eb63d5aA57B78B54704E256024E
    );

    uint256 public latestBUSDEquivalent;
    address[] public _path = [WISE, SBNB, WBNB, BUSD];

    function updateBUSDEquivalent()
        external
    {
       latestBUSDEquivalent = _getBUSDEquivalent();
    }

    function getBUSDEquivalent()
        external
        view
        returns (uint256)
    {
        return _getBUSDEquivalent();
    }

    function _getBUSDEquivalent()
        internal
        view
        returns (uint256)
    {
        try PANCAKE_ROUTER.getAmountsOut(
            YODAS_PER_WISE, _path
        ) returns (uint256[] memory results) {
            return results[3];
        } catch Error(string memory) {
            return latestBUSDEquivalent;
        } catch (bytes memory) {
            return latestBUSDEquivalent;
        }
    }
}
