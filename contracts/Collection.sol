pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

contract Collection is ERC721URIStorage, Ownable, ReentrancyGuard {
  using Counters for Counters.Counter;

  Counters.Counter private tokenIds;

  uint256 public maxSupply;

  constructor(
    string memory name_,
    string memory symbol_,
    address owner_,
    uint256 maxSupply_
  ) Ownable() ERC721(name_, symbol_) {
    maxSupply = maxSupply_;
    _transferOwnership(owner_);
  }

  function mint(address _to, string memory _tokenURI) external nonReentrant returns (uint256 tokenId) {
    tokenIds.increment();
    tokenId = tokenIds.current();
    require(tokenId <= maxSupply, 'cannot_exceed_maximum_number_of_items_in_collection');
    _safeMint(_to, tokenId);
    _setTokenURI(tokenId, _tokenURI);
  }
}
