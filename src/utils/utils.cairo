use crate::utils::structs::{Signature, StructForHash, StructForHashImpl};
use core::sha256::compute_sha256_byte_array;
use core::starknet::{ContractAddress};
use core::starknet::{syscalls,SyscallResultTrait};
use crate::utils::constants::{STRK_ADDRESS, MASK_250, ORACLE_ADDRESS};


/// Verifies that the sha256 hash of the public inputs given in the signature is equal to the
/// given one.
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


/// Precoputed the address that a deployed account will have given the deployer, the class_hash and the address
/// seed.
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


/// Verifies if the given user has enought STARK to pays his/her debt.
pub fn user_can_repay(user_addres: ContractAddress, debt: u128) -> bool {
    let response = syscalls::call_contract_syscall(
       STRK_ADDRESS.try_into().unwrap(),
       selector!("balance_of"),
       array![user_addres.into()].span(),
    ).unwrap_syscall();

    let low: u128 = (*response[0]).try_into().unwrap();
    let high: u128 = (*response[1]).try_into().unwrap();
    let balance = u256{ low , high }; 

    if balance < 2*debt.into() { return false ;} 
    return true;
}

/// Calls to the mock oracle to get the new modulus_F.
pub fn oracle_check()  -> u256 {
    let response = syscalls::call_contract_syscall(
        ORACLE_ADDRESS.try_into().unwrap(),
        selector!("get_modulus_F"),
        array![].span(),
    ) .unwrap_syscall();
    let low: u128 = (*response[0]).try_into().unwrap();
    let high: u128 = (*response[1]).try_into().unwrap();
    let modulus_F= u256{ low , high }; 
    return modulus_F;
}
