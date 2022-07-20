// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IERC20Mintable is IERC20Metadata {
    function mint(address _account, uint256 _amount) external;
}

contract TokenVesting is Ownable {
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

    mapping(address => BeneficiaryDetails) _beneficiaryDetails;
    mapping(address => SubWalletDetails) _beneficiarySubWalletDetails;

    // Beneficiary => List of sub-wallets
    mapping(address => address[]) _beneficiarySubWallets;

    mapping(uint256 => ReleasePercentRange) _releaseRangeMapping;

    address[] _beneficiaries;

    IERC20Mintable immutable _token;

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
            !_beneficiaryDetails[_beneficiary].valid,
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
            percentTokensAlloted + _amount <= TOTAL_VESTING_TOKENS,
            "Allocation amount's sum is more than total vesting tokens"
        );
        _;
    }

    constructor(
        address _tokenAddr,
        uint256 _lastMarkedPrice,
        uint256 _totalVestingTokens
    ) {
        _token = IERC20Mintable(_tokenAddr);
        TOTAL_VESTING_TOKENS = _totalVestingTokens;
        START_TIME = block.timestamp;
        lastMarkedPrice = _lastMarkedPrice;

        // Hardcoded range for Release amount %
        _addReleaseRange(0, 0, 0);
        _addReleaseRange(50, 5, 0);
        _addReleaseRange(60, 10, 0);
        _addReleaseRange(80, 20, 0);
        _addReleaseRange(100, 30, 0);
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
        _beneficiaries.push(_beneficiary);
        _beneficiaryDetails[_beneficiary].valid = true;
        _beneficiaryDetails[_beneficiary].haveSubWallets = _haveSubWallets;
        _beneficiaryDetails[_beneficiary].lastReleasedAt = _startFromNow
            ? block.timestamp
            : START_TIME;
        _beneficiaryDetails[_beneficiary].isSAPD = _isSAPD;
        _beneficiaryDetails[_beneficiary].totalReleasableToken = _amount;

        emit BeneficiaryAdded(
            _beneficiary,
            0,
            _beneficiaryDetails[_beneficiary].totalReleasableToken,
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
            _beneficiaryDetails[_beneficiary].valid != _isValid,
            "Cannot set same valid status"
        );

        _beneficiaryDetails[_beneficiary].valid = _isValid;

        emit BeneficiaryValidStatusUpdated(_beneficiary, _isValid);
    }

    function updateBeneficiaryAddress(
        address _oldBeneficiary,
        address _newBeneficiary
    ) external onlyOwner {
        require(
            _beneficiaryDetails[_oldBeneficiary].valid,
            "Beneficiary does not exist or is set invalid"
        );
        require(
            _newBeneficiary != address(0),
            "New beneficiary cannot be address zero"
        );

        _beneficiaryDetails[_newBeneficiary] = _beneficiaryDetails[
            _oldBeneficiary
        ];

        if (_beneficiaryDetails[_oldBeneficiary].haveSubWallets) {
            for (
                uint256 i = 0;
                i < _beneficiarySubWallets[_oldBeneficiary].length;
                i++
            ) {
                _beneficiarySubWalletDetails[
                    _beneficiarySubWallets[_oldBeneficiary][i]
                ].parentWallet = _newBeneficiary;
            }

            _beneficiarySubWallets[_newBeneficiary] = _beneficiarySubWallets[
                _oldBeneficiary
            ];
            delete _beneficiarySubWallets[_oldBeneficiary];
        }

        delete _beneficiaryDetails[_oldBeneficiary];

        emit BeneficiaryAddressUpdated(_oldBeneficiary, _newBeneficiary);
    }

    function addBeneficiarySubWallets(
        address _beneficiary,
        address[] memory _subWallets
    ) external onlyOwner {
        require(
            _beneficiaryDetails[_beneficiary].haveSubWallets,
            "Beneficiary have no sub-wallets"
        );

        for (uint256 i = 0; i < _subWallets.length; i++) {
            _beneficiarySubWallets[_beneficiary].push(_subWallets[i]);
            _beneficiarySubWalletDetails[_subWallets[i]] = SubWalletDetails(
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
            _beneficiarySubWalletDetails[_subWallet].parentWallet != address(0),
            "Sub-wallet does not exist"
        );
        require(
            _beneficiarySubWalletDetails[_subWallet].valid != _valid,
            "Cannot set same valid status for sub-wallet"
        );

        _beneficiarySubWalletDetails[_subWallet].valid = _valid;

        address[] storage parentSubWallets = _beneficiarySubWallets[
            _beneficiarySubWalletDetails[_subWallet].parentWallet
        ];
        if (_valid) {
            parentSubWallets.push(_subWallet);
            _beneficiarySubWalletDetails[_subWallet].index =
                parentSubWallets.length -
                1;
        } else {
            parentSubWallets[
                _beneficiarySubWalletDetails[_subWallet].index
            ] = parentSubWallets[parentSubWallets.length - 1];
            parentSubWallets.pop();
        }
    }

    function releaseLinearTokens(address _beneficiary) external {
        // Either owner or the beneficiary themselves can release their tokens
        // In case of owner, get the beneficiary from argument else msg.sender
        require(
            msg.sender == owner() || !_beneficiaryDetails[msg.sender].isSAPD
        );
        address beneficiary = msg.sender == owner() ? _beneficiary : msg.sender;

        (uint256 releasableTokens, uint256 roundsCovered) = getReleasableTokens(
            beneficiary
        );
        require(releasableTokens > 0, "Zero releasable tokens found");

        _beneficiaryDetails[beneficiary].roundsPassed += roundsCovered;

        _beneficiaryDetails[beneficiary].lastReleasedAt = block.timestamp;

        if (_beneficiaryDetails[beneficiary].haveSubWallets) {
            // must call releaseSubWalletTokens after this
            _beneficiaryDetails[beneficiary].toReleaseSubWallets = true;
        } else {
            _token.mint(beneficiary, releasableTokens);
        }

        _beneficiaryDetails[beneficiary].released += releasableTokens;
        totalReleasedTokens += releasableTokens;

        emit TokensReleasedForLinear(beneficiary, releasableTokens);
    }

    function releaseSAPDTokens(
        address beneficiary,
        uint256 currentTokenPrice,
        uint256 avgTokenPrice
    ) external onlySAPDOfficer {
        require(
            _beneficiaryDetails[beneficiary].isSAPD,
            "Beneficiary does not follow SAPD"
        );

        (uint256 releasableTokens, uint256 roundsCovered) = getReleasableTokens(
            beneficiary
        );
        releasableTokens += _beneficiaryDetails[beneficiary]
            .previousRoundTokens;
        require(releasableTokens > 0, "Zero releasable tokens found");

        _beneficiaryDetails[beneficiary].roundsPassed += roundsCovered;
        _beneficiaryDetails[beneficiary].lastReleasedAt = block.timestamp;

        (uint256 absPercentOfChange, bool isPositive) = _abs(
            int256(100 - ((lastMarkedPrice * 100) / avgTokenPrice))
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
            ? _releaseRangeMapping[startRange].positiveRangeReleasePercent
            : _releaseRangeMapping[startRange].negativeRangeReleasePercent;
        require(
            releasablePercentTokens > 0,
            "Release percent too low, cannot release tokens"
        );

        uint256 sapdReleasableTokens = (releasableTokens *
            releasablePercentTokens) / 100;

        if (_beneficiaryDetails[beneficiary].haveSubWallets) {
            // must call releaseSubWalletTokens after this
            _beneficiaryDetails[beneficiary].toReleaseSubWallets = true;
        } else {
            _token.mint(beneficiary, sapdReleasableTokens);
        }

        _beneficiaryDetails[beneficiary].previousRoundTokens =
            releasableTokens -
            sapdReleasableTokens;
        _beneficiaryDetails[beneficiary].released += sapdReleasableTokens;
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

        require(_beneficiaryDetails[beneficiary].valid, "Invalid beneficiary");
        require(
            _beneficiaryDetails[beneficiary].toReleaseSubWallets,
            "Subwallet tokens were already released"
        );
        require(
            _beneficiaryDetails[beneficiary].haveSubWallets,
            "Beneficiary does not have any subwallets"
        );
        require(
            _beneficiarySubWallets[beneficiary].length > 0,
            "No sub-wallets added for the beneficiary."
        );

        uint256 subWalletTokens = releasableTokens /
            _beneficiarySubWallets[beneficiary].length;
        for (
            uint256 i = 0;
            i < _beneficiarySubWallets[beneficiary].length;
            i++
        ) {
            _token.mint(
                _beneficiarySubWallets[beneficiary][i],
                subWalletTokens
            );
        }

        _beneficiaryDetails[beneficiary].releasable = 0;
        _beneficiaryDetails[beneficiary].toReleaseSubWallets = false;
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
        BeneficiaryDetails memory details = _beneficiaryDetails[_beneficiary];
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
        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            BeneficiaryDetails memory details = _beneficiaryDetails[
                _beneficiaries[i]
            ];
            (details.releasable, ) = getReleasableTokens(_beneficiaries[i]);
            _details[i] = details;
        }
    }

    function getBeneficiaries() external view returns (address[] memory) {
        return _beneficiaries;
    }

    function getBeneficiarySubWallets(address _beneficiary)
        external
        view
        returns (address[] memory)
    {
        return _beneficiarySubWallets[_beneficiary];
    }

    function getReleasableTokens(address _for)
        public
        view
        returns (uint256 _amount, uint256 _rounds)
    {
        if (
            _beneficiaryDetails[_for].valid &&
            _beneficiaryDetails[_for].roundsPassed < TOTAL_ROUNDS
        ) {
            uint256 durationPassed = block.timestamp -
                _beneficiaryDetails[_for].lastReleasedAt;
            uint256 roundsPassed = durationPassed / VESTING_DURATION;

            // Total rounds passed for this beneficiary including this period
            uint256 totalRoundsPassed = roundsPassed +
                _beneficiaryDetails[_for].roundsPassed;
            // Rounding off number of rounds passed since last release to not add up greater than TOTAL_ROUNDS
            uint256 moreThanLimitRounds = totalRoundsPassed - TOTAL_ROUNDS;
            roundsPassed = roundsPassed - moreThanLimitRounds;

            // Number of tokens to be vested for this account
            uint256 totalReleasableTokens = _beneficiaryDetails[_for]
                .totalReleasableToken;

            // Number of tokens vested till now for this role
            _amount = (totalReleasableTokens * roundsPassed) / TOTAL_ROUNDS;

            _rounds = roundsPassed;
        } else {
            _amount = 0;
            _rounds = 0;
        }
    }

    // ====== PRIVATES =========

    function _addReleaseRange(
        uint256 startRange,
        uint256 _positiveRangeReleasePercent,
        uint256 _negativeRangeReleasePercent
    ) private {
        _releaseRangeMapping[startRange] = ReleasePercentRange(
            _positiveRangeReleasePercent,
            _negativeRangeReleasePercent
        );
    }

    function _abs(int256 x) private pure returns (uint256, bool) {
        return x >= 0 ? (uint256(x), true) : (uint256(-x), false);
    }
}
