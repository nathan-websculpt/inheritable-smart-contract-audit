# InheritableSmartContractWallet

[//]: # "contest-details-open"

- Starts: March 06, 2025 Noon UTC
- Ends: March, 13, 2025 Noon UTC

- nSLOC: 211

## About the Project

Inheriting crypto funds in cold or hot wallets is still an issue until this day, the Inheritance Manager contract implements a time-locked inheritance management system, enabling secure distribution of assets to designated beneficiaries. It uses time-based locks to ensure that assets are only accessible after a specified period. The contract maintains a list of beneficiaries, automating the allocation of inheritance based on predefined conditions. This system offers a trustless and transparent way to manage estate planning, ensuring assets are distributed as intended without the need for intermediaries.

Inheritance Manager can also be used as a backup for your wallet.

An extra gimmick is, that the owner of this contract is able to mint NFTs representing real life assets in an extremely simple way. We are aware that these NFTs have no legal value,
we just integrated them, in case the beneficiaries agree to settle claims towards those assets on-chain within the contract.
The really important part for us is, that the inheritance of funds works flawless after the wallet has been inactive for more than 90 days (standard configuration).

For a more in-depth documentation please have a look at the natspec, it is very detailed.

## Examples:

Example 1, a personal backup scenario:

The Owner of this contract has 2 wallets, one primary as the owner wallet and one secondary one as a backup.

The owner lists his backup wallet as only beneficiary.

The owner loses access to his primary wallet for any reason.

After 90 Days the owner can reclaim his funds via `InheritanceManager::inherit()`

Example 2, the inheritance scenario:

The Owner of the contract lists the wallet addresses of e.g. his children as beneficiary.

If the Owner does not use his wallet for more than 90 days in this case, his children listed as beneficiaries
can call `InheritanceManager::inherit()` which will enable additional functionality within this contract.

1. `InheritanceManager::withdrawInheritedFunds` can be called, which send out funds, equally divided, to all beneficiaries

2. Should the owner have minted NFTs representing Real World assets (e.g. a house) the beneficiaries can opt-in to settle the financial claims fair on-chain leaving only the legal finalty to off-chain lawyers.

3. Should the value of the assets on-chain in NFT form be outdated, beneficiaries can opt-in to appoint a trustee to reevaluate those.

## Actors

Actors:

- `Owner`: The Owner of the smart contract wallet
- `Beneficiary`: Anyone set by the owner to inherit the smart contract and all it's balances.
- `Trustee`: Not necessary role, but can be appointed by the beneficiearies in case underlaying estate values of the NFTs need to be reevaluated and/or the payout asset has to be changed.

## Core Assumptions and Invariants

1. EVERY transaction the owner does with this contract must reset the 90 days timer
2. Noone can take ownership of this contract before the 90 days timelock is over
3. After the 90 days only the beneficiaries get access to the funds, entirely equally divided
4. If the beneficiaries settle the NFTs on-chain the amount to pay is
   `(Value / Number Of Beneficiaries) * (Number Of Beneficiaries - 1)`
   since the paying beneficiary does not need to pay his own share. The above calculation is equally distributed between the other beneficiaries.
5. We allow external contract interaction via `call{}()`. We are aware this can be dangerous, thats why we installed reentrancy guards. Nevertheless, we expect the users
   to validate their inputs beforehand, we do not take responsibility for security breaches using this function.

[//]: # "contest-details-close"
[//]: # "scope-open"

## Scope (contracts)

```
All Contracts in `src` are in scope.
```

```js
src/
├── InheritanceManager.sol
├── NFTFactory.sol
├── modules/
    ├──Trustee.sol
```

### Notice:

All issues related to the NFT part are automatically considered low, EXCEPT the issue would result in a loss of funds. Issues with minting, BaseURI or anything else which DOES NOT result in
a loss of Ether or any other ERC20 tokens are absolutely not a priority, since the NFT logic is convinience only and relies on off-chain finality anyway.

## Compatibilities

```
Compatibilities:
  Blockchains:
      - Ethereum
  Tokens:
      - No limitations. Inheritance Manager needs to be compatible with ether and every ERC20 token.
```

[//]: # "scope-close"
[//]: # "getting-started-open"

## Setup

This is a standard Foundry project, to run it use:

```shell
$ forge install
```

```shell
$ forge build
```

### Test

```shell
$ forge test
```

```shell
$ forge coverage
```

[//]: # "getting-started-close"
[//]: # "known-issues-open"

## Known Issues

None.

[//]: # "known-issues-close"
