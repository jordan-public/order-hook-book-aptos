# Demo

## Video

The video is [here](./CLOHB.mp4) and on [YouTube](https://youtu.be/xh5mLW__yBA).

## Slides

The slide presentation is [here](https://www.canva.com/design/DAGnmE-4gcA/vKhvfWyxIsM0svlLDUmwcA/edit?utm_content=DAGnmE-4gcA&utm_campaign=designshare&utm_medium=link2&utm_source=sharebutton).

## Demo instructions

Initialize for Devnet:
```
aptos init
```

Get some APT in the account:
```
aptos account fund-with-faucet
```

Deploy:
```
aptos move deploy-object --address-name clohb --language-version 2.2
```
and get:
```
Do you want to deploy this package at object address 0x0c6b401e6a8588ec0362dd751a017d366f6978516b3eccdaa8018b969e5dd866 [yes/no] >
y
package size 8738 bytes
Do you want to submit a transaction for a range of [915500 - 1373200] Octas at a gas unit price of 100 Octas? [yes/no] >
y
Transaction submitted: https://explorer.aptoslabs.com/txn/0xb590575dc7267acdaa3579baf279fc76d4c2aef91868befd3136e6d673007447?network=devnet
Code was successfully deployed to object address 0x0c6b401e6a8588ec0362dd751a017d366f6978516b3eccdaa8018b969e5dd866
{
  "Result": "Success"
}
```

To run all tests locally:
```
aptos move test --language-version 2.2
```
and get:
```
Running Move unit tests
[ PASS    ] 0x1::order_book::test_insert_remove_bid
[ PASS    ] 0x1::order_book::test_make_2offers_buy
[ PASS    ] 0x1::order_book::test_make_bid_sell
[ PASS    ] 0x1::order_book::test_make_bid_sell_worse
[ PASS    ] 0x1::order_book::test_make_offer_buy
[ PASS    ] 0x1::order_book::test_make_offer_buy_partial
[ PASS    ] 0x1::order_book::test_make_take_bid
[ PASS    ] 0x1::order_book::test_make_take_offer
[debug] 0x486f6f6b2065786563757465642061742070726963653a
[debug] 100
[ PASS    ] 0x1::order_book::test_minimal_hook
Test result: OK. Total tests: 9; passed: 9; failed: 0
{
  "Result": "Success"
}
```

To run a single test (see hook action in this case):
```
aptos move test --language-version 2.2 -f test_minimal_hook   
```
and get:
```
Running Move unit tests
[debug] 0x486f6f6b2065786563757465642061742070726963653a
[debug] 10000000000
[ PASS    ] 0x1234::order_book::test_minimal_hook
Test result: OK. Total tests: 1; passed: 1; failed: 0
{
  "Result": "Success"
}
```
To see that the hook was triggered.
To decode the message use:
```
echo 486f6f6b2065786563757465642061742070726963653a | xxd -r -p
```
and see:
```
Hook executed at price:
```