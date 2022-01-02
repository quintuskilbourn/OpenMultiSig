// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "contracts/MultiSig.sol";

contract OpenMultiSig is MultiSig {
  //
  //adds application submission, voting and acceptance functionality
  //

  //call MultiSig constructor
  constructor(uint[] memory _weights, address[] memory owners ,uint _thresh) payable MultiSig(_weights, owners, _thresh) {}

  mapping(uint => mapping(address => bool)) public appVoted; //keep track of who voted for which txn

  struct Application {
    address applicant;
    uint offer;     //how much they are offering to pay
    uint votesRequested; 
    bool accepted;
    uint votes;  //how many tokens have voted for this
    uint expiration;
    uint proposedThresh; //may need new threshold
  }

  Application[] public apps; 

  modifier notOwner() {
    require(weights[msg.sender]==0, "account already exists");
    _;
  }

  modifier appExists(uint _appIndex) {
    require(_appIndex < apps.length, "application does not exist");
    _;
  }

  modifier appNotAccepted(uint _appIndex) {
    require(!apps[_appIndex].accepted, "application already executed");
    _;
  }

  modifier appNotVoted(uint _appIndex) {
    require(!appVoted[_appIndex][msg.sender], "already voted");
    _;
  }

  event SubmitApplication(
    address indexed applicant,
    uint indexed appIndex,
    uint votesRequested,
    uint offer,
    uint proposedThresh
  );

  function submitApplication(
    uint _offer,
    uint _votesRequested,
    uint _proposedThresh
  ) public notOwner{
    require(_proposedThresh<= thresh + _votesRequested, "impossible threshold"); //else eth locked forever
    apps.push(
      Application({
        applicant: msg.sender,
        offer: _offer,
        votesRequested: _votesRequested,
        accepted: false,
        votes: 0,
        expiration: block.timestamp + 1 weeks,
        proposedThresh: _proposedThresh
      })
    );
    emit SubmitApplication(msg.sender, apps.length-1, _votesRequested, _offer, _proposedThresh);
  }


  event VoteApplication(address indexed voter, uint indexed appIndex, uint votes); //indexed so can be searched

  //vote to approve applicant, everyone votes at most once
  function voteApplication(uint _appIndex)
    public
    onlyOwner
    appExists(_appIndex)
    appNotAccepted(_appIndex)
    appNotVoted(_appIndex)
  {
    Application storage application = apps[_appIndex];
    application.votes += weights[msg.sender];
    appVoted[_appIndex][msg.sender] = true;
    emit VoteApplication(msg.sender, _appIndex, weights[msg.sender]);
  }

  event AppRevokeVote(address indexed owner, uint indexed txIndex, uint votes); //indexed so searchable

  function appRevokeVote(uint _appIndex)
    public
    onlyOwner
    appExists(_appIndex)
    appNotAccepted(_appIndex)
  {
    Application storage application = apps[_appIndex];
    require(appVoted[_appIndex][msg.sender], "not voted yet");
    application.votes -= weights[msg.sender];
    appVoted[_appIndex][msg.sender] = false;
    emit AppRevokeVote(msg.sender, _appIndex, weights[msg.sender]);
  }

  event CompleteApplication(address indexed applicant, uint assigned_votes, uint paid);

  //if enough votes, add participant
  function completeApplication(uint _appIndex) payable external appExists(_appIndex) appNotAccepted(_appIndex) {
    Application storage application = apps[_appIndex];
    require(application.expiration>=block.timestamp,"application expired"); //price of eth might change so limit time for approval
    require(application.votes>=thresh,"insufficient votes");
    require(application.offer<=msg.value,"insufficient value");
    application.accepted=true;
    weights[application.applicant] = application.votesRequested;
    totalWeight += application.votesRequested;
    thresh = application.proposedThresh;
  }
}

