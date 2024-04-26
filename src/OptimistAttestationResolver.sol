// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IEAS} from "eas-contracts/IEAS.sol";
import {Attestation} from "eas-contracts/Common.sol";

import {AllowlistResolverUpgradeable} from "./abstract/AllowlistResolverUpgradeable.sol";
import {SchemaResolverUpgradeable} from "./abstract/SchemaResolverUpgradeable.sol";

/**
 * @title EAS Schema Resolver for Optimist Attestation Resolver
 * @notice Manages schemas related to Optimist attestations.
 * @dev Only allowlisted entities can attest; successful attestations are record and allow to mint.
 */
contract OptimistAttestationResolver is
    SchemaResolverUpgradeable,
    AllowlistResolverUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    event OptimistAttestationCreated();
    event OptimistAttestationRevoked();

    bytes32 public constant PAUSE_ROLE = keccak256("optimist.hackathon-participants.pause-role");
    bytes32 public constant ADMIN_ROLE = keccak256("optimist.hackathon-participants.admin-role");
    bytes32 public constant ALLOWLIST_ROLE = keccak256("optimist.hackathon-participants.allowlist-role");

    /// @notice track recipient attestationUid
    mapping (address => bytes32) private attestationUidByRecipient;

    /**
    * @dev Locks the contract, preventing any future reinitialization. This implementation contract was designed to be called through proxies.
    * @custom:oz-upgrades-unsafe-allow constructor
    */
    constructor() {
        _disableInitializers();
    }

    /**
    * @dev Initializes the contract.
    * @param admin The address to be granted with the default admin Role.
    * @param eas The address of the EAS attestation contract.
    */
    function initialize(address admin, IEAS eas) initializer public {
        __SchemaResolver_init(eas);
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __AllowlistResolver_init();

        require(_grantRole(ADMIN_ROLE, admin));
        _setRoleAdmin(PAUSE_ROLE, ADMIN_ROLE);
        _setRoleAdmin(ALLOWLIST_ROLE, ADMIN_ROLE);
    }

    function hasAttestation(address user) public view returns (bool) {
        return attestationUidByRecipient[user] != bytes32(0);
    }

    /// @inheritdoc SchemaResolverUpgradeable
    function onAttest(
        Attestation calldata attestationInput,
        uint256
    ) internal
    whenNotPaused
    override(SchemaResolverUpgradeable, AllowlistResolverUpgradeable)
    returns (bool)
    {
        require(!allowedAttesters[attestationInput.attester], "OptimistAttestationResolver: attester is not allowed");
        require(attestationUidByRecipient[attestationInput.recipient] == bytes32(0), "OptimistAttestationResolver: recipient already record by uid");
        attestationUidByRecipient[attestationInput.recipient] = attestationInput.uid;
        return true;
    }

    /// @inheritdoc SchemaResolverUpgradeable
    function onRevoke(
        Attestation calldata attestationInput,
        uint256
    ) internal whenNotPaused override(SchemaResolverUpgradeable, AllowlistResolverUpgradeable) returns (bool) {
        require(!allowedAttesters[attestationInput.attester], "OptimistAttestationResolver: attester is not allowed");
        require(attestationUidByRecipient[attestationInput.recipient] != bytes32(0), "OptimistAttestationResolver: recipient not record by uid");
        attestationUidByRecipient[attestationInput.recipient] = bytes32(0);
        return true;
    }

    /**
    * @dev Pause the contract or not.
    * @param enableOrNot A flag used to determine whether to pause.
    */
    function enablePaused(bool enableOrNot) external onlyRole(PAUSE_ROLE) {
        if (enableOrNot) {
            _pause();
        } else {
            _unpause();
        }
    }

    /**
    * @dev Allow or remove attestor.
    * @param enableOrNot A flag used to determine whether to allow or remove.
    * @param attestor The attestor address
    */
    function enableAllowAttestor(bool enableOrNot, address attestor) external onlyRole(ALLOWLIST_ROLE) {
        if (enableOrNot) {
            _allowAttester(attestor);
        } else {
            _removeAttester(attestor);
        }
    }
}
