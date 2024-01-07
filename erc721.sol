// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

// Explicit imports from OpenZeppelin
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

/*
    @title A customizable ERC721 token contract with minting and dropping functionality
    @author TOCON.IO
    @custom:security-contact support@tocon.io
*/

contract ERC721_CONTRACT is
    Initializable,
    ERC721Upgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    uint256 public supply;
    uint256 public cost;
    uint256 public maxSupply;
    uint256 public maxSupplyPerAddress;
    bool public limited;
    bool public limitedPerAddress;
    string public metadataURI;

    // @notice Reserved storage space to allow for layout changes in the future.
    // @dev This is a placeholder array of 20 uint256, used to ensure that storage layout remains compatible when the contract is upgraded.
    //      The size of 20 is arbitrary but provides ample space for future additions to the contract's state variables. 
    //      When adding new state variables in an upgrade, they should be declared before this reserved space.
    //      After adding new variables, the size of this array should be reduced accordingly to maintain the alignment of storage slots.
    uint256[20] private _gap;

    event Minted(address indexed to, uint256 indexed tokenId, uint256 indexed mintAmount);
    event Dropped(address indexed to, uint256 indexed tokenId);
    event MaxSupplyPerAddressUpdated(uint256 maxSupplyPerAddress);
    event TokenURISet(string metadataURI);
    event CostSet(uint256 cost);


error MaxSupplyExceeded();
error MaxSupplyPerAddressExceeded();
error TransactionMustBeDirect();
error InsufficientFunds();
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
        for (uint256 i = 0; i < arrayLength; i++) {
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
        for (uint256 i = 0; i < arrayLength; i++) {
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
