// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import "eas-contracts/IEAS.sol";
import "./mocks/MockSchemaRegistry.sol";
import {MockEAS} from "./mocks/MockEAS.sol";
import {OptimistAllowlistAttestationResolver} from "../src/OptimistAllowlistAttestationResolver.sol";
import "../src/op-nft/Optimist.sol";

contract OptimistAttestationResolverTest is Test {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    string constant name = "Optimist name";
    string constant symbol = "OPTIMISTSYMBOL";
    string constant base_uri = "https://storageapi.fleek.co/6442819a1b05-bucket/optimist-nft/attributes";
    bytes32 public constant ALLOWLIST_ROLE = keccak256("optimist.allowlist-attestation-issuer.allowlist-role");

    OptimistAllowlistAttestationResolver optimistAttestationResolver;
    Optimist optimistNFT;
    MockEAS eas;
    MockSchemaRegistry registry;
    AttestationStation attestationStation;
    OptimistAllowlist optimistAllowlist;

    address resolverProxy;
    address optimistProxy;
    address admin = makeAddr("owner");
    address alice = address(10086);
    address bob = address(10090);

    address attester = makeAddr("attester0x01");
    address allowlist_role = makeAddr("allowlist_role");
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
        resolverProxy = Upgrades.deployTransparentProxy(
            "OptimistAllowlistAttestationResolver.sol:OptimistAllowlistAttestationResolver",
            admin,
            abi.encodeCall(OptimistAllowlistAttestationResolver.initialize, (admin, eas))
        );
        optimistAttestationResolver = OptimistAllowlistAttestationResolver(payable(resolverProxy));
        vm.prank(admin);
        optimistAttestationResolver.grantRole(ALLOWLIST_ROLE, allowlist_role);
        vm.prank(allowlist_role);
        optimistAttestationResolver.addAttesterToAttesterAllowlist(attester);
        optimistAllowlist = new OptimistAllowlist({
            _attestationStation: attestationStation ,
            _allowlistAttestor: fish_allowlistAttestor,
            _coinbaseQuestAttestor: gong_coinbaseAttestor,
            _optimistInviter: eve_inviteGranter,
            _easOptimistAllowlistAttestationResolver: optimistAttestationResolver
        });
        Options memory options;
        options.constructorData = abi.encode(
            name, symbol,
            carol_baseURIAttestor,
            attestationStation,
            optimistAllowlist
        );
        optimistProxy = Upgrades.deployTransparentProxy(
            "Optimist.sol:Optimist",
            admin,
            "",
            options
        );
        optimistNFT = Optimist(optimistProxy);

    }

    function test_mint_failed_before_attestation() external {
        vm.prank(bob);
        vm.expectRevert("Optimist: address is not on allowList");
        optimistNFT.mint(bob);
    }

    function test_mint_success_after_attestation() external {
        _createAttestation();
        _checkAliceNotInAllowList();
        _checkBobInAllowlist();
    }

    function _checkBobInAllowlist() internal {
        vm.prank(bob);
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), bob, _getTokenId(bob));
        optimistNFT.mint(bob);
    }

    function _checkAliceNotInAllowList() internal {
        vm.prank(alice);
        vm.expectRevert("Optimist: address is not on allowList");
        optimistNFT.mint(alice);
    }

    function _createAttestation() internal {
        string memory schema = "";
        bytes32 id = registry.register(schema, optimistAttestationResolver, false);
        assertNotEq(id, bytes32(0));
        AttestationRequestData memory requestData = AttestationRequestData({
            recipient: bob,
            expirationTime: uint64(block.timestamp + 120),
            revocable: false,
            refUID: bytes32(0),
            data: new bytes(0),
            value: 0
        });
        AttestationRequest memory request = AttestationRequest({
            schema: id,
            data: requestData
        });
        vm.prank(attester);
        bytes32 id2 = eas.attest(request);
        assertNotEq(id2, bytes32(0));
        assertTrue(optimistAttestationResolver.hasAttestation(bob));
    }

    function test_isemver_version() view external {
        assertEq(optimistAttestationResolver.version(), string(
            abi.encodePacked(Strings.toString(1), ".", Strings.toString(3), ".", Strings.toString(0))
        ));
    }
}