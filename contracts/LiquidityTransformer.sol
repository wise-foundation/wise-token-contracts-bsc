// SPDX-License-Identifier: -- 🦉 % 🥞 --

pragma solidity =0.7.5;

import './LiquidityInterfaces.sol';

contract LiquidityTransformer {

    using SafeMathLT for uint256;
    using SafeMathLT for uint128;

    IWiseTokenLT public WISE_CONTRACT;
    ISyntheticBNBToken public SBNB_CONTRACT;
    PancakeSwapV2PairLT public PANCAKE_PAIR;

    PancakeSwapRouterLT public constant PANCAKE_ROUTER = PancakeSwapRouterLT(
        // 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D // mainnet
        // 0x07d090e7FcBC6AFaA507A3441C7c5eE507C457e6 // testnet bsc
        // 0xc778417E063141139Fce010982780140Aa0cD5Ab // testnet eth
        0x57079e0d0657890218C630DA5248A1103a1b4ad0 // local
    );

    // address constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c; // mainnet
    // address constant WBNB = 0x1e33833a035069f42d68D1F53b341643De1C018D; // testnet bsc
    // address constant WBNB = 0xc778417E063141139Fce010982780140Aa0cD5Ab; // testnet eth (WETH)
    address constant WBNB = 0xEb59fE75AC86dF3997A990EDe100b90DDCf9a826; // local

    uint8 public constant INVESTMENT_DAYS = 15;
    uint128 public constant MAX_SUPPLY = 264000000E18;
    uint128 public constant MAX_INVEST = 200000E18;
    uint128 public constant TOKEN_COST = MAX_INVEST / (MAX_SUPPLY / 1E18);
    uint256 public constant REFUND_CAP = 100E18;

    struct Globals {
        uint256 cashBackTotal;
        uint256 investorCount;
        uint256 totalTransferTokens;
        uint256 totalBNBContributed;
        bool pancakeSwaped;
    }

    Globals public g;

    mapping(address => uint256) public investorBalance;
    mapping(address => uint256) public purchasedTokens;
    mapping(uint256 => address) public uniqueInvestors;

    event WiseReservation(
        address indexed senderAddress,
        uint256 investmentAmount,
        uint256 tokenAmount,
        uint64 indexed currentWiseDay,
        uint8 indexed investmentMode
    );

    event PancakeSwapResult(
        uint256 indexed amountTokenA,
        uint256 indexed amountTokenB,
        uint256 indexed liquidity
    );

    event CashBackIssued(
        address indexed investorAddress,
        uint256 indexed senderValue,
        uint256 indexed cashBackAmount
    );

    event RefundIssued(
        address indexed investorAddress,
        uint256 indexed refundAmount
    );

    modifier afterInvestmentDays() {
        require(
            _currentWiseDay() > INVESTMENT_DAYS,
            'WISE: ongoing investment phase'
        );
        _;
    }

    modifier afterPancakeSwapTransfer() {
        require (
            g.pancakeSwaped == true,
            'WISE: forward liquidity first'
        );
        _;
    }

    modifier belowMaximumInvest() {
        require(
            g.totalTransferTokens < MAX_SUPPLY,
            'reserveWise_MAX_SUPPLY_REACHED'
        );
        _;
    }

    modifier belowMaximumDay() {
        require(
            _currentWiseDay() > 0 &&
            _currentWiseDay() <= INVESTMENT_DAYS,
            'reserveWise_WRONG_INVESTMENT_DAY'
        );
        _;
    }

    modifier onlyKeeper() {
        require(
            msg.sender == settingsKeeper
        );
        _;
    }

    receive() external payable {
    }

    address payable settingsKeeper;

    constructor(
        address _wiseToken,
        address _pancakeSwapPair,
        address _syntheticBNB
    )
        payable
    {
        settingsKeeper = msg.sender;
        WISE_CONTRACT = IWiseTokenLT(_wiseToken);
        SBNB_CONTRACT = ISyntheticBNBToken(_syntheticBNB);
        PANCAKE_PAIR = PancakeSwapV2PairLT(_pancakeSwapPair);
    }

    function setSettings(
        address _wiseToken,
        address _pancakeSwapPair,
        address _syntheticBNB
    )
        external
        onlyKeeper
    {
        WISE_CONTRACT = IWiseTokenLT(_wiseToken);
        SBNB_CONTRACT = ISyntheticBNBToken(_syntheticBNB);
        PANCAKE_PAIR = PancakeSwapV2PairLT(_pancakeSwapPair);
    }

    function renounceKeeper()
        external
        onlyKeeper
    {
        settingsKeeper = address(0x0);
    }

    //  WISE RESERVATION (EXTERNAL FUNCTIONS)  //
    //  -------------------------------------  //

    /** @dev Performs reservation of WISE tokens with BNB
      */
    function reserveWise(
        uint8 _invesmentMode
    )
        external
        payable
        belowMaximumDay
        belowMaximumInvest
    {
        require(
            msg.value >= TOKEN_COST,
            'reserveWise_MIN_INVEST'
        );

        _reserveWise(
            msg.sender,
            msg.value,
            _invesmentMode
        );
    }

    /** @notice Allows reservation of WISE tokens with other BEP20 tokens
      * @dev this will require LT contract to be approved as spender
      * @param _tokenAddress address of an BEP20 token to use
      * @param _tokenAmount amount of tokens to use for reservation
      */
    function reserveWiseWithToken(
        address _tokenAddress,
        uint256 _tokenAmount,
        uint8 _invesmentMode
    )
        external
        belowMaximumDay
        belowMaximumInvest
    {
        IBEP20TokenLT _token = IBEP20TokenLT(
            _tokenAddress
        );

        _token.transferFrom(
            msg.sender,
            address(this),
            _tokenAmount
        );

        _token.approve(
            address(PANCAKE_ROUTER),
            _tokenAmount
        );

        address[] memory _path = preparePath(
            _tokenAddress
        );

        uint256[] memory amounts =
        PANCAKE_ROUTER.swapExactTokensForETH(
            _tokenAmount,
            0,
            _path,
            address(this),
            block.timestamp.add(2 hours)
        );

        require(
            amounts[1] >= TOKEN_COST,
            'WISE: investment below minimum'
        );

        _reserveWise(
            msg.sender,
            amounts[1],
            _invesmentMode
        );
    }

    //  WISE RESERVATION (INTERNAL FUNCTIONS)  //
    //  -------------------------------------  //

    function _reserveWise(
        address _senderAddress,
        uint256 _senderValue,
        uint8 _invesmentMode
    )
        internal
    {
        require(
            _invesmentMode < 6,
            'reserveWise_WRONG_MODE'
        );

        if (investorBalance[_senderAddress] == 0) {
            uniqueInvestors[
            g.investorCount] = _senderAddress;
            g.investorCount++;
        }

        (
            uint256 _senderTokens,
            uint256 _returnAmount
        ) =

        _getTokenAmount(
            g.totalBNBContributed,
            g.totalTransferTokens,
            _senderValue
        );

        g.totalBNBContributed += _senderValue;
        g.totalTransferTokens += _senderTokens;

        investorBalance[_senderAddress] += _senderValue;
        purchasedTokens[_senderAddress] += _senderTokens;

        if (
            _invesmentMode == 0 &&
            g.cashBackTotal < REFUND_CAP &&
            _returnAmount < _senderValue
        ) {
            uint256 cashBackAmount = _senderValue
                .sub(_returnAmount)
                .div(100);

            uint256 CASH_BACK = g.cashBackTotal
                .add(cashBackAmount);

            cashBackAmount = CASH_BACK < REFUND_CAP
                ? cashBackAmount
                : REFUND_CAP.sub(g.cashBackTotal);

            g.cashBackTotal =
            g.cashBackTotal.add(cashBackAmount);

            msg.sender.transfer(
                cashBackAmount
            );

            emit CashBackIssued(
                _senderAddress,
                _senderValue,
                cashBackAmount
            );
        }

        if (_returnAmount > 0) {
            msg.sender.transfer(
                _returnAmount
            );

            emit RefundIssued(
                msg.sender,
                _returnAmount
            );
        }

        emit WiseReservation(
            _senderAddress,
            _senderValue,
            _senderTokens,
            _currentWiseDay(),
            _invesmentMode
        );
    }

    function _getTokenAmount(
        uint256 _totalBNBContributed,
        uint256 _totalTransferTokens,
        uint256 _senderValue
    )
        private
        pure
        returns (
            uint256 tokenAmount,
            uint256 returnAmount
        )
    {
        tokenAmount = _senderValue
            .div(TOKEN_COST)
            .mul(1E18);

        uint256 NEW_SUPPLY = _totalTransferTokens
            .add(tokenAmount);

        if (NEW_SUPPLY > MAX_SUPPLY) {

            tokenAmount = MAX_SUPPLY
                .sub(_totalTransferTokens);

            uint256 availableValue = MAX_INVEST
                .sub(_totalBNBContributed);

            returnAmount = _senderValue
                .sub(availableValue);
        }
    }

    //  LIQUIDITY GENERATION FUNCTION  //
    //  -----------------------------  //

    /** @notice Creates initial liquidity on PancakeSwap by forwarding
      * reserved tokens equivalent to BNB contributed to the contract
      * @dev check addLiquidity documentation
      */
    function forwardLiquidity(/*🥞*/)
        external
        afterInvestmentDays
    {
        require (
            g.pancakeSwaped == false,
            'forwardLiquidity: swaped'
        );

        uint256 sbnbTokensAmount = g.totalBNBContributed;
        uint256 wiseTokensAmount = g.totalTransferTokens;

        SBNB_CONTRACT.liquidityDeposit{
            value: g.totalBNBContributed
        }();

        SBNB_CONTRACT.formLiquidity();

        SBNB_CONTRACT.approve(
            address(PANCAKE_ROUTER),
            sbnbTokensAmount
        );

        WISE_CONTRACT.mintSupply(
            address(this),
            wiseTokensAmount
        );

        WISE_CONTRACT.approve(
            address(PANCAKE_ROUTER),
            wiseTokensAmount
        );

        (
            uint256 amountTokenA,
            uint256 amountTokenB,
            uint256 liquidity
        ) =

        PANCAKE_ROUTER.addLiquidity(
            address(WISE_CONTRACT),
            address(SBNB_CONTRACT),
            wiseTokensAmount,
            sbnbTokensAmount,
            0,
            0,
            address(0x0),
            block.timestamp.add(2 hours)
        );

        g.pancakeSwaped = true;

        emit PancakeSwapResult(
            amountTokenA,
            amountTokenB,
            liquidity
        );
    }

    //  WISE TOKEN PAYOUT FUNCTIONS (INDIVIDUAL)  //
    //  ----------------------------------------  //

    /** @notice Allows to mint all the tokens
      * from investor and referrer perspectives
      * @dev can be called after forwardLiquidity()
      */
    function $getMyTokens(/*💰*/)
        external
        afterPancakeSwapTransfer
    {
        payoutInvestorAddress(
            msg.sender
        );
    }

    /** @notice Allows to mint tokens for specific investor address
      * @dev aggregades investors tokens across all investment days
      * and uses WISE_CONTRACT instance to mint all the WISE tokens
      * @param _investorAddress requested investor calculation address
      * @return _payout amount minted to the investors address
      */
    function payoutInvestorAddress(
        address _investorAddress
    )
        public
        afterPancakeSwapTransfer
        returns (
            uint256 _payout
        )
    {
        _payout =
        purchasedTokens[_investorAddress];
        purchasedTokens[_investorAddress] = 0;

        if (_payout > 0) {
            WISE_CONTRACT.mintSupply(
                _investorAddress,
                _payout
            );
        }
    }

    //  HELPER FUNCTIONS (PURE)  //
    //  -----------------------  //

    /** @notice prepares path variable for pancakeswap to exchange tokens
      * @dev used in reserveWiseWithToken() swapExactTokensForTokens call
      * @param _tokenAddress BEP20 token address to be swapped for BNB
      * @return _path that is used to swap tokens for BNB on pancakeswap
      */
    function preparePath(
        address _tokenAddress
    )
        internal
        pure
        returns (
            address[] memory _path
        )
    {
        _path = new address[](2);
        _path[0] = _tokenAddress;
        _path[1] = WBNB;
    }

    //  TIMING FUNCTIONS  //
    //  ----------------  //

    /** @notice shows current day of WiseToken
      * @dev value is fetched from WISE_CONTRACT
      * @return iteration day since WISE inception
      */
    function _currentWiseDay()
        public
        view
        returns (uint64)
    {
        return WISE_CONTRACT.currentWiseDay();
    }

    //  EMERGENCY REFUND FUNCTIONS  //
    //  --------------------------  //

    /** @notice allows refunds if funds are stuck
      */
    function requestRefund()
        external
        returns (
            uint256 amount,
            uint256 tokens
        )
    {
        require(
            g.pancakeSwaped == false  &&
            investorBalance[msg.sender] > 0 &&
            purchasedTokens[msg.sender] > 0 &&
            _currentWiseDay() > INVESTMENT_DAYS + 10,
           unicode'WISE: refund not possible 🥞'
        );

        amount =
        investorBalance[msg.sender];
        investorBalance[msg.sender] = 0;

        tokens =
        purchasedTokens[msg.sender];
        purchasedTokens[msg.sender] = 0;

        g.totalTransferTokens =
        g.totalTransferTokens.sub(
            tokens
        );

        if (amount > 0) {
            msg.sender.transfer(
                amount
            );

            emit RefundIssued(
                msg.sender,
                amount
            );
        }
    }
}

library SafeMathLT {

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, 'WISE: addition overflow');
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, 'WISE: subtraction overflow');
        uint256 c = a - b;
        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {

        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, 'WISE: multiplication overflow');

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, 'WISE: division by zero');
        uint256 c = a / b;
        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, 'WISE: modulo by zero');
        return a % b;
    }
}
