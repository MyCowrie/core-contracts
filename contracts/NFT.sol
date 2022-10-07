// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFT is ERC2981, ERC721Enumerable, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _currentTokenId;

    uint256 public immutable TOTAL_SUPPLY_CAP;

    constructor(uint256 totalSupply_) ERC721("Cowrie NFT", "COWRIE") {
        TOTAL_SUPPLY_CAP = totalSupply_;
    }

    // Only owner can mint NFTs since initially specified trusts/org.s will get NFTs
    function mintTo(address recipient, uint96 feeNumerator) external onlyOwner returns (uint256) {
        require(
            _currentTokenId.current() < TOTAL_SUPPLY_CAP,
            "Cannot mint more than total supply"
        );

        _currentTokenId.increment();
        uint256 newItemId = _currentTokenId.current();
        _safeMint(recipient, newItemId);

        // Default feeDenominator is 10000
        // so for example, feeNumerator = 500 gives 0.05% royalty
        _setTokenRoyalty(newItemId, recipient, feeNumerator);

        return newItemId;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721Enumerable, ERC2981)
        returns (bool)
    {
        return interfaceId == type(IERC721Enumerable).interfaceId || super.supportsInterface(interfaceId);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return "www.mycowrie.org/nft/";
    }
}
