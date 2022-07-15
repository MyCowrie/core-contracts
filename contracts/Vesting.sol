// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IERC20Mintable is IERC20Metadata {
    function mint(address _account, uint256 _amount) external;
}

contract TokenVesting is Ownable {
    using SafeMath for uint256;

    struct BeneficiaryDetails {
        uint256 released;
        uint256 releasable;
        uint256 totalReleasableToken;
        uint256 roundsPassed;
        uint256 lastReleasedAt;
        uint256 previousRoundTokens;
        bool haveSubWallets;
        bool toReleaseSubWallets;
        bool valid;
        bool isSAPD;
    }

    struct SubWalletDetails {
        address parentWallet;
        uint256 index;
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

    address public sapdOfficerAddress;

    mapping(address => BeneficiaryDetails) beneficiaryDetails;
    mapping(address => SubWalletDetails) beneficiarySubWalletDetails;

    // Beneficiary => List of sub-wallets
    mapping(address => address[]) beneficiarySubWallets;

    mapping(uint256 => ReleasePercentRange) releaseRangeMapping;

    address[] beneficiaries;

    IERC20Mintable immutable token;

    event TokensReleasedForLinear(address beneficiary, uint256 amount);
    event TokensReleasedForSAPD(address beneficiary, uint256 amount);
    event BeneficiaryAdded(
        address beneficiary,
        uint256 released,
        uint256 releasable,
        bool haveSubWallets,
        bool valid,
        bool isSAPD
    );
    event BeneficiaryValidStatusUpdated(address beneficiary, bool valid);
    event BeneficiaryAddressUpdated(
        address oldBeneficiary,
        address newBeneficiary
    );

    modifier onlyNewBeneficiary(address _beneficiary) {
        require(
            !beneficiaryDetails[_beneficiary].valid,
            "Address already exist as beneficiary"
        );
        _;
    }

    modifier onlySAPDOfficer() {
        require(
            msg.sender == sapdOfficerAddress,
            "Only SAPD Officer can call this function"
        );
        _;
    }

    // Cannot allocate more than 100% of TOTAL_VESTING_TOKENS
    modifier limitTokensAlloted(uint256 _amount) {
        require(
            percentTokensAlloted.add(_amount) <= TOTAL_VESTING_TOKENS,
            "Allocation amount's sum is more than total vesting tokens"
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

    function updateSAPDOfficerAddress(address _newSAPDOfficer)
        external
        onlyOwner
    {
        sapdOfficerAddress = _newSAPDOfficer;
    }

    function addBeneficiary(
        address _beneficiary,
        uint256 _amount,
        bool _haveSubWallets,
        bool _startFromNow,
        bool _isSAPD
    )
        external
        onlyOwner
        onlyNewBeneficiary(_beneficiary)
        limitTokensAlloted(_amount)
    {
        beneficiaries.push(_beneficiary);
        beneficiaryDetails[_beneficiary].valid = true;
        beneficiaryDetails[_beneficiary].haveSubWallets = _haveSubWallets;
        beneficiaryDetails[_beneficiary].lastReleasedAt = _startFromNow
            ? block.timestamp
            : START_TIME;
        beneficiaryDetails[_beneficiary].isSAPD = _isSAPD;
        beneficiaryDetails[_beneficiary].totalReleasableToken = _amount;

        emit BeneficiaryAdded(
            _beneficiary,
            0,
            beneficiaryDetails[_beneficiary].totalReleasableToken,
            _haveSubWallets,
            true,
            _isSAPD
        );
    }

    function updateBeneficiaryValidStatus(address _beneficiary, bool _isValid)
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

    function updateBeneficiaryAddress(
        address _oldBeneficiary,
        address _newBeneficiary
    ) external onlyOwner {
        require(
            beneficiaryDetails[_oldBeneficiary].valid,
            "Beneficiary does not exist or is set invalid"
        );
        require(
            _newBeneficiary != address(0),
            "New beneficiary cannot be address zero"
        );

        beneficiaryDetails[_newBeneficiary] = beneficiaryDetails[
            _oldBeneficiary
        ];

        if (beneficiaryDetails[_oldBeneficiary].haveSubWallets) {
            for (
                uint256 i = 0;
                i < beneficiarySubWallets[_oldBeneficiary].length;
                i++
            ) {
                beneficiarySubWalletDetails[
                    beneficiarySubWallets[_oldBeneficiary][i]
                ].parentWallet = _newBeneficiary;
            }

            beneficiarySubWallets[_newBeneficiary] = beneficiarySubWallets[
                _oldBeneficiary
            ];
            delete beneficiarySubWallets[_oldBeneficiary];
        }

        delete beneficiaryDetails[_oldBeneficiary];

        emit BeneficiaryAddressUpdated(_oldBeneficiary, _newBeneficiary);
    }

    function addBeneficiarySubWallets(
        address _beneficiary,
        address[] memory _subWallets
    ) external onlyOwner {
        require(
            beneficiaryDetails[_beneficiary].haveSubWallets,
            "Beneficiary have no sub-wallets"
        );

        for (uint256 i = 0; i < _subWallets.length; i++) {
            beneficiarySubWallets[_beneficiary].push(_subWallets[i]);
            beneficiarySubWalletDetails[_subWallets[i]] = SubWalletDetails(
                _beneficiary,
                i,
                true
            );
        }
    }

    function updateSubWalletValidStatus(address _subWallet, bool _valid)
        external
        onlyOwner
    {
        require(
            beneficiarySubWalletDetails[_subWallet].parentWallet != address(0),
            "Sub-wallet does not exist"
        );
        require(
            beneficiarySubWalletDetails[_subWallet].valid != _valid,
            "Cannot set same valid status for sub-wallet"
        );

        beneficiarySubWalletDetails[_subWallet].valid = _valid;

        address[] storage parentSubWallets = beneficiarySubWallets[
            beneficiarySubWalletDetails[_subWallet].parentWallet
        ];
        if (_valid) {
            parentSubWallets.push(_subWallet);
            beneficiarySubWalletDetails[_subWallet].index =
                parentSubWallets.length -
                1;
        } else {
            parentSubWallets[
                beneficiarySubWalletDetails[_subWallet].index
            ] = parentSubWallets[parentSubWallets.length - 1];
            parentSubWallets.pop();
        }
    }

    function releaseLinearTokens(address _beneficiary) external {
        // Either owner or the beneficiary themselves can release their tokens
        // In case of owner, get the beneficiary from argument else msg.sender
        require(
            msg.sender == owner() || !beneficiaryDetails[msg.sender].isSAPD
        );
        address beneficiary = msg.sender == owner() ? _beneficiary : msg.sender;

        (uint256 releasableTokens, uint256 roundsCovered) = getReleasableTokens(
            beneficiary
        );
        require(releasableTokens > 0, "Zero releasable tokens found");

        beneficiaryDetails[beneficiary].roundsPassed += roundsCovered;

        beneficiaryDetails[beneficiary].lastReleasedAt = block.timestamp;

        if (beneficiaryDetails[beneficiary].haveSubWallets) {
            // must call releaseSubWalletTokens after this
            beneficiaryDetails[beneficiary].toReleaseSubWallets = true;
        } else {
            token.mint(beneficiary, releasableTokens);
        }

        beneficiaryDetails[beneficiary].released += releasableTokens;
        totalReleasedTokens += releasableTokens;

        emit TokensReleasedForLinear(beneficiary, releasableTokens);
    }

    function releaseSAPDTokens(
        address beneficiary,
        uint256 currentTokenPrice,
        uint256 avgTokenPrice
    ) external onlySAPDOfficer {
        require(
            beneficiaryDetails[beneficiary].isSAPD,
            "Beneficiary does not follow SAPD"
        );

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

        uint256 sapdReleasableTokens = releasableTokens
            .mul(releasablePercentTokens)
            .div(100);

        if (beneficiaryDetails[beneficiary].haveSubWallets) {
            // must call releaseSubWalletTokens after this
            beneficiaryDetails[beneficiary].toReleaseSubWallets = true;
        } else {
            token.mint(beneficiary, sapdReleasableTokens);
        }

        beneficiaryDetails[beneficiary].previousRoundTokens = releasableTokens
            .sub(sapdReleasableTokens);
        beneficiaryDetails[beneficiary].released += sapdReleasableTokens;
        totalReleasedTokens += sapdReleasableTokens;

        lastMarkedPrice = currentTokenPrice;

        emit TokensReleasedForSAPD(beneficiary, sapdReleasableTokens);
    }

    // Release subwallet tokens after calling releaseSAPDTokens or releaseLinearTokens
    function releaseSubwalletTokens(address _beneficiary) external {
        // Either owner or the beneficiary themselves can release their tokens
        // In case of owner, get the beneficiary from argument else msg.sender
        address beneficiary = msg.sender == owner() ? _beneficiary : msg.sender;
        (uint256 releasableTokens, ) = getReleasableTokens(beneficiary);

        require(beneficiaryDetails[beneficiary].valid, "Invalid beneficiary");
        require(
            beneficiaryDetails[beneficiary].toReleaseSubWallets,
            "Subwallet tokens were already released"
        );
        require(
            beneficiaryDetails[beneficiary].haveSubWallets,
            "Beneficiary does not have any subwallets"
        );
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
            token.mint(beneficiarySubWallets[beneficiary][i], subWalletTokens);
        }

        beneficiaryDetails[beneficiary].releasable = 0;
        beneficiaryDetails[beneficiary].toReleaseSubWallets = false;
    }

    // ====== GETTERS =======

    function getBeneficiaryDetails(address _beneficiary)
        external
        view
        returns (
            uint256 _released,
            uint256 _releasable,
            uint256 _roundsPassed,
            uint256 _lastReleasedAt,
            uint256 _previousRoundTokens,
            uint256 _totalReleasableToken,
            bool _haveSubWallets,
            bool _valid,
            bool _isSAPD
        )
    {
        BeneficiaryDetails memory details = beneficiaryDetails[_beneficiary];
        (details.releasable, ) = getReleasableTokens(_beneficiary);

        _released = details.released;
        _releasable = details.releasable;
        _roundsPassed = details.roundsPassed;
        _lastReleasedAt = details.lastReleasedAt;
        _previousRoundTokens = details.previousRoundTokens;
        _totalReleasableToken = details.totalReleasableToken;
        _haveSubWallets = details.haveSubWallets;
        _valid = details.valid;
        _isSAPD = details.isSAPD;
    }

    function getAllBeneficiaryDetails()
        external
        view
        returns (BeneficiaryDetails[] memory _details)
    {
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            BeneficiaryDetails memory details = beneficiaryDetails[
                beneficiaries[i]
            ];
            (details.releasable, ) = getReleasableTokens(beneficiaries[i]);
            _details[i] = details;
        }
    }

    function getBeneficiaries() external view returns (address[] memory) {
        return beneficiaries;
    }

    function getBeneficiarySubWallets(address _beneficiary)
        external
        view
        returns (address[] memory)
    {
        return beneficiarySubWallets[_beneficiary];
    }

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
            _amount = totalReleasableTokens.mul(roundsPassed).div(TOTAL_ROUNDS);

            _rounds = roundsPassed;
        } else {
            _amount = 0;
            _rounds = 0;
        }
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
