pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/interfaces/IERC2981.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/access/AccessControl.sol';
import './interfaces/IMarketplace.sol';
import './libraries/TransferHelpers.sol';

contract Marketplace is Ownable, IERC721Receiver, IMarketplace, AccessControl {
  using Address for address;
  using SafeMath for uint256;

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

  event OfferItemCreated(bytes32 offerId, address creator, address collection, uint256 price, uint256 tokenId, uint256 endsIn);

  event OfferItemAccepted(bytes32 offerId);

  event OfferItemRejected(bytes32 offerId);

  event OfferItemCancelled(bytes32 offerId);

  mapping(bytes32 => AuctionItem) public _auctions;
  mapping(address => mapping(uint256 => uint256)) public _marketValue;
  mapping(bytes32 => OfferItem) public _offers;

  bytes32[] public _offerIds;
  bytes32[] public auctionIDs;

  uint256 public withdrawableBalance;

  bytes32 public withdrawerRole = keccak256(abi.encode('WITHDRAWER_ROLE'));

  constructor() {
    _grantRole(withdrawerRole, _msgSender());
  }

  function computeId(address collection, uint256 tokenId) private view returns (bytes32) {
    return keccak256(abi.encodePacked(collection, tokenId, address(this), block.timestamp));
  }

  function createAuction(
    address collection,
    uint256 tokenId,
    uint256 startingPrice,
    uint256 endsIn
  ) external returns (bytes32 auctionId) {
    require(collection.isContract());
    require(endsIn > block.timestamp && endsIn.sub(block.timestamp) >= 1 hours, 'auction_must_end_at_a_future_time_and_last_for_at_least_an_hour');
    require(IERC721(collection).ownerOf(tokenId) == _msgSender(), 'not_token_owner');
    require(IERC721(collection).isApprovedForAll(_msgSender(), address(this)), 'not_approved');
    IERC721(collection).safeTransferFrom(_msgSender(), address(this), tokenId);
    auctionId = computeId(collection, tokenId);
    _auctions[auctionId] = AuctionItem(_msgSender(), collection, startingPrice, address(0), tokenId, endsIn);
    auctionIDs.push(auctionId);
    _marketValue[collection][tokenId] = startingPrice;
    emit AuctionItemCreated(auctionId, _msgSender(), collection, startingPrice, address(0), tokenId, endsIn);
  }

  function _bidItem(bytes32 auctionId, uint256 amount) private {
    AuctionItem storage auctionItem = _auctions[auctionId];
    require(auctionItem._endsIn > block.timestamp, 'auction_ended_already');
    require(amount >= auctionItem._price, 'value_must_be_greater_than_or_equal_to_current_price');

    if (auctionItem._currentBidder != address(0)) {
      require(TransferHelpers._safeTransferEther(auctionItem._currentBidder, auctionItem._price), 'could_not_transfer_ether');
    }

    auctionItem._currentBidder = _msgSender();
    auctionItem._price = amount;

    emit AuctionItemUpdated(auctionId, amount);
  }

  function bidItem(bytes32 auctionId) external payable returns (bool) {
    _bidItem(auctionId, msg.value);
    return true;
  }

  function bulkBidItems(bytes32[] memory auctionIds, uint256[] memory amounts) external payable returns (bool) {
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
    (address royalty, uint256 royaltyValue) = IERC2981(auctionItem._collection).royaltyInfo(auctionItem._tokenId, _splitFee);

    Ownable ownable = Ownable(auctionItem._collection);

    require(TransferHelpers._safeTransferEther(auctionItem._owner, val.sub(_fee)));
    require(TransferHelpers._safeTransferEther(ownable.owner(), _collectionOwnerFee));
    require(TransferHelpers._safeTransferEther(royalty, royaltyValue));

    IERC721(auctionItem._collection).safeTransferFrom(address(this), auctionItem._currentBidder, auctionItem._tokenId);

    withdrawableBalance = withdrawableBalance.add(_splitFee.sub(royaltyValue));
    _marketValue[auctionItem._collection][auctionItem._tokenId] = val;

    delete _auctions[auctionId];
    emit AuctionItemFinalized(auctionId);
  }

  function cancelAuction(bytes32 auctionId) external {
    AuctionItem storage auctionItem = _auctions[auctionId];
    require(block.timestamp < auctionItem._endsIn, 'cannot_cancel_auction_after_end_time');
    require(auctionItem._owner == _msgSender());
    require(TransferHelpers._safeTransferEther(auctionItem._currentBidder, auctionItem._price));
    IERC721(auctionItem._collection).safeTransferFrom(address(this), auctionItem._owner, auctionItem._tokenId);
    delete _auctions[auctionId];
    emit AuctionItemCancelled(auctionId);
  }

  function _createOffer(
    address creator,
    address collection,
    uint256 tokenId,
    uint256 price,
    uint256 endsIn,
    address tokenOffered
  ) private returns (bytes32 offerId) {
    require(tokenOffered.isContract());
    require(collection.isContract());
    require(IERC20(tokenOffered).allowance(creator, address(this)) >= price, 'not_enough_allowance');
    require(price >= _marketValue[collection][tokenId], 'offer_must_be_greater_than_or_equal_to_market_value');
    require(endsIn > block.timestamp && endsIn.sub(block.timestamp) >= 1 hours, 'offer_must_end_at_a_future_time_and_must_last_at_least_an_hour');
    offerId = computeId(collection, tokenId);
    _offers[offerId] = OfferItem(creator, collection, price, tokenId, endsIn, tokenOffered);
    _offerIds.push(offerId);
    emit OfferItemCreated(offerId, creator, collection, price, tokenId, endsIn);
  }

  function createOffer(
    address collection,
    uint256 tokenId,
    uint256 price,
    uint256 endsIn,
    address tokenOffered
  ) external returns (bool) {
    _createOffer(_msgSender(), collection, tokenId, price, endsIn, tokenOffered);
    return true;
  }

  function bulkCreateOffer(
    address collection,
    uint256[] memory tokenIds,
    uint256[] memory amounts,
    uint256 endsIn,
    address tokenOffered
  ) external returns (bool) {
    require(tokenIds.length == amounts.length, 'token_ids_and_amounts_must_be_same_length');

    uint256 totalAmount;

    for (uint256 i = 0; i < amounts.length; i++) totalAmount = totalAmount.add(amounts[i]);

    require(IERC20(tokenOffered).allowance(_msgSender(), address(this)) >= totalAmount, 'not_enough_allowance');

    for (uint256 i = 0; i < tokenIds.length; i++) _createOffer(_msgSender(), collection, tokenIds[i], amounts[i], endsIn, tokenOffered);

    return true;
  }

  function acceptOffer(bytes32 offerId) external returns (bool) {
    OfferItem storage offerItem = _offers[offerId];
    require(IERC721(offerItem._collection).ownerOf(offerItem._tokenId) == _msgSender(), 'only_token_owner');
    require(offerItem._endsIn > block.timestamp, 'offer_ended');
    require(IERC721(offerItem._collection).isApprovedForAll(_msgSender(), address(this)), 'no_approval_given');

    uint256 _fee = offerItem._price.mul(9).div(100);
    uint256 _collectionOwnerFee = _fee.mul(10).div(100);
    uint256 _splitFee = _fee.sub(_collectionOwnerFee);
    (address royalty, uint256 royaltyValue) = IERC2981(offerItem._collection).royaltyInfo(offerItem._tokenId, _splitFee);

    Ownable ownable = Ownable(offerItem._collection);

    TransferHelpers._safeTransferFromERC20(offerItem._tokenOffered, offerItem._creator, _msgSender(), offerItem._price.sub(_fee));
    TransferHelpers._safeTransferFromERC20(offerItem._tokenOffered, offerItem._creator, ownable.owner(), _collectionOwnerFee);
    TransferHelpers._safeTransferFromERC20(offerItem._tokenOffered, offerItem._creator, royalty, royaltyValue);
    TransferHelpers._safeTransferFromERC20(offerItem._tokenOffered, offerItem._creator, address(this), _splitFee.sub(royaltyValue));

    IERC721(offerItem._collection).safeTransferFrom(_msgSender(), offerItem._creator, offerItem._tokenId);

    bytes32[] memory iOfferIds = _offerIds;

    for (uint256 i = 0; i < iOfferIds.length; i++) {
      OfferItem memory innerOfferItem = _offers[iOfferIds[i]];

      if (innerOfferItem._collection == offerItem._collection && innerOfferItem._tokenId == offerItem._tokenId && iOfferIds[i] != offerId) {
        delete _offers[_offerIds[i]];
        emit OfferItemCancelled(iOfferIds[i]);
      }
    }
    delete _offers[offerId];
    emit OfferItemAccepted(offerId);
    return true;
  }

  function rejectOffer(bytes32 offerId) external returns (bool) {
    OfferItem memory offerItem = _offers[offerId];
    require(IERC721(offerItem._collection).ownerOf(offerItem._tokenId) == _msgSender(), 'only_token_owner');
    delete _offers[offerId];
    emit OfferItemRejected(offerId);
    return true;
  }

  function cancelOffer(bytes32 offerId) external returns (bool) {
    OfferItem memory offerItem = _offers[offerId];
    require(offerItem._creator == _msgSender(), 'only_offer_creator');
    delete _offers[offerId];
    emit OfferItemCancelled(offerId);
    return true;
  }

  function withdrawEther(address to) external {
    require(hasRole(withdrawerRole, _msgSender()), 'only_withdrawer');
    require(TransferHelpers._safeTransferEther(to, withdrawableBalance));
    withdrawableBalance = 0;
  }

  function withdrawERC20(address token, address to) external {
    require(hasRole(withdrawerRole, _msgSender()), 'only_withdrawer');
    require(TransferHelpers._safeTransferERC20(token, to, IERC20(token).balanceOf(address(this))));
  }

  function setWithdrawer(address withdrawer) external onlyOwner {
    require(!hasRole(withdrawerRole, withdrawer), 'already_withdrawer');
    _grantRole(withdrawerRole, withdrawer);
  }

  function revokeWithdrawer(address withdrawer) external onlyOwner {
    require(hasRole(withdrawerRole, withdrawer), 'not_withdrawer');
    _revokeRole(withdrawerRole, withdrawer);
  }

  function getMarketValue(address collection, uint256 tokenId) external view returns (uint256) {
    return _marketValue[collection][tokenId];
  }

  function onERC721Received(
    address,
    address,
    uint256,
    bytes memory
  ) public virtual override returns (bytes4) {
    return this.onERC721Received.selector;
  }

  receive() external payable {
    withdrawableBalance = withdrawableBalance.add(msg.value);
  }
}
