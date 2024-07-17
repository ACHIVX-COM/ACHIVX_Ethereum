// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./ManagedToken.sol";

contract MultisigManager {
    // region voting accounts management internal
    uint constant MIN_VOTING_ACCOUNTS = 3;

    mapping(address => bool) votingAccounts;
    uint votingAccountsNumber;
    uint votingAccountsListGeneration;

    function _addVotingAccount(address _addr) private {
        if (!votingAccounts[_addr]) {
            votingAccounts[_addr] = true;
            votingAccountsNumber += 1;
        }
    }

    function _removeVotingAccount(address _addr) private {
        if (votingAccounts[_addr]) {
            require(
                votingAccountsNumber - 1 >= MIN_VOTING_ACCOUNTS,
                "not enough voting accounts will remain"
            );
            votingAccounts[_addr] = false;
            votingAccountsNumber -= 1;
        }
    }
    // endregion

    // region generic request handling
    struct Request {
        mapping(address => bool) approvedBy;
        uint approvals;
        bool completed;
        uint generation;
    }

    mapping(bytes32 => Request) requests;
    uint requestCount = 0;

    function _makeRequest() private returns (bytes32 reqId) {
        require(votingAccounts[msg.sender], "not a voting account");
        reqId = keccak256(
            abi.encode(
                requestCount++,
                blockhash(block.number - 1),
                address(this)
            )
        );
        requests[reqId].approvedBy[msg.sender] = true;
        requests[reqId].approvals = 1;
        requests[reqId].generation = votingAccountsListGeneration;
    }

    function _approveRequest(bytes32 reqId) private returns (bool approved) {
        require(votingAccounts[msg.sender], "not a voting account");

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
        }
    }

    function getMinApprovals() public view returns (uint approvals) {
        approvals = (votingAccountsNumber >> 1) + 1;
    }
    // endregion

    // region constructor
    constructor(address[] memory _votingAccounts) {
        for (uint i = 0; i < _votingAccounts.length; ++i) {
            _addVotingAccount(_votingAccounts[i]);
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

    mapping(bytes32 => OwnerChangeRequest) ownerChangeRequests;
    event OwnerChangeRequested(
        bytes32 reqId,
        address by,
        address token,
        address newOwner
    );

    function requestOwnerChange(
        ManagedToken token,
        address newOwner
    ) external returns (bytes32 reqId) {
        reqId = _makeRequest();
        ownerChangeRequests[reqId].token = token;
        ownerChangeRequests[reqId].newOwner = newOwner;
        emit OwnerChangeRequested(reqId, msg.sender, address(token), newOwner);
    }

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
    mapping(bytes32 => VotersChangeRequest) votersChangeRequests;
    event VotersListChangeRequested(
        bytes32 reqId,
        address by,
        address[] add,
        address[] remove
    );

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
    mapping(bytes32 => ManagedToken) pauseRequests;
    event PauseRequested(bytes32 reqId, address by, address token);

    function requestTokenPause(
        ManagedToken token
    ) external returns (bytes32 reqId) {
        require(address(token) != address(0));
        reqId = _makeRequest();
        pauseRequests[reqId] = token;
        emit PauseRequested(reqId, msg.sender, address(token));
    }

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
    mapping(bytes32 => ManagedToken) unpauseRequests;
    event UnpauseRequested(bytes32 reqId, address by, address token);

    function requestTokenUnpause(
        ManagedToken token
    ) external returns (bytes32 reqId) {
        require(address(token) != address(0));
        reqId = _makeRequest();
        unpauseRequests[reqId] = token;
        emit UnpauseRequested(reqId, msg.sender, address(token));
    }

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
    mapping(bytes32 => BlacklistRequest) blacklistRequests;
    event BlacklistRequested(
        bytes32 reqId,
        address by,
        address token,
        address account
    );

    function requestBlacklist(
        ManagedToken token,
        address account
    ) external returns (bytes32 reqId) {
        require(address(token) != address(0));
        reqId = _makeRequest();
        blacklistRequests[reqId].token = token;
        blacklistRequests[reqId].account = account;
        emit BlacklistRequested(reqId, msg.sender, address(token), account);
    }

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
    mapping(bytes32 => BlacklistRequest) unblacklistRequests;
    event UnblacklistRequested(
        bytes32 reqId,
        address by,
        address token,
        address account
    );

    function requestUnblacklist(
        ManagedToken token,
        address account
    ) external returns (bytes32 reqId) {
        require(address(token) != address(0));
        reqId = _makeRequest();
        unblacklistRequests[reqId].token = token;
        unblacklistRequests[reqId].account = account;
        emit UnblacklistRequested(reqId, msg.sender, address(token), account);
    }

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
    mapping(bytes32 => BlacklistRequest) blackFundsDestroyRequests;
    event BlackFundsDestructionRequested(
        bytes32 reqId,
        address by,
        address token,
        address account
    );

    function requestBlackFundsDestruction(
        ManagedToken token,
        address account
    ) external returns (bytes32 reqId) {
        require(address(token) != address(0));
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
    mapping(bytes32 => DeprecationRequest) deprecationRequests;
    event DeprecationRequested(
        bytes32 reqId,
        address by,
        address token,
        address upgraded
    );

    function requestDeprecation(
        ManagedToken token,
        address upgraded
    ) external returns (bytes32 reqId) {
        require(address(token) != address(0));
        require(upgraded != address(0));

        reqId = _makeRequest();
        deprecationRequests[reqId].token = token;
        deprecationRequests[reqId].upgradedToken = upgraded;
        emit DeprecationRequested(reqId, msg.sender, address(token), upgraded);
    }

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
    mapping(bytes32 => TokenIssueRequest) issueRequests;
    event IssueRequested(
        bytes32 reqId,
        address by,
        address token,
        uint amount,
        address to
    );

    function requestIssue(
        ManagedToken token,
        uint amount,
        address to
    ) external returns (bytes32 reqId) {
        require(address(token) != address(0));
        require(amount > 0);

        reqId = _makeRequest();
        issueRequests[reqId].token = token;
        issueRequests[reqId].to = to;
        issueRequests[reqId].amount = amount;
        emit IssueRequested(reqId, msg.sender, address(token), amount, to);
    }

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
    mapping(bytes32 => RedeemRequest) redeemRequests;
    event RedeemRequested(
        bytes32 reqId,
        address by,
        address token,
        uint amount
    );

    function requestRedeem(
        ManagedToken token,
        uint amount
    ) external returns (bytes32 reqId) {
        require(address(token) != address(0));
        require(amount > 0);

        reqId = _makeRequest();
        redeemRequests[reqId].token = token;
        redeemRequests[reqId].amount = amount;
        emit RedeemRequested(reqId, msg.sender, address(token), amount);
    }

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
