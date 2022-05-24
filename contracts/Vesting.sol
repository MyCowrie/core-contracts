// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IERC20Mintable is IERC20Metadata {
    function mint(address _account, uint256 _amount) external;
}

contract TokenVesting is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    event TokensReleasedForLinear(address beneficiary, uint256 amount);
    event TokensReleasedForPDO(address beneficiary, uint256 amount);
    event BeneficiaryAdded(
        address beneficiary,
        uint256 released,
        uint256 releasable,
        uint256 percentage,
        bool haveSubWallets,
        bool valid,
        bool isPDO
    );
    event BeneficiaryValidStatusUpdated(address beneficiary, bool valid);

    struct VestingDetails {
        uint256 startTime;
        uint256 endTime;
        bool initialized;
    }

    struct BeneficiaryDetails {
        uint256 released;
        uint256 releasable;
        uint256 percentage;
        uint256 totalReleasableToken;
        uint256 roundsPassed;
        uint256 lastReleasedAt;
        uint256 previousRoundTokens;
        bool haveSubWallets;
        bool valid;
        bool isPDO;
    }

    struct SubWalletDetails {
        address parentWallet;
        bool valid;
    }

    struct ReleasePercentRange {
        uint256 positiveRangeReleasePercent;
        uint256 negativeRangeReleasePercent;
    }

    uint256 public immutable TOTAL_VESTING_TOKENS;
    uint256 public immutable START_TIME;

    uint256 public constant VESTING_DURATION = 365 days; // 1 year
    uint256 public constant TOTAL_ROUNDS = 27; // 27 years

    uint256 public lastMarkedPrice;
    uint256 public totalReleasedTokens;
    uint256 public percentTokensAlloted;

    mapping(address => BeneficiaryDetails) beneficiaryDetails;
    mapping(address => SubWalletDetails) beneficiarySubWalletDetails;

    // Beneficiary => List of sub-wallets
    mapping(address => address[]) beneficiarySubWallets;

    mapping(uint256 => ReleasePercentRange) releaseRangeMapping;

    address[] beneficiaries;

    IERC20Mintable token;

    modifier onlyNewBeneficiary(address _beneficiary) {
        require(
            !beneficiaryDetails[_beneficiary].valid,
            "Address already exist as beneficiary"
        );
        _;
    }

    // Cannot allocate more than 100% of TOTAL_VESTING_TOKENS
    modifier limitTokensAlloted(uint256 _percent) {
        require(
            percentTokensAlloted.add(_percent) <= 100,
            "Tokens allocation percentage summing up more than 100%"
        );
        _;
    }

    constructor(
        address _token,
        uint256 _lastMarkedPrice,
        uint256 _totalVestingTokens
    ) {
        token = IERC20Mintable(_token);
        TOTAL_VESTING_TOKENS = _totalVestingTokens;
        START_TIME = block.timestamp;
        lastMarkedPrice = _lastMarkedPrice;

        // Hardcoded range for Release amount %
        addReleaseRange(0, 0, 0);
        addReleaseRange(50, 5, 0);
        addReleaseRange(60, 10, 0);
        addReleaseRange(80, 20, 0);
        addReleaseRange(100, 30, 0);
    }

    function addBeneficiary(
        address _beneficiary,
        uint256 _percentage,
        bool _haveSubWallets,
        bool _startFromNow,
        bool _isPDO
    )
        public
        onlyOwner
        onlyNewBeneficiary(_beneficiary)
        limitTokensAlloted(_percentage)
    {
        beneficiaries.push(_beneficiary);
        beneficiaryDetails[_beneficiary].valid = true;
        beneficiaryDetails[_beneficiary].percentage = _percentage;
        beneficiaryDetails[_beneficiary].haveSubWallets = _haveSubWallets;
        beneficiaryDetails[_beneficiary].lastReleasedAt = _startFromNow
            ? block.timestamp
            : START_TIME;
        beneficiaryDetails[_beneficiary].isPDO = _isPDO;
        beneficiaryDetails[_beneficiary]
            .totalReleasableToken = TOTAL_VESTING_TOKENS.mul(_percentage).div(
            100
        );

        emit BeneficiaryAdded(
            _beneficiary,
            0,
            beneficiaryDetails[_beneficiary].totalReleasableToken,
            _percentage,
            _haveSubWallets,
            true,
            _isPDO
        );
    }

    function updateBeneficiaryIsValid(address _beneficiary, bool _isValid)
        external
        onlyOwner
    {
        require(
            beneficiaryDetails[_beneficiary].valid != _isValid,
            "Cannot set same valid status"
        );

        beneficiaryDetails[_beneficiary].valid = _isValid;

        emit BeneficiaryValidStatusUpdated(_beneficiary, _isValid);
    }

    function addBeneficiarySubWallets(
        address _beneficiary,
        address[] memory _subWallets
    ) public onlyOwner {
        require(
            beneficiaryDetails[_beneficiary].haveSubWallets,
            "Beneficiary have no sub-wallets"
        );

        for (uint256 i = 0; i < _subWallets.length; i++) {
            beneficiarySubWallets[_beneficiary].push(_subWallets[i]);
            beneficiarySubWalletDetails[_subWallets[i]] = SubWalletDetails(
                _beneficiary,
                true
            );
        }
    }

    function updateBeneficiaryPercentage(
        address _beneficiary,
        uint256 _newPercentage
    ) public onlyOwner limitTokensAlloted(_newPercentage) {
        beneficiaryDetails[_beneficiary].percentage = _newPercentage;
    }

    function releaseLinearTokens(address beneficiary) public nonReentrant {
        require(!beneficiaryDetails[beneficiary].isPDO, "Beneficiary does not follow Linear release approach");

        (uint256 releasableTokens, uint256 roundsCovered) = getReleasableTokens(
            beneficiary
        );
        require(releasableTokens > 0, "Zero releasable tokens found");

        beneficiaryDetails[beneficiary].roundsPassed += roundsCovered;

        beneficiaryDetails[beneficiary].lastReleasedAt = block.timestamp;

        if (beneficiaryDetails[beneficiary].haveSubWallets) {
            require(
                beneficiarySubWallets[beneficiary].length > 0,
                "No sub-wallets added for the beneficiary."
            );

            uint256 subWalletTokens = releasableTokens.div(
                beneficiarySubWallets[beneficiary].length
            );
            for (
                uint256 i = 0;
                i < beneficiarySubWallets[beneficiary].length;
                i++
            ) {
                token.mint(
                    beneficiarySubWallets[beneficiary][i],
                    subWalletTokens
                );
            }
        } else {
            token.mint(beneficiary, releasableTokens);
        }

        beneficiaryDetails[beneficiary].released += releasableTokens;
        totalReleasedTokens += releasableTokens;

        emit TokensReleasedForLinear(beneficiary, releasableTokens);
    }

    function releasePDOTokens(
        address beneficiary,
        uint256 currentTokenPrice,
        uint256 avgTokenPrice
    ) public nonReentrant {
        require(beneficiaryDetails[beneficiary].isPDO, "Beneficiary does not follow PDO");

        (uint256 releasableTokens, uint256 roundsCovered) = getReleasableTokens(
            beneficiary
        );
        releasableTokens += beneficiaryDetails[beneficiary].previousRoundTokens;
        require(releasableTokens > 0, "Zero releasable tokens found");

        beneficiaryDetails[beneficiary].roundsPassed += roundsCovered;
        beneficiaryDetails[beneficiary].lastReleasedAt = block.timestamp;

        (uint256 absPercentOfChange, bool isPositive) = abs(
            int256(100 - lastMarkedPrice.mul(100).div(avgTokenPrice))
        );
        uint256 startRange = 0;

        // Decide the range according to Rise/Fall %
        if (absPercentOfChange < 50) {
            startRange = 0;
        } else if (absPercentOfChange < 60) {
            startRange = 50;
        } else if (absPercentOfChange < 80) {
            startRange = 60;
        } else if (absPercentOfChange < 100) {
            startRange = 80;
        } else {
            startRange = 100;
        }

        uint256 releasablePercentTokens = isPositive
            ? releaseRangeMapping[startRange].positiveRangeReleasePercent
            : releaseRangeMapping[startRange].negativeRangeReleasePercent;
        require(
            releasablePercentTokens > 0,
            "Release percent too low, cannot release tokens"
        );

        uint256 pdoReleasableTokens = releasableTokens
            .mul(releasablePercentTokens)
            .div(100);

        if (beneficiaryDetails[beneficiary].haveSubWallets) {
            require(
                beneficiarySubWallets[beneficiary].length > 0,
                "No sub-wallets added for the beneficiary."
            );

            uint256 subWalletTokens = pdoReleasableTokens.div(
                beneficiarySubWallets[beneficiary].length
            );
            for (
                uint256 i = 0;
                i < beneficiarySubWallets[beneficiary].length;
                i++
            ) {
                token.mint(
                    beneficiarySubWallets[beneficiary][i],
                    subWalletTokens
                );
            }
        } else {
            token.mint(beneficiary, pdoReleasableTokens);
        }

        beneficiaryDetails[beneficiary].previousRoundTokens = releasableTokens
            .sub(pdoReleasableTokens);
        beneficiaryDetails[beneficiary].released += pdoReleasableTokens;
        totalReleasedTokens += pdoReleasableTokens;

        lastMarkedPrice = currentTokenPrice;

        emit TokensReleasedForPDO(beneficiary, pdoReleasableTokens);
    }

    // ====== GETTERS =======

    function getReleasableTokens(address _for)
        public
        view
        returns (uint256 _amount, uint256 _rounds)
    {
        if (
            beneficiaryDetails[_for].valid &&
            beneficiaryDetails[_for].roundsPassed < TOTAL_ROUNDS
        ) {
            uint256 durationPassed = block.timestamp.sub(
                beneficiaryDetails[_for].lastReleasedAt
            );
            uint256 roundsPassed = durationPassed.div(VESTING_DURATION);

            // Total rounds passed for this beneficiary including this period
            uint256 totalRoundsPassed = roundsPassed.add(
                beneficiaryDetails[_for].roundsPassed
            );
            // Rounding off number of rounds passed since last release to not add up greater than TOTAL_ROUNDS
            (, uint256 moreThanLimitRounds) = totalRoundsPassed.trySub(
                TOTAL_ROUNDS
            );
            (, roundsPassed) = roundsPassed.trySub(moreThanLimitRounds);

            // Number of tokens to be vested for this account
            uint256 totalReleasableTokens = beneficiaryDetails[_for]
                .totalReleasableToken;

            // Number of tokens vested till now for this role
            uint256 releasable = totalReleasableTokens.div(TOTAL_ROUNDS).mul(
                roundsPassed
            );

            (, _amount) = releasable.trySub(beneficiaryDetails[_for].released);
            _rounds = roundsPassed;
        } else {
            _amount = 0;
            _rounds = 0;
        }
    }

    function getBeneficiaryDetails(address _beneficiary)
        public
        view
        returns (
            uint256 _released,
            uint256 _releasable,
            uint256 _percentage,
            uint256 _roundsPassed,
            uint256 _lastReleasedAt,
            uint256 _previousRoundTokens,
            uint256 _totalReleasableToken,
            bool _haveSubWallets,
            bool _valid,
            bool _isPDO
        )
    {
        BeneficiaryDetails memory details = beneficiaryDetails[_beneficiary];
        (details.releasable, ) = getReleasableTokens(_beneficiary);

        _released = details.released;
        _releasable = details.releasable;
        _percentage = details.percentage;
        _roundsPassed = details.roundsPassed;
        _lastReleasedAt = details.lastReleasedAt;
        _previousRoundTokens = details.previousRoundTokens;
        _totalReleasableToken = details.totalReleasableToken;
        _haveSubWallets = details.haveSubWallets;
        _valid = details.valid;
        _isPDO = details.isPDO;
    }

    function getBeneficiaries() public view returns (address[] memory) {
        return beneficiaries;
    }

    function getBeneficiarySubWallets(address _beneficiary)
        public
        view
        returns (address[] memory)
    {
        return beneficiarySubWallets[_beneficiary];
    }

    // ====== PRIVATES =========

    function abs(int256 x) private pure returns (uint256, bool) {
        return x >= 0 ? (uint256(x), true) : (uint256(-x), false);
    }

    function addReleaseRange(
        uint256 startRange,
        uint256 _positiveRangeReleasePercent,
        uint256 _negativeRangeReleasePercent
    ) private {
        releaseRangeMapping[startRange] = ReleasePercentRange(
            _positiveRangeReleasePercent,
            _negativeRangeReleasePercent
        );
    }
}
