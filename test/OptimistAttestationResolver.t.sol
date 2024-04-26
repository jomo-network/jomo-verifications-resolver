// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import "eas-contracts/IEAS.sol";
import "./mocks/MockSchemaRegistry.sol";
import {MockEAS} from "./mocks/MockEAS.sol";
import {OptimistAttestationResolver} from "../src/OptimistAttestationResolver.sol";
import {AllowlistOptimistNFT} from "../src/op-nft/AllowlistOptimistNFT.sol";

contract OptimistAttestationResolverTest is Test {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    string constant name = "Optimist name";
    string constant symbol = "OPTIMISTSYMBOL";
    string constant base_uri = "https://storageapi.fleek.co/6442819a1b05-bucket/optimist-nft/attributes";
    bytes32 public constant ALLOWLIST_ROLE = keccak256("optimist.hackathon-participants.allowlist-role");

    OptimistAttestationResolver optimistAttestationResolver;
    AllowlistOptimistNFT optimistNFT;
    MockEAS eas;
    MockSchemaRegistry registry;

    address transparentProxy;
    address admin = makeAddr("owner");
    address alice = address(10086);
    address bob = address(10090);

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
        registry = new MockSchemaRegistry();
        eas = new MockEAS(registry);
        transparentProxy = Upgrades.deployTransparentProxy(
            "OptimistAttestationResolver.sol:OptimistAttestationResolver",
            admin,
            abi.encodeCall(OptimistAttestationResolver.initialize, (admin, eas))
        );
        optimistAttestationResolver = OptimistAttestationResolver(payable(transparentProxy));
        optimistNFT = new AllowlistOptimistNFT({
            _name: name,
            _symbol: symbol,
            _baseURIAttestor: carol_baseURIAttestor,
            _optimistAllowlist: optimistAttestationResolver
        });
        vm.prank(admin);
        optimistAttestationResolver.grantRole(ALLOWLIST_ROLE, allowlist_role);
    }

    function test_mint_failed_before_make_attestation() external {
        vm.prank(bob);
        vm.expectRevert("AllowlistOptimistNFT: address is not on allowList");
        optimistNFT.mint(bob);
    }

    function test_register_schema_and_create_attestation() external {
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
        vm.prank(allowlist_role);
        bytes32 id2 = eas.attest(request);
        assertNotEq(id2, bytes32(0));
        assertTrue(optimistAttestationResolver.hasAttestation(bob));

        vm.prank(alice);
        vm.expectRevert("AllowlistOptimistNFT: address is not on allowList");
        optimistNFT.mint(alice);

        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), bob, _getTokenId(bob));
        vm.prank(bob);
        optimistNFT.mint(bob);
    }

    function test_isemver_version() view external {
        assertEq(optimistAttestationResolver.version(), string(
            abi.encodePacked(Strings.toString(1), ".", Strings.toString(3), ".", Strings.toString(0))
        ));
    }
}