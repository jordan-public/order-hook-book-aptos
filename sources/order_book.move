module clohb::order_book {
    use std::signer;
    use std::option::Option;
    use aptos_std::big_ordered_map;

    /// Enum for order book entries
    enum Entry has copy, drop, store {
        Bid { owner: address, amount: u64, price : u64 },
        Offer { owner: address, amount: u64, price : u64 },
        Hook { owner: address, price: u64, reward: u64, callback: |u64| bool },
    }

    /// The order book resource
    struct OrderBook has key {
        bids: big_ordered_map::BigOrderedMap<u64, Entry>, // key: price, value: Entry
        offers: big_ordered_map::BigOrderedMap<u64, Entry>, // key: price, value: Entry
    }

    /// Publish the order book under the deployer's account
    fun init_module(account: &signer) { // Instead of init()
        assert!(!exists<OrderBook>(signer::address_of(account)), 1);
        move_to(account, OrderBook {
            bids: big_ordered_map::new(),
            offers: big_ordered_map::new(),
        });
    }

    /// Insert a bid or hook into the bids map
    public fun insert_bid(account: &signer, entry: Entry) acquires OrderBook {
        let addr = signer::address_of(account);
        let order_book_owner = @clohb; // The address of the module
        match (entry) {
            Entry::Bid { owner, amount, price } => {
                assert!(owner == addr, 2);
                let book = borrow_global_mut<OrderBook>(order_book_owner);
                book.bids.add(price, entry);
            },
            Entry::Hook { owner, price, reward, callback } => {
                assert!(owner == addr, 2);
                let book = borrow_global_mut<OrderBook>(order_book_owner);
                book.bids.add(price, entry);
            },
            _ => abort 3,
        }
    }

    /// Insert an offer or hook into the offers map
    public fun insert_offer(account: &signer, entry: Entry) acquires OrderBook {
        let addr = signer::address_of(account);
        let order_book_owner = @clohb; // The address of the module
        match (entry) {
            Entry::Offer { owner, amount, price } => {
                assert!(owner == addr, 2);
                let book = borrow_global_mut<OrderBook>(order_book_owner);
                book.offers.add(price, entry);
            },
            Entry::Hook { owner, price, reward, callback } => {
                assert!(owner == addr, 2);
                let book = borrow_global_mut<OrderBook>(order_book_owner);
                book.offers.add(price, entry);
            },
            _ => abort 3,
        };
    }

    /// Remove a bid or hook from the bids map (only by owner)
    public entry fun remove_bid(account: &signer, price: u64) acquires OrderBook {
        let addr = signer::address_of(account);
        let order_book_owner = @clohb; // The address of the module
        let book = borrow_global_mut<OrderBook>(order_book_owner);
        let entry = book.bids.remove(&price);
        match (entry) {
            Entry::Bid { owner, amount, price } => {
                assert!(owner == addr, 2);
            },
            Entry::Hook { owner, price, reward, callback } => {
                assert!(owner == addr, 2);
            },
            _ => abort 3,
        }
    }

    /// Remove an offer or hook from the offers map (only by owner)
    public entry fun remove_offer(account: &signer, price: u64) acquires OrderBook {
        let addr = signer::address_of(account);
        let order_book_owner = @clohb; // The address of the module
        let book = borrow_global_mut<OrderBook>(order_book_owner);
        let entry = book.offers.remove(&price);
        match (entry) {
            Entry::Offer { owner, amount, price } => {
                assert!(owner == addr, 2);
            },
            Entry::Hook { owner, price, reward, callback } => {
                assert!(owner == addr, 2);
            },
            _ => abort 3,
        }
    }

    /// Taker takes the best bid (highest price) or executes the hook if it's on top
    public entry fun take_best_bid(account: &signer) acquires OrderBook {
        let addr = signer::address_of(account);
        let order_book_owner = @clohb; // The address of the module
        let book = borrow_global_mut<OrderBook>(order_book_owner);
        let (_, entry) = book.bids.pop_back(); // remove_max !!! verify this
        match (entry) {
            Entry::Bid { owner, amount, price } => {
                assert!(owner == addr, 2);
                // transfer logic here
            },
            Entry::Hook { owner, price, reward, callback } => {
                assert!(owner == addr, 2);
                // call hook logic here
            },
            _ => abort 3,
        }
    }

    /// Taker takes the best offer (lowest price) or executes the hook if it's on top
    public entry fun take_best_offer(account: &signer) acquires OrderBook{
        let addr = signer::address_of(account);
        let order_book_owner = @clohb; // The address of the module
        let book = borrow_global_mut<OrderBook>(order_book_owner);
        let (_, entry) = book.offers.pop_front(); // remove_min !!! verify this
        match (entry) {
            Entry::Offer { owner, amount, price } => {
                assert!(owner == addr, 2);
                // transfer logic here
            },
            Entry::Hook { owner, price, reward, callback } => {
                assert!(owner == addr, 2);
                // call hook logic here
            },
            _ => abort 3,
        }
    }
}
