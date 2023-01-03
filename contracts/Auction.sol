pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import '@openzeppelin/contracts/security/Pausable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import './libraries/TransferHelpers.sol';

contract Auction is Ownable, IERC721Receiver, Pausable, ReentrancyGuard {
  using Address for address;

  uint256 public startTime;
  uint256 public endTime;
  uint256 public tokenId;
  uint256 public highestBid;
  uint256 public startPrice;

  uint8 public marketplacePercentage;

  address public collection;
  address public profitRecipient;
  address public highestBidder;
  address public bidAsset;

  modifier requirementsBeforeBid(uint256 amount) {
    require(block.timestamp >= startTime, 'auction_not_started');
    require(block.timestamp < endTime, 'auction_has_ended');

    if (highestBid == 0) {
      require(amount >= startPrice, 'must_be_greater_than_or_equal_to_start_price');
    } else {
      require(amount > highestBid, 'must_be_greater_than_highest_bid');
    }
    _;
  }

  constructor(address newOwner) {
    _transferOwnership(newOwner);
  }

  function bidEther() external payable nonReentrant requirementsBeforeBid(msg.value) whenNotPaused {
    highestBid = msg.value;
    highestBidder = _msgSender();
  }

  function bidERC20(uint256 amount) external nonReentrant requirementsBeforeBid(amount) whenNotPaused {
    require(bidAsset != address(0) && bidAsset.isContract(), 'erc20_bids_not_supported_by_this_auction');
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
