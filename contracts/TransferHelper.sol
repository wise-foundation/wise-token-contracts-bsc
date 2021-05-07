// SPDX-License-Identifier: -- 🦉 % 🥞 --

pragma solidity =0.7.5;

interface ITransferToken {
    function transfer(
        address recipient,
        uint256 amount
    )
        external
        returns (bool);
}

contract TransferHelper {

    address transferInvoker;

    constructor(address _transferInvoker) {
        transferInvoker = _transferInvoker;
    }

    modifier onlyTransferInvoker() {
        require(
            transferInvoker == msg.sender,
            'TransferHelper: wrong sender'
        );
        _;
    }

    function forwardFunds(
        address _tokenAddress,
        uint256 _forwardAmount
    )
        external
        onlyTransferInvoker
        returns (bool)
    {
        ITransferToken token = ITransferToken(
            _tokenAddress
        );

        return token.transfer(
            transferInvoker,
            _forwardAmount
        );
    }

    function getTransferInvokerAddress()
        public
        view
        returns (address)
    {
        return transferInvoker;
    }
}
