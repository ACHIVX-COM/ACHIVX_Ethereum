// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./Token.sol";

/**
 * @title Base contract for contracts that can be used as upgraded versions of Token
 */
abstract contract TokenUpgrade is UpgradedStandardToken {
    mapping(address => bool) private isBalanceMigrated;
    mapping(address => uint) private balances;

    mapping(address => mapping(address => bool)) private isAllowanceMigrated;
    mapping(address => mapping(address => uint)) private allowed;

    uint internal _totalSupply;

    LegacyToken internal legacyToken;

    constructor(LegacyToken _legacyToken) {
        legacyToken = _legacyToken;
        _totalSupply = _legacyToken.totalSupply();
    }

    modifier legacyOnly() {
        require(
            msg.sender == address(legacyToken),
            "called not from legacy contract"
        );
        _;
    }

    function _setBalance(address addr, uint value) internal {
        balances[addr] = value;
        isBalanceMigrated[addr] = true;
    }

    function _setAllowance(address from, address to, uint value) internal {
        allowed[from][to] = value;
        isAllowanceMigrated[from][to] = true;
    }

    function _emitTransfer(address from, address to, uint value) internal {
        emit Transfer(from, to, value);
        legacyToken.emitTransfer(from, to, value);
    }

    function _emitApproval(
        address owner,
        address spender,
        uint value
    ) internal {
        emit Approval(owner, spender, value);
        legacyToken.emitApproval(owner, spender, value);
    }

    function totalSupply() external view returns (uint) {
        return _totalSupply;
    }

    function balanceOf(address who) public view returns (uint balance) {
        if (isBalanceMigrated[who]) {
            balance = balances[who];
        } else {
            balance = legacyToken.legacyBalance(who);
        }
    }

    function allowance(
        address owner,
        address spender
    ) public view returns (uint) {
        if (isAllowanceMigrated[owner][spender]) {
            return allowed[owner][spender];
        } else {
            return legacyToken.legacyAllowance(owner, spender);
        }
    }
}
