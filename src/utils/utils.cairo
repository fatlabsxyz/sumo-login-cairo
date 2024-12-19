use crate::utils::structs::{Signature, StructForHash, StructForHashImpl};
use core::sha256::compute_sha256_byte_array;
use core::starknet::{ContractAddress};

const MASK_250: u256 = 1809251394333065553493296640760748560207343510400633813116524750123642650623;

pub fn validate_all_inputs_hash(signature : @Signature, all_inputs_hash: Span<u256>) -> bool {
    let (eph_0, eph_1) = *signature.eph_key;

    let inputs: Array<u256> = array![
                eph_0.into(),
                eph_1.into(),
                (*signature.address_seed),
                (*signature.max_block).into(),
                (*signature.iss_b64_F).into(),
                (*signature.iss_index_in_payload_mod_4).into(),
                (*signature.header_F).into(),
                (*signature.modulus_F).into()
            ];

    let sha256_input = concatenate_inputs(inputs.span());
    let hash_result = compute_sha256_byte_array(@sha256_input);

    let left: u256 = *all_inputs_hash.at(0);
    let right: u256 = (*hash_result.span().at(0)).into();
    left == right
}

fn concatenate_inputs(inputs: Span<u256>) -> ByteArray {
    let mut byte_array = Default::default();
    let mut index = 0_u32;
    while index < inputs.len() {
        let int_value: u256 = *inputs.at(index);
        byte_array.append_word(int_value.high.into(), 16);
        byte_array.append_word(int_value.low.into(), 16);
        index += 1;
    };
    byte_array
}


pub fn mask_address_seed(address_seed: u256 ) -> felt252 {
    let masked_address_seed: felt252 = (address_seed & MASK_250).try_into().unwrap();
    return masked_address_seed;
}


pub fn precompute_account_address( deployer_address: ContractAddress, class_hash:felt252, address_seed:u256)
    -> ContractAddress {
        let salt: felt252 = mask_address_seed(address_seed);
        let hash_zero_array: felt252 = 2089986280348253421170679821480865132823066470938446095505822317253594081284;
        let struct_to_hash = StructForHash {
            prefix: 'STARKNET_CONTRACT_ADDRESS',
            deployer_address: deployer_address.try_into().unwrap(),
            salt: salt,
            class_hash: class_hash,
            constructor_calldata_hash: hash_zero_array,
        };
        let hash = struct_to_hash.hash();
        hash.try_into().unwrap()
    }
