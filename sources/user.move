module npiece::user {
    use std::type_name::{Self, TypeName};

    use sui::tx_context::{Self, TxContext};
    use sui::clock::{Clock};
    use sui::object::{Self, ID, UID};
    use sui::coin::{Self, Coin};
    use sui::balance;
    use sui::transfer;
    use sui::event;

    use npiece::collection::{Self as col, Npiece};
    use npiece::nft::{Self as punk, Punk};

    friend npiece::admin;

    // FeeTable
    struct FeeTable<phantom T, phantom C> has key {
        id: UID,
        mint: u64,
        update_name: u64,
        update_bio: u64,
        update_both: u64,
        balance: Coin<C>
    }

    // Events
    struct CreateFeeTable has copy, drop {
        nft_type: TypeName,
        fee_type: TypeName
    }

    struct FeeUpdated has copy, drop {
        table_id: ID,
        fee_name: vector<u8>,
        old_fee: u64,
        new_fee: u64
    }

    struct NftUpdated has copy, drop {
        nft_id: ID,
        field: vector<u8>,
        old_value: vector<u8>,
        new_value: vector<u8>
    }

    // Errors
    const ENotValidHolder: u64 = 0;
    const EInsufficientBalance: u64 = 1;
    const EInvalidKey: u64 = 2;

    // ===== FeeTable =====
    public(friend) fun new_feetable<T, C>(
        mint: u64,
        update_name: u64,
        update_bio: u64,
        update_both: u64,
        ctx: &mut TxContext
    ): ID {
        let feetable = FeeTable<T, C> {
            id: object::new(ctx),
            mint,
            update_name,
            update_bio,
            update_both,
            balance: coin::zero<C>(ctx)
        };
        
        event::emit(CreateFeeTable {
            nft_type: type_name::get<T>(),
            fee_type: type_name::get<C>()
        });
        let id = object::uid_to_inner(&feetable.id);
        transfer::share_object(feetable);
        id
    }

    public(friend) fun set_fee<T, C>(
        feetable: &mut FeeTable<T, C>,
        key: vector<u8>,
        value: u64
    ) {
        let old_fee: u64;
        if (key == b"mint") {
            old_fee = feetable.mint;
            feetable.mint = value;
        } else if (key == b"update_name") {
            old_fee = feetable.update_name;
            feetable.update_name = value;
        } else if (key == b"update_bio") {
            old_fee = feetable.update_bio;
            feetable.update_bio = value;
        } else if (key == b"update_both") {
            old_fee = feetable.update_both;
            feetable.update_both = value;
        } else {
            abort EInvalidKey
        };
        event::emit(FeeUpdated {
            table_id: object::uid_to_inner(&feetable.id),
            fee_name: key,
            old_fee,
            new_fee: value
        })
    }

    // ===== Payments =====
    public(friend) fun take_profit<T, C>(feetable: &mut FeeTable<T, C>, ctx: &mut TxContext) {
        let all_balance = balance::value(coin::balance(&feetable.balance));
        let profit = &mut feetable.balance;
        let balance = coin::balance_mut(profit);

        let taken = coin::take(
            balance, 
            all_balance,
            ctx
        );
        transfer::public_transfer(taken, tx_context::sender(ctx));
    }

    fun receive_payment<T, C>(feetable: &mut FeeTable<T, C>, payment: Coin<C>, key: vector<u8>, ctx: &mut TxContext) {
        assert_balance(feetable, key, &payment);
        let paid = coin::split(&mut payment, get_fee(feetable, key), ctx);
        coin::join(&mut feetable.balance, paid);

        if (coin::value(&payment) > 0) {
            transfer::public_transfer(payment, tx_context::sender(ctx));
        } else {
            coin::destroy_zero(payment);
        };
    }

    fun assert_balance<T, C>(feetable: &mut FeeTable<T, C>, key: vector<u8>, payment: &Coin<C>) {
        let fee = get_fee(feetable, key);
        let bal = balance::value(coin::balance(payment));
        assert!(bal >= fee, EInsufficientBalance);
    }

    fun get_fee<T, C>(feetable: &mut FeeTable<T, C>, key: vector<u8>): u64 {
        if (key == b"mint") {
            return feetable.mint
        } else if (key == b"update_name") {
            return feetable.update_name
        } else if (key == b"update_bio") {
            return feetable.update_bio
        } else if (key == b"update_both") {
            return feetable.update_both
        } else {
            abort EInvalidKey
        }
    }

    // ==== shared function for user =====
    entry fun mint<T, C>(
        self: &mut Npiece<T>,
        feetable: &mut FeeTable<T, C>,
        payment: Coin<C>,
        name: vector<u8>,
        bio: vector<u8>,
        clockobj: &Clock,
        ctx: &mut TxContext
    ) {
        receive_payment(feetable, payment, b"mint", ctx);
        col::mint(self, name, bio, clockobj, ctx);
    }

    // ===== user function for PUNK colleciton =====
    entry fun burn_punk(collection: &mut Npiece<Punk>, nft: Punk, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        let id = punk::get_id(&nft);
        let registered_id = &col::remove_holder(collection, sender);
        assert!(registered_id == id, ENotValidHolder);
        punk::burn(nft, ctx);
    }

    entry fun update_punk_name<C>(nft: &mut Punk, feetable: &mut FeeTable<Punk, C>, payment: Coin<C>, name: vector<u8>, ctx: &mut TxContext) {
        receive_payment(feetable, payment, b"update_name", ctx);
        punk::set_name(nft, name);
    }

    entry fun update_punk_bio<C>(nft: &mut Punk, feetable: &mut FeeTable<Punk, C>, payment: Coin<C>, bio: vector<u8>, ctx: &mut TxContext) {
        receive_payment(feetable, payment, b"update_bio", ctx);
        punk::set_bio(nft, bio);
    }

    entry fun update_punk_name_and_bio<C>(nft: &mut Punk, feetable: &mut FeeTable<Punk, C>, payment: Coin<C>, name: vector<u8>, bio: vector<u8>, ctx: &mut TxContext) {
        receive_payment(feetable, payment, b"update_both", ctx);
        punk::set_name(nft, name);
        punk::set_bio(nft, bio);
    }

    #[test]
    fun test_feetable() {
        use sui::test_scenario::{Self as ts, ctx};
        use sui::sui::SUI;
        use std::debug;

        // create test addresses representing users
        let admin = @0xABCD;

        // first transaction to emulate module initialization
        let scenario_val = ts::begin(admin);
        let scenario = &mut scenario_val;
        {
            new_feetable<Punk, SUI>(
                0u64, 
                10u64, 
                10u64, 
                10u64, 
                ctx(scenario)
            );
        };

        let effect1 = ts::next_tx(scenario, admin);
        {
            debug::print(&ts::num_user_events(&effect1));
            let feetable = ts::take_shared<FeeTable<Punk, SUI>>(scenario);
            let minted = coin::mint_for_testing<SUI>(1000000000, ctx(scenario));
            receive_payment(&mut feetable, minted, b"mint", ctx(scenario));
            ts::return_shared(feetable);
        };
        let effect2 = ts::next_tx(scenario, admin);
        {
            debug::print(&ts::num_user_events(&effect2));
            debug::print(&effect2);
        };
        
        ts::end(scenario_val);
    }
}