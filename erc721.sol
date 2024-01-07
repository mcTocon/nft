// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

/*
@author TOCON.IO
@custom:security-contact support@tocon.io
______________________________________________________________________________________________________        
_______________________________________________________________________________________________________       
_______/\\\__________________________________________________________________________/\\\_______________      
_____/\\\\\\\\\\\_____/\\\\\________/\\\\\\\\_____/\\\\\_____/\\/\\\\\\______________\///______/\\\\\____     
_____\////\\\////____/\\\///\\\____/\\\//////____/\\\///\\\__\/\\\////\\\______________/\\\___/\\\///\\\__    
_________\/\\\_______/\\\__\//\\\__/\\\__________/\\\__\//\\\_\/\\\__\//\\\____________\/\\\__/\\\__\//\\\_   
__________\/\\\_/\\__\//\\\__/\\\__\//\\\________\//\\\__/\\\__\/\\\___\/\\\____________\/\\\_\//\\\__/\\\__  
___________\//\\\\\____\///\\\\\/____\///\\\\\\\\__\///\\\\\/___\/\\\___\/\\\____/\\\____\/\\\__\///\\\\\/___ 
_____________\/////_______\/////________\////////_____\/////_____\///____\///____\///_____\///_____\/////_____
_______________________________________________________________________________________________________________                 
*/  

// Explicit imports from OpenZeppelin
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

/// @title A customizable ERC721 token contract with minting and dropping functionality
contract ERC721_CONTRACT is
    Initializable,
    ERC721Upgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
/// @notice Total number of tokens minted
    uint256 public supply;

/// @notice Cost to mint each token
    uint256 public cost;

/// @notice Maximum number of tokens that can be minted
    uint256 public maxSupply;

/// @notice Maximum number of tokens that can be owned by a single address
    uint256 public maxSupplyPerAddress;

/// @notice Flag indicating if the token has a limited supply
    bool public limited;

/// @notice Flag indicating if there is a limit per address
    bool public limitedPerAddress;

/// @notice Base URI for token metadata
    string public metadataURI;

// @notice Reserved storage space to allow for layout changes in the future.
// @dev This is a placeholder array of 20 uint256, used to ensure that storage layout remains compatible when the contract is upgraded.
//      The size of 20 is arbitrary but provides ample space for future additions to the contract's state variables. 
//      When adding new state variables in an upgrade, they should be declared before this reserved space.
//      After adding new variables, the size of this array should be reduced accordingly to maintain the alignment of storage slots.
    uint256[20] private _gap;



/// @notice Emitted when a new token is minted.
/// @param to The address receiving the minted token.
/// @param tokenId The unique identifier for the minted token.
/// @param mintAmount The amount of tokens minted in this transaction.
    event Minted(address indexed to, uint256 indexed tokenId, uint256 indexed mintAmount);

/// @notice Emitted when a token is dropped.
/// @param to The address receiving the dropped token.
/// @param tokenId The unique identifier for the dropped token.
    event Dropped(address indexed to, uint256 indexed tokenId);

/// @notice Emitted when the cost of the token is set.
/// @param cost The new cost of the token.
    event CostSet(uint256 indexed  cost);

/// @notice Emitted when the token URI is set.
/// @param metadataURI The URI pointing to the token metadata.
    event TokenURISet(string indexed  metadataURI);

/// @notice Emitted when the maximum supply per address is updated.
/// @param maxSupplyPerAddress The new maximum supply limit per address.
    event MaxSupplyPerAddressUpdated(uint256 indexed  maxSupplyPerAddress);
    
/// @notice Error thrown when an attempt is made to mint more than the maximum supply.
    error MaxSupplyExceeded();
/// @notice Error thrown when an attempt is made to mint more than the allowed maximum supply per address.
    error MaxSupplyPerAddressExceeded();
/// @notice Error thrown when a transaction is not sent directly by an EOA (Externally Owned Account).
    error TransactionMustBeDirect();
/// @notice Error thrown when the funds sent with a transaction are insufficient.
    error InsufficientFunds();
/// @notice Error thrown when there are no funds available for a requested operation.
    error NoFundsAvailable();

/*
    @notice Initializes the contract with necessary parameters
    @param owner The address of the contract owner
    @param _metadataURI The base URI for token metadata
    @param _name The name of the ERC721 token
    @param _symbol The symbol of the ERC721 token
    @param _cost The cost of minting each token
    @param _maxSupply The maximum supply of tokens
    @param _maxSupplyPerAddress The maximum number of tokens that can be owned by a single address
    @param _limited Flag indicating if the token has a limited supply
    @param _limitedPerAddress Flag indicating if there is a limit per address
*/
    function initialize(
        address owner,
        string memory _metadataURI,
        string memory _name,
        string memory _symbol,
        uint256 _cost,
        uint256 _maxSupply,
        uint256 _maxSupplyPerAddress,
        bool _limited,
        bool _limitedPerAddress
    ) external initializer {
        __ERC721_init(_name, _symbol);
        __Ownable_init(owner);
        metadataURI = _metadataURI;
        cost = _cost;
        maxSupply = _maxSupply;
        limited = _limited;
        if (!_limited) {
            maxSupply = type(uint256).max;
        }
        maxSupplyPerAddress = _maxSupplyPerAddress;
        limitedPerAddress = _limitedPerAddress;
        if (!_limitedPerAddress) {
            maxSupplyPerAddress = type(uint256).max;
        }
        _disableInitializers();
    }

/// @dev Ensures minting does not exceed the max supply
    modifier mintRequirements(uint256 _mintAmount) {
        if (limited) {
            if (supply + _mintAmount > maxSupply) revert MaxSupplyExceeded();
        }
        _;
    }

/// @notice Mints new tokens
/// @dev Mints a specified amount of tokens to a given address
/// @param _mintAmount The number of tokens to mint
/// @param _to The address to mint the tokens to
    function mint(uint256 _mintAmount, address _to)
        external
        payable
        mintRequirements(_mintAmount)
        nonReentrant
    {
        if (msg.sender != _to) revert TransactionMustBeDirect();
        if (msg.sender != owner()) {
            if (msg.value < cost * _mintAmount) revert InsufficientFunds();
            if (IERC721(this).balanceOf(_to) + _mintAmount > maxSupplyPerAddress) revert MaxSupplyPerAddressExceeded();
            
        }
        uint256 arrayLength = _mintAmount;
        for (uint256 i = 0; i < arrayLength; ++i) {
            unchecked {
                supply++;
            }
            _safeMint(_to, supply);
            emit Minted(_to, supply, _mintAmount);
        }
    }

/// @notice Drops tokens to multiple addresses
/// @param _receivers An array of addresses to receive the tokens
    function drop(address[] memory _receivers)
        external
        mintRequirements(_receivers.length)
        onlyOwner
    {
        uint256 arrayLength = _receivers.length;
        for (uint256 i = 0; i < arrayLength; ++i) {
            unchecked {
                supply++;
            }
            _safeMint(_receivers[i], supply);
            emit Dropped(_receivers[i], supply);
        }
    }

/// @notice Sets the maximum supply of tokens per address
/// @param _maxSupplyPerAddress The new maximum supply per address
    function setMaxSupplyPerAddress(uint256 _maxSupplyPerAddress)
        external
        onlyOwner
    {
        maxSupplyPerAddress = _maxSupplyPerAddress;
        emit MaxSupplyPerAddressUpdated(_maxSupplyPerAddress);

    }

/// @notice Updates the base URI for token metadata
/// @param _metadataURI The new base URI
    function setTokenURI(string memory _metadataURI) external onlyOwner {
        metadataURI = _metadataURI;
        emit TokenURISet(_metadataURI);
    }

/// @notice Sets the cost of minting a token
/// @param _cost The new cost per token
    function setCost(uint256 _cost) external onlyOwner {
        cost = _cost;
        emit CostSet(_cost);
    }

/// @notice Returns the URI for a given token's metadata
/// @return The URI of the token's metadata
    function _tokenURI() external view returns (string memory) {
        return metadataURI;
    }

/// @notice Withdraws the contract's balance to the owner's address
/// @dev Can only be called by the contract owner and is non-reentrant
    function withdraw() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        if (balance == 0) revert NoFundsAvailable();
        AddressUpgradeable.sendValue(payable(owner()), balance);
    }
}


