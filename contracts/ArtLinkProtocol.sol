// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ArtLink Protocol
 * @dev A decentralized protocol for digital art creation, marketplace, and royalty distribution
 * @notice This contract enables artists to mint, list, sell NFTs with automated royalty payments
 */
contract ArtLinkProtocol {
    
    // Structs
    struct Artwork {
        uint256 tokenId;
        address payable artist;
        string title;
        string description;
        string ipfsHash;
        uint256 price;
        uint256 royaltyPercentage;
        bool isListed;
        bool exists;
        uint256 createdAt;
        uint256 salesCount;
    }
    
    struct Artist {
        bool isVerified;
        uint256 artworksCreated;
        uint256 totalEarnings;
        uint256 reputation;
        string profileHash;
        uint256 registeredAt;
    }
    
    struct Sale {
        uint256 saleId;
        uint256 tokenId;
        address seller;
        address buyer;
        uint256 price;
        uint256 timestamp;
        bool isSecondarySale;
    }
    
    // State variables
    address public owner;
    uint256 public platformFeePercentage;
    uint256 public tokenCounter;
    uint256 public saleCounter;
    uint256 public totalVolume;
    bool private locked;
    
    // Constants
    uint256 public constant MAX_ROYALTY = 30; // 30% maximum royalty
    uint256 public constant MIN_PRICE = 0.001 ether;
    uint256 public constant VERIFICATION_FEE = 0.05 ether;
    
    // Mappings
    mapping(uint256 => Artwork) public artworks;
    mapping(uint256 => address) public tokenOwner;
    mapping(address => Artist) public artists;
    mapping(uint256 => Sale) public sales;
    mapping(address => uint256[]) public artistCreations;
    mapping(address => uint256[]) public userCollections;
    mapping(uint256 => address[]) public artworkOwnershipHistory;
    
    // Events
    event ArtworkMinted(
        uint256 indexed tokenId,
        address indexed artist,
        string title,
        uint256 price,
        uint256 timestamp
    );
    event ArtworkListed(
        uint256 indexed tokenId,
        uint256 price,
        uint256 timestamp
    );
    event ArtworkUnlisted(
        uint256 indexed tokenId,
        uint256 timestamp
    );
    event ArtworkSold(
        uint256 indexed tokenId,
        address indexed seller,
        address indexed buyer,
        uint256 price,
        uint256 royaltyPaid,
        bool isSecondarySale
    );
    event ArtistVerified(
        address indexed artist,
        uint256 timestamp
    );
    event RoyaltyPaid(
        uint256 indexed tokenId,
        address indexed artist,
        uint256 amount
    );
    event PriceUpdated(
        uint256 indexed tokenId,
        uint256 oldPrice,
        uint256 newPrice
    );
    event PlatformFeeUpdated(
        uint256 oldFee,
        uint256 newFee
    );
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "ArtLink: Caller is not the owner");
        _;
    }
    
    modifier onlyTokenOwner(uint256 tokenId) {
        require(tokenOwner[tokenId] == msg.sender, "ArtLink: Not the token owner");
        _;
    }
    
    modifier artworkExists(uint256 tokenId) {
        require(artworks[tokenId].exists, "ArtLink: Artwork does not exist");
        _;
    }
    
    modifier noReentrant() {
        require(!locked, "ArtLink: Reentrant call detected");
        locked = true;
        _;
        locked = false;
    }
    
    /**
     * @dev Constructor initializes the protocol with owner and platform fee
     */
    constructor() {
        owner = msg.sender;
        platformFeePercentage = 2; // 2% platform fee
        tokenCounter = 0;
        saleCounter = 0;
        locked = false;
    }
    
    /**
     * @dev Allows artists to register on the platform
     * @param profileHash IPFS hash of artist profile information
     */
    function registerArtist(string memory profileHash) external {
        require(!artists[msg.sender].isVerified, "ArtLink: Already registered");
        require(bytes(profileHash).length > 0, "ArtLink: Invalid profile hash");
        
        artists[msg.sender] = Artist({
            isVerified: false,
            artworksCreated: 0,
            totalEarnings: 0,
            reputation: 0,
            profileHash: profileHash,
            registeredAt: block.timestamp
        });
    }
    
    /**
     * @dev Allows artists to get verified by paying verification fee
     */
    function getVerified() external payable noReentrant {
        require(bytes(artists[msg.sender].profileHash).length > 0, "ArtLink: Must register first");
        require(!artists[msg.sender].isVerified, "ArtLink: Already verified");
        require(msg.value >= VERIFICATION_FEE, "ArtLink: Insufficient verification fee");
        
        artists[msg.sender].isVerified = true;
        
        // Transfer fee to platform
        (bool success, ) = owner.call{value: msg.value}("");
        require(success, "ArtLink: Fee transfer failed");
        
        emit ArtistVerified(msg.sender, block.timestamp);
    }
    
    /**
     * @dev Allows artists to mint new artwork as NFT
     * @param title The title of the artwork
     * @param description Description of the artwork
     * @param ipfsHash IPFS hash where artwork is stored
     * @param price Initial listing price
     * @param royaltyPercentage Royalty percentage for secondary sales (max 30%)
     */
    function mintArtwork(
        string memory title,
        string memory description,
        string memory ipfsHash,
        uint256 price,
        uint256 royaltyPercentage
    ) external returns (uint256) {
        require(bytes(artists[msg.sender].profileHash).length > 0, "ArtLink: Must register as artist");
        require(bytes(title).length > 0, "ArtLink: Title cannot be empty");
        require(bytes(ipfsHash).length > 0, "ArtLink: IPFS hash required");
        require(price >= MIN_PRICE, "ArtLink: Price too low");
        require(royaltyPercentage <= MAX_ROYALTY, "ArtLink: Royalty exceeds maximum");
        
        tokenCounter++;
        uint256 newTokenId = tokenCounter;
        
        artworks[newTokenId] = Artwork({
            tokenId: newTokenId,
            artist: payable(msg.sender),
            title: title,
            description: description,
            ipfsHash: ipfsHash,
            price: price,
            royaltyPercentage: royaltyPercentage,
            isListed: true,
            exists: true,
            createdAt: block.timestamp,
            salesCount: 0
        });
        
        tokenOwner[newTokenId] = msg.sender;
        artistCreations[msg.sender].push(newTokenId);
        userCollections[msg.sender].push(newTokenId);
        artworkOwnershipHistory[newTokenId].push(msg.sender);
        
        artists[msg.sender].artworksCreated++;
        artists[msg.sender].reputation += 10;
        
        emit ArtworkMinted(newTokenId, msg.sender, title, price, block.timestamp);
        emit ArtworkListed(newTokenId, price, block.timestamp);
        
        return newTokenId;
    }
    
    /**
     * @dev Allows token owners to list their artwork for sale
     * @param tokenId The ID of the token to list
     * @param price The listing price
     */
    function listArtwork(uint256 tokenId, uint256 price) 
        external 
        onlyTokenOwner(tokenId)
        artworkExists(tokenId) 
    {
        require(!artworks[tokenId].isListed, "ArtLink: Already listed");
        require(price >= MIN_PRICE, "ArtLink: Price too low");
        
        artworks[tokenId].isListed = true;
        artworks[tokenId].price = price;
        
        emit ArtworkListed(tokenId, price, block.timestamp);
    }
    
    /**
     * @dev Allows token owners to unlist their artwork
     * @param tokenId The ID of the token to unlist
     */
    function unlistArtwork(uint256 tokenId) 
        external 
        onlyTokenOwner(tokenId)
        artworkExists(tokenId) 
    {
        require(artworks[tokenId].isListed, "ArtLink: Not listed");
        
        artworks[tokenId].isListed = false;
        
        emit ArtworkUnlisted(tokenId, block.timestamp);
    }
    
    /**
     * @dev Allows token owners to update the price of listed artwork
     * @param tokenId The ID of the token
     * @param newPrice The new price
     */
    function updatePrice(uint256 tokenId, uint256 newPrice) 
        external 
        onlyTokenOwner(tokenId)
        artworkExists(tokenId) 
    {
        require(artworks[tokenId].isListed, "ArtLink: Not listed");
        require(newPrice >= MIN_PRICE, "ArtLink: Price too low");
        
        uint256 oldPrice = artworks[tokenId].price;
        artworks[tokenId].price = newPrice;
        
        emit PriceUpdated(tokenId, oldPrice, newPrice);
    }
    
    /**
     * @dev Allows users to purchase listed artwork
     * @param tokenId The ID of the token to purchase
     */
    function purchaseArtwork(uint256 tokenId) 
        external 
        payable 
        artworkExists(tokenId)
        noReentrant 
    {
        Artwork storage artwork = artworks[tokenId];
        require(artwork.isListed, "ArtLink: Artwork not for sale");
        require(msg.sender != tokenOwner[tokenId], "ArtLink: Cannot buy your own artwork");
        require(msg.value >= artwork.price, "ArtLink: Insufficient payment");
        
        address payable seller = payable(tokenOwner[tokenId]);
        uint256 salePrice = artwork.price;
        bool isSecondarySale = artwork.salesCount > 0;
        
        // Calculate fees
        uint256 platformFee = (salePrice * platformFeePercentage) / 100;
        uint256 royaltyFee = 0;
        uint256 sellerAmount = salePrice - platformFee;
        
        // Calculate and pay royalty if secondary sale
        if (isSecondarySale) {
            royaltyFee = (salePrice * artwork.royaltyPercentage) / 100;
            sellerAmount -= royaltyFee;
            
            // Pay royalty to original artist
            (bool royaltySuccess, ) = artwork.artist.call{value: royaltyFee}("");
            require(royaltySuccess, "ArtLink: Royalty payment failed");
            
            artists[artwork.artist].totalEarnings += royaltyFee;
            emit RoyaltyPaid(tokenId, artwork.artist, royaltyFee);
        } else {
            // First sale - artist is seller, so they get full amount minus platform fee
            artists[artwork.artist].totalEarnings += sellerAmount;
        }
        
        // Pay seller
        (bool sellerSuccess, ) = seller.call{value: sellerAmount}("");
        require(sellerSuccess, "ArtLink: Seller payment failed");
        
        // Pay platform fee
        (bool feeSuccess, ) = owner.call{value: platformFee}("");
        require(feeSuccess, "ArtLink: Platform fee payment failed");
        
        // Update ownership
        address previousOwner = tokenOwner[tokenId];
        tokenOwner[tokenId] = msg.sender;
        userCollections[msg.sender].push(tokenId);
        artworkOwnershipHistory[tokenId].push(msg.sender);
        
        // Update artwork state
        artwork.isListed = false;
        artwork.salesCount++;
        
        // Update reputation
        artists[artwork.artist].reputation += 5;
        
        // Record sale
        saleCounter++;
        sales[saleCounter] = Sale({
            saleId: saleCounter,
            tokenId: tokenId,
            seller: previousOwner,
            buyer: msg.sender,
            price: salePrice,
            timestamp: block.timestamp,
            isSecondarySale: isSecondarySale
        });
        
        totalVolume += salePrice;
        
        // Refund excess payment
        if (msg.value > salePrice) {
            (bool refundSuccess, ) = payable(msg.sender).call{value: msg.value - salePrice}("");
            require(refundSuccess, "ArtLink: Refund failed");
        }
        
        emit ArtworkSold(tokenId, previousOwner, msg.sender, salePrice, royaltyFee, isSecondarySale);
    }
    
    /**
     * @dev Returns artwork details
     * @param tokenId The ID of the artwork
     */
    function getArtwork(uint256 tokenId) 
        external 
        view 
        artworkExists(tokenId)
        returns (
            address artist,
            string memory title,
            string memory description,
            string memory ipfsHash,
            uint256 price,
            uint256 royaltyPercentage,
            bool isListed,
            uint256 salesCount
        )
    {
        Artwork memory artwork = artworks[tokenId];
        return (
            artwork.artist,
            artwork.title,
            artwork.description,
            artwork.ipfsHash,
            artwork.price,
            artwork.royaltyPercentage,
            artwork.isListed,
            artwork.salesCount
        );
    }
    
    /**
     * @dev Returns artist statistics
     * @param artistAddress The artist's address
     */
    function getArtistStats(address artistAddress) 
        external 
        view 
        returns (
            bool isVerified,
            uint256 artworksCreated,
            uint256 totalEarnings,
            uint256 reputation,
            string memory profileHash
        )
    {
        Artist memory artist = artists[artistAddress];
        return (
            artist.isVerified,
            artist.artworksCreated,
            artist.totalEarnings,
            artist.reputation,
            artist.profileHash
        );
    }
    
    /**
     * @dev Returns all artworks created by an artist
     * @param artistAddress The artist's address
     */
    function getArtistCreations(address artistAddress) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return artistCreations[artistAddress];
    }
    
    /**
     * @dev Returns all artworks owned by a user
     * @param userAddress The user's address
     */
    function getUserCollection(address userAddress) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return userCollections[userAddress];
    }
    
    /**
     * @dev Returns ownership history of an artwork
     * @param tokenId The ID of the artwork
     */
    function getOwnershipHistory(uint256 tokenId) 
        external 
        view 
        artworkExists(tokenId)
        returns (address[] memory) 
    {
        return artworkOwnershipHistory[tokenId];
    }
    
    /**
     * @dev Returns sale details
     * @param saleId The ID of the sale
     */
    function getSaleDetails(uint256 saleId) 
        external 
        view 
        returns (
            uint256 tokenId,
            address seller,
            address buyer,
            uint256 price,
            uint256 timestamp,
            bool isSecondarySale
        )
    {
        Sale memory sale = sales[saleId];
        return (
            sale.tokenId,
            sale.seller,
            sale.buyer,
            sale.price,
            sale.timestamp,
            sale.isSecondarySale
        );
    }
    
    /**
     * @dev Returns platform statistics
     */
    function getPlatformStats() 
        external 
        view 
        returns (
            uint256 totalArtworks,
            uint256 totalSales,
            uint256 volumeTraded
        )
    {
        return (tokenCounter, saleCounter, totalVolume);
    }
    
    /**
     * @dev Allows owner to update platform fee percentage
     * @param newFeePercentage New fee percentage (max 10%)
     */
    function updatePlatformFee(uint256 newFeePercentage) external onlyOwner {
        require(newFeePercentage <= 10, "ArtLink: Fee too high");
        uint256 oldFee = platformFeePercentage;
        platformFeePercentage = newFeePercentage;
        emit PlatformFeeUpdated(oldFee, newFeePercentage);
    }
    
    /**
     * @dev Allows owner to withdraw accumulated platform fees
     */
    function withdrawPlatformFees() external onlyOwner noReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "ArtLink: No fees to withdraw");
        
        (bool success, ) = owner.call{value: balance}("");
        require(success, "ArtLink: Withdrawal failed");
    }
    
    /**
     * @dev Transfers ownership of the platform to a new owner
     * @param newOwner The address of the new owner
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "ArtLink: Invalid new owner");
        owner = newOwner;
    }
    
    /**
     * @dev Returns the current owner of a token
     * @param tokenId The ID of the token
     */
    function ownerOf(uint256 tokenId) 
        external 
        view 
        artworkExists(tokenId)
        returns (address) 
    {
        return tokenOwner[tokenId];
    }
    
    /**
     * @dev Checks if an artwork is currently listed for sale
     * @param tokenId The ID of the artwork
     */
    function isListed(uint256 tokenId) 
        external 
        view 
        artworkExists(tokenId)
        returns (bool) 
    {
        return artworks[tokenId].isListed;
    }
    
    /**
     * @dev Fallback function
     */
    receive() external payable {
        revert("ArtLink: Direct transfers not allowed");
    }
}
