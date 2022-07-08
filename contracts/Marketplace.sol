pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract MarketPlace is Ownable {
  using Address for address;
  using SafeMath for uint256;

  struct AuctionItem {
    address _owner;
    address _collection;
    uint256 _price;
    address _currentBidder;
    uint256 _tokenId;
    uint256 _endsIn;
  }

  struct OfferItem {
    address _creator;
    address _collection;
    uint256 _price;
    address _tokenId;
    uint256 _endsIn;
  }

  mapping(bytes32 => AuctionItem) public _auctions;
  mapping(bytes32 => uint256) public _marketValue;

  function computeId(address collection, uint256 tokenId) private pure returns (bytes32) {
    return keccak256(abi.encodePacked(collection, tokenId));
  }

  function createAuction(
    address collection,
    uint256 tokenId,
    uint256 startingPrice,
    uint256 endsIn
  ) external returns (bytes32 auctionId) {
    require(collection.isContract(), 'call_to_non_contract');
    require(
      endsIn > block.timestamp && endsIn.sub(block.timestamp) >= 1 hours,
      'auction_must_end_at_a_future_time_and_last_for_at_least_an_hour'
    );
    require(IERC721(collection).ownerOf(tokenId) == _msgSender(), 'not_token_owner');
    require(IERC721(collection).isApprovedForAll(_msgSender(), address(this)), 'not_approved');
    IERC721(collection).safeTransferFrom(_msgSender(), address(this), tokenId);
    auctionId = computeId(collection, tokenId);
    _auctions[auctionId] = AuctionItem(_msgSender(), collection, startingPrice, address(0), tokenId, endsIn);
    _marketValue[auctionId] = startingPrice;
  }
}
