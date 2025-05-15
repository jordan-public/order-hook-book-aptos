# Demo

## Video

The video is [here]() and on [YouTube]().

## Slides

The slide presentation is [here]().

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
Do you want to deploy this package at object address 0xc6982b896da0e9731d809041fa72ea100bb396b3abc3248b2536b4d3e58b18c6 [yes/no] >
y
package size 6383 bytes
Do you want to submit a transaction for a range of [776000 - 1164000] Octas at a gas unit price of 100 Octas? [yes/no] >
y
Transaction submitted: https://explorer.aptoslabs.com/txn/0x5673e71ba11c9d204fd4700e42b462466e8f2bf6a4ab2dd7fcf10ed68f5897f2?network=devnet
Code was successfully deployed to object address 0xc6982b896da0e9731d809041fa72ea100bb396b3abc3248b2536b4d3e58b18c6
{
  "Result": "Success"
}
```

To run all tests locally:
```
```