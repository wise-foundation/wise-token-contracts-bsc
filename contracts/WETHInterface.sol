pragma solidity ^0.7.0;

contract WETHInterface {
    string public name = "Wrapped Ether";
    string public symbol = "WETH";
    uint8  public decimals = 18;

    receive() external payable { deposit(); }

    mapping (address => uint) public  balanceOf;
    mapping (address => mapping (address => uint)) public allowance;

    function deposit() public payable {}

    function withdraw(uint wad) public {}

    function totalSupply() public view returns (uint) {}

    function approve(address guy, uint wad) public returns (bool) {}

    function transfer(address dst, uint wad) public returns (bool) {}

    function transferFrom(address src, address dst, uint wad) public returns (bool) {}
}
