module clohb::order_book {
    use std::signer;
    use std::option::{Self, Option};
    use aptos_std::big_ordered_map;
    use aptos_framework::fungible_asset::{Self, MintRef, BurnRef, Metadata, FungibleAsset};
    use aptos_framework::object::{Self, ExtendRef, DeleteRef, TransferRef, ConstructorRef};
    use aptos_framework::primary_fungible_store;
    use std::error;
    use std::string::utf8;
    use std::debug;

    const D8 : u64 = 100000000; // 1**8 as all prices are in 8 decimals

    const ASSET_A_SYMBOL: vector<u8> = b"A";
    const ASSET_B_SYMBOL: vector<u8> = b"B";

    const OBJECT_SEED: vector<u8> = b"object_seed";
    const E_NOT_OBJECT_OWNER: u64 = 1;
    struct ObjectRefs has key {
        extend_ref: ExtendRef,
        transfer_ref: Option<object::TransferRef>,
        delete_ref: Option<object::DeleteRef>,
    }
    
    /// Enum for order book entries
    enum Entry has store {
        Bid { owner: address, amount: u64, price : u64 },
        Offer { owner: address, amount: u64, price : u64 },
        Hook { owner: address, price: u64, reward: u64, callback: |u64| bool has copy+drop+store },
    }

    /// The order book resource
    struct OrderBook has key {
        bids: big_ordered_map::BigOrderedMap<u64, Entry>, // key: price, value: Entry
        offers: big_ordered_map::BigOrderedMap<u64, Entry>, // key: price, value: Entry
    }

    struct TokenAddresses has key {
        address_a: address,
        address_b: address,
    }

    /// Publish the order book under the deployer's account
    fun init_module(account: &signer) { // Instead of init()
        assert!(!exists<OrderBook>(signer::address_of(account)), 1);
        move_to(account, OrderBook {
            bids: big_ordered_map::new_with_type_size_hints(8, 8, 64, 128),
            offers: big_ordered_map::new_with_type_size_hints(8, 8, 64, 128),
        });

        // Fungible Assets
        let constructor_a_ref = &object::create_named_object(account, ASSET_A_SYMBOL);
        let constructor_b_ref = &object::create_named_object(account, ASSET_B_SYMBOL);

        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor_a_ref,
            option::none(),
            utf8(b"A Coin"), /* name */
            utf8(ASSET_A_SYMBOL), /* symbol */
            8, /* decimals */
            utf8(b"http://example.com/favicon.ico"), /* icon */
            utf8(b"http://example.com"), /* project */
        );
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor_b_ref,
            option::none(),
            utf8(b"B Coin"), /* name */
            utf8(ASSET_B_SYMBOL), /* symbol */
            8, /* decimals */
            utf8(b"http://example.com/favicon.ico"), /* icon */
            utf8(b"http://example.com"), /* project */
        );

        let mint_a_ref = fungible_asset::generate_mint_ref(constructor_a_ref);
        let mint_b_ref = fungible_asset::generate_mint_ref(constructor_b_ref);
        let address_a = object::address_from_constructor_ref(constructor_a_ref);
        let address_b = object::address_from_constructor_ref(constructor_b_ref);
        move_to(account, TokenAddresses {
            address_a,
            address_b,
        });

        primary_fungible_store::mint(&mint_a_ref, @clohb, 1000 * D8); // 1000 A
        primary_fungible_store::mint(&mint_b_ref, @clohb, 1000 * D8); // 1000 B

        //  From: https://github.com/aptos-labs/daily-move/blob/main/snippets/design-patterns/autonomous-objects/sources/base.move
        let constructor_ref = object::create_named_object(account, OBJECT_SEED);
        setup_object(&constructor_ref, false);
    }

    /// Sets up the object
    //  From: https://github.com/aptos-labs/daily-move/blob/main/snippets/design-patterns/autonomous-objects/sources/base.move
    fun setup_object(constructor_ref: &ConstructorRef, can_transfer: bool) {
        // -- Generate references --
        // These references let you control what is possible with an object

        // Lets you get a signer of the object to do anything with it
        let extend_ref = object::generate_extend_ref(constructor_ref);

        // Lets you gate the ability to transfer the object
        //
        // In this case, we allow for "soulbound" or non-transferring objects
        let transfer_ref = if (can_transfer) {
            option::some(object::generate_transfer_ref(constructor_ref))
        } else {
            option::none()
        };

        // Lets you delete this object, if possible
        // Sticky objects and named objects can't be deleted
        let delete_ref = if (object::can_generate_delete_ref(constructor_ref)) {
            option::some(object::generate_delete_ref(constructor_ref))
        } else {
            option::none()
        };

        // -- Store references --
        // A creator of the object can choose which of these to save, and move them into any object alongside
        // In this case, we'll save all of them so we can illustrate what you can do with them.
        //
        // If any of the references are not created and stored during object creation, they cannot be added
        // later.

        // Move the References to be stored at the object address
        let object_signer = object::generate_signer(constructor_ref);

        move_to(&object_signer, ObjectRefs {
            extend_ref,
            transfer_ref,
            delete_ref,
        });
    }

    /// Fetches the address of the object
    // From: https://github.com/aptos-labs/daily-move/blob/main/snippets/design-patterns/autonomous-objects/sources/base.move
    public fun fetch_object_address(): address {
        // Note we don't check that the object doesn't exist
        // Because it must be create by deployment of the code
//        object::create_object_address(&@deploy_address, OBJECT_SEED)
        object::create_object_address(&@clohb, OBJECT_SEED)
    }

    /// Fetches the object signer for the object
    ///
    /// Note that a call like this must have some permissions checks, if you do not it's a security issue.  This leads
    /// to our owner ownership permission design pattern.
    // From: https://github.com/aptos-labs/daily-move/blob/main/snippets/design-patterns/autonomous-objects/sources/base.move
    public fun get_object_signer(caller: &signer): signer acquires ObjectRefs {
        // DESIGN PATTERN (Object Ownership Permission): Ensure that the caller is the owner of the object
        // This is a general design pattern to ensure that only the owner of the object can do something with it
        let caller_address = signer::address_of(caller);
        let object_address = fetch_object_address();
        let object = object::address_to_object<ObjectRefs>(object_address);
        // Anyone: assert!(caller_address == object::owner(object), E_NOT_OBJECT_OWNER);

        // Note you can alternatively use `owns` but, it checks recursively owners on the objects
        // Anyone: assert!(object::owns(object, caller_address), E_NOT_OBJECT_OWNER);

        let refs = &ObjectRefs[object_address];
        object::generate_signer_for_extending(&refs.extend_ref)
    }

    /// Insert a hook into the bids or offers map
    // Should be "entry" function but it does not work in the current version - waiting for resolution!!!
    public fun insert_bid_hook(account: &signer, callback: |u64| bool has copy+drop+store, price: u64, reward: u64) acquires OrderBook, TokenAddresses {
        let addr = signer::address_of(account);
        let order_book_owner = @clohb; // The address of the module
        let book = borrow_global_mut<OrderBook>(order_book_owner);
        let entry = Entry::Hook { owner: addr, price, reward, callback };
        book.bids.add(price, entry);
        // Handle payment for the hook caller reward (in Base Currerncy)
        let ta = borrow_global_mut<TokenAddresses>(order_book_owner);
        let to = fetch_object_address();
        primary_fungible_store::transfer(account, object::address_to_object<0x1::object::ObjectCore>(ta.address_b), to, reward);
    }

    /// Insert a hook into the offers or offers map
    // Should be "entry" function but it does not work in the current version - waiting for resolution!!!
    public fun insert_offer_hook(account: &signer, callback: |u64| bool has copy+drop+store, price: u64, reward: u64) acquires OrderBook, TokenAddresses {
        let addr = signer::address_of(account);
        let order_book_owner = @clohb; // The address of the module
        let book = borrow_global_mut<OrderBook>(order_book_owner);
        let entry = Entry::Hook { owner: addr, price, reward, callback };
        book.offers.add(price, entry);
        // Handle payment for the hook caller reward (in Base Currerncy)
        let ta = borrow_global_mut<TokenAddresses>(order_book_owner);
        let to = fetch_object_address();
        primary_fungible_store::transfer(account, object::address_to_object<0x1::object::ObjectCore>(ta.address_b), to, reward);
    }

    /// Insert a bid into the bids map
    public entry fun insert_bid(account: &signer, amount: u64, price: u64) acquires OrderBook, TokenAddresses {
        let addr = signer::address_of(account);
        let order_book_owner = @clohb; // The address of the module
        let book = borrow_global_mut<OrderBook>(order_book_owner);
        book.bids.add(price, Entry::Bid { owner: addr, amount, price });
        // Lock funds for the bid
        let ta = borrow_global_mut<TokenAddresses>(order_book_owner);
        let to_lock_amount_b = (amount * price) / D8;
        let to = fetch_object_address();
        primary_fungible_store::transfer(account, object::address_to_object<0x1::object::ObjectCore>(ta.address_b), to, to_lock_amount_b);
    }

    /// Insert an offer into the offers map
    public entry fun insert_offer(account: &signer, amount: u64, price: u64) acquires OrderBook, TokenAddresses {
        let addr = signer::address_of(account);
        let order_book_owner = @clohb; // The address of the module
        let book = borrow_global_mut<OrderBook>(order_book_owner);
        book.offers.add(price, Entry::Offer { owner: addr, amount, price });
        // Lock funds for the offer
        let ta = borrow_global_mut<TokenAddresses>(order_book_owner);
        let to_lock_amount_a = amount;
        let to = fetch_object_address();
        primary_fungible_store::transfer(account, object::address_to_object<0x1::object::ObjectCore>(ta.address_a), to, to_lock_amount_a);

    }

    /// Remove a bid or hook from the bids map (only by owner)
    public entry fun remove_bid(account: &signer, price: u64) acquires OrderBook, TokenAddresses, ObjectRefs {
        let addr = signer::address_of(account);
        let order_book_owner = @clohb; // The address of the module
        let book = borrow_global_mut<OrderBook>(order_book_owner);
        let entry = book.bids.remove(&price);
        let ta = borrow_global_mut<TokenAddresses>(order_book_owner);
        match (entry) {
            Entry::Bid { owner, amount, price } => {
                assert!(owner == addr, 2);
                let to_unlock_amount_b = (amount * price) / D8;
                let from = get_object_signer(account);
                primary_fungible_store::transfer(&from, object::address_to_object<0x1::object::ObjectCore>(ta.address_b), addr, to_unlock_amount_b);
            },
            Entry::Hook { owner, price, reward, callback } => {
                assert!(owner == addr, 2);
                // Refund reward payment to the hook owner
                let from = get_object_signer(account);
                primary_fungible_store::transfer(&from, object::address_to_object<0x1::object::ObjectCore>(ta.address_b), owner, reward);
            },
            _ => abort 3,
        }
    }

    /// Remove an offer or hook from the offers map (only by owner)
    public entry fun remove_offer(account: &signer, price: u64) acquires OrderBook, TokenAddresses, ObjectRefs {
        let addr = signer::address_of(account);
        let order_book_owner = @clohb; // The address of the module
        let book = borrow_global_mut<OrderBook>(order_book_owner);
        let entry = book.offers.remove(&price);
        let ta = borrow_global_mut<TokenAddresses>(order_book_owner);
        match (entry) {
            Entry::Offer { owner, amount, price } => {
                assert!(owner == addr, 2);
                let to_unlock_amount_a = amount;
                let from = get_object_signer(account);
                primary_fungible_store::transfer(&from, object::address_to_object<0x1::object::ObjectCore>(ta.address_a), addr, to_unlock_amount_a);
            },
            Entry::Hook { owner, price, reward, callback } => {
                assert!(owner == addr, 2);
                // Refund reward payment to the hook owner
                let from = get_object_signer(account);
                primary_fungible_store::transfer(&from, object::address_to_object<0x1::object::ObjectCore>(ta.address_b), owner, reward);
            },
            _ => abort 3,
        }
    }

    /// Buy, taking as much as possible and making a bid for the rest
    public entry fun buy(account: &signer, amount: u64, limit_price: u64) acquires OrderBook, TokenAddresses, ObjectRefs {
        if (amount == 0) {
            return;
        };
        loop {
            let (was_bid, took) = take_best_offer(account, amount, limit_price);
            if (!was_bid) {
                continue;
            };
            if (took == 0) {
                break;
            };
            amount -= took;
        };
        if (amount > 0) {
            // Make a offer for the remaining amount
            insert_bid(account, amount, limit_price);
        }
    }

    /// Sell, taking as much as possible and making an offer for the rest
    public entry fun sell(account: &signer, amount: u64, limit_price: u64) acquires OrderBook, TokenAddresses, ObjectRefs {
        if (amount == 0) {
            return;
        };
        loop {
            let (was_offer, took) = take_best_bid(account, amount, limit_price);
            if (!was_offer) {
                continue;
            };
            if (took == 0) {
                break;
            };
            amount -= took;
        };
        if (amount > 0) {
            // Make a offer for the remaining amount
            insert_offer(account, amount, limit_price);
        }
    }

    /// Taker takes (sells to) the best bid (highest price) or executes the hook if it's on top
    /// Returns <bool, u64> - true if a bid or nothing was executed, false if a hook was taken
    /// and the amount of the bid taken
    fun take_best_bid(account: &signer, limit_amount: u64, limit_price: u64): (bool, u64) acquires OrderBook, TokenAddresses, ObjectRefs {
        let addr = signer::address_of(account);
        let order_book_owner = @clohb; // The address of the module
        let book = borrow_global_mut<OrderBook>(order_book_owner);
        if (book.bids.is_empty()) {
            return (true, 0); // No bid available
        };
        let (bid_price, _) = book.bids.borrow_back(); // Highest bid
        if (bid_price < limit_price) {
            return (true, 0); // No suitable bid available
        };
        let (_, entry) = book.bids.pop_back(); // Highest bid
        let ta = borrow_global_mut<TokenAddresses>(order_book_owner);
        match (entry) {
            Entry::Bid { owner, amount: bid_size, price: bid_price } => {
                if (bid_size > limit_amount) {
                    // Put back the remaining amount
                    book.bids.add(bid_price, Entry::Bid { owner, amount: bid_size - limit_amount, price: bid_price });
                };
                let executed_amount = if (bid_size > limit_amount) { limit_amount } else { bid_size };
                // transfer logic here: swap executed_amount at bid_price
                let to_pay_owner_amount_a = executed_amount; // From signer to owner
                let to_pay_caller_amount_b = (executed_amount * bid_price) / D8; // From funds locked in the Bid
                let from = get_object_signer(account);
                primary_fungible_store::transfer(account, object::address_to_object<0x1::object::ObjectCore>(ta.address_a), owner, to_pay_owner_amount_a);
                primary_fungible_store::transfer(&from, object::address_to_object<0x1::object::ObjectCore>(ta.address_b), addr, to_pay_caller_amount_b);
                (true, executed_amount)
            },
            Entry::Hook { owner, price, reward, callback } => {
                if (callback(price)) {
                    // extra logic here
                } else {
                    // extra logic here
                };
                // Refund reward payment to the hook owner
                let from = get_object_signer(account);
                primary_fungible_store::transfer(&from, object::address_to_object<0x1::object::ObjectCore>(ta.address_b), owner, reward);
                (false, 0)
            },
            _ => abort 3,
        }
    }

    /// Taker takes the best offer (lowest price) or executes the hook if it's on top
    /// Returns <bool, u64> - true if an offer or nothing was executed, false if a hook was taken
    /// and the amount of the bid taken
    fun take_best_offer(account: &signer, limit_amount: u64, limit_price: u64): (bool, u64) acquires OrderBook, TokenAddresses, ObjectRefs {
        let addr = signer::address_of(account);
        let order_book_owner = @clohb; // The address of the module
        let book = borrow_global_mut<OrderBook>(order_book_owner);
        if (book.offers.is_empty()) {
            return (true, 0); // No offer available
        };
        let (offer_price, _) = book.offers.borrow_front(); // Lowest offer
        if (offer_price > limit_price) {
            return (true, 0); // No suitable offer available
        };
        let (_, entry) = book.offers.pop_front(); // Lowest offer
        let ta = borrow_global_mut<TokenAddresses>(order_book_owner);
        match (entry) {
            Entry::Offer { owner, amount: offer_size, price: offer_price } => {
                if (offer_size > limit_amount) {
                    // Put back the remaining amount
                    book.offers.add(offer_price, Entry::Offer { owner, amount: offer_size - limit_amount, price: offer_price });
                };
                let executed_amount = if (offer_size > limit_amount) { limit_amount } else { offer_size };
                // transfer logic here: swap executed_amount at offer_price
                let to_pay_owner_amount_b = (executed_amount * offer_price) / D8; // From signer
                let to_pay_caller_amount_a = executed_amount; // From funds locked in the Bid
                let from = get_object_signer(account);
                primary_fungible_store::transfer(account, object::address_to_object<0x1::object::ObjectCore>(ta.address_b), owner, to_pay_owner_amount_b);
                primary_fungible_store::transfer(&from, object::address_to_object<0x1::object::ObjectCore>(ta.address_a), addr, to_pay_caller_amount_a);
                (true, executed_amount)
            },
            Entry::Hook { owner, price, reward, callback } => {
                if (callback(price)) {
                    // extra logic here
                } else {
                    // extra logic here
                };
                // Refund reward payment to the hook owner
                let from = get_object_signer(account);
                primary_fungible_store::transfer(&from, object::address_to_object<0x1::object::ObjectCore>(ta.address_b), owner, reward);
                (false, 0)
            },
            _ => abort 3,
        }
    }

    #[test(account = @clohb)]
    public fun test_insert_remove_bid(account: signer) acquires OrderBook, TokenAddresses, ObjectRefs {
        //let addr = signer::address_of(&account);

        init_module(&account);
        insert_bid(&account, 100, 10 * D8);
        remove_bid(&account, 10 * D8);
    }

    #[persistent]
    fun my_hook(price: u64): bool {
        // Hook logic here
        let msg:vector<u8> = b"Hook executed at price:";
        debug::print(&msg);
        debug::print(&price);

        true
    }

    #[test(account = @clohb)]
    public entry fun test_minimal_hook(account: signer) acquires OrderBook, TokenAddresses, ObjectRefs {
        init_module(&account);
        insert_bid_hook(&account, my_hook, 100 * D8, 5);
        let (was_bid, amount) = take_best_bid(&account, 100 * D8, 10);
        assert!(!was_bid, 2);
        assert!(amount == 0, 3);
    }

    #[test(account = @clohb)]
    public entry fun test_make_take_bid(account: signer) acquires OrderBook, TokenAddresses, ObjectRefs {
        init_module(&account);
        insert_bid(&account, 100, 10 * D8);
        let (was_bid, amount) = take_best_bid(&account, 50, 10 * D8);
        assert!(was_bid, 2);
        assert!(amount == 50, 3);
    }

    #[test(account = @clohb)]
    public entry fun test_make_take_offer(account: signer) acquires OrderBook, TokenAddresses, ObjectRefs {
        init_module(&account);
        insert_offer(&account, 100, 10 * D8);
        let (was_offer, amount) = take_best_offer(&account, 50, 10 * D8);
        assert!(was_offer, 2);
        assert!(amount == 50, 3);
    }

    #[test(account = @clohb)]
    public entry fun test_make_bid_sell(account: signer) acquires OrderBook, TokenAddresses, ObjectRefs {
        init_module(&account);
        insert_bid(&account, 100, 10 * D8); // To buy 100 at 10
        sell(&account, 150, 10 * D8); // Sell 150 at 10
        let order_book_owner = @clohb; // The address of the module
        let book = borrow_global_mut<OrderBook>(order_book_owner);
        assert!(book.bids.is_empty(), 2);
        let (_, entry) = book.offers.borrow_front(); // Lowest offer
        match (entry) {
            Entry::Offer { owner, amount: offer_size, price: offer_price } => {
                assert!(*offer_size == 50, 3);
                assert!(*offer_price == 10 * D8, 4);
            },
            _ => abort 5,
        };
    }

    #[test(account = @clohb)]
    public entry fun test_make_bid_sell_worse(account: signer) acquires OrderBook, TokenAddresses, ObjectRefs {
        init_module(&account);
        insert_bid(&account, 100, 10 * D8); // To buy 100 at 10
        sell(&account, 150, 9 * D8); // Sell 150 at 10
        let order_book_owner = @clohb; // The address of the module
        let book = borrow_global_mut<OrderBook>(order_book_owner);
        assert!(book.bids.is_empty(), 2);
        let (_, entry) = book.offers.borrow_front(); // Lowest offer
        match (entry) {
            Entry::Offer { owner, amount: offer_size, price: offer_price } => {
                assert!(*offer_size == 50, 3);
                assert!(*offer_price == 9 * D8, 4);
            },
            _ => abort 5,
        };
    }

    #[test(account = @clohb)]
    public entry fun test_make_offer_buy(account: signer) acquires OrderBook, TokenAddresses, ObjectRefs {
        init_module(&account);
        insert_offer(&account, 100, 10 * D8); // To sell 100 at 10
        buy(&account, 150, 10 * D8); // Buy 150 at 10
        let order_book_owner = @clohb; // The address of the module
        let book = borrow_global_mut<OrderBook>(order_book_owner);
        assert!(book.offers.is_empty(), 2);
        let (_, entry) = book.bids.borrow_back(); // Highest bid
        match (entry) {
            Entry::Bid { owner, amount: bid_size, price: bid_price } => {
                assert!(*bid_size == 50, 3);
                assert!(*bid_price == 10 * D8, 4);
            },
            _ => abort 5,
        };
    }

    #[test(account = @clohb)]
    public entry fun test_make_2offers_buy(account: signer) acquires OrderBook, TokenAddresses, ObjectRefs {
        init_module(&account);
        insert_offer(&account, 100, 10 * D8); // To sell 100 at 10
        insert_offer(&account, 100, 9 * D8); // To sell 100 at 10
        buy(&account, 250, 10 * D8); // Buy 150 at 10
        let order_book_owner = @clohb; // The address of the module
        let book = borrow_global_mut<OrderBook>(order_book_owner);
        assert!(book.offers.is_empty(), 2);
        let (_, entry) = book.bids.borrow_back(); // Highest bid
        match (entry) {
            Entry::Bid { owner, amount: bid_size, price: bid_price } => {
                assert!(*bid_size == 50, 3);
                assert!(*bid_price == 10 * D8, 4);
            },
            _ => abort 5,
        };
    }

    #[test(account = @clohb)]
    public entry fun test_make_offer_buy_partial(account: signer) acquires OrderBook, TokenAddresses, ObjectRefs {
        init_module(&account);
        insert_offer(&account, 100, 10 * D8); // To sell 100 at 10
        buy(&account, 50, 11 * D8); // Buy 150 at 10
        let order_book_owner = @clohb; // The address of the module
        let book = borrow_global_mut<OrderBook>(order_book_owner);
        let (_, entry) = book.offers.borrow_back(); // Highest bid
        match (entry) {
            Entry::Offer { owner, amount: offer_size, price: offer_price } => {
                assert!(*offer_size == 50, 3);
                assert!(*offer_price == 10 * D8, 4);
            },
            _ => abort 5,
        };
        assert!(book.bids.is_empty(), 2);
        
    }

}
