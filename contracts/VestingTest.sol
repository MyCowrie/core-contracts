// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.15;

import "./Vesting.sol";

contract VestingTest is TokenVesting {
    constructor(
        address _tokenAddr,
        uint256 _lastMarkedPrice,
        uint256 _totalVestingTokens
    ) TokenVesting(_tokenAddr, _lastMarkedPrice, _totalVestingTokens) {}

    function VESTING_DURATION() public pure override returns (uint256) {
        return 1;
    }

    function TOTAL_ROUNDS() public pure override returns (uint256) {
        return 1;
    }
}
