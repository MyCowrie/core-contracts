// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract CISToken is ERC20, Ownable {
    using SafeMath for uint256;

    address public vestingAddress;

    modifier onlyVesting {
        require(msg.sender == vestingAddress);
        _;
    }

    constructor(uint256 _initialSupply) ERC20("CIS", "CIS") {
        _mint(msg.sender, _initialSupply);
    }

    function decimals() public pure override returns (uint8) {
        return 9;
    }

    function mint(address _account, uint256 _amount) public onlyVesting {
        _mint(_account, _amount);
    }

    function mintOnlyOwner(address _account, uint256 _amount) public onlyOwner {
        _mint(_account, _amount);
    }

    function burn(address _account, uint256 _amount) public onlyOwner {
        _burn(_account, _amount);
    }

    function setVestingAddress(address _address) public onlyOwner {
        vestingAddress = _address;
    }
}
