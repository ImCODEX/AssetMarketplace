// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Asset is ERC721, Ownable, ReentrancyGuard {
    uint256 private _currentTokenId = 0;

    mapping(address => bool) private authorizedOwners;
    AggregatorV3Interface internal priceFeedEUR;

    struct AssetData {
        string assetType;
        string assetDetails;
        string assetURI;
        uint256 priceEUR;
    }

    mapping(uint256 => AssetData) public assets;
    mapping(uint256 => uint256) public totalShares; // totalShares
    mapping(uint256 => mapping(address => uint256))
        public partialOwnershipShares; // mapping of asset ID to mapping of address to partial ownership shares

    event AssetInstanceCreated(string assetType, uint256 tokenId);
    event AssetPurchased(
        address indexed buyer,
        uint256 assetId,
        uint256 shares,
        uint256 price
    );
    event PartialOwnershipTransferred(
        uint256 assetId,
        address indexed from,
        address indexed to,
        uint256 shares
    );

    constructor(
        string memory name,
        string memory symbol,
        address _priceFeedEUR
    ) ERC721(name, symbol) {
        priceFeedEUR = AggregatorV3Interface(_priceFeedEUR);
    }

    // Other functions and modifiers ...

    modifier onlyAuthorizedOwner() {
    require(authorizedOwners[msg.sender], "Caller is not an authorized owner");
    _;
    }

    function addAuthorizedOwner(address newOwner) public onlyOwner {
    authorizedOwners[newOwner] = true;
    }

    function removeAuthorizedOwner(address ownerToRemove) public onlyOwner {
    authorizedOwners[ownerToRemove] = false;
    }

    function transferPartialOwnership(uint256 assetId, address newOwner, uint256 shares) public onlyAuthorizedOwner {
        require(_exists(assetId), "Asset: nonexistent token");
        require(partialOwnershipShares[assetId][msg.sender] >= shares, "Asset: insufficient ownership to transfer");
        partialOwnershipShares[assetId][msg.sender] -= shares;
        partialOwnershipShares[assetId][newOwner] += shares;
        emit PartialOwnershipTransferred(assetId, msg.sender, newOwner, shares);
    }

    function createAsset(string memory assetType, string memory assetDetails, string memory assetURI, uint256 _totalShares, uint256 priceEUR) public onlyAuthorizedOwner returns (uint256) {
        require(bytes(assetType).length > 0, "Asset: assetType must not be empty");
        require(bytes(assetDetails).length > 0, "Asset: assetDetails must not be empty");
        require(bytes(assetURI).length > 0, "Asset: assetURI must not be empty");
        require(_totalShares > 0, "Asset: _totalShares must be greater than 0");
        require(priceEUR > 0, "Asset: priceEUR must be greater than 0");
        uint256 newTokenId = _currentTokenId + 1;
        _mint(msg.sender, newTokenId);
        assets[newTokenId] = AssetData(
            assetType,
            assetDetails,
            assetURI,
            priceEUR
        );
        partialOwnershipShares[newTokenId][msg.sender] = _totalShares; // set the owner's partial ownership to the total shares
        totalShares[newTokenId] = _totalShares;
        _currentTokenId = newTokenId;

        emit AssetInstanceCreated(assetType, newTokenId);

        return newTokenId;
    }
   
    function buyAssetShares(uint256 assetId, uint256 shares) public payable {
        require(_exists(assetId), "Asset: nonexistent token");

        uint256 pricePerShareEUR = assets[assetId].priceEUR;
        uint256 pricePerShareETH = convertEURtoETH(pricePerShareEUR);
        uint256 totalPrice = pricePerShareETH * shares;

        require(msg.value >= totalPrice, "Asset: Insufficient funds sent");
        require(shares > 0, "Asset: Shares must be greater than 0");
        uint256 remainingEther = msg.value - totalPrice;
        if (remainingEther > 0) {
            // Return any remaining Ether to the buyer
            payable(msg.sender).transfer(remainingEther);
        }

        // Transfer the payment to the owner of the Asset
        address assetOwner = ownerOf(assetId);
        payable(assetOwner).transfer(totalPrice);

        // Transfer the partial ownership shares
        transferPartialOwnership(assetId, msg.sender, shares);

        emit AssetPurchased(msg.sender, assetId, shares, totalPrice);
    }

    function convertEURtoETH(uint256 amountEUR) internal view returns (uint256) {
        (, int256 price, , , ) = priceFeedEUR.latestRoundData();
        require(price > 0, "Asset: Failed to get the ETH price");
        uint256 priceETH = uint256(price);
        uint256 amountETH = (amountEUR * 1e18) / priceETH;
        return amountETH;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "Asset: URI query for nonexistent token");
        return assets[tokenId].assetURI;
    }

    function getPartialOwnership(uint256 assetId, address owner) public view returns (uint256) {
        return partialOwnershipShares[assetId][owner];
    }

    function getTotalShares(uint256 assetId) public view returns (uint256) {
        return totalShares[assetId];
    }

    function getPricePerShare(uint256 assetId) public view returns (uint256) {
        uint256 pricePerShareEUR = assets[assetId].priceEUR;
        uint256 pricePerShareETH = convertEURtoETH(pricePerShareEUR);
        return pricePerShareETH;
    }
}
