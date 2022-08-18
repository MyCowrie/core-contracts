// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFT is ERC721Enumerable, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _currentTokenId;

    uint256 public immutable TOTAL_SUPPLY_CAP;

    constructor(uint256 totalSupply_) ERC721("Cowrie NFT", "COWRIE") {
        TOTAL_SUPPLY_CAP = totalSupply_;
    }

    // Only owner can mint NFTs since initially specified trusts/org.s will get NFTs
    function mintTo(address recipient) onlyOwner external returns (uint256) {
        require(
            _currentTokenId.current() < TOTAL_SUPPLY_CAP,
            "Cannot mint more than total supply"
        );

        _currentTokenId.increment();
        uint256 newItemId = _currentTokenId.current();
        _safeMint(recipient, newItemId);
        return newItemId;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return "www.mycowrie.org/nft/";
    }
}
