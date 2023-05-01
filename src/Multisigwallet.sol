// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;


/// @title A conventional Multi-sig Wallet
/// @author Pol Ureña
/// @notice This multi-sig wallet can be owned by a limited (4) amount of signatures,
///         and those are initialized at the beggining

contract MultisigWallet {

    error InvalidOwnerAddress();
    error OwnerAlreadyRegistered();
    error InvalidMinNumConfirmations();
    error NotOwner();
    error TransactionIndexDoesntExist();
    error TransactionAlreadyExecuted();
    error OwnerAlreadyVoted();
    error NotEnoughVotesToBeExecuted();

    event SubmitTransaction(
        address indexed ownerCreator,
        uint indexed index,
        address indexed to,
        uint value,
        bytes data
    );
    event AfirmativeVoteTransaction(
        address indexed owner,
        uint indexed index
    );
    event NegativeVoteTransaction(
        address indexed owner,
        uint indexed index
    );
    event ExecuteTransaction(
        address indexed owner,
        uint indexed index
    );

    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
        int votes;
    }

    /* State variables */
    address[4] public s_owners;
    int immutable public i_minNumConfirmations;
    Transaction[] public s_transactionLog;
    mapping(address => bool) public s_isOwner;
    mapping(uint => mapping(address => bool)) public s_didVoted;



    
    /// @notice all the signatures for this walled are initialized in the constructor as well as the 
    ///         minimum number of confirmations.
    /// @param _owners array of addresses that must be different from address 0 and from each other.
    /// @param _minNumConfirmations the minimum number of confirmations for a transaction to be executed.
    ///                             It must be a number between 0 and the amount of owners, in this case 4.
    constructor(address[4] memory _owners, int _minNumConfirmations){
        if(_minNumConfirmations > 4 || _minNumConfirmations==0){
            revert InvalidMinNumConfirmations();
        }
        i_minNumConfirmations = _minNumConfirmations;
        for(uint index = 0; index<_owners.length; index++){
            address owner = _owners[index];
            if(owner==address(0)){
                revert InvalidOwnerAddress();
            }
            if(s_isOwner[owner]==true){
                revert OwnerAlreadyRegistered();
            }
            s_isOwner[owner] = true;
            s_owners[index] = owner;
        }
    }

    /// @notice modifier to check if the function caller is one of the multisig owner

    modifier isOwner(){
        if(s_isOwner[msg.sender]==false){
            revert NotOwner();
        }
        _;
    }

    /// @notice modifier to check if the transaction to confirm, revoke or execute exists

    modifier transactionExists(uint _index){
        if(s_transactionLog.length == 0 || _index >= s_transactionLog.length){
            revert TransactionIndexDoesntExist();
        }
        _;
    }

    /// @notice modifier to check if the transaction to confirm, revoke or execute has not been executed yet

    modifier transactionNotExecuted(uint _index){
        if(s_transactionLog[_index].executed==true){
            revert TransactionAlreadyExecuted();
        }
        _;
    }

    /// @notice modifier to check if the owner already confirmed or revoked the transaction

    modifier notVoted(uint _index){
        if(s_didVoted[_index][msg.sender]==true){
            revert OwnerAlreadyVoted();
        }
        _;
    }

    /// Creates a transaction that will be confirmed from the owners
    /// @param _to the receiver of the transaction
    /// @param _value the value of the transaction (aka how much eth is this transaction going to send)
    /// @param _data the data that will be sent along with the transaction
    /// @notice only the owners can create new transactions

    function submitTransaction(address _to, uint _value, bytes memory _data) public isOwner(){
        s_transactionLog.push(Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false,
            votes: 0
        }));

        emit SubmitTransaction(msg.sender, s_transactionLog.length-1, _to, _value, _data);
    }

    /// Vote for a transaction
    /// @param _index index of the transaction inside the transaction log
    /// @param _vote true if the vote is to confirm a transaction or false to revoke
    /// @notice this function is only callable by owners, the transaction must exist, 
    ///         can't be executed and the caller could not voted yet

    function voteForTransaction(uint _index, bool _vote) public isOwner() transactionExists(_index) transactionNotExecuted(_index) notVoted(_index){
        if(_vote){
            s_transactionLog[_index].votes++;

            emit AfirmativeVoteTransaction(msg.sender, _index);
        } else {
            s_transactionLog[_index].votes--;

            emit NegativeVoteTransaction(msg.sender, _index);
        }
        s_didVoted[_index][msg.sender] = true;
    }

    /// Execute transaction function
    /// @param _index  index of the transaction from inside the transaction array
    /// @notice this function must be called by one of the owners, the transaction must exist, and can't be executed yet.

    function executeTransaction(uint _index) public isOwner() transactionExists(_index) transactionNotExecuted(_index){
        if(s_transactionLog[_index].votes < i_minNumConfirmations){
            revert NotEnoughVotesToBeExecuted();
        }
        s_transactionLog[_index].executed = true;   
        (bool success, ) = s_transactionLog[_index].to.call{value: s_transactionLog[_index].value}(s_transactionLog[_index].data);
        require(success, "transaction failed");

        emit ExecuteTransaction(msg.sender, _index);
    }

    function getVotes(uint _index) public view returns(int){
        return s_transactionLog[_index].votes;
    }
}