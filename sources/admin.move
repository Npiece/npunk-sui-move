module npiece::admin {
    use std::vector as vec;

    use sui::tx_context::TxContext;
    use sui::package::Publisher;
    
    use npiece::collection::{Self as col, Npiece};
    use npiece::user::{Self, FeeTable};

    // ===== Collection =====
    entry fun create_new_collection<T: key>(
        pub: &Publisher, 
        base_url: vector<u8>,
        logo_url: vector<u8>,
        ctx: &mut TxContext
    ) {
        col::create_and_share<T>(pub, base_url, logo_url, ctx);
    }

    entry fun set_logo_url<T>(self: &mut Npiece<T>, logo_url: vector<u8>, pub: &Publisher) {
        col::set_logo_url(self, logo_url, pub);
    }

    entry fun set_homepage_url<T>(self: &mut Npiece<T>, homepage_url: vector<u8>, pub: &Publisher) {
        col::set_homepage_url(self, homepage_url, pub);
    }

    entry fun set_base_url<T>(self: &mut Npiece<T>, base_url: vector<u8>, pub: &Publisher) {
        col::set_homepage_url(self, base_url, pub);
    }

    entry fun toggle_lock<T>(self: &mut Npiece<T>, pub: &Publisher) {
        col::toggle_lock(self, pub);
    }

    // ===== Holders =====
    entry fun is_holder<T>(self: &Npiece<T>, addr: address): bool {
        col::is_holder(self, addr)
    }

    // ===== Whitelist =====
    entry fun add_whitelist<T>(self: &mut Npiece<T>, addr: address, pub: &Publisher) {
        col::add_whitelist(self, addr, pub);
    }

    // batch processes
    entry fun batch_add_whitelist<T>(self: &mut Npiece<T>, addrs: vector<address>, pub: &Publisher) {
        let (i, len) = (0u64, vec::length(&addrs));
        while (i < len) {
            let addr = vec::pop_back(&mut addrs);
            col::add_whitelist(self, addr, pub);
            i = i + 1;
        }
    }

    entry fun batch_remove_whitelist<T>(self: &mut Npiece<T>, addrs:vector<address>, pub: &Publisher) {
        let (i, len) = (0u64, vec::length(&addrs));
        while (i < len) {
            let addr = vec::pop_back(&mut addrs);
            col::remove_whitelist(self, addr, pub);
        }
    }

    // ===== Fee =====
    // publish new FeeChart object
    entry fun publish_feetable<T: key, C: key+store>(
        mint: u64,
        update_name: u64,
        update_bio: u64,
        update_both: u64,
        collection: &mut Npiece<T>,
        pub: &Publisher,
        ctx: &mut TxContext
    ) {
        col::assert_authority<T>(pub);
        let id = user::new_feetable<T, C>(mint, update_name, update_bio, update_both, ctx);
        col::add_feetable(collection, id);
    }

    // update the fee of corespond key in published FeeChart object
    entry fun update_fee<T: key, C: key+store>(
        chart: &mut FeeTable<T, C>,
        key: vector<u8>,
        value: u64,
        pub: &Publisher
    ) {
        col::assert_authority<T>(pub);
        user::set_fee(chart, key, value);
    }
}