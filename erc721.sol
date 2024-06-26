// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

/// @title A customizable ERC721 token contract.
/// @author TOCON.IO.
/// @custom:security-contact security@tocon.io

///_______________________________________________________________________________________________________
////______/\\\__________________________________________________________________________/\\\_______________
/////___/\\\\\\\\\\\_____/\\\\\________/\\\\\\\\_____/\\\\\_____/\\/\\\\\\______________\///______/\\\\\____
//////__\////\\\////____/\\\///\\\____/\\\//////____/\\\///\\\__\/\\\////\\\______________/\\\___/\\\///\\\__
///////_____\/\\\_______/\\\__\//\\\__/\\\__________/\\\__\//\\\_\/\\\__\//\\\____________\/\\\__/\\\__\//\\\_
////////_____\/\\\_/\\__\//\\\__/\\\__\//\\\________\//\\\__/\\\__\/\\\___\/\\\____________\/\\\_\//\\\__/\\\__
/////////_____\//\\\\\____\///\\\\\/____\///\\\\\\\\__\///\\\\\/___\/\\\___\/\\\____/\\\____\/\\\__\///\\\\\/___
//////////______\/////_______\/////________\////////_____\/////_____\///____\///____\///_____\///_____\/////_____
///////////_______________________________________________________________________________________________________

// Explicit imports from OpenZeppelin.
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/// @title A customizable ERC721 token contract with minting and dropping functionality.
contract ERC721_CONTRACT is
    Initializable,
    ERC721Upgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    // =========================================== State Variables ===========================================

    /// @notice Total number of tokens minted.
    uint256 public supply;

    /// @notice Cost to mint each token.
    uint256 public cost;

    /// @notice Maximum number of tokens that can be minted.
    uint256 public maxSupply;

    /// @notice Maximum number of tokens that can be owned by a single address.
    uint256 public maxSupplyPerAddress;

    /// @notice Flag indicating if the token has a limited supply.
    bool public limited;

    /// @notice Flag indicating if there is a limit per address.
    bool public limitedPerAddress;
    
    /// @notice Flag indicating if the mint function is currently paused.
    bool public pause;

    /// @notice Base URI for token metadata.
    string public metadataURI;

    /// @notice Tracks balance of tokens minted per address.
    mapping(address account => uint256 balance) public mintedBalance;

    // @notice Reserved storage space to allow for layout changes in the future.
    // @dev This is a placeholder array of 20 uint256, used to ensure that storage layout remains compatible when the contract is upgraded.
    //      The size of 20 is arbitrary but provides ample space for future additions to the contract's state variables.
    //      When adding new state variables in an upgrade, they should be declared before this reserved space.
    //      After adding new variables, the size of this array should be reduced accordingly to maintain the alignment of storage slots.
    uint256[20] private _gap;

    // ============================================== Events ==============================================

    /// @notice Emitted when the contract is initialized.
    /// @param owner The address of the contract owner.
    /// @param metadataURI The base URI for token metadata.
    /// @param name The name of the ERC721 token.
    /// @param symbol The symbol of the ERC721 token.
    /// @param cost The cost of minting each token.
    /// @param maxSupply The maximum supply of tokens.
    /// @param maxSupplyPerAddress The maximum number of tokens that can be owned by a single address.
    /// @param limited Flag indicating if the token has a limited supply.
    /// @param limitedPerAddress Flag indicating if there is a limit per address.
    event ERC721Initialized(
        address indexed owner,
        string metadataURI,
        string indexed name,
        string indexed symbol,
        uint256 cost,
        uint256 maxSupply,
        uint256 maxSupplyPerAddress,
        bool limited,
        bool limitedPerAddress
    );

    /// @notice Emitted when a new token is minted.
    /// @param to The address receiving the minted token.
    /// @param tokenId The unique identifier for the minted token.
    /// @param mintAmount The amount of tokens minted in this transaction.
    event Minted(
        address indexed to,
        uint256 indexed tokenId,
        uint256 indexed mintAmount
    );

    /// @notice Emitted when a token is dropped.
    /// @param to The address receiving the dropped token.
    /// @param tokenId The unique identifier for the dropped token.
    event Dropped(address indexed to, uint256 indexed tokenId);

    /// @notice Emitted when a token is burned.
    /// @param tokenId The unique identifier for the burned token.
    event Burned(uint256 indexed tokenId);

    /// @notice Emitted when the cost of the token is set.
    /// @param cost The new cost of the token.
    event CostSet(uint256 indexed cost);

    /// @notice Emitted when the token URI is set.
    /// @param metadataURI The URI pointing to the token metadata.
    event TokenURISet(string indexed metadataURI);

    /// @notice Emitted when the maximum supply per address is updated.
    /// @param maxSupplyPerAddress The new maximum supply limit per address.
    event MaxSupplyPerAddressUpdated(uint256 indexed maxSupplyPerAddress);

    /// @notice Emitted when the contract pause state is changed.
    /// @param pause The new pause state of the contract.
    event pausedContract(bool indexed pause);

    // ============================================== Errors ==============================================

    /// @notice Error thrown when an attempt is made to mint more than the maximum supply.
    error MaxSupplyExceeded();
    /// @notice Error thrown when the maximum supply per address is exceeded.
    error MaxSupplyPerAddressExceeded();
    /// @notice Error thrown when a transaction is not sent directly.
    error TransactionMustBeDirect();
    /// @notice Error thrown when there are no funds available for a requested operation.
    error NoFundsAvailable();
    /// @notice Error thrown when unauthorized access attempts occur.
    error UnauthorizedAccess();
    /// @notice Error thrown when failing to send funds.
    error WithdrawFailed();
    /// @notice Error thrown when the contract is paused.
    error Paused();

    // ============================================ initialize ============================================

    /// @notice Initializes the contract with necessary parameters.
    /// @param owner The address of the contract owner.
    /// @param _metadataURI The base URI for token metadata.
    /// @param _name The name of the ERC721 token.
    /// @param _symbol The symbol of the ERC721 token.
    /// @param _cost The cost of minting each token.
    /// @param _maxSupply The maximum supply of tokens.
    /// @param _maxSupplyPerAddress The maximum number of tokens that can be owned by a single address.
    /// @param _limited Flag indicating if the token has a limited supply.
    /// @param _limitedPerAddress Flag indicating if there is a limit per address.
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
        limitedPerAddress = _limitedPerAddress;
        if (!_limitedPerAddress || _maxSupplyPerAddress > maxSupply) {
            maxSupplyPerAddress = maxSupply;
        } else {
            maxSupplyPerAddress = _maxSupplyPerAddress;
        }
        emit ERC721Initialized(
            owner,
            metadataURI,
            _name,
            _symbol,
            cost,
            maxSupply,
            maxSupplyPerAddress,
            limited,
            limitedPerAddress
        );
    }

    // ============================================ Modifiers ============================================

    /// @dev Ensures minting does not exceed the max supply.
    modifier mintRequirements(uint256 _mintAmount) {
        if (limited) {
            if (supply + _mintAmount > maxSupply) revert MaxSupplyExceeded();
        }
        _;
    }

    /// @dev Ensures transactions meet user permission criteria for minting.
    modifier userPermissions(uint256 _mintAmount, address _to) {
        if (msg.sender != owner()) {
            if (msg.sender != _to) revert TransactionMustBeDirect();
            if (msg.value < cost * _mintAmount) revert NoFundsAvailable();
            if (limitedPerAddress) {
                if (
                    IERC721(this).balanceOf(_to) + _mintAmount >
                    maxSupplyPerAddress ||
                    mintedBalance[_to] + _mintAmount > maxSupplyPerAddress
                ) revert MaxSupplyPerAddressExceeded();
            }
        }
        _;
    }

    // ============================================ Functions ============================================

    /// @notice Mints new tokens.
    /// @dev Mints a specified amount of tokens to a given address.
    /// @param _mintAmount The number of tokens to mint.
    /// @param _to The address to mint the tokens to.
    function mint(uint256 _mintAmount, address _to)
        external
        payable
        mintRequirements(_mintAmount)
        userPermissions(_mintAmount, _to)
        nonReentrant
    {
        if (pause) revert Paused();
        uint256 arrayLength = _mintAmount;
        for (uint256 i = 0; i < arrayLength; ++i) {
            supply++;
            _safeMint(_to, supply);
            mintedBalance[_to] += 1;
            emit Minted(_to, supply, _mintAmount);
        }
    }

    /// @notice Drops tokens to multiple addresses.
    /// @param _receivers An array of addresses to receive the tokens.
    function drop(address[] memory _receivers)
        external
        mintRequirements(_receivers.length)
        onlyOwner
    {
        uint256 arrayLength = _receivers.length;
        for (uint256 i = 0; i < arrayLength; ++i) {
            supply++;
            _safeMint(_receivers[i], supply);
            mintedBalance[_receivers[i]] += 1;
            emit Dropped(_receivers[i], supply);
        }
    }

    /// @notice Burns a specific token by its unique token ID.
    /// @param _tokenId The unique identifier for the token to be burned.
    function burn(uint256 _tokenId) external {
        address tokenOwner = ownerOf(_tokenId);
        if (msg.sender != owner() && msg.sender != tokenOwner)
            revert UnauthorizedAccess();
        _burn(_tokenId);
        mintedBalance[tokenOwner] -= 1;
        emit Burned(_tokenId);
    }

    /// @notice Sets the maximum supply of tokens per address.
    /// @dev Can only be called by the contract owner.
    /// @param _maxSupplyPerAddress The new maximum supply per address.
    function setMaxSupplyPerAddress(uint256 _maxSupplyPerAddress)
        external
        onlyOwner
    {
        if (_maxSupplyPerAddress > maxSupply)
            revert MaxSupplyPerAddressExceeded();
        limitedPerAddress = true;
        maxSupplyPerAddress = _maxSupplyPerAddress;
        emit MaxSupplyPerAddressUpdated(_maxSupplyPerAddress);
    }

    /// @notice Updates the base URI for token metadata.
    /// @dev Can only be called by the contract owner.
    /// @param _metadataURI The new base URI.
    function setTokenURI(string memory _metadataURI) external onlyOwner {
        metadataURI = _metadataURI;
        emit TokenURISet(_metadataURI);
    }

    /// @notice Sets the cost of minting a token.
    /// @dev Can only be called by the contract owner.
    /// @param _cost The new cost per token.
    function setCost(uint256 _cost) external onlyOwner {
        cost = _cost;
        emit CostSet(_cost);
    }

    /// @notice Sets the pause state of the mint function.
    /// @dev Can only be called by the contract owner.
    /// @param _pause The new pause state for the mint function.
    function setPause(bool _pause) external onlyOwner {
        pause = _pause;
        emit pausedContract(_pause);
    }

    /// @notice Returns the URI for a given token's metadata.
    /// @return The URI of the token's metadata.
    function tokenURI(uint256)
        public
        view
        virtual
        override
        returns (string memory)
    {
        return metadataURI;
    }

    /// @notice Withdraws the contract's balance to the owner's address.
    /// @dev Can only be called by the contract owner and is non-reentrant.
    function withdraw() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        if (balance == 0) revert NoFundsAvailable();
        (bool sent, ) = owner().call{value: balance}("");
        if (!sent) revert WithdrawFailed();
    }
}
