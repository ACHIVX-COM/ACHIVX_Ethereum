// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import "./ManagedToken.sol";

/**
 * @title A multi-signature contract for token management
 * @notice Enables multiple users to manage a token contract.
 * List of contract owners is set on initialization.
 * All actions should be approved by majority (N / 2 + 1) of owners.
 * List of owners can be changed with approval of the same majority of current owners.
 * There must always be at least 3 owner accounts.
 * @notice This contract supports fixed set of actions that can be performed on managed token contracts or the management contract itself.
 * Such actions include change of token ownership token supply regulation, token blacklist management, etc.
 * For each supported action, there are two methods.
 * First method named `request*` enables any owner account to suggest an action to perform.
 * Such methods create a "request" in this management contract and return it's unique identifier.
 * The second method named `approve*` then should be called by other owner(s) to approve the operation.
 * The action is executed immediately, as part of the `approve*` method when the last approval happens.
 */
contract MultisigManager {
    // region voting accounts management internal
    /**
     * @dev Minimal number of voting accounts.
     * Attempts to initialize the contract with a number of voting accounts less than this one or to change list of voting accounts
     * to such size will be reverted.
     */
    uint public constant MIN_VOTING_ACCOUNTS = 3;

    mapping(address => bool) public isVotingAccount;

    /**
     * @dev Number of active voting accounts.
     * List and number of voting accounts can be changed (see `requestVotersListChange`, `approveVotersListChange`)
     * but their number never goes below `MIN_VOTING_ACCOUNTS`.
     */
    uint public votingAccountsNumber;

    /**
     * @dev Version of voting accounts list.
     * This number is increased every time the owners list changes.
     * It is used to prevent requests initiated with different owners list from being approved after the list is changed.
     */
    uint private votingAccountsListGeneration;

    /**
     * @notice Emitted when an `address` is added to the owners list
     */
    event VoterAdded(address);
    /**
     * @notice Emitted when `address` is removed from owners list
     */
    event VoterRemoved(address);

    /**
     * @dev Add an address to the list of owners.
     * Does nothing if the address is already an owner.
     */
    function _addVotingAccount(address addr) private {
        require(
            addr != address(0),
            "cannot add zero address to voting accounts list"
        );

        if (!isVotingAccount[addr]) {
            assert(votingAccountsNumber < type(uint).max);
            isVotingAccount[addr] = true;
            votingAccountsNumber += 1;
            emit VoterAdded(addr);
        }
    }

    /**
     * @dev Remove an address from the list of owners.
     * Does nothing if the address is not an owner.
     */
    function _removeVotingAccount(address addr) private {
        if (isVotingAccount[addr]) {
            require(
                votingAccountsNumber - 1 >= MIN_VOTING_ACCOUNTS,
                "not enough voting accounts will remain"
            );
            isVotingAccount[addr] = false;
            votingAccountsNumber -= 1;
            emit VoterRemoved(addr);
        }
    }
    // endregion

    // region generic request handling
    struct Request {
        mapping(address => bool) approvedBy;
        uint approvals;
        bool completed;
        /** @dev `votingAccountsListGeneration` at moment of this request creation */
        uint generation;
    }

    mapping(bytes32 => Request) private requests;
    uint private requestCount = 0;

    /**
     * @dev Emitted when a request gets executed after getting enough approvals
     */
    event RequestCompleted(bytes32 indexed reqId);

    /**
     * @dev Create a request and approve it from the sender of current transaction.
     * @dev The returned request identifier is a pseudo-random number based on request index and previous block hash.
     * That makes request ids unpredictable enough to make it difficult enough to create (accidentally or maliciously)
     * a confirmation transaction before the request is created.
     * @return reqId identifier of the created request; it can be used later to call `_approveRequest`
     */
    function _makeRequest() private returns (bytes32 reqId) {
        require(isVotingAccount[msg.sender], "not a voting account");
        reqId = keccak256(
            abi.encode(requestCount++, blockhash(block.number - 1))
        );
        assert(requests[reqId].approvals == 0); // Check for request id collision
        requests[reqId].approvedBy[msg.sender] = true;
        requests[reqId].approvals = 1;
        requests[reqId].generation = votingAccountsListGeneration;
    }

    /**
     * @dev Approve given request by the sender of current transaction.
     * @return approved `true` iff the approval is successful and is the last approval necessary to execute the request;
     * the caller is expected to execute the request immediately in such case.
     */
    function _approveRequest(bytes32 reqId) private returns (bool approved) {
        require(isVotingAccount[msg.sender], "not a voting account");

        Request storage req = requests[reqId];

        require(req.approvals > 0, "invalid request id");
        require(!req.completed, "request already completed");
        require(
            req.generation == votingAccountsListGeneration,
            "request invalidated after voters list change"
        );
        require(
            !req.approvedBy[msg.sender],
            "already approved by this account"
        );

        req.approvedBy[msg.sender] = true;
        req.approvals += 1;

        if (req.approvals >= getMinApprovals()) {
            approved = true;
            req.completed = true;
            emit RequestCompleted(reqId);
        }
    }

    /**
     * @notice Returns the number of approvals necessary to execute a request.
     * The number is based on current owners list size.
     */
    function getMinApprovals() public view returns (uint approvals) {
        approvals = (votingAccountsNumber >> 1) + 1;
    }

    modifier whenTokenAddressValid(ManagedToken token) {
        require(address(token) != address(0), "token address cannot be zero");
        _;
    }
    // endregion

    // region constructor
    /**
     * @param votingAccounts initial list of voting accounts/owners. Should contain at least `MIN_VOTING_ACCOUNTS` distinct addresses.
     */
    constructor(address[] memory votingAccounts) {
        for (uint i = 0; i < votingAccounts.length; ++i) {
            _addVotingAccount(votingAccounts[i]);
        }

        require(
            votingAccountsNumber >= MIN_VOTING_ACCOUNTS,
            "not enough voting accounts"
        );

        votingAccountsListGeneration = 1;
    }
    // endregion

    // region owner change
    struct OwnerChangeRequest {
        ManagedToken token;
        address newOwner;
    }

    mapping(bytes32 => OwnerChangeRequest) private ownerChangeRequests;

    /**
     * @notice Emitted when token owner change requested
     * @param reqId request id
     * @param by address that sent the request
     * @param token token contract address
     * @param newOwner new owner address
     */
    event OwnerChangeRequested(
        bytes32 reqId,
        address by,
        address token,
        address newOwner
    );

    /**
     * @notice Create a request to change owner of `token` to `newOwner`.
     * @notice Emits `OwnerChangeRequested` event with request id and parameters.
     * @return reqId the identifier of the request that can later be used with `approveOwnerChange`
     */
    function requestOwnerChange(
        ManagedToken token,
        address newOwner
    ) external whenTokenAddressValid(token) returns (bytes32 reqId) {
        reqId = _makeRequest();
        ownerChangeRequests[reqId].token = token;
        ownerChangeRequests[reqId].newOwner = newOwner;
        emit OwnerChangeRequested(reqId, msg.sender, address(token), newOwner);
    }

    /**
     * @notice Approve an owner change request
     * @param reqId request id generated by `requestOwnerChange`
     */
    function approveOwnerChange(bytes32 reqId) external {
        require(
            ownerChangeRequests[reqId].newOwner != address(0),
            "invalid owner change request id"
        );

        if (_approveRequest(reqId)) {
            ownerChangeRequests[reqId].token.transferOwnership(
                ownerChangeRequests[reqId].newOwner
            );
        }
    }
    // endregion

    // region voters change
    struct VotersChangeRequest {
        address[] addVoters;
        address[] removeVoters;
    }
    mapping(bytes32 => VotersChangeRequest) private votersChangeRequests;

    /**
     * @notice Emitted when owners list change is requested
     * @param reqId request id
     * @param by address that sent the request
     * @param add addresses to add to owners list
     * @param remove addresses to remove from owners list
     */
    event VotersListChangeRequested(
        bytes32 reqId,
        address by,
        address[] add,
        address[] remove
    );

    /**
     * @notice Create a request to change list of owners.
     * @notice Emits `VotersListChangeRequested` with request id and parameters.
     * @dev When request executes, first `addVoters` will be added to the list then `removeVoters` will be removed.
     * So, `removeVoters` has "higher priority" than `addVoters` and if certain address is contained in both of them
     * then it will not be a voter after request execution.
     * @param addVoters addresses to add to the list
     * @param removeVoters addresses to remove from the list
     * @return reqId the identifier of the request that can later be used with `approveVotersListChange`
     */
    function requestVotersListChange(
        address[] calldata addVoters,
        address[] calldata removeVoters
    ) external returns (bytes32 reqId) {
        require(addVoters.length > 0 || removeVoters.length > 0);

        reqId = _makeRequest();
        votersChangeRequests[reqId].addVoters = addVoters;
        votersChangeRequests[reqId].removeVoters = removeVoters;
        emit VotersListChangeRequested(
            reqId,
            msg.sender,
            addVoters,
            removeVoters
        );
    }

    /**
     * @notice Approve owners list change request
     * @param reqId request id generated by `requestVotersListChange`
     */
    function approveVotersListChange(bytes32 reqId) external {
        address[] storage addVoters = votersChangeRequests[reqId].addVoters;
        address[] storage removeVoters = votersChangeRequests[reqId]
            .removeVoters;
        require(
            addVoters.length > 0 || removeVoters.length > 0,
            "invalid voters list change request"
        );

        if (_approveRequest(reqId)) {
            for (uint i = 0; i < addVoters.length; ++i) {
                _addVotingAccount(addVoters[i]);
            }

            for (uint i = 0; i < removeVoters.length; ++i) {
                _removeVotingAccount(removeVoters[i]);
            }
        }

        votingAccountsListGeneration += 1;
    }
    // endregion

    // region pause
    mapping(bytes32 => ManagedToken) private pauseRequests;

    /**
     * @notice Emitted when token pause is requested
     * @param reqId request id
     * @param by address that sent the request
     * @param token token contract address
     */
    event PauseRequested(bytes32 reqId, address by, address token);

    /**
     * @notice Request token pause.
     * @notice Emits `PauseRequested` with request id and parameters
     * @param token the token to pause
     * @return reqId the identifier of the request that can later be used with `approveTokenPause`
     */
    function requestTokenPause(
        ManagedToken token
    ) external whenTokenAddressValid(token) returns (bytes32 reqId) {
        reqId = _makeRequest();
        pauseRequests[reqId] = token;
        emit PauseRequested(reqId, msg.sender, address(token));
    }

    /**
     * @notice Approve token pause request
     * @param reqId request id generated by `requestTokenPause`
     */
    function approveTokenPause(bytes32 reqId) external {
        require(
            address(pauseRequests[reqId]) != address(0),
            "invalid pause request id"
        );

        if (_approveRequest(reqId)) {
            pauseRequests[reqId].pause();
        }
    }
    // endregion

    // region unpause
    mapping(bytes32 => ManagedToken) private unpauseRequests;

    /**
     * @notice Emitted when token unpause is requested
     * @param reqId request id
     * @param by address that sent the request
     * @param token token contract address
     */
    event UnpauseRequested(bytes32 reqId, address by, address token);

    /**
     * @notice Request token unpause.
     * @notice Emits `UnpauseRequested` with request id and parameters
     * @param token the token to unpause
     * @return reqId the identifier of the request that can later be used with `approveTokenUnpause`
     */
    function requestTokenUnpause(
        ManagedToken token
    ) external whenTokenAddressValid(token) returns (bytes32 reqId) {
        reqId = _makeRequest();
        unpauseRequests[reqId] = token;
        emit UnpauseRequested(reqId, msg.sender, address(token));
    }

    /**
     * @notice Approve token unpause request
     * @param reqId request id generated by `requestTokenUnpause`
     */
    function approveTokenUnpause(bytes32 reqId) external {
        require(
            address(unpauseRequests[reqId]) != address(0),
            "invalid unpause request id"
        );

        if (_approveRequest(reqId)) {
            unpauseRequests[reqId].unpause();
        }
    }
    // endregion

    // region blacklist address
    struct BlacklistRequest {
        ManagedToken token;
        address account;
    }
    mapping(bytes32 => BlacklistRequest) private blacklistRequests;

    /**
     * @notice Emitted when blacklisting is requested
     * @param reqId request id
     * @param by address that sent the request
     * @param token token contract address
     * @param account the account to add to blacklist
     */
    event BlacklistRequested(
        bytes32 reqId,
        address by,
        address token,
        address account
    );

    /**
     * @notice Request blacklisting an account.
     * @notice Emits `BlacklistRequested` with request id and parameters
     * @param token the token to blacklist account in
     * @param account address to blacklist
     * @return reqId the identifier of the request that can later be used with `approveBlacklist`
     */
    function requestBlacklist(
        ManagedToken token,
        address account
    ) external whenTokenAddressValid(token) returns (bytes32 reqId) {
        reqId = _makeRequest();
        blacklistRequests[reqId].token = token;
        blacklistRequests[reqId].account = account;
        emit BlacklistRequested(reqId, msg.sender, address(token), account);
    }

    /**
     * @notice Approve account blacklisting request
     * @param reqId request id generated by `requestBlacklist`
     */
    function approveBlacklist(bytes32 reqId) external {
        require(
            address(blacklistRequests[reqId].token) != address(0),
            "invalid blacklist request id"
        );

        if (_approveRequest(reqId)) {
            blacklistRequests[reqId].token.addBlackList(
                blacklistRequests[reqId].account
            );
        }
    }
    // endregion

    // region unblacklist address
    mapping(bytes32 => BlacklistRequest) private unblacklistRequests;

    /**
     * @notice Emitted when un-blacklisting is requested
     * @param reqId request id
     * @param by address that sent the request
     * @param token token contract address
     * @param account the account to remove from blacklist
     */
    event UnblacklistRequested(
        bytes32 reqId,
        address by,
        address token,
        address account
    );

    /**
     * @notice Request un-blacklisting an account.
     * @notice Emits `UnblacklistRequested` with request id and parameters
     * @param token the token to un-blacklist account in
     * @param account address to un-blacklist
     * @return reqId the identifier of the request that can later be used with `approveUnblacklist`
     */
    function requestUnblacklist(
        ManagedToken token,
        address account
    ) external whenTokenAddressValid(token) returns (bytes32 reqId) {
        reqId = _makeRequest();
        unblacklistRequests[reqId].token = token;
        unblacklistRequests[reqId].account = account;
        emit UnblacklistRequested(reqId, msg.sender, address(token), account);
    }

    /**
     * @notice Approve account un-blacklisting request
     * @param reqId request id generated by `requestUnblacklist`
     */
    function approveUnblacklist(bytes32 reqId) external {
        require(
            address(unblacklistRequests[reqId].token) != address(0),
            "invalid unblacklist request id"
        );

        if (_approveRequest(reqId)) {
            unblacklistRequests[reqId].token.removeBlackList(
                unblacklistRequests[reqId].account
            );
        }
    }
    // endregion

    // region destroy black funds
    mapping(bytes32 => BlacklistRequest) private blackFundsDestroyRequests;

    /**
     * @notice Emitted when destruction of tokens owned by a blacklisted account is requested
     * @param reqId request id
     * @param by address that sent the request
     * @param token token contract address
     * @param account the account to remove tokens from
     */
    event BlackFundsDestructionRequested(
        bytes32 reqId,
        address by,
        address token,
        address account
    );

    /**
     * @notice Request burning of tokens owned by a blacklisted address.
     * @notice Emits `BlackFundsDestructionRequested` with request id and parameters
     * @param token token contract
     * @param account the blacklisted address whose tokens should be burned
     * @return reqId the identifier of the request that can later be used with `approveBlackFundsDestruction`
     */
    function requestBlackFundsDestruction(
        ManagedToken token,
        address account
    ) external whenTokenAddressValid(token) returns (bytes32 reqId) {
        reqId = _makeRequest();
        blackFundsDestroyRequests[reqId].token = token;
        blackFundsDestroyRequests[reqId].account = account;
        emit BlackFundsDestructionRequested(
            reqId,
            msg.sender,
            address(token),
            account
        );
    }

    /**
     * @notice Approve request for burning tokens owned by a blacklisted account.
     * @param reqId request id generated by `requestBlackFundsDestruction`
     */
    function approveBlackFundsDestruction(bytes32 reqId) external {
        require(
            address(blackFundsDestroyRequests[reqId].token) != address(0),
            "invalid funds destruction request id"
        );

        if (_approveRequest(reqId)) {
            blackFundsDestroyRequests[reqId].token.destroyBlackFunds(
                blackFundsDestroyRequests[reqId].account
            );
        }
    }
    // endregion

    // region deprecate
    struct DeprecationRequest {
        ManagedToken token;
        address upgradedToken;
    }
    mapping(bytes32 => DeprecationRequest) private deprecationRequests;

    /**
     * @notice Emitted when token contract deprecation is requested
     * @param reqId request id
     * @param by address that sent the request
     * @param token token contract address
     * @param upgraded address of upgraded token implementation
     */
    event DeprecationRequested(
        bytes32 reqId,
        address by,
        address token,
        address upgraded
    );

    /**
     * @notice Request deprecation of token contract.
     * @notice Emits `DeprecationRequested` with request id and parameters
     * @param token token contract
     * @param upgraded new implementation contract
     * @return reqId the identifier of the request that can later be used with `approveDeprecation`
     */
    function requestDeprecation(
        ManagedToken token,
        address upgraded
    ) external whenTokenAddressValid(token) returns (bytes32 reqId) {
        require(upgraded != address(0));

        reqId = _makeRequest();
        deprecationRequests[reqId].token = token;
        deprecationRequests[reqId].upgradedToken = upgraded;
        emit DeprecationRequested(reqId, msg.sender, address(token), upgraded);
    }

    /**
     * @notice Approve request for deprecation of token contract
     * @param reqId request id generated by `requestDeprecation`
     */
    function approveDeprecation(bytes32 reqId) external {
        require(
            address(deprecationRequests[reqId].token) != address(0),
            "invalid deprecation request id"
        );

        if (_approveRequest(reqId)) {
            deprecationRequests[reqId].token.deprecate(
                deprecationRequests[reqId].upgradedToken
            );
        }
    }
    // endregion

    // region issue
    struct TokenIssueRequest {
        ManagedToken token;
        address to;
        uint amount;
    }
    mapping(bytes32 => TokenIssueRequest) private issueRequests;

    /**
     * @notice Emitted when token issue is requested
     * @param reqId request id
     * @param by address that sent the request
     * @param token token contract address
     * @param amount amount of tokens to create
     * @param to address to send token to
     */
    event IssueRequested(
        bytes32 reqId,
        address by,
        address token,
        uint amount,
        address to
    );

    /**
     * @notice Request issue (mint, emission) of new tokens.
     * @notice Emits `IssueRequested` with request id and parameters
     * @param token token contract
     * @param amount number of tokens to create
     * @param to address to send tokens to
     * @return reqId the identifier of the request that can later be used with `approveIssue`
     */
    function requestIssue(
        ManagedToken token,
        uint amount,
        address to
    ) external whenTokenAddressValid(token) returns (bytes32 reqId) {
        require(amount > 0);

        reqId = _makeRequest();
        issueRequests[reqId].token = token;
        issueRequests[reqId].to = to;
        issueRequests[reqId].amount = amount;
        emit IssueRequested(reqId, msg.sender, address(token), amount, to);
    }

    /**
     * @notice Approve request for tokens emission
     * @param reqId request id generated by `requestIssue`
     */
    function approveIssue(bytes32 reqId) external {
        require(
            address(issueRequests[reqId].token) != address(0),
            "invalid issue request id"
        );

        if (_approveRequest(reqId)) {
            issueRequests[reqId].token.issue(
                issueRequests[reqId].amount,
                issueRequests[reqId].to
            );
        }
    }
    // endregion

    // region redeem
    struct RedeemRequest {
        ManagedToken token;
        uint amount;
    }
    mapping(bytes32 => RedeemRequest) private redeemRequests;

    /**
     * @notice Emitted when token destruction
     * @param reqId request id
     * @param by address that sent the request
     * @param token token contract address
     * @param amount amount of tokens to burn
     */
    event RedeemRequested(
        bytes32 reqId,
        address by,
        address token,
        uint amount
    );

    /**
     * @notice Request redeeming (burning) tokens.
     * @notice Tokens should be first transferred to token's owner address - this contract.
     * @notice Emits `RedeemRequested` with request id and parameters
     * @param token token contract
     * @param amount number of tokens to burn
     * @return reqId the identifier of the request that can later be used with `approveRedeem`
     */
    function requestRedeem(
        ManagedToken token,
        uint amount
    ) external whenTokenAddressValid(token) returns (bytes32 reqId) {
        require(amount > 0);

        reqId = _makeRequest();
        redeemRequests[reqId].token = token;
        redeemRequests[reqId].amount = amount;
        emit RedeemRequested(reqId, msg.sender, address(token), amount);
    }

    /**
     * @notice Approve request for tokens destruction
     * @param reqId request id generated by `requestRedeem`
     */
    function approveRedeem(bytes32 reqId) external {
        require(
            address(redeemRequests[reqId].token) != address(0),
            "invalid redeem request id"
        );

        if (_approveRequest(reqId)) {
            redeemRequests[reqId].token.redeem(redeemRequests[reqId].amount);
        }
    }
    // endregion
}
