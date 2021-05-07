// SPDX-License-Identifier: -- 🦉 % 🥞 --

pragma solidity =0.7.5;

import "./LiquidityToken.sol";

contract WiseToken is LiquidityToken {

    address public LIQUIDITY_TRANSFORMER;
    address public transformerGateKeeper;

    constructor(
        address _syntheticBNBAddress
    ) BEP20(
        "Wise Token",
        "WISB"
    )
        payable
    {
        SBNB = ISyntheticBNB(
            _syntheticBNBAddress
        );

        transformerGateKeeper = msg.sender;
    }

    modifier onlyKeeper() {
        require(
            transformerGateKeeper == msg.sender
        );
        _;
    }

    receive() external payable {
        revert();
    }

    function setLiquidityTransfomer(
        address _immutableTransformer
    )
        external
        onlyKeeper
    {
        LIQUIDITY_TRANSFORMER =
        _immutableTransformer;
    }

    function setBUSD(
        address _equalizerAddress
    )
        external
        onlyKeeper
    {
        BUSD_EQ = IBUSDEquivalent(
            _equalizerAddress
        );
    }

    function renounceKeeper()
        external
        onlyKeeper
    {
        transformerGateKeeper = address(0x0);
    }

    /**
     * @notice allows liquidityTransformer to mint supply
     * @dev executed from liquidityTransformer upon PANCAKESWAP transfer
     * and during reservation payout to contributors and referrers
     * @param _investorAddress address for minting WISE tokens
     * @param _amount of tokens to mint for _investorAddress
     */
    function mintSupply(
        address _investorAddress,
        uint256 _amount
    )
        external
    {
        require(
            msg.sender == LIQUIDITY_TRANSFORMER
        );

        _mint(
            _investorAddress,
            _amount
        );
    }

    /**
     * @notice allows to create stake directly with BNB
     * if you don't have WISE tokens method will wrap
     * your BNB to SBNB and use that amount on PANCAKESWAP
     * returned amount of WISE tokens will be used to stake
     * @param _lockDays amount of days it is locked for.
     * @param _referrer referrer address for +10% bonus
     */
    function createStakeWithBNB(
        uint64 _lockDays,
        address _referrer
    )
        external
        payable
        returns (bytes16, uint256, bytes16 referralID)
    {
        address[] memory path = new address[](3);
            path[0] = WBNB;
            path[1] = address(SBNB);
            path[2] = address(this);

        uint256[] memory amounts =
        PANCAKE_ROUTER.swapExactETHForTokens{
            value: msg.value
        }(
            YODAS_PER_WISE,
            path,
            msg.sender,
            block.timestamp + 2 hours
        );

        return createStake(
            amounts[2],
            _lockDays,
            _referrer
        );
    }

    /**
     * @notice allows to create stake with another token
     * if you don't have WISE tokens method will convert
     * and use amount returned from PANCAKESWAP to open a stake
     * @dev the token must have WBNB pair on PANCAKESWAP
     * @param _tokenAddress any BEP20 token address
     * @param _tokenAmount amount to be converted to WISE
     * @param _lockDays amount of days it is locked for.
     * @param _referrer referrer address for +10% bonus
     */
    function createStakeWithToken(
        address _tokenAddress,
        uint256 _tokenAmount,
        uint64 _lockDays,
        address _referrer
    )
        external
        returns (bytes16, uint256, bytes16 referralID)
    {
        IBEP20Token token = IBEP20Token(
            _tokenAddress
        );

        token.transferFrom(
            msg.sender,
            address(this),
            _tokenAmount
        );

        token.approve(
            address(PANCAKE_ROUTER),
            _tokenAmount
        );

        address[] memory path = new address[](4);
            path[0] = _tokenAddress;
            path[1] = WBNB;
            path[2] = address(SBNB);
            path[3] = address(this);

        uint256[] memory amounts =
        PANCAKE_ROUTER.swapExactTokensForTokens(
            _tokenAmount,
            YODAS_PER_WISE,
            path,
            msg.sender,
            block.timestamp + 2 hours
        );

        return createStake(
            amounts[3],
            _lockDays,
            _referrer
        );
    }

    function getPairAddress()
        external
        view
        returns (address)
    {
        return address(PANCAKE_PAIR);
    }

    function getTotalStaked()
        external
        view
        returns (uint256)
    {
        return globals.totalStaked;
    }

    function getLiquidityTransformer()
        external
        view
        returns (address)
    {
        return LIQUIDITY_TRANSFORMER;
    }

    function getSyntheticTokenAddress()
        external
        view
        returns (address)
    {
        return address(SBNB);
    }

    function extendLTAuction()
        external
    {
        if (_currentWiseDay() == uint64(15)) {
            if (LAUNCH_TIME + 16 days - block.timestamp <= 10 minutes) {
                uint256 newBalance = address(LIQUIDITY_TRANSFORMER).balance;
                if (newBalance - LTBalance >= 10 ether) {
                    LTBalance = newBalance;
                    LAUNCH_TIME = LAUNCH_TIME + 10 minutes;
                }
            }
        }
        if (_currentWiseDay() > uint64(15)) {
            LAUNCH_TIME = 1619395200;
        }
    }
}
