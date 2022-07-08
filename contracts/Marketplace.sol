pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/interfaces/IERC2981.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import './libraries/TransferHelpers.sol';

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

  event AuctionItemCreated(
    bytes32 auctionId,
    address creator,
    address collection,
    uint256 price,
    address currentBidder,
    uint256 tokenId,
    uint256 endsIn
  );

  event AuctionItemUpdated(bytes32 auctionId, uint256 newPrice);

  event AuctionItemFinalized(bytes32 auctionId);

  event AuctionItemCancelled(bytes32 auctionId);

  mapping(bytes32 => AuctionItem) public _auctions;
  mapping(address => mapping(uint256 => uint256)) public _marketValue;

  uint256 public withdrawableBalance;

  function computeId(address collection, uint256 tokenId) private pure returns (bytes32) {
    return keccak256(abi.encodePacked(collection, tokenId, address(this), block.timestamp));
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
    _marketValue[collection][tokenId] = startingPrice;
    emit AuctionItemCreated(auctionId, _msgSender(), collection, startingPrice, address(0), tokenId, endsIn);
  }

  function _bidItem(bytes32 auctionId, uint256 amount) private {
    AuctionItem storage auctionItem = _auctions[auctionId];
    require(auctionItem._endsIn > block.timestamp, 'auction_ended_already');
    require(amount > auctionItem._price, 'value_must_be_greater_than_current_price');

    if (auctionItem._currentBidder != address(0)) {
      require(
        TransferHelpers._safeTransferEther(auctionItem._currentBidder, auctionItem._price),
        'could_not_transfer_ether'
      );
    }

    auctionItem._currentBidder = _msgSender();
    auctionItem._price = amount;

    emit AuctionItemUpdated(auctionId, amount);
  }

  function bidItem(bytes32 auctionId) external payable returns (bool) {
    _bidItem(auctionId, msg.value);
    return true;
  }

  function bulkBidItems(bytes32[] auctionIds, uint256[] amounts) external payable returns (bool) {
    require(auctionIds.length == amounts.length, 'auction_ids_and_amounts_must_be_same_length');

    uint256 totalAmount;

    for (uint256 i = 0; i < amounts.length; i++) totalAmount = totalAmount.add(amounts[i]);

    require(totalAmount == msg.value, 'not_enough_ether_for_bulk_bid');

    for (uint256 i = 0; i < auctionIds.length; i++) _bidItem(auctionIds[i], amounts[i]);

    return true;
  }

  function finalizeAuction(bytes32 auctionId) external {
    AuctionItem storage auctionItem = _auctions[auctionId];
    require(block.timestamp >= auctionItem._endsIn, 'cannot_finalize_auction_before_end_time');
    uint256 val = auctionItem._price;
    uint256 _fee = val.mul(7).div(100);
    uint256 _collectionOwnerFee = _fee.mul(10).div(100);
    uint256 _splitFee = _fee.sub(_collectionOwnerFee);
    (address royalty, uint256 royaltyValue) = IERC2981(auctionItem._collection).royaltyInfo(
      auctionItem._tokenId,
      _splitFee
    );

    Ownable ownable = Ownable(auctionItem._collection);

    require(TransferHelpers._safeTransferEther(auctionItem._owner, val.sub(_fee)), 'could_not_transfer_ether');
    require(TransferHelpers._safeTransferEther(ownable.owner(), _collectionOwnerFee), 'could_not_transfer_ether');
    require(TransferHelpers._safeTransferEther(royalty, royaltyValue), 'could_not_transfer_ether');

    IERC721(auctionItem._collection).safeTransferFrom(address(this), auctionItem._currentBidder, auctionItem._tokenId);

    withdrawableBalance = withdrawableBalance.add(_splitFee.sub(royaltyValue));
    _marketValue[auctionItem._collection][auctionItem._tokenId] = val;

    emit AuctionItemFinalized(auctionId);

    delete _auctions[auctionId];
  }

  function cancelAuction(bytes32 auctionId) external {
    AuctionItem storage auctionItem = _auctions[auctionId];
    require(block.timestamp < auctionItem._endsIn, 'cannot_cancel_auction_after_end_time');
    require(auctionItem._owner == _msgSender(), 'must_be_token_owner');
    require(
      TransferHelpers._safeTransferEther(auctionItem._currentBidder, auctionItem._price),
      'could_not_transfer_ether'
    );
    IERC721(auctionItem._collection).safeTransferFrom(address(this), auctionItem._owner, auctionItem._tokenId);

    emit AuctionItemCancelled(auctionId);

    delete _auctions[auctionId];
  }
}
