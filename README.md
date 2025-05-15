# Aptos Order-Hook Book

## Demo: Video, Slides and Demo Instructions

The demo video, slides and instructions are [here](./demo/README.md)

## Abstract



## Introduction

## Solution

## Implementation

Order Book in Aptos, but a very specific one:

The Order Book uses BigOrderedMap from https://github.com/aptos-labs/aptos-core/blob/main/aptos-move/framework/aptos-framework/sources/datastructures/big_ordered_map.move for storing the bids and offer tables.

There are 2 Big Ordered Maps, one for the bids and one for the offers.

Each such map is ordered by price, where the best bid is the one with the highest price, while the best offer is the one with the lowest price.

A Maker can insert a bid or an offer at any price (anywhere in the table). The Maker (the owner of the bid or offer) can remove any of their bids and/or offers.

This Order Book is very specific: It forces the takers to take the best, then the next best entry etc. in the order of their prices. The taker cannot just take any entry from the middle of the book.

Each entry could be either Bid (Offer) or a Hook. The Bid and Offer taking are obvious. The Hook pays the taker to be taken. The Hook contains a closure (callback) that can be called to perform some operation, such as loan liquidation. The price ordering rule forces the Hook to be executed only when it is on top of the book (best Hook, like best Bid or Offer).
