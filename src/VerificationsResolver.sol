// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IEAS} from "eas-contracts/IEAS.sol";
import {Attestation} from "eas-contracts/Common.sol";

import {SchemaResolverUpgradeable} from "./abstract/SchemaResolverUpgradeable.sol";
import "./op-nft/AttestationStation.sol";
import "./libraries/AttestationErrors.sol";

/**
 * @title EAS Schema Resolver for Optimist Verifications
 * @notice Manages schemas related to Optimist Verifications attestations.
 * @dev Only allowlisted entities can attest; successful attestations are record and allow to mint.
 */
contract VerificationsResolver is
    SchemaResolverUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    bytes32 public constant PAUSE_ROLE = keccak256("optimist.hackathon-participants.pause-role");
    bytes32 public constant ADMIN_ROLE = keccak256("optimist.hackathon-participants.admin-role");
    bytes32 public constant VERIFICATIONS_RESOLVER_ATTESTATION_KEY = bytes32("optimist.hackathon-participants");

    AttestationStation private _attestationStation;

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
    function initialize(address admin, AttestationStation attestationStation, IEAS eas) initializer public {
        __SchemaResolver_init(eas);
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        _attestationStation = attestationStation;
        require(_grantRole(ADMIN_ROLE, admin));
        _setRoleAdmin(PAUSE_ROLE, ADMIN_ROLE);
    }

    function getAttestation(address mintTo) external view returns (bool) {
        return keccak256(_attestationStation.attestations(address(this), mintTo, VERIFICATIONS_RESOLVER_ATTESTATION_KEY)) == keccak256(bytes("true"));
    }

    /// @inheritdoc SchemaResolverUpgradeable
    function onAttest(
        Attestation calldata attestationInput,
        uint256
    ) internal whenNotPaused override(SchemaResolverUpgradeable) returns (bool) {
        (bytes32 keys, address mintTo) = abi.decode(attestationInput.data, (bytes32, address));
        if (keys == VERIFICATIONS_RESOLVER_ATTESTATION_KEY) {
            _attestationStation.attest(mintTo, VERIFICATIONS_RESOLVER_ATTESTATION_KEY, bytes("true"));
        } else {
            revert AttestationErrors.UnverifiedAttest();
        }
        return true;
    }

    /// @inheritdoc SchemaResolverUpgradeable
    function onRevoke(
        Attestation calldata,
        uint256
    ) internal whenNotPaused view override(SchemaResolverUpgradeable) returns (bool) {
        return true;
    }

    function enablePaused(bool enableOrNot) external onlyRole(PAUSE_ROLE) {
        if (enableOrNot) {
            _pause();
        } else {
            _unpause();
        }
    }
}
