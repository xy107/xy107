// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC4906} from "@openzeppelin/contracts/interfaces/IERC4906.sol";
import {IXY} from "./interfaces/IXY.sol";
import {IXY107} from "./interfaces/IXY107.sol";

contract XY107 is ERC721, ReentrancyGuard, IERC4906, IXY107 {
    using Address for address payable;
    using Strings for string;
    using Strings for uint256;

    struct Metadata {
        string name;
        string description;
        /// @dev Keccak-256 of the exact, unmodified image bytes returned by the image URL.
        bytes32 imageHash;
    }

    uint256 public constant MINT_PRICE_ETH = 1 ether;
    uint256 public constant HERO_COUNT = 107;
    uint256 public constant SONGJIANG_TOKEN_ID = 1;
    uint256 public constant MAX_NAME_BYTES = 128;
    uint256 public constant MAX_DESCRIPTION_BYTES = 2_048;

    IXY public immutable override XY;
    uint256 public heroMintCount;
    string public imageBaseURI;
    mapping(uint256 => Metadata) public metadata;
    mapping(address => bool) public hasMintedHero;

    bool private _burningSongjiang;
    string private _contractUri;

    event MetadataCommitted(uint256 indexed tokenId, bytes32 indexed imageHash);
    event ImageBaseURIUpdated(string imageBaseURI);
    event ContractURIUpdated();
    event HeroMinted(address indexed minter, uint256 indexed tokenId);
    event SongjiangNftBurned();
    event EthWithdrawn(address indexed recipient, uint256 amountEth);

    error Unauthorized();
    error InvalidToken();
    error InvalidState();
    error SongjiangLocked();

    constructor(string memory name_, string memory symbol_, address xy_) ERC721(name_, symbol_) {
        if (xy_ == address(0)) revert InvalidState();
        XY = IXY(xy_);
        // The receiver is this contract, which intentionally does not implement ERC721Receiver.
        // forge-lint: disable-next-line(unsafe-oz-erc721-mint)
        _mint(address(this), SONGJIANG_TOKEN_ID);
    }

    function commitMetadata(
        uint256 tokenId,
        string calldata name_,
        string calldata description_,
        /// Keccak-256 of the exact, unmodified image bytes returned by the derived image URL.
        bytes32 imageHash_
    ) external {
        if (msg.sender != XY.operator()) revert Unauthorized();
        // Songjiang's archival record may be committed after its paired, permissionless burn.
        // All other metadata must belong to a live hero NFT.
        if (tokenId != SONGJIANG_TOKEN_ID && _ownerOf(tokenId) == address(0)) {
            revert InvalidToken();
        }
        uint256 nameLength = bytes(name_).length;
        uint256 descriptionLength = bytes(description_).length;
        if (
            nameLength == 0 || nameLength > MAX_NAME_BYTES || descriptionLength == 0
                || descriptionLength > MAX_DESCRIPTION_BYTES || imageHash_ == bytes32(0)
                || metadata[tokenId].imageHash != bytes32(0)
        ) {
            revert InvalidState();
        }
        metadata[tokenId] =
            Metadata({name: name_, description: description_, imageHash: imageHash_});
        emit MetadataCommitted(tokenId, imageHash_);
        emit MetadataUpdate(tokenId);
    }

    function setImageBaseURI(string calldata imageBaseUri_) external {
        if (msg.sender != XY.operator()) revert Unauthorized();
        bytes calldata uri = bytes(imageBaseUri_);
        if (uri.length == 0 || uri[uri.length - 1] == 0x2f) revert InvalidState();
        imageBaseURI = imageBaseUri_;
        emit ImageBaseURIUpdated(imageBaseUri_);
        // The collection's fixed upper token ID is clearer here than an extra constant.
        // forge-lint: disable-next-line(literal-instead-of-constant)
        emit BatchMetadataUpdate(SONGJIANG_TOKEN_ID, 108);
    }

    function setContractURI(string calldata contractUri_) external {
        if (msg.sender != XY.operator()) revert Unauthorized();
        if (bytes(contractUri_).length == 0) revert InvalidState();
        _contractUri = contractUri_;
        emit ContractURIUpdated();
    }

    function contractURI() external view returns (string memory) {
        return _contractUri;
    }

    function mint(uint256 tokenId) external payable nonReentrant {
        // The fixed 2–108 token range is clearer inline than as two extra constants.
        // forge-lint: disable-next-line(literal-instead-of-constant)
        if (tokenId < 2 || tokenId > 108 || msg.value != MINT_PRICE_ETH) {
            revert InvalidToken();
        }
        if (hasMintedHero[msg.sender] || _ownerOf(tokenId) != address(0)) revert InvalidState();
        // HeroMinted below records this access-control state transition.
        // forge-lint: disable-next-line(missing-events-access-control)
        hasMintedHero[msg.sender] = true;
        ++heroMintCount;
        _safeMint(msg.sender, tokenId);
        emit HeroMinted(msg.sender, tokenId);
    }

    function withdrawEth(uint256 amountEth) external nonReentrant {
        address recipient = XY.CREATOR();
        if (msg.sender != recipient) revert Unauthorized();
        if (amountEth > address(this).balance) revert InvalidState();
        emit EthWithdrawn(recipient, amountEth);
        payable(recipient).sendValue(amountEth);
    }

    function burnSongjiang() external nonReentrant {
        if (heroMintCount != HERO_COUNT) revert Unauthorized();
        if (_ownerOf(SONGJIANG_TOKEN_ID) == address(0)) revert InvalidState();
        _burningSongjiang = true;
        _burn(SONGJIANG_TOKEN_ID);
        _burningSongjiang = false;
        emit SongjiangNftBurned();
        XY.burnSongjiangLock();
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        Metadata storage tokenMetadata = metadata[tokenId];
        if (tokenMetadata.imageHash == bytes32(0)) return "";
        string memory image = bytes(imageBaseURI).length == 0
            ? ""
            : string.concat(imageBaseURI, "/", tokenId.toString());
        string memory json = string.concat(
            '{"name":"',
            tokenMetadata.name.escapeJSON(),
            '","description":"',
            tokenMetadata.description.escapeJSON(),
            '","image":"',
            image.escapeJSON(),
            '","image_hash":"',
            Strings.toHexString(uint256(tokenMetadata.imageHash), 32),
            '"}'
        );
        return string.concat("data:application/json;base64,", Base64.encode(bytes(json)));
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, IERC165)
        returns (bool)
    {
        return interfaceId == bytes4(0x49064906) || super.supportsInterface(interfaceId);
    }

    function approve(address to, uint256 tokenId) public override(ERC721, IERC721) {
        if (tokenId == SONGJIANG_TOKEN_ID) revert SongjiangLocked();
        super.approve(to, tokenId);
    }

    function _update(address to, uint256 tokenId, address auth)
        internal
        override
        returns (address)
    {
        address from = _ownerOf(tokenId);
        if (tokenId == SONGJIANG_TOKEN_ID && from != address(0) && !_burningSongjiang) {
            revert SongjiangLocked();
        }
        return super._update(to, tokenId, auth);
    }
}
