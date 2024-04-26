// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";
import "eas-contracts/IEAS.sol";
import "./mocks/MockEAS.sol";
import "./mocks/MockSchemaRegistry.sol";
import "../src/op-nft/Optimist.sol";
import {OptimistAttestationResolver} from "../src/OptimistAttestationResolver.sol";
import {OptimistV2} from "../src/op-nft/OptimistV2.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "openzeppelin-foundry-upgrades/Options.sol";
import "openzeppelin-foundry-upgrades/Options.sol";

contract OptimistV2TestForUpgrade is Test {

    address optimistProxy;
    address admin = makeAddr("admin");
    address initOwner = makeAddr("initOwner");

    string constant name = "Optimist name";
    string constant symbol = "OPTIMISTSYMBOL";

    Optimist optimist;
    AttestationStation attestationStation;
    OptimistAllowlist optimistAllowlist;
    OptimistAttestationResolver optimistAttestationResolver;
    MockEAS eas;
    MockSchemaRegistry registry;

    address carol_baseURIAttestor = makeAddr("carol_baseURIAttestor");
    address eve_inviteGranter = makeAddr("eve_inviteGranter");
    address fish_allowlistAttestor = makeAddr("fish_allowlist");
    address gong_coinbaseAttestor = makeAddr("gong_coinbaseAttestor");

    function setUp() public {
        // fill users some gas
        vm.deal(admin, 1 ether);
        attestationStation = new AttestationStation();
        optimistAllowlist = new OptimistAllowlist({
            _attestationStation: attestationStation ,
            _allowlistAttestor: fish_allowlistAttestor,
            _coinbaseQuestAttestor: gong_coinbaseAttestor,
            _optimistInviter: eve_inviteGranter
        });
        Options memory options;
        options.constructorData = abi.encode(name, symbol, carol_baseURIAttestor, attestationStation, optimistAllowlist);
        optimistProxy = Upgrades.deployTransparentProxy(
            "Optimist.sol:Optimist",
            initOwner,
            "",
            options
        );
        optimist = Optimist(optimistProxy);
    }

    function test_upgrade() external {
        registry = new MockSchemaRegistry();
        eas = new MockEAS(registry);
        address resolverProxy = Upgrades.deployTransparentProxy(
            "OptimistAttestationResolver.sol:OptimistAttestationResolver",
            admin,
            abi.encodeCall(OptimistAttestationResolver.initialize, (admin, eas, optimist))
        );
        optimistAttestationResolver = OptimistAttestationResolver(payable(resolverProxy));
        Options memory options;
        options.constructorData = abi.encode(name, symbol, carol_baseURIAttestor, attestationStation, optimistAllowlist);
        address impl1 = Upgrades.getImplementationAddress(optimistProxy);
        address adminAddress = Upgrades.getAdminAddress(optimistProxy);
        Upgrades.upgradeProxy(
            address(optimistProxy),
            "OptimistV2.sol:OptimistV2",
            abi.encodeCall(OptimistV2.initializeV2, (optimistAttestationResolver)),
            options,
            initOwner
        );
        address impl2 = Upgrades.getImplementationAddress(optimistProxy);
        assertEq(Upgrades.getAdminAddress(optimistProxy), adminAddress);
        assertFalse(impl2 == impl1);
    }
}
