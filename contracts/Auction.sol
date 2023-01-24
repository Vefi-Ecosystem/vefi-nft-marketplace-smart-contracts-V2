pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import '@openzeppelin/contracts/security/Pausable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/interfaces/IERC2981.sol';
import './libraries/TransferHelpers.sol';

contract Auction is Ownable, IERC721Receiver, Pausable, ReentrancyGuard {
  using Address for address;
  using SafeMath for uint256;

  uint256 public immutable startTime;
  uint256 public immutable endTime;
  uint256 public immutable tokenId;
  uint256 public highestBid;
  uint256 public immutable startPrice;

  uint8 public immutable marketplacePercentage;
  uint8 public immutable collectionOwnerPercentage;

  address public immutable collection;
  address public immutable profitRecipient;
  address public highestBidder;
  address public immutable bidAsset;
  address public immutable marketplaceFeeRecipient;

  bool public isFinalized;

  event Bid(address indexed highestBidder, uint256 highestBid);
  event Finalized();

  modifier requirementsBeforeBid(uint256 amount) {
    require(block.timestamp >= startTime, 'auction_not_started');
    require(block.timestamp < endTime, 'auction_has_ended');
    require(!isFinalized, 'auction_has_been_finalized');

    if (highestBid == 0) {
      require(amount >= startPrice, 'must_be_greater_than_or_equal_to_start_price');
    } else {
      require(amount > highestBid, 'must_be_greater_than_highest_bid');
    }
    _;
  }

  constructor(
    address newOwner,
    uint256 _startTime,
    uint256 _endTime,
    address _collection,
    address _profitRecipient,
    uint256 _tokenId,
    uint256 _startPrice,
    uint8 _mpPercentage,
    uint8 _collectionOwnerPercentage,
    address _mpFeeRecipient,
    address _bidAsset
  ) {
    require(_bidAsset == address(0) || _bidAsset.isContract(), 'must_be_contract_or_zero_address');
    _transferOwnership(newOwner);
    startTime = _startTime;
    endTime = _endTime;
    collection = _collection;
    profitRecipient = _profitRecipient;
    tokenId = _tokenId;
    marketplacePercentage = _mpPercentage;
    collectionOwnerPercentage = _collectionOwnerPercentage;
    marketplaceFeeRecipient = _mpFeeRecipient;
    startPrice = _startPrice;
    bidAsset = _bidAsset;
  }

  function bidEther() external payable nonReentrant requirementsBeforeBid(msg.value) whenNotPaused {
    if (highestBidder != address(0)) {
      TransferHelpers._safeTransferEther(highestBidder, highestBid);
    }

    highestBid = msg.value;
    highestBidder = _msgSender();
    emit Bid(highestBidder, highestBid);
  }

  function bidERC20(uint256 amount) external nonReentrant requirementsBeforeBid(amount) whenNotPaused {
    require(bidAsset != address(0) && bidAsset.isContract(), 'erc20_bids_not_supported_by_this_auction');
    if (highestBidder != address(0)) TransferHelpers._safeTransferERC20(bidAsset, highestBidder, highestBid);

    require(IERC20(bidAsset).allowance(_msgSender(), address(this)) >= amount, 'not_enough_allowance');
    TransferHelpers._safeTransferFromERC20(bidAsset, _msgSender(), address(this), amount);
    highestBid = amount;
    highestBidder = _msgSender();
    emit Bid(highestBidder, highestBid);
  }

  function cancelBid() external nonReentrant {
    require(_msgSender() == highestBidder, 'must_be_highest_bidder');
    require(!isFinalized, 'already_finalized');
    TransferHelpers._safeTransferERC20(bidAsset, _msgSender(), highestBid);
    highestBidder = address(0);
    emit Bid(highestBidder, highestBid);
  }

  function finalizeAuction() external nonReentrant whenNotPaused onlyOwner {
    require(!isFinalized, 'already_finalized');
    require(block.timestamp >= endTime, 'cannot_finalize_auction_before_end_time');
    require(highestBidder != address(0), 'highest_bidder_is_zero_address');
    uint256 bal = bidAsset.isContract() && bidAsset != address(0) ? IERC20(bidAsset).balanceOf(address(this)) : address(this).balance;
    uint256 fee = bal.mul(marketplacePercentage).div(100);
    uint256 collectionOwnerFee = fee.mul(collectionOwnerPercentage).div(100);
    uint256 splitFee = fee.sub(collectionOwnerFee);
    (address royalty, uint256 royaltyValue) = IERC2981(collection).royaltyInfo(tokenId, splitFee);
    Ownable ownable = Ownable(collection);

    if (bidAsset != address(0)) {
      TransferHelpers._safeTransferERC20(bidAsset, profitRecipient, bal.sub(fee));
      TransferHelpers._safeTransferERC20(bidAsset, ownable.owner(), collectionOwnerFee);
      TransferHelpers._safeTransferERC20(bidAsset, royalty, royaltyValue);
      TransferHelpers._safeTransferERC20(bidAsset, marketplaceFeeRecipient, splitFee.sub(royaltyValue));
    } else {
      TransferHelpers._safeTransferEther(profitRecipient, bal.sub(fee));
      TransferHelpers._safeTransferEther(ownable.owner(), collectionOwnerFee);
      TransferHelpers._safeTransferEther(royalty, royaltyValue);
      TransferHelpers._safeTransferEther(marketplaceFeeRecipient, splitFee.sub(royaltyValue));
    }

    IERC721(collection).safeTransferFrom(address(this), highestBidder, tokenId);
    emit Finalized();
  }

  function onERC721Received(
    address,
    address,
    uint256,
    bytes memory
  ) public virtual override returns (bytes4) {
    return this.onERC721Received.selector;
  }
}
