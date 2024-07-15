// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

interface IOwnable {
    function transferOwnership(address newOwner) external;
}

interface IPausable {
    function pause() external;

    function unpause() external;
}

interface IBlackList {
    function addBlackList(address _evilUser) external;

    function removeBlackList(address _clearedUser) external;

    function destroyBlackFunds(address _blackListedUser) external;
}

interface IDeprecatable {
    function deprecate(address _upgradedAddress) external;
}

interface ManagedToken is IOwnable, IPausable, IBlackList, IDeprecatable {
    function issue(uint amount, address to) external;

    function redeem(uint amount) external;
}
