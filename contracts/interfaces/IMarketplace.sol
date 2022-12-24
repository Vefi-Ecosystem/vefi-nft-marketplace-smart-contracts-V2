pragma solidity ^0.8.0;

interface IMarketplace {
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
    uint256 _tokenId;
    uint256 _endsIn;
  }

  function withdrawableBalance() external view returns (uint256);

  function withdrawerRole() external view returns (bytes32);

  function auctionIDs(uint256) external view returns (bytes32);

  function _auctions(bytes32)
    external
    view
    returns (
      address,
      address,
      uint256,
      address,
      uint256,
      uint256
    );
}
