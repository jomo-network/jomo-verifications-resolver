// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ERC721BurnableUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import "eas-contracts/ISemver.sol";
import "./OptimistAllowlist.sol";
import "./AttestationStation.sol";
import {OptimistAttestationResolver} from "../OptimistAttestationResolver.sol";

/// @author Optimism Collective
/// @author Gitcoin
/// @title  Optimist
/// @notice A Soul Bound Token for real humans only(tm).
/// @custom:oz-upgrades-from Optimist
contract OptimistV2 is ERC721BurnableUpgradeable, ISemver {
    /// @notice Attestation key used by the attestor to attest the baseURI.
    bytes32 public constant BASE_URI_ATTESTATION_KEY = bytes32("optimist.base-uri");

    /// @notice Attestor who attests to baseURI.
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address public immutable BASE_URI_ATTESTOR;

    /// @notice Address of the AttestationStation contract.
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    AttestationStation public immutable ATTESTATION_STATION;

    /// @notice Address of the OptimistAllowlist contract.
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    OptimistAllowlist public immutable OPTIMIST_ALLOWLIST;

    /// @notice Address of OptimistAttestationResolver contract.
    OptimistAttestationResolver public OPTIMIST_ATTESTATION_RESOLVER;

    /// @notice Semantic version.
    /// @custom:semver 2.1.0
    string public constant version = "2.1.0";

    /// @param _name               Token name.
    /// @param _symbol             Token symbol.
    /// @param _baseURIAttestor    Address of the baseURI attestor.
    /// @param _attestationStation Address of the AttestationStation contract.
    /// @param _optimistAllowlist  Address of the OptimistAllowlist contract
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        string memory _name,
        string memory _symbol,
        address _baseURIAttestor,
        AttestationStation _attestationStation,
        OptimistAllowlist _optimistAllowlist
    ) {
        BASE_URI_ATTESTOR = _baseURIAttestor;
        ATTESTATION_STATION = _attestationStation;
        OPTIMIST_ALLOWLIST = _optimistAllowlist;
        initialize(_name, _symbol);
    }

    /// @notice Initializes the Optimist contract.
    /// @param _name   Token name.
    /// @param _symbol Token symbol.
    function initialize(
        string memory _name,
        string memory _symbol
    ) public initializer {
        __ERC721_init(_name, _symbol);
        __ERC721Burnable_init();
    }

    /// @notice Initialize the OptimistAttestatioResolver contract.
    /// @param _attestationResolver OptimistAttestationResolver.
    function initializeV2(
        OptimistAttestationResolver _attestationResolver
    ) public initializer {
        OPTIMIST_ATTESTATION_RESOLVER = _attestationResolver;
    }

    /// @notice Allows an address to mint an Optimist NFT. Token ID is the uint256 representation
    ///         of the recipient's address. Recipients must be permitted to mint, eventually anyone
    ///         will be able to mint. One token per address.
    /// @param _recipient Address of the token recipient.
    function mint(address _recipient) public {
        require(isOnAllowList(_recipient), "OptimistV2: address is not on allowList");
        _safeMint(_recipient, tokenIdOfAddress(_recipient));
    }

    /// @notice Returns the baseURI for all tokens.
    /// @return uri_ BaseURI for all tokens.
    function baseURI() public view returns (string memory uri_) {
        uri_ = string(
            abi.encodePacked(
                ATTESTATION_STATION.attestations(BASE_URI_ATTESTOR, address(this), bytes32("optimist.base-uri"))
            )
        );
    }

    /// @notice Returns the token URI for a given token by ID
    /// @param _tokenId Token ID to query.
    /// @return uri_ Token URI for the given token by ID.
    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory uri_) {
        uri_ = string(
            abi.encodePacked(
                baseURI(),
                "/",
                // Properly format the token ID as a 20 byte hex string (address).
                Strings.toHexString(_tokenId, 20),
                ".json"
            )
        );
    }

    /// @notice Checks OptimistAllowlist to determine whether a given address is allowed to mint
    ///         the Optimist NFT. Since the Optimist NFT will also be used as part of the
    ///         Citizens House, mints are currently restricted. Eventually anyone will be able
    ///         to mint.
    /// @return allowed_ Whether or not the address is allowed to mint yet.
    function isOnAllowList(address _recipient) public view returns (bool allowed_) {
        allowed_ = OPTIMIST_ALLOWLIST.isAllowedToMint(_recipient) || OPTIMIST_ATTESTATION_RESOLVER.hasAttestation(_recipient);
    }

    /// @notice Returns the token ID for the token owned by a given address. This is the uint256
    ///         representation of the given address.
    /// @return Token ID for the token owned by the given address.
    function tokenIdOfAddress(address _owner) public pure returns (uint256) {
        return uint256(uint160(_owner));
    }

    /// @notice Disabled for the Optimist NFT (Soul Bound Token).
    function approve(address, uint256) public pure override {
        revert("OptimistV2: soul bound token");
    }

    /// @notice Disabled for the Optimist NFT (Soul Bound Token).
    function setApprovalForAll(address, bool) public virtual override {
        revert("OptimistV2: soul bound token");
    }

    /// @notice Prevents transfers of the Optimist NFT (Soul Bound Token).
    /// @param _from Address of the token sender.
    /// @param _to   Address of the token recipient.
    function _beforeTokenTransfer(address _from, address _to, uint256) internal virtual {
        require(_from == address(0) || _to == address(0), "OptimistV2: soul bound token");
    }
}