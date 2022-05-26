// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract CISToken is ERC20Capped, Ownable {
    using SafeMath for uint256;

    address public vestingAddress;

    modifier onlyVesting {
        require(msg.sender == vestingAddress);
        _;
    }

    /*
        INITIAL SUPPLY:
            ICO TOKENS: 137,327,459 + 46,664,000 = 183,991,459
            INCLUDES 1ST YEAR-ON-YEAR VESTING

        TOTAL SUPPLY CAP: 1,397,255,459
    */
    constructor(uint256 _initialSupply) ERC20("CIS", "CIS") ERC20Capped(1397255459 * 10 ** decimals()) {
        _mint(msg.sender, _initialSupply);
    }

    // Will be set at the time of deployment
    function decimals() public pure override returns (uint8) {
        return 9;
    }

    function mint(address _account, uint256 _amount) public onlyVesting {
        _mint(_account, _amount);
    }

    function burn(address _account, uint256 _amount) public onlyOwner {
        _burn(_account, _amount);
    }
}
