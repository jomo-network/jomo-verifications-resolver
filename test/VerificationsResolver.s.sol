// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Test} from "forge-std/Test.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import "eas-contracts/IEAS.sol";
import "../src/VerificationsResolverOnlyForTestUpgrade.sol";
import "./mocks/MockEAS.sol";
import "./mocks/MockSchemaRegistry.sol";
import "../src/VerificationsResolver.sol";

contract VerificationsResolverTestForUpgrade is Test {

    address transparentProxy;
    address admin = makeAddr("owner");

    VerificationsResolver verificationResolver;
    AttestationStation attestationStation;
    MockEAS eas;
    MockSchemaRegistry registry;

    function setUp() public {
        // fill users some gas
        vm.deal(admin, 1 ether);
    }

    function test_upgrade_for_testing() external {
        attestationStation = new AttestationStation();
        registry = new MockSchemaRegistry();
        eas = new MockEAS(registry);
        transparentProxy = Upgrades.deployTransparentProxy(
            "VerificationsResolver.sol:VerificationsResolver",
            admin,
            abi.encodeCall(VerificationsResolver.initialize, (admin, attestationStation, eas))
        );
        verificationResolver = VerificationsResolver(payable(transparentProxy));

        address impl1 = Upgrades.getImplementationAddress(transparentProxy);
        address adminAddress = Upgrades.getAdminAddress(transparentProxy);
        assertFalse(adminAddress == address(0));
        Upgrades.upgradeProxy(
            transparentProxy,
            "VerificationsResolverOnlyForTestUpgrade.sol",
            "",
            admin
        );
        address impl2 = Upgrades.getImplementationAddress(transparentProxy);
        VerificationsResolverOnlyForTestUpgrade instance = VerificationsResolverOnlyForTestUpgrade(payable(transparentProxy));
        assertEq(Upgrades.getAdminAddress(transparentProxy), adminAddress);
        assertTrue(instance.showUpgradeTrue());
        assertFalse(impl2 == impl1);
    }
}
