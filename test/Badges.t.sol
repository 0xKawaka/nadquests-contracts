// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {Badges} from "../src/Badges.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract BadgesTest is Test {
    Badges public badges;

    address public trustedAuthority = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint256 internal trustedAuthorityPK =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    address public owner = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public minter = address(0x1234);
    address public secondMinter = address(0x1235);

    // Sample twitterId to use for tests.
    string public twitterId = "testTwitter";

    function setUp() public {
        // Deploy the Badges contract
        badges = new Badges();
        // Initialize with the trustedAuthority and owner
        badges.initialize(trustedAuthority, owner);
    }
    
    function testInitialize() public {
        // Check that the trusted authority is set
        assertEq(badges.trustedAuthority(), trustedAuthority);
    }

    function testOwner() public {
        // The contract's owner should be the address that called initialize (which is this contract in setUp()).
        assertEq(badges.owner(), owner);
    }

    function testSetTokenURI() public {
        // Only the owner can set the token URI
        vm.prank(owner);
        badges.setTokenURI(1, "ipfs://someUri");
        string memory uri = badges.uri(1);
        assertEq(uri, "ipfs://someUri");
    }

    function testCannotSetTokenURIIfNotOwner() public {
        // Start impersonating some other address
        address notOwner = address(0x1234);
        vm.startPrank(notOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, notOwner));
        badges.setTokenURI(2, "ipfs://randomUri");
    }

    function testMintBadgeSuccess() public {
        // Define the NFT type to mint
        uint256 tokenType = 42;
        // Some arbitrary key to tie to the signature
        bytes32 key = keccak256("my-unique-badge-key");

        // Construct the message hash including the twitterId.
        bytes32 messageHash = keccak256(
            abi.encodePacked(minter, tokenType, key, twitterId)
        );

        // Convert to the "Ethereum Signed Message" hash
        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );

        // Use Foundry's vm.sign() to sign with the known private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(trustedAuthorityPK, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Impersonate the minter to call mintNFT, now including twitterId.
        vm.prank(minter);
        badges.mintNFT(tokenType, key, twitterId, signature);

        // Verify the minter now has 1 badge of that type
        uint256 balance = badges.balanceOf(minter, tokenType);
        assertEq(balance, 1, "Minter should have 1 badge of tokenType 42");
    }

    function testMintBadgeKeyReuseFails() public {
        uint256 tokenType = 42;
        bytes32 key = keccak256("my-unique-badge-key");

        // Prepare signature including twitterId
        bytes32 messageHash = keccak256(
            abi.encodePacked(minter, tokenType, key, twitterId)
        );
        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(trustedAuthorityPK, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // First mint (works)
        vm.prank(minter);
        badges.mintNFT(tokenType, key, twitterId, signature);

        // Minter tries to mint again using the same key. Should revert.
        vm.prank(minter);
        vm.expectRevert("Key already used");
        badges.mintNFT(tokenType, key, twitterId, signature);
    }

    function testMintBadgeInvalidSignatureFails() public {
        uint256 tokenType = 42;
        bytes32 key = keccak256("my-other-badge-key");

        // This time we sign with a different private key (not the trustedAuthorityPK).
        uint256 bogusKey = 0xABC; // Just a random private key for test
        bytes32 messageHash = keccak256(
            abi.encodePacked(minter, tokenType, key, twitterId)
        );
        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bogusKey, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Attempt to mint with an invalid signature
        vm.prank(minter);
        vm.expectRevert("Invalid key");
        badges.mintNFT(tokenType, key, twitterId, signature);
    }

    function testMintBadgeAlreadyMintedFails() public {
        uint256 tokenType = 42;
        bytes32 key = keccak256("my-unique-badge-key");

        // Prepare signature including twitterId for the first mint
        bytes32 messageHash = keccak256(
            abi.encodePacked(minter, tokenType, key, twitterId)
        );
        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(trustedAuthorityPK, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // First mint (works)
        vm.prank(minter);
        badges.mintNFT(tokenType, key, twitterId, signature);

        // Attempt to mint a second badge of the same type with a different key but the same twitterId.
        bytes32 key2 = keccak256("my-second-badge-key");
        bytes32 messageHash2 = keccak256(
            abi.encodePacked(minter, tokenType, key2, twitterId)
        );
        bytes32 ethSignedMessageHash2 = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash2)
        );
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(trustedAuthorityPK, ethSignedMessageHash2);
        bytes memory signature2 = abi.encodePacked(r2, s2, v2);

        // Minter tries to mint again using the same twitterId for the same tokenType. Should revert.
        vm.prank(minter);
        vm.expectRevert("User already minted this type");
        badges.mintNFT(tokenType, key2, twitterId, signature2);

        // Attempt to mint with second minter but same twitterId. Should revert.
        bytes32 key3 = keccak256("my-third-badge-key");
        bytes32 messageHash3 = keccak256(
            abi.encodePacked(secondMinter, tokenType, key3, twitterId)
        );
        bytes32 ethSignedMessageHash3 = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash3)
        );
        (uint8 v3, bytes32 r3, bytes32 s3) = vm.sign(trustedAuthorityPK, ethSignedMessageHash3);
        bytes memory signature3 = abi.encodePacked(r3, s3, v3);

        // Second minter tries to mint with the same twitterId for the same tokenType. Should revert.
        vm.prank(secondMinter);
        vm.expectRevert("Twitter ID already minted this type");
        badges.mintNFT(tokenType, key3, twitterId, signature3);
    }
}
