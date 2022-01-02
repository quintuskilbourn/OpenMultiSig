# OpenMultiSig
Solidity Demo - Mutlisig investment contract that allows: 1) paid applications to join and multisig to scale as well as 2) assigning "weighting" (i.e. votes) to each owner. 

This repo was started using code from https://solidity-by-example.org/, after which siginificant changes were made (e.g. adding voting and application functionality).

The easiest way to run this code for now is to paste into the Remix IDE (https://remix.ethereum.org). 

## Understanding the code
Most functions are quite self explanatory. The general flow for transactions and applications is the same: 
* submit proposal (open for applications, onlyOwner for transactions)
* submission must be voted on (only owners)
* once enough votes have been assigned, transaction can be executed/applicant can be added by another function call. 

## Future work:
* deploy on replit and ropsten testnets
* add deployment js files
* Make gas efficient
* Add a way to propose changing voting threshold
* add way to "cash-out"
* find an excuse to use assembly
* find way to interact with more contracts to demonstrate awareness of reentrancy and other dangers
