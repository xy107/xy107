// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {BaseTest} from "./Base.t.sol";
import {XY} from "../src/XY.sol";
import {XY107} from "../src/XY107.sol";

contract XY107Test is BaseTest {
    string internal constant NAME = "Hero \"Two\"";
    string internal constant DESCRIPTION = "Rain\\water\nhero";
    string internal constant IMAGE_BASE_URI = "https://images.xy.example";
    bytes32 internal constant IMAGE_HASH = keccak256("hero-image-bytes");

    function testConstructorCreatesLockedSongjiangNft() public view {
        assertEq(nft.name(), "XY107");
        assertEq(nft.symbol(), "XY107");
        assertEq(address(nft.XY()), address(xy));
        assertEq(nft.ownerOf(1), address(nft));
        assertTrue(nft.supportsInterface(0x49064906));
        assertTrue(nft.supportsInterface(0x80ac58cd));
        assertFalse(nft.supportsInterface(0xffffffff));
    }

    function testConstructorRejectsZeroXy() public {
        vm.expectRevert(XY107.InvalidState.selector);
        new XY107("XY107", "XY107", address(0));
    }

    function testCommitMetadataBuildsEscapedOnChainJson() public {
        _mint(alice, 2);
        vm.prank(creator);
        nft.commitMetadata(2, NAME, DESCRIPTION, IMAGE_HASH);
        assertEq(nft.tokenURI(2), _expectedTokenUri(""));

        vm.prank(creator);
        nft.setImageBaseURI(IMAGE_BASE_URI);
        assertEq(nft.tokenURI(2), _expectedTokenUri(IMAGE_BASE_URI));
    }

    function testCommitMetadataRejectsUnauthorizedAndMissingTokens() public {
        vm.prank(alice);
        vm.expectRevert(XY107.Unauthorized.selector);
        nft.commitMetadata(2, NAME, DESCRIPTION, IMAGE_HASH);

        vm.prank(creator);
        vm.expectRevert(XY107.InvalidToken.selector);
        nft.commitMetadata(2, NAME, DESCRIPTION, IMAGE_HASH);
    }

    function testCommitMetadataValidatesEveryFieldAndIsImmutable() public {
        _mint(alice, 2);
        string memory longName = _repeat("n", nft.MAX_NAME_BYTES() + 1);
        string memory longDescription = _repeat("d", nft.MAX_DESCRIPTION_BYTES() + 1);

        vm.startPrank(creator);
        vm.expectRevert(XY107.InvalidState.selector);
        nft.commitMetadata(2, "", DESCRIPTION, IMAGE_HASH);
        vm.expectRevert(XY107.InvalidState.selector);
        nft.commitMetadata(2, longName, DESCRIPTION, IMAGE_HASH);
        vm.expectRevert(XY107.InvalidState.selector);
        nft.commitMetadata(2, NAME, "", IMAGE_HASH);
        vm.expectRevert(XY107.InvalidState.selector);
        nft.commitMetadata(2, NAME, longDescription, IMAGE_HASH);
        vm.expectRevert(XY107.InvalidState.selector);
        nft.commitMetadata(2, NAME, DESCRIPTION, bytes32(0));

        nft.commitMetadata(2, NAME, DESCRIPTION, IMAGE_HASH);
        vm.expectRevert(XY107.InvalidState.selector);
        nft.commitMetadata(2, NAME, DESCRIPTION, keccak256("replacement"));
        vm.stopPrank();
    }

    function testImageBaseUriCanOnlyBeSetByOperator() public {
        vm.prank(alice);
        vm.expectRevert(XY107.Unauthorized.selector);
        nft.setImageBaseURI(IMAGE_BASE_URI);

        vm.startPrank(creator);
        vm.expectRevert(XY107.InvalidState.selector);
        nft.setImageBaseURI("");
        vm.expectRevert(XY107.InvalidState.selector);
        nft.setImageBaseURI("https://images.xy.example/");
        nft.setImageBaseURI(IMAGE_BASE_URI);
        vm.stopPrank();
        assertEq(nft.imageBaseURI(), IMAGE_BASE_URI);
    }

    function testContractUriCanOnlyBeSetByOperator() public {
        assertEq(nft.contractURI(), "");
        vm.prank(alice);
        vm.expectRevert(XY107.Unauthorized.selector);
        nft.setContractURI("ipfs://collection");

        vm.startPrank(creator);
        vm.expectRevert(XY107.InvalidState.selector);
        nft.setContractURI("");
        nft.setContractURI("ipfs://collection");
        vm.stopPrank();
        assertEq(nft.contractURI(), "ipfs://collection");
    }

    function testMintCreatesOneHeroPerAddress() public {
        _mint(alice, 2);
        assertEq(nft.ownerOf(2), alice);
        assertTrue(nft.hasMintedHero(alice));
        assertEq(nft.heroMintCount(), 1);
        assertEq(nft.tokenURI(2), "");

        vm.prank(alice);
        vm.expectRevert(XY107.InvalidState.selector);
        nft.mint{value: 1 ether}(3);
        vm.prank(bob);
        vm.expectRevert(XY107.InvalidState.selector);
        nft.mint{value: 1 ether}(2);
    }

    function testMintAcceptsBothRangeBoundaries() public {
        _mint(alice, 2);
        _mint(bob, 108);
        assertEq(nft.ownerOf(2), alice);
        assertEq(nft.ownerOf(108), bob);
    }

    function testMintRejectsInvalidTokenAndPrice() public {
        vm.startPrank(alice);
        vm.expectRevert(XY107.InvalidToken.selector);
        nft.mint{value: 1 ether}(1);
        vm.expectRevert(XY107.InvalidToken.selector);
        nft.mint{value: 1 ether}(109);
        vm.expectRevert(XY107.InvalidToken.selector);
        nft.mint{value: 0.9 ether}(2);
        vm.stopPrank();
    }

    function testWithdrawEthIsCreatorOnlyAndBalanceLimited() public {
        _mint(alice, 2);

        vm.prank(admin);
        vm.expectRevert(XY107.Unauthorized.selector);
        nft.withdrawEth(1 ether);
        vm.prank(creator);
        vm.expectRevert(XY107.InvalidState.selector);
        nft.withdrawEth(1 ether + 1);

        uint256 balanceBefore = creator.balance;
        vm.prank(creator);
        nft.withdrawEth(1 ether);
        assertEq(creator.balance, balanceBefore + 1 ether);
        assertEq(address(nft).balance, 0);
    }

    function testCreatorCannotBurnSongjiangBeforeAllHeroesMint() public {
        vm.prank(creator);
        vm.expectRevert(XY107.Unauthorized.selector);
        nft.burnSongjiang();
    }

    function testNonCreatorCannotBurnSongjiangEarly() public {
        vm.prank(alice);
        vm.expectRevert(XY107.Unauthorized.selector);
        nft.burnSongjiang();
    }

    function testAnyoneCanBurnSongjiangAfterAllHeroesMint() public {
        for (uint256 tokenId = 2; tokenId <= 108; ++tokenId) {
            address minter = address(uint160(tokenId + 1_000));
            vm.deal(minter, 1 ether);
            _mint(minter, tokenId);
        }

        vm.prank(alice);
        nft.burnSongjiang();
        assertEq(xy.trancheRemaining(XY.Tranche.SONGJIANG), 0);
    }

    function testBurnSongjiangRejectsSecondBurn() public {
        for (uint256 tokenId = 2; tokenId <= 108; ++tokenId) {
            address minter = address(uint160(tokenId + 1_000));
            vm.deal(minter, 1 ether);
            _mint(minter, tokenId);
        }

        nft.burnSongjiang();
        vm.expectRevert(XY107.InvalidState.selector);
        nft.burnSongjiang();
    }

    function testSongjiangCannotBeApprovedOrTransferred() public {
        vm.prank(address(nft));
        vm.expectRevert(XY107.SongjiangLocked.selector);
        nft.approve(alice, 1);
        vm.prank(address(nft));
        vm.expectRevert(XY107.SongjiangLocked.selector);
        nft.transferFrom(address(nft), alice, 1);
    }

    function testHeroCanBeApprovedAndTransferred() public {
        _mint(alice, 2);
        vm.prank(alice);
        nft.approve(bob, 2);
        vm.prank(bob);
        nft.transferFrom(alice, bob, 2);
        assertEq(nft.ownerOf(2), bob);
    }

    function testTokenUriRejectsMissingToken() public {
        vm.expectRevert();
        nft.tokenURI(2);
    }

    function _mint(address minter, uint256 tokenId) private {
        vm.prank(minter);
        nft.mint{value: 1 ether}(tokenId);
    }

    function _expectedTokenUri(string memory baseUri) private pure returns (string memory) {
        string memory image =
            bytes(baseUri).length == 0 ? "" : string.concat(baseUri, "/", Strings.toString(2));
        string memory json = string.concat(
            '{"name":"Hero \\"Two\\"","description":"Rain\\\\water\\nhero","image":"',
            image,
            '","image_hash":"',
            Strings.toHexString(uint256(IMAGE_HASH), 32),
            '"}'
        );
        return string.concat("data:application/json;base64,", Base64.encode(bytes(json)));
    }

    function _repeat(string memory character, uint256 count)
        private
        pure
        returns (string memory result)
    {
        bytes memory output = new bytes(count);
        bytes1 value = bytes(character)[0];
        for (uint256 i; i < count; ++i) {
            output[i] = value;
        }
        result = string(output);
    }
}
