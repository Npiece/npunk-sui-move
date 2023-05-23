// NFT attributes as dynamic field
// open user can update (within the limits) and pay
module npiece::nft {
    use std::string::{utf8, String};
    use sui::object::{Self, UID, ID};
    use sui::transfer;
    use sui::event;
    use sui::url::{Self, Url};
    use sui::vec_map::{Self, VecMap};
    use sui::tx_context::{Self, TxContext};

    const DESCRIPTION: vector<u8> = b"NpiecePunks Genesis Collection";
    const SYMBOL: vector<u8> = b"NPUNK";
    const MIN_STATS: u64 = 10;
    const MAX_STATS: u64 = 100;

    // Error code
    const EIsSoulBound: u64 = 0;
    const EStatsMinimum: u64 = 1;
    const EStatsMaximum: u64 = 2;

    friend npiece::collection;
    friend npiece::admin;
    friend npiece::user;

    // Non Fungible Token (NFT)
    struct Punk has key {
        id: UID,
        name: String,
        description: String,
        bio: String,
        birthday: u64,
        symbol: String,
        url: Url,
        collection_id: ID,
        stats: VecMap<String, Points>,
        soulbound: bool
    }

    struct Points has store, copy, drop {
        value: u64
    }

    // Events
    struct PunkerBorn has copy, drop {
        id: ID,
        addr: ID
    }

    struct PunkerGone has copy, drop {
        addr: ID
    }

    // internal function
    public(friend) fun mint_to_sender(
        name: vector<u8>,
        bio: vector<u8>,
        image_url: vector<u8>,
        collection_id: ID,
        birthday: u64,
        ctx: &mut TxContext,
    ): vector<u8> {
        let id = object::new(ctx);
        let nft = Punk {
            id, 
            name: utf8(name), 
            description: utf8(DESCRIPTION), 
            bio: utf8(bio),
            birthday: birthday,
            symbol: utf8(SYMBOL),
            url: url::new_unsafe_from_bytes(image_url), 
            collection_id,
            stats: new_stats(&MIN_STATS),
            soulbound: true
        };
        let nft_id = object::uid_to_bytes(&nft.id);
        let recipient = tx_context::sender(ctx);
        let recipient_id = object::id_from_address(*&recipient);
        transfer::transfer(nft, recipient);
        event::emit(PunkerBorn {id: object::id_from_bytes(*&nft_id), addr: recipient_id});
        nft_id
    }

    fun new_stats(init_val: &u64): VecMap<String, Points> {
        let stats = vec_map::empty<String, Points>();
        let points = &Points {value: *init_val};
        vec_map::insert(&mut stats, utf8(b"Strength"), *points);
        vec_map::insert(&mut stats, utf8(b"Dexterity"), *points);
        vec_map::insert(&mut stats, utf8(b"Constitution"), *points);
        vec_map::insert(&mut stats, utf8(b"Intelligence"), *points);
        vec_map::insert(&mut stats, utf8(b"Wisdom"), *points);
        vec_map::insert(&mut stats, utf8(b"Charisma"), *points);
        stats
    }

    // burn function can be executed by holder
    public(friend) fun burn(nft: Punk, ctx: &mut TxContext) {
        let Punk { 
            id, 
            name:_, 
            description:_, 
            bio: _,
            birthday: _,
            symbol:_, 
            url:_, 
            collection_id:_, 
            stats,
            soulbound: _ } = nft;
        let addr = object::id_from_address(tx_context::sender(ctx));

        // deconstruct stats
        let (i, len) = (0u64, vec_map::size(&stats));
        while (i < len) {
            let (_, _) = vec_map::remove_entry_by_idx(&mut stats, 0);
            i = i + 1;
        };
        
        event::emit(PunkerGone {addr});
        object::delete(id);
    }

    public(friend) fun transfer(nft: Punk, recipient: address) {
        assert!(!nft.soulbound, EIsSoulBound);
        transfer::transfer(nft, recipient);
    }

    // TODO: name and bio change
    public(friend) fun unbound_from_soul(nft: &mut Punk) {
        nft.soulbound = false;
    }

    public(friend) fun bound_to_soul(nft: &mut Punk) {
        nft.soulbound = true;
    }

    public(friend) fun set_name(nft: &mut Punk, name: vector<u8>) {
        nft.name = utf8(name);
    }

    public(friend) fun set_bio(nft: &mut Punk, bio: vector<u8>) {
        nft.bio = utf8(bio);
    }

    // TODO: reset or add stat points, StatPointCap for given statspoint when available
    public(friend) fun increase_stat_point(nft: &mut Punk, key: vector<u8>) {
        let stats = &mut nft.stats;
        let field = vec_map::get_mut(stats, &utf8(key));
        assert!(field.value + 1 <= MAX_STATS, EStatsMaximum);
        field.value = field.value + 1;
    }

    public(friend) fun reset_stat_point(nft: &mut Punk, key: vector<u8>): u64 {
        let stats = &mut nft.stats;
        let field = vec_map::get_mut(stats, &utf8(key));
        assert!(field.value > MIN_STATS, EStatsMinimum);
        let remain_points = *&field.value - MIN_STATS;
        field.value = MIN_STATS;
        remain_points
    }

    public(friend) fun override_stat_point(nft: &mut Punk, key: vector<u8>, value: u64) {
        let stats = &mut nft.stats;
        let field = vec_map::get_mut(stats, &utf8(key));
        assert!(value == MAX_STATS, EStatsMaximum);
        field.value = value;
    }

    // Getter function
    public fun get_id(nft: &Punk): &ID {
        object::uid_as_inner(&nft.id)
    }

    public fun get_name(nft: &Punk): String {
        nft.name
    }

    public fun get_description(nft: &Punk): String {
        nft.description
    }

    public fun get_symbol(nft: &Punk): String {
        nft.symbol
    }

    public fun get_url(nft: &Punk): Url {
        nft.url
    }

    public fun get_stats(nft: &Punk): VecMap<String, Points> {
        nft.stats
    }

    public fun get_stat_point(nft: &Punk, key: vector<u8>): u64 {
        let points = vec_map::get(&nft.stats, &utf8(key));
        points.value
    }
    
    #[test_only]
    // Inventory object to test dynamic field
    struct Inventory has key, store {
        id: UID
    }

    #[test]
    // test function for dynamic field for future conduction
    fun test_dynamic_field() {
        use sui::test_scenario::{Self as ts, ctx};
        // use std::vector as vec;
        use std::debug;
        use sui::dynamic_field as df;

        // create test addresses representing users
        let admin = @0xABCD;
        let stranger = @0xBABE;

        // first transaction to emulate minting nft
        let scenario_val = ts::begin(admin);
        let scenario = &mut scenario_val;
        {
            let name = b"tester";
            let id = object::new(ctx(scenario));
            let collection_id = *object::uid_as_inner(&id);
            let image_url = b"http://npiece.xyz/nfts/test.png";

            let bio = b"hi, this is tester";

            mint_to_sender(
                name, 
                bio, 
                image_url, 
                collection_id,
                0u64, 
                ctx(scenario)
            );
            object::delete(id);
        };

        // second transaction to emulate adding dynamic field
        ts::next_tx(scenario, admin);
        {
            let nft = ts::take_from_sender<Punk>(scenario);
            let inven = Inventory {
                id: object::new(ctx(scenario))
            };

            // add 'inventory' object to dynamic field
            df::add(&mut nft.id, b"inventory", inven);
            // print the contents in 'inventory' dynamic field. asigned type arguments indicates <Name, Field>
            debug::print(df::borrow<vector<u8>, Inventory>(&nft.id, b"inventory"));
            ts::return_to_sender(scenario, nft);
        };

        // third transaction to update stats
        ts::next_tx(scenario, stranger);
        {
            let nft = ts::take_from_address<Punk>(scenario, admin);
            assert!(get_stat_point(&nft, b"Strength") == 10, 0);
            increase_stat_point(&mut nft, b"Strength");
            assert!(get_stat_point(&nft, b"Strength") == 11, 0);
            ts::return_to_address( admin, nft);
        };


        // fourth transaction to emulate burning
        ts::next_tx(scenario, admin);
        {
            let nft = ts::take_from_sender<Punk>(scenario);
            let remains = reset_stat_point(&mut nft, b"Strength");
            assert!(get_stat_point(&nft, b"Strength") == 10, 0);
            assert!(remains == 1, 0);
            burn(nft, ctx(scenario));
        };

        ts::end(scenario_val);
    }
}