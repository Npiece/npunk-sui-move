/// Npiece Collection main module
module npiece::collection {

    use std::string::{Self, utf8, String};
    use std::option::{Self, Option};
    use std::vector as vec;
    use std::ascii;
    use std::type_name;

    use sui::object::{Self, ID, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::url::{Self, Url};
    use sui::package::{Self, Publisher};
    use sui::display;
    use sui::table::{Self, Table};
    use sui::clock::{Self, Clock};

    use npiece::nft::{Self, Punk};
    use npiece::utils;
    
    friend npiece::admin;
    friend npiece::user;

    /// NpiecePunk Collection shared object
    /// Also the registry of the project details  
    struct Npiece<phantom T> has key {
        id: UID,
        name: String,
        description: String,
        version: u64,
        url: Option<Url>,
        external_url: Option<Url>,
        base_url: Option<Url>,
        whitelist: vector<ID>, // whitelist
        holders: Table<ID, ID>, // list of holder
        feetables: vector<ID>,
        locked: bool, // if locked, only whitelist can mint
    }

    // Version: this should be updated for each upgrading
    const VERSION: u64 = 2;
    const DESCRIPTION: vector<u8> = b"Dive into the captivating pixel-art collection, representing your virtual identity, created by the Npiece community on the vibrant Sui network.";

    // Error code
    const ENotOwner: u64 = 0;
    const ENotAdmin: u64 = 1;
    const EWrongVersion: u64 = 2;
    const EMintLocked: u64 = 3;
    const EInWhiteList: u64 = 4;
    const ENotInWhiteList: u64 = 5;
    const EIsHolder: u64 = 6;
    const EIsNotHolder: u64 = 7;
    const ENotValidFeeTable: u64 = 8;
    
    /// One-Time Witness (OTW)
    struct COLLECTION has drop {}

    fun init(otw: COLLECTION, ctx:&mut TxContext) {
        // 1. Create a publisher (OTW required). This grants root user privileges.
        // This process already check `is_one_time_witness`, so no need to duplicate
        let sender = tx_context::sender(ctx);
        let publisher: Publisher = package::claim(otw, ctx);

        // 2. Create collection object (shared object)
        // Create genesis collection
        create_and_share<Punk>(
            &publisher,
            b"https://npiece.xyz/nfts/",
            b"https://npiece.xyz/nfts/logo.png",
            ctx
        );

        // 3. Send publisher to sender
        transfer::public_transfer(publisher, sender);
    }

    // Only publisher can create collection
    fun create<T>(pub: &Publisher, ctx: &mut TxContext): Npiece<T> {
        assert_authority<T>(pub);
        let nft_typename = type_name::get<T>();
        let module_len = ascii::length(&type_name::get_module(&nft_typename));
        
        let nft_name = string::from_ascii(type_name::into_string(nft_typename));
        let nft_name = string::sub_string(&nft_name, 68+module_len, ascii::length(&type_name::into_string(nft_typename)));

        let name= utf8(b"Npiece");
        string::append(&mut name, nft_name);
        string::append(&mut name, utf8(b"s"));

        Npiece<T> {
            id: object::new(ctx),
            name: name,
            description: utf8(DESCRIPTION),
            version: VERSION,
            url: option::none(),
            external_url: option::none(),
            base_url: option::none(),
            whitelist: vec::empty<ID>(),
            holders: table::new(ctx),
            feetables: vec::empty<ID>(),
            locked: true,
        }
    }

    // Provide accessibility to admin for creating new collection 
    public(friend) fun create_and_share<T: key>(
        pub: &Publisher,
        base_url: vector<u8>,
        logo_url: vector<u8>,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let collection = create<T>(pub, ctx);
        set_base_url(&mut collection, base_url, pub);
        set_logo_url(&mut collection, logo_url, pub);
        set_homepage_url(&mut collection, b"https://npiece.xyz", pub);

        let name_field = collection.name;
        string::append_utf8(&mut name_field, b": {name}");

        let dp = display::new<T>(pub, ctx);
        display::add(&mut dp, utf8(b"name"), name_field);
        display::add(&mut dp, utf8(b"bio"), utf8(b"{bio}"));
        display::add(&mut dp, utf8(b"description"), utf8(b"{description}"));
        display::add(&mut dp, utf8(b"image_url"), utf8(b"{url}"));
        display::add(&mut dp, utf8(b"stats"), utf8(b"{stats}"));
        display::update_version(&mut dp);

        transfer::share_object(collection);
        transfer::public_transfer(dp, sender);
    }

    /// ===== Update collection configuration =====
    /// admin functions
    public(friend) fun set_logo_url<T>(self: &mut Npiece<T>, logo_url: vector<u8>, pub: &Publisher) {
        assert_authority<T>(pub);
        self.url = option::some(url::new_unsafe_from_bytes(logo_url));
    }

    public(friend) fun set_homepage_url<T>(self: &mut Npiece<T>, homepage_url: vector<u8>, pub: &Publisher) {
        assert_authority<T>(pub);
        self.external_url = option::some(url::new_unsafe_from_bytes(homepage_url));
    }

    public(friend) fun set_base_url<T>(self: &mut Npiece<T>, base_url: vector<u8>, pub: &Publisher) {
        assert_authority<T>(pub);
        self.base_url = option::some(url::new_unsafe_from_bytes(base_url));
    }

    public(friend) fun toggle_lock<T>(self: &mut Npiece<T>, pub: &Publisher) {
        assert_authority<T>(pub);
        if (self.locked) {
            self.locked = false;
        } else {
            self.locked = true;
        }
    }

    // User function
    fun mint_<T>(
        self: &mut Npiece<T>,
        name: vector<u8>,
        bio: vector<u8>,
        clockobj: &Clock,
        ctx: &mut TxContext
    ) {
        
        let birthday = clock::timestamp_ms(clockobj);
        let sender = tx_context::sender(ctx);

        assert!(!is_holder_(&self.holders, object::id_from_address(*&sender)), EIsHolder);

        let collection_id = *object::uid_as_inner(&self.id);
        let image_url = ascii::into_bytes(
            url::inner_url(option::borrow(&self.base_url))
            );
        vec::append(&mut image_url, utils::address_to_hashcode(&sender));
        vec::append(&mut image_url, b".png");

        let nft_id_bytes = nft::mint_to_sender(name,  bio, image_url, collection_id, birthday, ctx);
        add_holder_(self, object::id_from_address(sender), object::id_from_bytes(nft_id_bytes));
    }

    public(friend) fun mint<T>(
        self: &mut Npiece<T>, 
        name: vector<u8>,
        bio: vector<u8>,
        clockobj: &Clock,
        ctx: &mut TxContext) {
        
        if (self.locked) {
            // check whitelist
            let wl = &self.whitelist;
            let id = object::id_from_address(tx_context::sender(ctx)); 
            if (utils::is_in_list(wl, &id)) {
                mint_(self, name, bio, clockobj, ctx);
                drop_whitelist(self, &id);
            } else {
                abort EMintLocked
            };
        } else {
            mint_(self, name, bio, clockobj, ctx);
        };
    }

    // ===== WhiteList =====
    fun drop_whitelist<T>(self: &mut Npiece<T>, addr: &ID) {
        let wl = &self.whitelist;
        let (in_wl, i) = vec::index_of(wl, addr);
        if (in_wl) {
            vec::remove<ID>(
                &mut self.whitelist,
                i
            );
        } else {
            abort ENotInWhiteList
        };
    }

    // publisher only function to add address to whitelist
    public(friend) fun add_whitelist<T>(self: &mut Npiece<T>, addr: address, pub: &Publisher) {
        assert_authority<T>(pub);
        let wl = &self.whitelist;
        let id = object::id_from_address(addr);
        if (!utils::is_in_list(wl, &id)) {
            vec::push_back<ID>(
                &mut self.whitelist, 
                id
            );
        } else {
            abort EInWhiteList
        };
    }

    public(friend) fun remove_whitelist<T>(self: &mut Npiece<T>, addr: address, pub: &Publisher) {
        assert_authority<T>(pub);
        let id = &object::id_from_address(addr);
        drop_whitelist(self, id);
    }

    // ===== Holder list ======
    // holder addition
    fun add_holder_<T>(self: &mut Npiece<T>, addr: ID, nft: ID) {
        table::add(&mut self.holders, addr, nft);
    }

    fun is_holder_(holder: &Table<ID,ID>, addr: ID): bool {
        table::contains(holder, addr)
    }

    fun remove_holder_<T>(self: &mut Npiece<T>, addr: ID): ID {
        table::remove(&mut self.holders, addr)
    }

    public(friend) fun is_holder<T>(self: &Npiece<T>, addr: address): bool {
        is_holder_(&self.holders, object::id_from_address(addr))
    }

    public(friend) fun get_holders<T>(self: &Npiece<T>): &Table<ID, ID> {
        &self.holders
    }

    public(friend) fun remove_holder<T>(self: &mut Npiece<T>, addr: address): ID {
        let id = &object::id_from_address(addr);
        assert!(is_holder_(&self.holders, *id), EIsNotHolder);
        remove_holder_(self, *id)
    }

    /// FeeTables
    public(friend) fun add_feetable<T>(self: &mut Npiece<T>, id: ID) {
        vec::push_back(&mut self.feetables, id);
    }

    public(friend) fun remove_feetable<T>(self: &mut Npiece<T>, id: ID) {
        let (is_in, i) = vec::index_of(&self.feetables, &id);
        assert!(is_in, ENotValidFeeTable);
        vec::remove(&mut self.feetables, i);
    }

    /// ===== Upgradeability =====
    public(friend) fun assert_version<T>(self: &Npiece<T>) {
        assert!(self.version == VERSION, EWrongVersion);
    }

    public(friend) fun assert_authority<T>(pub: &Publisher) {
        assert!(package::from_package<T>(pub), ENotOwner);
    }

    entry fun migrate<T>(self: &mut Npiece<T>, pub: &Publisher) {
        assert_authority<T>(pub);
        assert!(self.version < VERSION, EWrongVersion);
        
        self.version = VERSION;
    }

    #[test]
    fun test_collection() {
        use sui::test_scenario::{Self, ctx};
        use sui::display::{Display};
        use std::type_name;
        use std::ascii;
        use std::debug;

        // create test addresses representing users
        let admin = @0xABCD;

        // first transaction to emulate module initialization
        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        {
            init(COLLECTION {}, ctx(scenario));
        };

        // second transcation to check objects that admin received during first transaction
        test_scenario::next_tx(scenario, admin);
        {
            // check Publisher
            let pub = test_scenario::take_from_sender<Publisher>(scenario);
            let pub_tn = type_name::get<Publisher>();
            
            let pub_module = package::published_module(&pub);
            debug::print(&pub_tn);
            assert!(pub_module == &ascii::string(b"collection"), 0);
            test_scenario::return_to_sender(scenario, pub);

            // take Display and print object
            let dp = test_scenario::take_from_sender<Display<Punk>>(scenario);
            debug::print(&dp);
            test_scenario::return_to_sender(scenario, dp);
        };

        // end test
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_mint() {
        use sui::test_scenario::{Self, ctx};
        use std::debug;

        // create test addresses representing users
        let admin = @0xABCD;
        let minter = @0xACEF;

        // first transaction to emulate module initialization
        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        let clockobj = clock::create_for_testing(ctx(scenario));
        {
            init(COLLECTION {}, ctx(scenario));
            debug::print(&utf8(b"tx_1: init module collection."));
        };

        // second transaction to add minter to whitelist
        test_scenario::next_tx(scenario, admin);
        {
            let collection = test_scenario::take_shared<Npiece<Punk>>(scenario);
            let publisher = test_scenario::take_from_sender<Publisher>(scenario);
            add_whitelist(&mut collection, minter, &publisher);
            debug::print(&utf8(b"tx_2: minter address is added to whitelist."));
            assert!(vec::length(&collection.whitelist) == 1, 0);
            test_scenario::return_shared(collection);
            test_scenario::return_to_sender(scenario, publisher);
        };

        // third transaction to emulate mint
        test_scenario::next_tx(scenario, minter);
        {
            let collection = test_scenario::take_shared<Npiece<Punk>>(scenario);
            assert!(&collection.name == &utf8(b"NpiecePunks"), 0);
            // mint function consume collection, so no need to return to shared
            mint(&mut collection, b"tester #1", b"I am tester!", &clockobj, ctx(scenario));
            assert!(is_holder_(&collection.holders, object::id_from_address(minter)), EIsNotHolder);
            test_scenario::return_shared(collection);
            debug::print(&utf8(b"tx_3: nft minted to minter address."));
        };

        // fourth transaction to check minted nft and emulate burn
        let txe_3rd = test_scenario::next_tx(scenario, minter);
        {
            // expect 1 mint event from previous transaction
            assert!(test_scenario::num_user_events(&txe_3rd) == 1, 0);

            let nft = test_scenario::take_from_sender<Punk>(scenario);
            assert!(nft::get_name(&nft) == utf8(b"tester #1"), 0);
            debug::print(&utf8(b"tx_4: check name of minted nft and burn."));
            nft::burn(nft, ctx(scenario));
        };

        // fifth transaction to check whitelist
        let txe_4th = test_scenario::next_tx(scenario, admin);
        {
            // expect 1 burn event from previous transaction
            assert!(test_scenario::num_user_events(&txe_4th) == 1, 0);

            let collection = test_scenario::take_shared<Npiece<Punk>>(scenario);
            debug::print(&utf8(b"tx_5: check updated whitelist and holder"));
            assert!(vec::length(&collection.whitelist) == 0, 0);
            assert!(table::length(&collection.holders) == 1, 0);
            test_scenario::return_shared(collection);
        };

        // end test
        clock::destroy_for_testing(clockobj);
        test_scenario::end(scenario_val);
    }
}