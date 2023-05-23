# Testnet Info

## Contract address

```toml
[main]
owner       = 0xcf5f0047cc0956b8b4670862d529219024ec8565d5b892cb2a97173b7b2fe5c7
test_nft    = 0x166b9b9224a64a3e08221b534320cf2efd4e3e82f8014224f6c3aedf1ba86303

[package]
version_1   = 0x6cb3f91b410713730d4b68cff7487efad05f8c7a0e26b32e0db806caac022b51
version_2   = 0xa5adeafef1054d43d368e794a3e75bee7c9d58bbdfc3fcf8b32836c8223d13f6

[objects]
collection  = 0xfbdd3edd688ad935f262b6ad12c0df8258ba8764ee747e3dd023a4ae83c6d431
nft_type    = 0x6cb3f91b410713730d4b68cff7487efad05f8c7a0e26b32e0db806caac022b51::nft::Punk
publisher   = 0xceabb0bf5d08c00b7c5012df2704f20bed8a9c22bd9005f2821076de665681de
upgradeCap  = 0x7f229771e99fde6e0c6f6d31bfe61b3f4482bcce6589286b22a4983626ac56b5
punkdisplay = 0x08d2226761017dec950375745ef00fd8e2949042fc5280f8ec038c95e5d492ae
sui         = 0x2::sui::SUI

[feetable]
punk_sui    = 0x66952d1a28dcd6628f58173e03517d162cc36eb1f7adb075baac63d0526faf07
```

## Upgrade contract

```rust
# upgrade contract with UpgradeCap v1 to v2
sui client upgrade --upgrade-capability 0x7f229771e99fde6e0c6f6d31bfe61b3f4482bcce6589286b22a4983626ac56b5 --gas-budget 300000000

# call migrate v1 to v3 (migration failed due to the missing upgrade VERSION constant)
sui client call --package 0xa5adeafef1054d43d368e794a3e75bee7c9d58bbdfc3fcf8b32836c8223d13f6 --module collection --function migrate --args 0xfbdd3edd688ad935f262b6ad12c0df8258ba8764ee747e3dd023a4ae83c6d431 0xceabb0bf5d08c00b7c5012df2704f20bed8a9c22bd9005f2821076de665681de --type-args 0x6cb3f91b410713730d4b68cff7487efad05f8c7a0e26b32e0db806caac022b51::nft::Punk --gas-budget 300000000
```
