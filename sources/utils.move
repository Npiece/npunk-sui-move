module npiece::utils {
    use std::vector as vec;
    use std::hash::sha3_256 as hash;
    use std::string::{Self, String};
    use sui::url::{Self, Url};
    use sui::address;

    public fun u64_to_bytes(value: u64): vector<u8> {
        let buffer = vec::empty<u8>();
        while (value != 0) {
            vec::push_back(&mut buffer, ((48 + value % 10) as u8));
            value = value / 10;
        };
        vec::reverse(&mut buffer);
        buffer
    }

    public fun u64_to_string(value: u64): String {
        if (value == 0) {
            return string::utf8(b"0")
        };
        let buffer = u64_to_bytes(value);
        string::utf8(buffer)
    }

    public fun u128_to_bytes(value: u128): vector<u8> {
        let buffer = vec::empty<u8>();
        while (value != 0) {
            vec::push_back(&mut buffer, ((48 + value % 10) as u8));
            value = value / 10;
        };
        vec::reverse(&mut buffer);
        buffer
    }

    public fun u128_to_string(value: u128): String {
        if (value == 0) {
            return string::utf8(b"0")
        };
        let buffer = u128_to_bytes(value);
        string::utf8(buffer)
    }

    public fun string_to_url(value: String): Url {
        url::new_unsafe(string::to_ascii(value))
    }

    public fun address_to_hashcode(addr: &address): vector<u8> {
        use sui::hex;
        hex::encode(hash(address::to_bytes(*addr)))
    }    

    public fun is_in_list<T>(list: &vector<T>, addr: &T): bool {
        let (in_list, _i) = vec::index_of(list, addr);
        in_list
    }

    // ==== Testing suits ====
    // test preparation
    #[test_only]
    const USER: address = @0xBABE;
    #[test_only]
    use std::debug;

    // main unit test
    #[test]
    fun test_utils() { 
        debug::print(&USER);
        debug::print(&string::utf8(address_to_hashcode(&USER)));
        assert!(address_to_hashcode(&USER) == b"8578218f2a7a25bc5424c0055a347d0e8ce536e19657ab08c456a297707051ec", 0);
    }
}