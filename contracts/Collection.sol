pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';

contract Collection is ERC721URIStorage, Ownable, ReentrancyGuard {
  using Counters for Counters.Counter;
  using SafeMath for uint256;

  Counters.Counter private tokenIds;

  uint256 public maxSupply;
  uint256 public currentSupply;

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
    require(currentSupply <= maxSupply, 'cannot_exceed_maximum_number_of_items_in_collection');
    tokenIds.increment();
    tokenId = tokenIds.current();
    _safeMint(_to, tokenId);
    _setTokenURI(tokenId, _tokenURI);

    currentSupply = currentSupply.add(1);
  }

  function burn(uint256 _tokenId) external nonReentrant onlyOwner {
    require(_exists(_tokenId), 'token_must_exist');
    _burn(_tokenId);

    currentSupply = currentSupply.sub(1);
  }
}
