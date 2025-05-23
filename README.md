# Aptos Central Limit Order-Hook Book

## Demo: Video, Slides and Demo Instructions

The demo video, slides and instructions are [here](./demo/README.md)

## Abstract

Order-Hook Book is a novel protocol on Aptos, which implements an Order Book Decentralized Exchange, capable of atomic execution of registered callbacks (***Hooks***) when certain price levels are reached via trading. These hooks can be registered by anyone permissionlessly, so that anyone or any protocol can achieve immediate reactions to
prices crossing specified levels. Such reactions can be used for:
- Delinquent loan liquidation in lending DeFi protocols
- Delinquent leveraged position liquidation in leveraged trading protocols
- Undercollateralized option position liquidation
- ... and many other needs.

## Prior work

This work is motivated by my prior work on [Guardian Oracle-Keeper](https://github.com/jordan-public/guardian-oracle-keeper) Protocol and [Watchtower](https://github.com/jordan-public/watchtower-1timehooks4sale) Protocol, both implemented on Ethereum Virtual Machine (EVM), on generic Automated Market Maker (AMM) and Unsiwap V4. Both implement atomic callbacks for similar purposes, however, it is price-prohibitive to implement such protocols on Order Book Exchanges, as Order Book entry lifetime management requires constant insertion and removal of such entries.

Aptos, on the other hand allows for extremely inexpensive management of
of complex data structures, which allows the possibility to implement
atomic actions into a Decentralized Exchange based on ***Order Book***.
This allows for reacting to non-proportionally correlated assets,
such as Options, which are almost exclusively traded on Order Books.

## Introduction

As mentioned above, many DeFi protocols are in dire need of fast reactions
to price movements. Typical implementations use Oracles and Keepers, which have their own problems:
- Oracles are needed to read the prices and react if such prices cross
specific levels. Oracles typically have high latency, especially if they
are implemented off-chain or in need of cross-chain information sharing.
- Keepers are needed to trigger on-chain execution, as the blockchain cannot initiate or schedule calls on its own, to poll for oracle price changes. As the keeper has to initiate an on-chain transaction from outside, this causes additional delays.

This problem is relatively serious. Here are a few examples:
- Capital Efficiency Issue: Users are asked to put two houses down as collateral in order to get a 
loan for one house from a DeFi lending protocol. This is simply because the lending protocol cannot perform timely liquidations and it is asking for excessive overcollateralization. 
- Functionality Issue: Implementation of an on-chain options protocol that
would allow for "naked" option writing is next to impossible. Yet, asking
for collateral in Credit Spread or Debit Spread option strategies, defeats
the purpose of those strategies. Short Call + Long Put is not even remotely the same as Short Call + Long Put + Underlying Collateral (required on-chain).
- Leverage Issue: Perpetual Trading Protocols cannot achieve proper leverage
without either lowering the leverage limit to the user or having the 
liquidity providers take extra risks (see Infinity Pools).

## Solution

The solution I am implementing is Atomic Reactions. Previously, I have implemented such mechanism using AMMs. However, such implementation cannot
react to price actions on assets that are not AMM-suitable, such as Options.

In addition, this protocol provides economic incentive to all participants
in order to motivate it's proper usage.

### How does this work?

The Order Book consists of two tables, one containing Bids and the 
other containing Offers. A ***Maker*** is the participant who creates
a Bid or an Offer containing an amount and limit price of a specific asset pair and publishes it onto the Order Book. A ***Taker*** can
remove such Bid or Offer from the Order Book and initiate a swap of assets
with the Maker:

![Order Book](./docs/OrderBook.png)

Traditionally, Takers can take any Bid or Offer, in any
order ahead of a better priced one, as they may have a preference in choosing a conterparty, based on their credibility and credit worthiness.
In DeFi this is not an issue, as all settlement is safely enforced by the protocol. This is exactly what we are leveraging on: ***Our Order Book is sorted by price and the order of execution must follow this sequence***. As Aptos transactions are inexpensive, matching a larger order with several small orders (Bids or Offers) is not an issue:

![Ordered Execution](./docs/OrderedExecution.png)

This allows us to insert Hooks between the Order Book entries and have
them execute only when the desired price target is reached:

![CHLOB](./docs/CLHOB.png)

These Hooks follow specific rules:
- The Order Book Bids and Offers are sorted by price, and execution
is enforced to be in this order.
- Each Hook has a price. This determines where in the Order Book it has to
be inserted.
- Each Hook has a signature ```| price: u64 | bool```. It is called with
the price as parameter and returns a Boolean value determining whether it
successfully executed or reverted, to be used in future incentivization nuances.
- Anyone can permissionlessly place a Hook at any price level in the Bids
or Offers table in the Order Book. When the Hook position reaches the top of the corresponding table (highest in Bids; lowest in Offers), anyone
can Take it and execute it permissionlessly.
- The Maker of the hook pays a fee.
- The Taker of the hook and the Protocol share the fee received from the
Maker. 

## Economic Incentive

To make sure the Order-Hook Book Protocol operates as intended, there
are economic incentives for every participant:
- Protocols/Callers pay rewards to use Hooks to improve Capital Efficiency and mitigate Delinquency Risk
- Hook Takers receive reward for triggering the Hooks
- Order-Hook Book Protocol collects part of the reward as fees

## Implementation

This protocol is written in Move and it runs on Aptos.

The Order Book uses [BigOrderedMap](https://github.com/aptos-labs/aptos-core/blob/main/aptos-move/framework/aptos-framework/sources/datastructures/big_ordered_map.move) from the Aptos standard libraries for storing the bids and offer tables. In this prototype there is a limitation of one entry (Bid or Offer) per price on each side of the Order Book. A negligible "dust" exchange rate has to be added to the price, to avoid collisions. This also mitigates the issue of ordering the entries by
creation time. In the future, the key can be made to be a pair of <Price, Time>.

The front of the BigOrderMap has the lowest price and the back the highest.

Any Maker can insert a bid or an offer at any price (anywhere in the table). The Maker (the owner of the bid or offer) can remove any of their bids and/or offers.

This Order Book is very specific: It forces the takers to take the best, then the next best entry etc. in the order of their prices. The taker cannot just take any entry from the middle of the book.

Each entry could be either Bid (Offer) or a Hook, imlemented as Move Enum data structure. The Bid and Offer taking are obvious. The Hook pays the taker to be taken. The Hook contains a closure (callback) that can be called to perform some operation, such as loan liquidation. The price ordering rule forces the Hook to be executed only when it is on top of the book (best Hook, like best Bid or Offer).

To accommodate for callbacks I had to use the switch ```--language-version 2.2```. Presently we cannot implement passing of Hooks (closures) via Move
```entry``` functions, before this feature is implemented in Aptos Move.
To mitigate this problem, we are defining the Hooks inside our code thus
limiting the set of available Hooks.
