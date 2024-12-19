use crate::setup::{setup_login};
use crate::signature::{signature};
use core::starknet::account::Call;
use sumo::login::login_contract::ILoginDispatcher;
use sumo::login::login_contract::ILoginDispatcherTrait;
use starknet::{contract_address_const};
use core::starknet::{ContractAddress};

use snforge_std::{start_cheat_signature, start_cheat_caller_address, };
use snforge_std::start_cheat_block_number;
use snforge_std::{start_cheat_transaction_hash};

//const DEPLOY_FEE: u64 = 1_000_000;
//const LOGIN_FEE: u64 = 1_000_000;
//const LOGIN_ADDRESS: felt252 = 0x75662cc8b986d55d709d58f698bbb47090e2474918343b010192f487e30c23f;

#[derive(Serde, Drop, Debug)]
struct Signature {
    signature_type: felt252,
    r: felt252,
    s: felt252,
    eph_key: (felt252, felt252),
    address_seed: u256,
    max_block: felt252,
    iss_b64_F: u256,
    iss_index_in_payload_mod_4: felt252,
    header_F: u256,
    modulus_F: u256,
    garaga: Span<felt252>
}


fn call_validate_(login_address: ContractAddress, login_dispatcher : ILoginDispatcher) {
    let zero = contract_address_const::<0>();
    start_cheat_caller_address(login_address, zero);
    let call: Call = Call{to:login_address.try_into().unwrap(), selector:selector!("deploy"),calldata:array![].span()};
    login_dispatcher.__validate__(array![call].span());
}


#[test]
fn __validate__correct_signature() {
    let (login_address, login_dispatcher) = setup_login();
    
    let signature = signature();
    let tx_hash: felt252 = 0x2418c6772ea47ddc9e3ea548bd2dfc9e9ce42365da5df0a2e872967e857bb97;
    let block_number: u64 = 100_000_u64;

    start_cheat_signature(login_address , signature) ;
    start_cheat_transaction_hash(login_address , tx_hash);
    start_cheat_block_number(login_address , block_number);
    call_validate_(login_address, login_dispatcher);
}

#[test]
#[should_panic(expected: 'Login: invalid user signature')]
fn __validate__worng__r() {
    let (login_address, login_dispatcher) = setup_login();
    
    let mut signer = signature();
    let mut base_signature: Signature = Serde::<Signature>::deserialize(ref signer).unwrap();
    base_signature.r = 0x0;

    let mut signature = array![];
    base_signature.serialize(ref signature);

    let tx_hash: felt252 = 0x2418c6772ea47ddc9e3ea548bd2dfc9e9ce42365da5df0a2e872967e857bb97;
    let block_number: u64 = 100_000_u64;

    start_cheat_signature(login_address , signature.span()) ;
    start_cheat_transaction_hash(login_address , tx_hash);
    start_cheat_block_number(login_address , block_number);
    call_validate_(login_address, login_dispatcher);
}

#[test]
#[should_panic(expected: 'Login: invalid oauth signature')]
fn __validate__worng__modulus() {
    let (login_address, login_dispatcher) = setup_login();
    
    let mut signer = signature();
    let mut base_signature: Signature = Serde::<Signature>::deserialize(ref signer).unwrap();
    base_signature.modulus_F = 41231414_u256;

    let mut signature = array![];
    base_signature.serialize(ref signature);

    let tx_hash: felt252 = 0x2418c6772ea47ddc9e3ea548bd2dfc9e9ce42365da5df0a2e872967e857bb97;
    let block_number: u64 = 100_000_u64;

    start_cheat_signature(login_address , signature.span()) ;
    start_cheat_transaction_hash(login_address , tx_hash);
    start_cheat_block_number(login_address , block_number);
    call_validate_(login_address, login_dispatcher);
}


#[test]
#[should_panic(expected: 'Login: invalid AIH')]
fn __validate__worng__AllInputsHash() {
    //the header is only used in the AIH computation, changing it breaks the
    //AIH validation
    let (login_address, login_dispatcher) = setup_login();
    
    let mut signer = signature();
    let mut base_signature: Signature = Serde::<Signature>::deserialize(ref signer).unwrap();
    base_signature.header_F = 41231414_u256;

    let mut signature = array![];
    base_signature.serialize(ref signature);

    let tx_hash: felt252 = 0x2418c6772ea47ddc9e3ea548bd2dfc9e9ce42365da5df0a2e872967e857bb97;
    let block_number: u64 = 100_000_u64;

    start_cheat_signature(login_address , signature.span()) ;
    start_cheat_transaction_hash(login_address , tx_hash);
    start_cheat_block_number(login_address , block_number);
    call_validate_(login_address, login_dispatcher);
}

