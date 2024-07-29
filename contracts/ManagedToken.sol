// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

interface ERC165 {
    /**
     * @notice Query if a contract implements an interface
     * @param interfaceID The interface identifier, as specified in ERC-165
     * @dev Interface identification is specified in ERC-165.
     * @return `true` if the contract implements `interfaceID` and
     *  `interfaceID` is not 0xffffffff, `false` otherwise
     */
    function supportsInterface(bytes4 interfaceID) external view returns (bool);
}

/**
 * @title ERC-173 Contract Ownership Standard
 * @dev Note: the ERC-165 identifier for this interface is 0x7f5828d0
 */
interface ERC173 is ERC165 {
    /**
     * @dev This emits when ownership of a contract changes.
     */
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @notice Get the address of the owner
     * @return The address of the owner.
     */
    function owner() external view returns (address);

    /**
     * @notice Set the address of the new owner of the contract
     * @dev Set _newOwner to address(0) to renounce any ownership.
     * @param _newOwner The address of the new owner of the contract
     */
    function transferOwnership(address _newOwner) external;
}

/**
 * @title Interface for a contract that may have some of it's operations be paused
 */
interface IPausable {
    /**
     * @notice Pause operations of this contract
     * @dev This method must fail if called by unauthorized user
     */
    function pause() external;

    /**
     * @notice Resume paused operations of this contract
     * @dev This method must fail if called by unauthorized user
     */
    function unpause() external;

    /**
     * @notice Emitted when the contract gets paused
     */
    event Pause();

    /**
     * @notice Emitted when the contract gets unpaused
     */
    event Unpause();
}

/**
 * @title Interface for token contracts with blacklist management functionality
 */
interface IBlackList {
    /**
     * @notice Add given address to blacklist.
     * @param _evilUser the address to add to blacklist
     */
    function addBlackList(address _evilUser) external;

    /**
     * @notice Remove given address from blacklist.
     * @param _clearedUser the address to remove from blacklist
     */
    function removeBlackList(address _clearedUser) external;

    /**
     * @dev Destroy tokens owned by a blacklisted account.
     * @param _blackListedUser the blacklisted address
     */
    function destroyBlackFunds(address _blackListedUser) external;

    /**
     * Emitted when tokens owned by a blacklisted address are destroyed.
     * @param _blackListedUser the blacklisted account
     * @param _balance amount of tokens previously owned by the account
     */
    event DestroyedBlackFunds(address _blackListedUser, uint _balance);

    /**
     * Emitted when an address is added to the blacklist
     * @param _user the address added to the blacklist
     */
    event AddedBlackList(address _user);

    /**
     * Emitted when an address is removed from blacklist
     * @param _user the address removed from the blacklist
     */
    event RemovedBlackList(address _user);
}

interface IDeprecatable {
    /**
     * @notice Mark this contract as deprecated and start delegating some operations to a different contract
     * @param _upgradedAddress address of new contract to delegate calls to
     */
    function deprecate(address _upgradedAddress) external;
}

/**
 * @title Methods for token supply management (token emission and destruction)
 */
interface ISupply {
    /**
     * @notice Create new tokens and send them to given address
     * @param amount Number of tokens to be issued
     * @param to Address to send tokens to
     */
    function issue(uint amount, address to) external;

    /**
     * @notice Redeem (burn) tokens.
     * The tokens are withdrawn from the owner address.
     * The balance must be enough to cover the redeem or the call will fail.
     * @param amount Number of tokens to be redeemed
     */
    function redeem(uint amount) external;

    /** Emitted when new token are issued */
    event Issue(uint amount, address to);

    /** Emitted when tokens are redeemed */
    event Redeem(uint amount);
}

/**
 * @title Interface for token contracts manageable by `MultisigManager` contract.
 */
interface ManagedToken is
    ERC173,
    IPausable,
    IBlackList,
    IDeprecatable,
    ISupply
{}
