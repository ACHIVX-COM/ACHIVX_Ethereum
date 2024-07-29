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
abstract contract Ownable is ERC173 {
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

    function transferOwnership(address newOwner) external override onlyOwner {
        owner = newOwner;
        emit OwnershipTransferred(msg.sender, newOwner);
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
    /**
     * Transfer tokens to multiple accounts
     *
     * @param tos addresses to send tokens to
     * @param values amounts of tokens to send (length must match length of @param tos)
     */
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
    function transfer(address _to, uint _value) public virtual override {
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
    function approve(address _spender, uint _value) public virtual override {
        // To change the approve amount you first have to reduce the addresses`
        //  allowance to zero by calling `approve(_spender, 0)` if it is not
        //  already 0 to mitigate the race condition described here:
        //  https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
        require(_value == 0 || allowed[msg.sender][_spender] == 0);

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

/**
 * @title Extended ERC20 token implementation mixin
 * @dev Implements a batch transfer method
 */
abstract contract ExtendedToken is StandardToken, ERC20Extended {
    using SafeMath for uint;

    /**
     * @notice transfer tokens to multiple addresses
     * @param _tos addresses to transfer tokens to
     * @param _values amounts of tokens to transfer to each address
     */
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
     * @inheritdoc IPausable
     */
    function pause() external onlyOwner whenNotPaused {
        paused = true;
        emit Pause();
    }

    /**
     * @inheritdoc IPausable
     */
    function unpause() external onlyOwner whenPaused {
        paused = false;
        emit Unpause();
    }
}

/**
 * @title Token with account blacklist mixin
 * @notice Maintains a blacklist of addresses.
 * Blacklist can be modified by contract owner.
 * Tokens owned by blacklisted addresses can be burned by contract owner.
 */
abstract contract BlackList is Ownable, BasicToken, IBlackList {
    mapping(address => bool) public isBlackListed;

    /**
     * @dev Requires a given address to not be blacklisted
     * @param account the address to check
     */
    modifier whenNotBlackListed(address account) {
        require(!isBlackListed[account], "account blacklisted");
        _;
    }

    /**
     * @inheritdoc IBlackList
     */
    function addBlackList(address _evilUser) external onlyOwner {
        isBlackListed[_evilUser] = true;
        emit AddedBlackList(_evilUser);
    }

    /**
     * @inheritdoc IBlackList
     */
    function removeBlackList(address _clearedUser) external onlyOwner {
        isBlackListed[_clearedUser] = false;
        emit RemovedBlackList(_clearedUser);
    }

    /**
     * @inheritdoc IBlackList
     */
    function destroyBlackFunds(address _blackListedUser) external onlyOwner {
        require(isBlackListed[_blackListedUser], "account not blacklisted");
        uint dirtyFunds = balanceOf(_blackListedUser);
        balances[_blackListedUser] = 0;
        _totalSupply -= dirtyFunds;
        emit DestroyedBlackFunds(_blackListedUser, dirtyFunds);
    }
}

/**
 * @title Interface for upgraded version of ERC20 token contract
 * @dev The methods defined in this interface should be only callable by the legacy contract
 */
interface UpgradedStandardToken is ERC20 {
    /**
     * @notice Method called by legacy contract when its `transfer` method is called
     * @param from address to transfer from; `msg.sender` of original transaction
     * @param to address to transfer tokens to
     * @param value amount of tokens to transfer
     */
    function transferByLegacy(address from, address to, uint value) external;

    /**
     * @notice Method called by legacy contract when its `transferFrom` method is called
     * @param sender `msg.sender` of original transaction that may be allowed to spend tokens of `from`
     * @param from address to transfer from
     * @param to address to transfer tokens to
     * @param value amount of tokens to transfer
     */
    function transferFromByLegacy(
        address sender,
        address from,
        address to,
        uint value
    ) external;

    /**
     * @notice Method called by legacy contract when its `approve` method is called
     * @param from the address that approves token spending; `msg.sender` of original transaction
     * @param spender the address that receives allowance from `from`
     * @param value the new allowance value
     */
    function approveByLegacy(
        address from,
        address spender,
        uint value
    ) external;

    /**
     * @notice Method called by legacy contract when its `batchTransfer` extension method is called
     * @param from the address to transfer tokens from; `msg.sender` of original transaction
     * @param tos addresses to send tokens to
     * @param values amounts of tokens to send
     */
    function batchTransferByLegacy(
        address from,
        address[] calldata tos,
        uint[] calldata values
    ) external;
}

/**
 * @title Deprecatable/upgradable contract mixin
 * @dev Contract owner may declare this contract deprecated and set an address of the new implementation.
 * It's responsibility of concrete contract to delegate method calls to the new implementation.
 */
abstract contract Deprecateable is Ownable, IDeprecatable {
    address public upgradedAddress;
    bool public deprecated;

    constructor() {
        deprecated = false;
    }

    /** Emitted when contract is deprecated */
    event Deprecate(address newAddress);

    /**
     * @inheritdoc IDeprecatable
     */
    function deprecate(address _upgradedAddress) external onlyOwner {
        deprecated = true;
        upgradedAddress = _upgradedAddress;
        emit Deprecate(_upgradedAddress);
    }

    /**
     * @dev Allow a method to be called by upgraded version of the token contract only.
     */
    modifier onlyUpgraded() {
        require(deprecated, "contract not deprecated");
        require(upgradedAddress == msg.sender);
        _;
    }

    /**
     * @dev Disallow a method from being called when the contract is deprecated.
     */
    modifier whenNotDeprecated() {
        require(!deprecated, "contract is deprecated");
        _;
    }
}

/**
 * @title A deprecatable ERC20 token interface
 * @dev Contains methods of deprecatable ERC20 token that can be used by it's upgraded version.
 */
interface LegacyToken is ERC20, IDeprecatable {
    /**
     * @notice Read balance of given account before contract deprecation.
     * @dev The balanceOf method is expected to be delegated to the upgraded contract, so a separate method is
     * necessary to let the upgraded contract fetch initial balances of accounts.
     * @param addr the address
     * @return balance balance of the address before contract upgrade
     */
    function legacyBalance(address addr) external view returns (uint balance);

    /**
     * @notice Read allowance from before the contract was deprecated.
     * @dev The allowance() method is expected to be delegated to the upgraded contract, so a separate method is
     * necessary to let the upgraded contract fetch initial allowances.
     * @param from address to spend tokens from
     * @param to address that is allowed to spend tokens
     * @return remaining remaining allowance
     */
    function legacyAllowance(
        address from,
        address to
    ) external view returns (uint remaining);

    /**
     * @notice Emit Transfer event from upgrade contract.
     * @dev Should only be callable by the upgrade contract.
     * Makes transfers performed through the upgrade contract be reflected in the legacy contract.
     * @param from the address tokens were transferred from
     * @param to the address tokens were sent to
     * @param value amount of tokens transferred
     */
    function emitTransfer(address from, address to, uint value) external;

    /**
     * @notice Emit Approval event from upgrade contract.
     * @dev Should only be callable from upgrade contract.
     * @param owner owner of the wallet
     * @param spender the address allowed to spend tokens
     * @param value new allowance value
     */
    function emitApproval(address owner, address spender, uint value) external;
}

/**
 * @title An upgradeable ERC20 token contract.
 * @notice Based on Tether USD (USDT) contract.
 */
contract Token is
    Deprecateable,
    LegacyToken,
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

    /**
     * @inheritdoc ERC165
     */
    function supportsInterface(
        bytes4 interfaceID
    ) external pure returns (bool) {
        return
            (interfaceID == 0x01ffc9a7) || // ERC165
            (interfaceID == 0x7f5828d0) || // ERC173
            (interfaceID == 0x36372b07) || // ERC20
            false;
    }

    /**
     * @inheritdoc ERC20Basic
     */
    function transfer(
        address _to,
        uint _value
    )
        public
        override(BasicToken, ERC20Basic)
        whenNotPaused
        whenNotBlackListed(msg.sender)
    {
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

    /**
     * @inheritdoc ERC20
     */
    function transferFrom(
        address _from,
        address _to,
        uint _value
    )
        public
        override(ERC20, StandardToken)
        whenNotPaused
        whenNotBlackListed(_from)
    {
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

    /**
     * @inheritdoc ERC20Basic
     */
    function balanceOf(
        address who
    ) public view override(BasicToken, ERC20Basic) returns (uint) {
        if (deprecated) {
            return UpgradedStandardToken(upgradedAddress).balanceOf(who);
        } else {
            return super.balanceOf(who);
        }
    }

    /**
     * @inheritdoc ERC20
     */
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

    /**
     * @inheritdoc ERC20
     */
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

    /**
     * @inheritdoc ERC20Extended
     */
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

    /**
     * @inheritdoc ERC20Basic
     */
    function totalSupply() public view returns (uint) {
        if (deprecated) {
            return StandardToken(upgradedAddress).totalSupply();
        } else {
            return _totalSupply;
        }
    }

    /**
     * @inheritdoc LegacyToken
     */
    function legacyBalance(
        address addr
    ) external view onlyUpgraded returns (uint balance) {
        balance = balances[addr];
    }

    /**
     * @inheritdoc LegacyToken
     */
    function legacyAllowance(
        address from,
        address to
    ) external view onlyUpgraded returns (uint remaining) {
        remaining = allowed[from][to];
    }

    /**
     * @inheritdoc LegacyToken
     */
    function emitTransfer(
        address from,
        address to,
        uint value
    ) external onlyUpgraded {
        emit Transfer(from, to, value);
    }

    /**
     * @inheritdoc LegacyToken
     */
    function emitApproval(
        address owner,
        address spender,
        uint value
    ) external onlyUpgraded {
        emit Approval(owner, spender, value);
    }

    /**
     * @inheritdoc ISupply
     */
    function issue(
        uint amount,
        address to
    ) external onlyOwner whenNotDeprecated {
        require(_totalSupply + amount > _totalSupply);
        require(balances[to] + amount > balances[to]);

        balances[to] = balances[to].add(amount);
        _totalSupply = _totalSupply.add(amount);
        emit Issue(amount, to);
    }

    /**
     * @inheritdoc ISupply
     */
    function redeem(uint amount) external onlyOwner whenNotDeprecated {
        _totalSupply = _totalSupply.sub(amount);
        balances[owner] = balances[owner].sub(amount);
        emit Redeem(amount);
    }
}
