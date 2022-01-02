// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

contract MultiSig  {
  uint public thresh;    //threshold
  uint public totalWeight;  
  mapping(address=>uint) public weights;
  mapping(uint => mapping(address => bool)) public voted; //keep track of who voted for which txn


  struct Transaction {
    address to;
    uint value;
    bytes data;
    bool executed;
    uint votes;  //how many tokens have voted for this
  }

  Transaction[] public transactions; 


  modifier onlyOwner() {
    require(weights[msg.sender]>0, "not owner");
    _;
  }

  modifier txExists(uint _txIndex) {
    require(_txIndex < transactions.length, "tx does not exist");
    _;
  }

  modifier notExecuted(uint _txIndex) {
    require(!transactions[_txIndex].executed, "tx already executed");
    _;
  }

  modifier notVoted(uint _txIndex) {
    require(!voted[_txIndex][msg.sender], "already voted");
    _;
  }


  constructor(uint[] memory _weights, address[] memory owners ,uint _thresh) payable {

    require(_weights.length==owners.length,"weights and owners do not match");
    require(_weights.length > 0, "owners required"); //also catches the case when owners.length==0
    require(_thresh > 0, "invalid threshold");
    
    for (uint i = 0; i < _weights.length; i++) {
      require(owners[i] != address(0), "invalid owner");
      require(weights[owners[i]]==0, "owner not unique"); //already assigned weight
      totalWeight += _weights[i];
      weights[owners[i]] = _weights[i];
    }
    //now we have a fraction of votes assigned to each member of multisig
    require(_thresh <= totalWeight, "impossible threshold");
    thresh = _thresh;
  }

  event Deposit(address indexed sender, uint amount, uint balance);

  receive() external payable {
    emit Deposit(msg.sender, msg.value, address(this).balance);
  }
  //
  //transaction submission, voting and execution flow below
  //
  event SubmitTransaction(
    address indexed owner,
    uint indexed txIndex,
    address indexed to,
    uint value,
    uint votes,
    bytes data
  );

  function submitTransaction(
    address _to,
    uint _value,
    bytes memory _data
  ) public onlyOwner {
    transactions.push(
      Transaction({
        to: _to,
        value: _value,
        data: _data,
        executed: false,
        votes: weights[msg.sender] //assume proposer is in favour
      })
    );
    voted[transactions.length-1][msg.sender] = true;
    emit SubmitTransaction(msg.sender, transactions.length-1, _to, _value, weights[msg.sender],_data);
  }

  event TransactionVote(address indexed owner, uint indexed txIndex, uint votes); //indexed so can be searched

  function voteTransaction(uint _txIndex)
    public
    onlyOwner
    txExists(_txIndex)
    notExecuted(_txIndex)
    notVoted(_txIndex)
  {
    Transaction storage transaction = transactions[_txIndex];
    transaction.votes += weights[msg.sender];
    voted[_txIndex][msg.sender] = true;
    emit TransactionVote(msg.sender, _txIndex, weights[msg.sender]);
  }

  event RevokeVote(address indexed owner, uint indexed txIndex, uint votes); //indexed so searchable

  function revokeVote(uint _txIndex)
    public
    onlyOwner
    txExists(_txIndex)
    notExecuted(_txIndex)
  {
    Transaction storage transaction = transactions[_txIndex];
    require(voted[_txIndex][msg.sender], "not voted yet");
    transaction.votes -= weights[msg.sender];
    voted[_txIndex][msg.sender] = false;
    emit RevokeVote(msg.sender, _txIndex, weights[msg.sender]);
  }

  //not executing right after votes surpass thresh because of gas costs
  event ExecuteTransaction(address indexed owner, uint indexed txIndex);
  function executeTransaction(uint _txIndex)
    public
    onlyOwner
    txExists(_txIndex)
    notExecuted(_txIndex)
  {
    Transaction storage transaction = transactions[_txIndex];
    require(transaction.votes >= thresh, "insufficient votes");
    transaction.executed = true; //set this before the transaction to avoid reentrancy

    (bool success, ) = transaction.to.call{value: transaction.value}(
        transaction.data
    );
    require(success, "tx failed");
    emit ExecuteTransaction(msg.sender, _txIndex);
  }

  //
  //everything below is just basic getters
  //
  function getTransactionCount() public view returns (uint) {
    return transactions.length;
  }

  function getTransaction(uint _txIndex)
    public
    view
    returns (
        address to,
        uint value,
        bytes memory data,
        bool executed,
        uint votes
    ){
      
    Transaction storage transaction = transactions[_txIndex];

    return (
      transaction.to,
      transaction.value,
      transaction.data,
      transaction.executed,
      transaction.votes
    );
  }
}

