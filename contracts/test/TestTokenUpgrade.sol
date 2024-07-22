// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../TokenUpgrade.sol";

/**
 * @title Upgrade contract for testing purposes
 *
 * @dev Actual upgrade contract should at least also implement Ownable and Deprecatable (for further upgrades).
 */
contract TestTokenUpgrade is TokenUpgrade {
    using SafeMath for uint;

    constructor(LegacyToken _legacy) TokenUpgrade(_legacy) {}

    function transfer(address to, uint value) external {
        _setBalance(msg.sender, balanceOf(msg.sender).sub(value));
        _setBalance(to, balanceOf(to).add(value));
        _emitTransfer(msg.sender, to, value);
    }

    function transferFrom(address from, address to, uint value) external {
        _setAllowance(from, to, allowance(from, msg.sender).sub(value));
        _setBalance(from, balanceOf(from).sub(value));
        _setBalance(to, balanceOf(to).add(value));
        _emitTransfer(from, to, value);
    }

    function approve(address spender, uint value) external {
        _setAllowance(msg.sender, spender, value);
        _emitApproval(msg.sender, spender, value);
    }

    function transferByLegacy(
        address from,
        address to,
        uint value
    ) external legacyOnly {
        _setBalance(from, balanceOf(from).sub(value));
        _setBalance(to, balanceOf(to).add(value));
        _emitTransfer(from, to, value);
    }

    function transferFromByLegacy(
        address sender,
        address from,
        address to,
        uint value
    ) external legacyOnly {
        _setAllowance(from, sender, allowance(from, sender).sub(value));
        _setBalance(from, balanceOf(from).sub(value));
        _setBalance(to, balanceOf(to).add(value));
        _emitTransfer(from, to, value);
    }

    function approveByLegacy(
        address from,
        address spender,
        uint value
    ) external legacyOnly {
        _setAllowance(from, spender, value);
        _emitApproval(from, spender, value);
    }

    function batchTransferByLegacy(
        address from,
        address[] calldata tos,
        uint[] calldata values
    ) external legacyOnly {
        require(tos.length == values.length);

        uint fromBalance = balanceOf(from);

        for (uint i = 0; i < tos.length; ++i) {
            uint value = values[i];
            fromBalance = fromBalance.sub(value);
            address to = tos[i];
            require(to != from);
            _setBalance(to, balanceOf(to).add(value));
            _emitTransfer(from, to, value);
        }

        _setBalance(from, fromBalance);
    }
}
