// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract Badges is
    Initializable,
    ERC1155Upgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    // Mapping to store the metadata URI for each NFT type
    mapping(uint256 => string) private _tokenURIs;

    // Mapping to track used keys for each NFT type (to prevent reuse)
    mapping(uint256 => mapping(bytes32 => bool)) private _usedKeys;

    // Mapping to track which users have minted which NFT types
    mapping(uint256 => mapping(address => bool)) private _hasMinted;

    // Mapping to track which Twitter IDs have minted each NFT type
    mapping(uint256 => mapping(string => bool)) private _hasMintedTwitter;

    // Address that is allowed to sign keys, replace with your own logic or remove
    address public trustedAuthority;

    // Event to log new NFT type creation
    event NewNFTTypeAdded(uint256 indexed tokenType, string metadataURI);

    /// @dev Initialize the contract (required for UUPS upgradeable contracts).
    ///      Must be called exactly once.
    function initialize(address _trustedAuthority, address _owner) public initializer {
        __ERC1155_init("");        // Initialize ERC1155
        __Ownable_init(_owner);     // Initialize Ownable
        __UUPSUpgradeable_init();   // Initialize UUPS

        // Set your trusted authority (or remove if not needed)
        trustedAuthority = _trustedAuthority;
    }

    /// @dev Add or update the metadata URI for an NFT type (only callable by the owner)
    function setTokenURI(uint256 tokenType, string memory metadataURI)
        external
        onlyOwner
    {
        _tokenURIs[tokenType] = metadataURI;
        emit NewNFTTypeAdded(tokenType, metadataURI);
    }

    /// @dev Mint an NFT of a specific type using a valid key and a Twitter ID.
    ///      A given Twitter ID can only mint one NFT of each token type.
    function mintNFT(
        uint256 tokenType,
        bytes32 key,
        string memory twitterId,
        bytes memory signature
    ) external {
        require(!_usedKeys[tokenType][key], "Key already used");
        require(!_hasMinted[tokenType][msg.sender], "User already minted this type");
        require(!_hasMintedTwitter[tokenType][twitterId], "Twitter ID already minted this type");
        require(_verifyKey(msg.sender, tokenType, key, twitterId, signature), "Invalid key");

        _usedKeys[tokenType][key] = true;               // Mark the key as used
        _hasMinted[tokenType][msg.sender] = true;         // Mark the user as minted
        _hasMintedTwitter[tokenType][twitterId] = true;   // Mark the Twitter ID as minted
        _mint(msg.sender, tokenType, 1, "");              // Mint the NFT
    }

    /// @dev Check if a user has minted an NFT of a given type.
    function hasMinted(uint256 tokenType, address user)
        external
        view
        returns (bool)
    {
        return _hasMinted[tokenType][user];
    }

    /// @dev Check if a Twitter ID has minted an NFT of a given type.
    function hasMintedTwitter(uint256 tokenType, string memory twitterId)
        external
        view
        returns (bool)
    {
        return _hasMintedTwitter[tokenType][twitterId];
    }

    /// @dev Override the URI function to return dynamic metadata based on the NFT type.
    function uri(uint256 tokenType)
        public
        view
        override
        returns (string memory)
    {
        return _tokenURIs[tokenType];
    }

    /// @dev Verify the key using a cryptographic signature that now also embeds a Twitter ID.
    function _verifyKey(
        address user,
        uint256 tokenType,
        bytes32 key,
        string memory twitterId,
        bytes memory signature
    ) internal view returns (bool) {
        // Include user address, tokenType, key, and twitterId in the signed message.
        // You can also include chain id (or other parameters) if desired.
        bytes32 messageHash = keccak256(abi.encodePacked(
            user,
            tokenType,
            key,
            twitterId
            // block.chainid  // Optionally include chain id for uniqueness across chains.
        ));

        address signer = recoverSigner(messageHash, signature);
        return (signer == trustedAuthority);
    }

    /// @dev Helper function to recover the signer's address from a message hash and signature.
    function recoverSigner(bytes32 messageHash, bytes memory signature)
        internal
        pure
        returns (address)
    {
        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = splitSignature(signature);
        return ecrecover(ethSignedMessageHash, v, r, s);
    }

    /// @dev Helper function to split the signature into v, r, s components.
    function splitSignature(bytes memory sig)
        internal
        pure
        returns (
            uint8,
            bytes32,
            bytes32
        )
    {
        require(sig.length == 65, "Invalid signature length");
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
        return (v, r, s);
    }

    /// @dev UUPS upgradeability: authorize upgrades to the contract (only owner).
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}
}
