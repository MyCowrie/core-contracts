// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Token is ERC20Capped, Ownable {
    address public vestingAddress;

    modifier onlyVesting() {
        require(msg.sender == vestingAddress);
        _;
    }

    /*
        Total Supply Cap: 1,412,463,573

        July 2022 total mint: 481 692 287.6
        - 282 492 714,6 Staking 20% of total supply
        - 199,199,573 (Vip: 183,991,459 + Reserve: 6,008,541 + 5% Referral comm: 9,199,573)
    */
    constructor(uint256 _initialSupply)
        ERC20("Cowrie", "COWRIE")
        ERC20Capped(1412463573 * 10**decimals())
    {
        _mint(msg.sender, _initialSupply);
        // Call setVestingAddress function after deploying
    }

    function mint(address _account, uint256 _amount) external onlyVesting {
        _mint(_account, _amount);
    }

    function setVestingAddress(address _vestingAddress) external onlyOwner {
        require(
            vestingAddress != _vestingAddress,
            "Cannot set same Vesting address"
        );
        vestingAddress = _vestingAddress;
    }
}
