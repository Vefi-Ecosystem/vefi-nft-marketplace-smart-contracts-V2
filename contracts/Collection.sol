pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/access/AccessControl.sol';
import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';

contract Collection is ERC721URIStorage, Ownable, ReentrancyGuard, AccessControl {
  using Counters for Counters.Counter;
  using SafeMath for uint256;

  Counters.Counter private tokenIds;

  uint256 public maxSupply;
  uint256 public currentSupply;
  uint256 public mintStartTime;

  bytes32 public minterRole = keccak256(abi.encode('MINTER_ROLE'));

  modifier ownerOrMinter() {
    require(owner() == _msgSender() || hasRole(minterRole, _msgSender()), 'must_be_owner_or_minter');
    _;
  }

  constructor(
    string memory name_,
    string memory symbol_,
    address owner_,
    uint256 maxSupply_,
    uint256 mintStartTime_
  ) Ownable() ERC721(name_, symbol_) {
    maxSupply = maxSupply_;
    mintStartTime = mintStartTime_;
    _grantRole(minterRole, _msgSender());
    _transferOwnership(owner_);
  }

  function mint(address _to, string memory _tokenURI) external nonReentrant ownerOrMinter returns (uint256 tokenId) {
    require(currentSupply <= maxSupply, 'cannot_exceed_maximum_number_of_items_in_collection');
    require(block.timestamp >= mintStartTime, 'not_open_for_minting');
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

  function addMinter(address _minter) external onlyOwner {
    require(!hasRole(minterRole, _minter), 'already_minter');
    _grantRole(minterRole, _minter);
  }

  function removeMinter(address _minter) external onlyOwner {
    require(hasRole(minterRole, _minter), 'not_a_minter');
    _revokeRole(minterRole, _minter);
  }

  function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControl, ERC721) returns (bool) {
    return interfaceId == type(IAccessControl).interfaceId || super.supportsInterface(interfaceId);
  }
}
