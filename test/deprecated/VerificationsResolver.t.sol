// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import "eas-contracts/IEAS.sol";
import "../../src/op-nft/OptimistAllowlist.sol";
import "../../src/op-nft/Optimist.sol";
import "../../src/deprecated/VerificationsResolver.sol";
import "../mocks/MockSchemaRegistry.sol";
import {MockEAS} from "../mocks/MockEAS.sol";

contract VerificationsResolverTest is Test {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    string constant name = "Optimist name";
    string constant symbol = "OPTIMISTSYMBOL";
    string constant base_uri = "https://storageapi.fleek.co/6442819a1b05-bucket/optimist-nft/attributes";
    bytes32 public constant VERIFICATIONS_RESOLVER_ATTESTATION_KEY = bytes32("optimist.hackathon-participants");
    VerificationsResolver verificationResolver;
    AttestationStation attestationStation;
    Optimist optimist;
    OptimistAllowlist optimistAllowlist;
    MockEAS eas;
    MockSchemaRegistry registry;

    address transparentProxy;
    address admin = makeAddr("owner");
    address alice = address(10086);
    address bob = address(10090);

    address carol_baseURIAttestor = makeAddr("carol_baseURIAttestor");
    address eve_inviteGranter = makeAddr("eve_inviteGranter");
    address fish_allowlistAttestor = makeAddr("fish_allowlist");
    address gong_coinbaseAttestor = makeAddr("gong_coinbaseAttestor");

    function setUp() public {
        // fill users some gas
        vm.deal(admin, 1 ether);
        vm.deal(alice, 1 ether);
        vm.deal(bob, 1 ether);
        vm.deal(carol_baseURIAttestor, 1 ether);
        vm.deal(eve_inviteGranter, 1 ether);
        vm.deal(fish_allowlistAttestor, 1 ether);
        vm.deal(gong_coinbaseAttestor, 1 ether);
        _initializeContracts();
    }

    /// @notice Returns address as uint256.
    function _getTokenId(address _owner) internal pure returns (uint256) {
        return uint256(uint160(address(_owner)));
    }

    function _initializeContracts() internal {
        attestationStation = new AttestationStation();
        registry = new MockSchemaRegistry();
        eas = new MockEAS(registry);
        transparentProxy = Upgrades.deployTransparentProxy(
            "VerificationsResolver.sol:VerificationsResolver",
            admin,
            abi.encodeCall(VerificationsResolver.initialize, (admin, attestationStation, eas))
        );
        verificationResolver = VerificationsResolver(payable(transparentProxy));
        optimistAllowlist = new OptimistAllowlist({
            _attestationStation: attestationStation ,
            _allowlistAttestor: fish_allowlistAttestor,
            _coinbaseQuestAttestor: gong_coinbaseAttestor,
            _optimistInviter: eve_inviteGranter,
            _verificationsResolver: address(verificationResolver)
        });
        optimist = new Optimist({
            _name: name,
            _symbol: symbol,
            _baseURIAttestor: carol_baseURIAttestor,
            _attestationStation: attestationStation,
            _optimistAllowlist: optimistAllowlist
        });
    }

    function test_mint_failed_before_verifications_resolver() external {
        vm.prank(bob);
        vm.expectRevert("Optimist: address is not on allowList");
        optimist.mint(bob);
    }

    function test_register_schema_and_create_attestation() external {
        string memory schema = "bytes32 key,address mintTo";
        bytes32 id = registry.register(schema, verificationResolver, false);
        assertNotEq(id, bytes32(0));
        AttestationRequestData memory requestData = AttestationRequestData({
            recipient: bob,
            expirationTime : uint64(block.timestamp + 120),
            revocable: false,
            refUID: bytes32(0),
            data: abi.encode(VERIFICATIONS_RESOLVER_ATTESTATION_KEY, bob),
            value: 0
        });
        AttestationRequest memory request = AttestationRequest({
            schema: id,
            data: requestData
        });
        bytes32 id2 = eas.attest(request);
        assertNotEq(id2, bytes32(0));
        assertTrue(verificationResolver.getAttestation(bob));

        vm.prank(alice);
        vm.expectRevert("Optimist: address is not on allowList");
        optimist.mint(alice);

        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), bob, _getTokenId(bob));
        vm.prank(bob);
        optimist.mint(bob);
    }

}