// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

contract ERC721_CONTRACT is
    Initializable,
    ERC721Upgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable  
{
    uint256 public supply;
    uint256 public cost;
    uint256 public maxSupply;
    bool public limited;
    string public metadataURI;

    event Minted(address indexed to, uint256 indexed tokenId, uint256 indexed mintAmount);
    event Dropped(address indexed to, uint256 indexed tokenId);

    function initialize(
        address owner,
        string memory _metadataURI,
        string memory _name,
        string memory _symbol,
        uint256 _cost,
        uint256 _maxSupply,
        bool _limited
    ) external initializer {
        __ERC721_init(_name, _symbol);
        __Ownable_init(owner);
        metadataURI = _metadataURI;
        cost = _cost;
        maxSupply = _maxSupply;
        limited = _limited;
        if(!_limited){
        maxSupply = type(uint256).max;
        }
    }

    modifier mintRequirements(uint256 _mintAmount) {
        if (limited) {
            require(
                supply + _mintAmount <= maxSupply,
                "Max supply exceeded!"
            );
        }
        _;
    }

    function mint(uint256 _mintAmount, address _to) public payable mintRequirements(_mintAmount) nonReentrant {
        require(msg.sender == tx.origin, "The transaction must be sent directly from an EOA.");
        if (msg.sender != owner()) {
            require(msg.value >= cost * _mintAmount, "Insufficient funds!");
        }
        for (uint256 i = 0; i < _mintAmount; i++) {
            supply++;
            _safeMint(_to, supply);
            emit Minted(_to, supply, _mintAmount); 
        }
    }

    function Drop(address[] memory _receivers) external mintRequirements( _receivers.length) {
        for (uint256 i = 0; i < _receivers.length; i++) {
           supply++;
            _safeMint(_receivers[i], supply); 
            emit Dropped(_receivers[i], supply);   
        }
    }

    function setTokenURI(string memory _metadataURI) public onlyOwner {
        metadataURI = _metadataURI;
    }

    function setCost(uint256 _cost) public onlyOwner {
        cost = _cost;
    }

    function tokenURI(uint256) public view override returns (string memory) {
         return metadataURI;
    }
     
    function withdraw() public onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds available for withdrawal");
        payable(owner()).transfer(balance);
    }

}
