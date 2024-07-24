// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

interface ERC165 {
    /// @notice Query if a contract implements an interface
    /// @param interfaceID The interface identifier, as specified in ERC-165
    /// @dev Interface identification is specified in ERC-165. 
    /// @return `true` if the contract implements `interfaceID` and
    ///  `interfaceID` is not 0xffffffff, `false` otherwise
    function supportsInterface(bytes4 interfaceID) external view returns (bool);
}

/// @title ERC-173 Contract Ownership Standard
///  Note: the ERC-165 identifier for this interface is 0x7f5828d0
interface ERC173 is ERC165 {
    /// @dev This emits when ownership of a contract changes.    
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /// @notice Get the address of the owner    
    /// @return The address of the owner.
    function owner() view external returns(address);
	
    /// @notice Set the address of the new owner of the contract
    /// @dev Set _newOwner to address(0) to renounce any ownership.
    /// @param _newOwner The address of the new owner of the contract    
    function transferOwnership(address _newOwner) external;	
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

interface ManagedToken is ERC173, IPausable, IBlackList, IDeprecatable {
    function issue(uint amount, address to) external;

    function redeem(uint amount) external;
}
