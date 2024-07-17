// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./ManagedToken.sol";

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);
        return c;
    }
}

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
abstract contract Ownable is IOwnable {
    address public owner;

    /**
     * @param _initialOwner the initial owner of the contract
     */
    constructor(address _initialOwner) {
        require(_initialOwner != address(0), "owner is zero");
        owner = _initialOwner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "not an owner");
        _;
    }

    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(address newOwner) public override onlyOwner {
        if (newOwner != address(0)) {
            owner = newOwner;
        }
    }
}

/**
 * @title ERC20Basic
 * @dev Simpler version of ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
interface ERC20Basic {
    function totalSupply() external view returns (uint);
    function balanceOf(address who) external view returns (uint);
    function transfer(address to, uint value) external;
    event Transfer(address indexed from, address indexed to, uint value);
}

/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
interface ERC20 is ERC20Basic {
    function allowance(
        address owner,
        address spender
    ) external view returns (uint);
    function transferFrom(address from, address to, uint value) external;
    function approve(address spender, uint value) external;
    event Approval(address indexed owner, address indexed spender, uint value);
}

/**
 * @title ERC20 interface with extension functions
 */
interface ERC20Extended is ERC20 {
    function batchTransfer(
        address[] calldata tos,
        uint[] calldata values
    ) external;
}

/**
 * @title Basic token
 * @dev Basic version of StandardToken, with no allowances.
 */
abstract contract BasicToken is Ownable, ERC20Basic {
    using SafeMath for uint;

    uint public _totalSupply;

    mapping(address => uint) public balances;

    constructor(uint _initialSupply, address _supplier) {
        _totalSupply = _initialSupply;
        balances[_supplier] = _initialSupply;
    }

    /**
     * @dev transfer token for a specified address
     * @param _to The address to transfer to.
     * @param _value The amount to be transferred.
     */
    function transfer(
        address _to,
        uint _value
    ) public virtual override {
        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        emit Transfer(msg.sender, _to, _value);
    }

    /**
     * @dev Gets the balance of the specified address.
     * @param _owner The address to query the the balance of.
     * @return balance An uint representing the amount owned by the passed address.
     */
    function balanceOf(
        address _owner
    ) public view virtual override returns (uint balance) {
        return balances[_owner];
    }
}

/**
 * @title Standard ERC20 token
 *
 * @dev Implementation of the basic standard token.
 * @dev https://github.com/ethereum/EIPs/issues/20
 * @dev Based oncode by FirstBlood: https://github.com/Firstbloodio/token/blob/master/smart_contract/FirstBloodToken.sol
 */
abstract contract StandardToken is BasicToken, ERC20 {
    using SafeMath for uint;

    mapping(address => mapping(address => uint)) public allowed;

    uint public constant MAX_UINT = 2 ** 256 - 1;

    /**
     * @dev Transfer tokens from one address to another
     * @param _from address The address which you want to send tokens from
     * @param _to address The address which you want to transfer to
     * @param _value uint the amount of tokens to be transferred
     */
    function transferFrom(
        address _from,
        address _to,
        uint _value
    ) public virtual override {
        uint _allowance = allowed[_from][msg.sender];

        if (_allowance < MAX_UINT) {
            allowed[_from][msg.sender] = _allowance.sub(_value);
        }
        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_value);
        emit Transfer(_from, _to, _value);
    }

    /**
     * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
     * @param _spender The address which will spend the funds.
     * @param _value The amount of tokens to be spent.
     */
    function approve(
        address _spender,
        uint _value
    ) public virtual override {
        // To change the approve amount you first have to reduce the addresses`
        //  allowance to zero by calling `approve(_spender, 0)` if it is not
        //  already 0 to mitigate the race condition described here:
        //  https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
        require(!((_value != 0) && (allowed[msg.sender][_spender] != 0)));

        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
    }

    /**
     * @dev Function to check the amount of tokens than an owner allowed to a spender.
     * @param _owner address The address which owns the funds.
     * @param _spender address The address which will spend the funds.
     * @return remaining A uint specifying the amount of tokens still available for the spender.
     */
    function allowance(
        address _owner,
        address _spender
    ) public view virtual override returns (uint remaining) {
        return allowed[_owner][_spender];
    }
}

abstract contract ExtendedToken is StandardToken, ERC20Extended {
    using SafeMath for uint;

    function batchTransfer(
        address[] calldata _tos,
        uint[] calldata _values
    ) public virtual override {
        require(_tos.length == _values.length);
        uint senderBalance = balances[msg.sender];

        for (uint i = 0; i < _tos.length; ++i) {
            address to = _tos[i];
            require(to != address(0));
            uint amount = _values[i];
            require(amount > 0);
            require(amount <= senderBalance);

            if (to != msg.sender) {
                senderBalance = senderBalance.sub(amount);
                balances[to] = balances[to].add(amount);
            }

            emit Transfer(msg.sender, to, amount);
        }

        balances[msg.sender] = senderBalance;
    }
}

/**
 * @title Pausable
 * @dev Base contract which allows children to implement an emergency stop mechanism.
 */
abstract contract Pausable is Ownable, IPausable {
    event Pause();
    event Unpause();

    bool public paused = false;

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     */
    modifier whenNotPaused() {
        require(!paused, "contract paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     */
    modifier whenPaused() {
        require(paused, "contract not paused");
        _;
    }

    /**
     * @dev called by the owner to pause, triggers stopped state
     */
    function pause() public onlyOwner whenNotPaused {
        paused = true;
        emit Pause();
    }

    /**
     * @dev called by the owner to unpause, returns to normal state
     */
    function unpause() public onlyOwner whenPaused {
        paused = false;
        emit Unpause();
    }
}

abstract contract BlackList is Ownable, BasicToken, IBlackList {
    /////// Getters to allow the same blacklist to be used also by other contracts ///////
    function getBlackListStatus(address _maker) external view returns (bool) {
        return isBlackListed[_maker];
    }

    mapping(address => bool) public isBlackListed;

    modifier whenNotBlackListed(address account) {
        require(!isBlackListed[account], "account blacklisted");
        _;
    }

    function addBlackList(address _evilUser) public onlyOwner {
        isBlackListed[_evilUser] = true;
        emit AddedBlackList(_evilUser);
    }

    function removeBlackList(address _clearedUser) public onlyOwner {
        isBlackListed[_clearedUser] = false;
        emit RemovedBlackList(_clearedUser);
    }

    function destroyBlackFunds(address _blackListedUser) public onlyOwner {
        require(isBlackListed[_blackListedUser], "account not blacklisted");
        uint dirtyFunds = balanceOf(_blackListedUser);
        balances[_blackListedUser] = 0;
        _totalSupply -= dirtyFunds;
        emit DestroyedBlackFunds(_blackListedUser, dirtyFunds);
    }

    event DestroyedBlackFunds(address _blackListedUser, uint _balance);

    event AddedBlackList(address _user);

    event RemovedBlackList(address _user);
}

interface UpgradedStandardToken is ERC20 {
    // those methods are called by the legacy contract
    // and they must ensure msg.sender to be the contract address
    function transferByLegacy(address from, address to, uint value) external;
    function transferFromByLegacy(
        address sender,
        address from,
        address spender,
        uint value
    ) external;
    function approveByLegacy(
        address from,
        address spender,
        uint value
    ) external;
    function batchTransferByLegacy(
        address from,
        address[] calldata tos,
        uint[] calldata values
    ) external;
}

abstract contract Deprecateable is Ownable, IDeprecatable {
    address public upgradedAddress;
    bool public deprecated;

    constructor() {
        deprecated = false;
    }

    /** Emitted when contract is deprecated */
    event Deprecate(address newAddress);

    /**
     * Deprecate current contract in favour of a new one.
     */
    function deprecate(address _upgradedAddress) public onlyOwner {
        deprecated = true;
        upgradedAddress = _upgradedAddress;
        emit Deprecate(_upgradedAddress);
    }

    modifier onlyUpgraded() {
        require(deprecated, "contract not deprecated");
        require(upgradedAddress == msg.sender);
        _;
    }
}

contract Token is
    Deprecateable,
    Pausable,
    ExtendedToken,
    BlackList,
    ManagedToken
{
    using SafeMath for uint;

    string public name;
    string public symbol;
    uint public decimals;

    /**
     * @param _owner Initial owner of the contract
     * @param _initialSupply Initial supply of the contract
     * @param _supplier The wallet that receives initial supply of tokens
     * @param _name Token Name
     * @param _symbol Token symbol
     * @param _decimals Token decimals
     */
    constructor(
        address _owner,
        uint _initialSupply,
        address _supplier,
        string memory _name,
        string memory _symbol,
        uint _decimals
    ) Ownable(_owner) BasicToken(_initialSupply, _supplier) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    // Forward ERC20 methods to upgraded contract if this one is deprecated
    function transfer(
        address _to,
        uint _value
    ) public override(BasicToken, ERC20Basic) whenNotPaused whenNotBlackListed(msg.sender) {
        if (deprecated) {
            return
                UpgradedStandardToken(upgradedAddress).transferByLegacy(
                    msg.sender,
                    _to,
                    _value
                );
        } else {
            return super.transfer(_to, _value);
        }
    }

    // Forward ERC20 methods to upgraded contract if this one is deprecated
    function transferFrom(
        address _from,
        address _to,
        uint _value
    ) public override(ERC20, StandardToken) whenNotPaused whenNotBlackListed(_from) {
        if (deprecated) {
            return
                UpgradedStandardToken(upgradedAddress).transferFromByLegacy(
                    msg.sender,
                    _from,
                    _to,
                    _value
                );
        } else {
            return super.transferFrom(_from, _to, _value);
        }
    }

    // Forward ERC20 methods to upgraded contract if this one is deprecated
    function balanceOf(
        address who
    ) public view override(BasicToken, ERC20Basic) returns (uint) {
        if (deprecated) {
            return UpgradedStandardToken(upgradedAddress).balanceOf(who);
        } else {
            return super.balanceOf(who);
        }
    }

    // Forward ERC20 methods to upgraded contract if this one is deprecated
    function approve(
        address _spender,
        uint _value
    ) public override(ERC20, StandardToken) {
        if (deprecated) {
            return
                UpgradedStandardToken(upgradedAddress).approveByLegacy(
                    msg.sender,
                    _spender,
                    _value
                );
        } else {
            return super.approve(_spender, _value);
        }
    }

    // Forward ERC20 methods to upgraded contract if this one is deprecated
    function allowance(
        address _owner,
        address _spender
    ) public view override(ERC20, StandardToken) returns (uint remaining) {
        if (deprecated) {
            return StandardToken(upgradedAddress).allowance(_owner, _spender);
        } else {
            return super.allowance(_owner, _spender);
        }
    }

    // Forward ERC20 methods to upgraded contract if this one is deprecated
    function batchTransfer(
        address[] calldata _tos,
        uint[] calldata _values
    ) public override whenNotPaused whenNotBlackListed(msg.sender) {
        if (deprecated) {
            return
                UpgradedStandardToken(upgradedAddress).batchTransferByLegacy(
                    msg.sender,
                    _tos,
                    _values
                );
        } else {
            return super.batchTransfer(_tos, _values);
        }
    }

    // Forward ERC20 methods to upgraded contract if this one is deprecated
    function totalSupply() public view returns (uint) {
        if (deprecated) {
            return StandardToken(upgradedAddress).totalSupply();
        } else {
            return _totalSupply;
        }
    }

    /**
     * Emit transfer event from upgraded version of the contract.
     */
    function emitTransfer(address from, address to, uint value) public onlyUpgraded {
        emit Transfer(from, to, value);
    }

    /**
     * Emit approval event from upgraded version of the contract.
     */
    function emitApproval(address owner, address spender, uint value) public onlyUpgraded {
        emit Approval(owner, spender, value);
    }

    /**
     * Issue a new amount of tokens
     *
     * @param amount Number of tokens to be issued
     * @param to Address to send tokens to
     */
    function issue(uint amount, address to) public onlyOwner {
        require(_totalSupply + amount > _totalSupply);
        require(balances[to] + amount > balances[to]);

        balances[to] = balances[to].add(amount);
        _totalSupply = _totalSupply.add(amount);
        emit Issue(amount, to);
    }

    /**
     * Redeem tokens.
     * These tokens are withdrawn from the owner address.
     * The balance must be enough to cover the redeem or the call will fail.
     *
     * @param amount Number of tokens to be redeemed
     */
    function redeem(uint amount) public onlyOwner {
        _totalSupply = _totalSupply.sub(amount);
        balances[owner] = balances[owner].sub(amount);
        emit Redeem(amount);
    }

    /** Emitted when new token are issued */
    event Issue(uint amount, address to);

    /** Emitted when tokens are redeemed */
    event Redeem(uint amount);
}
