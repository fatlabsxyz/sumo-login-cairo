//These test pretend  to test all the functionalities of the __validate__ functions of the Login account.
//the mock signature is un tests/signature.cairo.

use crate::setup::{ setup_login };
use sumo::login::login_contract::{ ILoginDispatcher , ILoginDispatcherTrait };
use crate::signatures::garaga_signature::{ signature };
use crate::signatures::admin_signatures::{
    correct_admin_signature,
    incorrect_admin_signature,
    incorrect_signature_type
};

use core::starknet::{
    ContractAddress,
    contract_address_const,
    account::Call
};

use snforge_std::{
    start_cheat_signature,
    start_cheat_caller_address,
    start_cheat_block_number,
    start_cheat_transaction_hash,
    start_cheat_transaction_version_global,
};

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


fn call_deploy(login_address: ContractAddress, login_dispatcher : ILoginDispatcher) {
    let zero = contract_address_const::<0>();
    start_cheat_caller_address(login_address, zero);
    let call: Call = Call{to:login_address, selector:selector!("deploy"),calldata:array![].span()};
    login_dispatcher.__validate__(array![call].span());
}

fn call_deploy_of_other(login_address: ContractAddress, login_dispatcher : ILoginDispatcher) {
    let zero = contract_address_const::<0>();
    start_cheat_caller_address(login_address, zero);
    let other: felt252 = 12345;
    let call: Call = Call{to:other.try_into().unwrap(), selector:selector!("deploy"),calldata:array![].span()};
    login_dispatcher.__validate__(array![call].span());
}

fn call_login(login_address: ContractAddress, login_dispatcher : ILoginDispatcher) {
    let zero = contract_address_const::<0>();
    start_cheat_caller_address(login_address, zero);
    let call: Call = Call{to:login_address, selector:selector!("login"),calldata:array![].span()};
    login_dispatcher.__validate__(array![call].span());
}


fn multicall_deploy(login_address: ContractAddress, login_dispatcher : ILoginDispatcher) {
    let zero = contract_address_const::<0>();
    start_cheat_caller_address(login_address, zero);
    let call_1: Call = Call{to:login_address, selector:selector!("deploy"),calldata:array![].span()};
    let call_2: Call = Call{to:login_address, selector:selector!("deploy"),calldata:array![].span()};
    login_dispatcher.__validate__(array![call_1,call_2].span());
}


fn call_admin_entrypoint(login_address: ContractAddress, login_dispatcher : ILoginDispatcher) {
    let zero = contract_address_const::<0>();
    start_cheat_caller_address(login_address, zero);
    let call: Call = Call{to:login_address, selector:selector!("update_oauth_public_key"),calldata:array![].span()};
    login_dispatcher.__validate__(array![call].span());
}




#[test]
fn correct_signature() {
    let (login_address, login_dispatcher) = setup_login();
    
    let signature = signature();
    let tx_hash: felt252 = 0x2418c6772ea47ddc9e3ea548bd2dfc9e9ce42365da5df0a2e872967e857bb97;
    let block_number: u64 = 100_000_u64;

    start_cheat_signature(login_address , signature) ;
    start_cheat_transaction_hash(login_address , tx_hash);
    start_cheat_block_number(login_address , block_number);
    call_deploy(login_address, login_dispatcher);
}


#[test]
#[should_panic(expected:  'Login: invalid caller')]
fn only_protocol() {
    let (login_address, login_dispatcher) = setup_login();
    
    let signature = signature();
    let tx_hash: felt252 = 0x2418c6772ea47ddc9e3ea548bd2dfc9e9ce42365da5df0a2e872967e857bb97;
    let block_number: u64 = 100_000_u64;

    start_cheat_signature(login_address , signature) ;
    start_cheat_transaction_hash(login_address , tx_hash);
    start_cheat_block_number(login_address , block_number);
    let call: Call = Call{to:login_address, selector:selector!("deploy"),calldata:array![].span()};
    login_dispatcher.__validate__(array![call].span());
}


#[test]
#[should_panic(expected:  'Login: invalid tx version')]
fn tx_version() {
    let (login_address, login_dispatcher) = setup_login();
    
    let signature = signature();
    let tx_hash: felt252 = 0x2418c6772ea47ddc9e3ea548bd2dfc9e9ce42365da5df0a2e872967e857bb97;
    let block_number: u64 = 100_000_u64;

    start_cheat_signature(login_address , signature) ;
    start_cheat_transaction_hash(login_address , tx_hash);
    start_cheat_block_number(login_address , block_number);
    start_cheat_transaction_version_global(0);
    call_deploy(login_address, login_dispatcher);
}


#[test]
#[should_panic(expected: 'Login: multicalls not allowed')]
fn user_multicall_not_alowed() {
    let (login_address, login_dispatcher) = setup_login();
    
    let signature = signature();
    let tx_hash: felt252 = 0x2418c6772ea47ddc9e3ea548bd2dfc9e9ce42365da5df0a2e872967e857bb97;
    let block_number: u64 = 100_000_u64;

    start_cheat_signature(login_address , signature) ;
    start_cheat_transaction_hash(login_address , tx_hash);
    start_cheat_block_number(login_address , block_number);
    multicall_deploy(login_address, login_dispatcher);
}


#[test]
#[should_panic(expected:  'Login: outside call now allowed')]
fn only_self_call() {
    let (login_address, login_dispatcher) = setup_login();
    
    let signature = signature();
    let tx_hash: felt252 = 0x2418c6772ea47ddc9e3ea548bd2dfc9e9ce42365da5df0a2e872967e857bb97;
    let block_number: u64 = 100_000_u64;

    start_cheat_signature(login_address , signature) ;
    start_cheat_transaction_hash(login_address , tx_hash);
    start_cheat_block_number(login_address , block_number);
    call_deploy_of_other(login_address, login_dispatcher);
}


#[test]
#[should_panic(expected: 'Login: sellector not allowed')]
fn not_user_entrypoint() {
    let (login_address, login_dispatcher) = setup_login();
    
    let signature = signature();
    let tx_hash: felt252 = 0x2418c6772ea47ddc9e3ea548bd2dfc9e9ce42365da5df0a2e872967e857bb97;
    let block_number: u64 = 100_000_u64;

    start_cheat_signature(login_address , signature) ;
    start_cheat_transaction_hash(login_address , tx_hash);
    start_cheat_block_number(login_address , block_number);
    call_admin_entrypoint(login_address, login_dispatcher);
}


#[test]
#[should_panic(expected: 'Login: invalid user signature')]
fn wrong_user_signature() {
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
    call_deploy(login_address, login_dispatcher);
}

#[test]
#[should_panic(expected:  'Login: proof expired')]
fn expired_proof() {
    let (login_address, login_dispatcher) = setup_login();
    
    let signature = signature();
    let tx_hash: felt252 = 0x2418c6772ea47ddc9e3ea548bd2dfc9e9ce42365da5df0a2e872967e857bb97;
    let block_number: u64 = 1_100_000_u64;

    start_cheat_signature(login_address , signature) ;
    start_cheat_transaction_hash(login_address , tx_hash);
    start_cheat_block_number(login_address , block_number);
    call_deploy(login_address, login_dispatcher);
}


#[test]
#[should_panic(expected: 'Login: invalid oauth signature')]
fn worng__modulus() {
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
    call_deploy(login_address, login_dispatcher);
}


#[test]
#[should_panic(expected: 'Login: invalid AIH')]
fn AllInputsHash() {
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
    call_deploy(login_address, login_dispatcher);
}


#[test]
#[should_panic(expected:  'Login: allready an usser')]
fn already_an_user() {
    let (login_address, login_dispatcher) = setup_login();
    let signature = signature();
    start_cheat_signature(login_address , signature) ;
    let _account_address: ContractAddress  = login_dispatcher.deploy();
    
    let tx_hash: felt252 = 0x2418c6772ea47ddc9e3ea548bd2dfc9e9ce42365da5df0a2e872967e857bb97;
    let block_number: u64 = 100_000_u64;

    start_cheat_signature(login_address , signature) ;
    start_cheat_transaction_hash(login_address , tx_hash);
    start_cheat_block_number(login_address , block_number);
    call_deploy(login_address, login_dispatcher);
}


#[test]
#[should_panic(expected:  'Login: not a sumo usser')]
fn not_an_user() {
    let (login_address, login_dispatcher) = setup_login();
    
    let signature = signature();
    let tx_hash: felt252 = 0x2418c6772ea47ddc9e3ea548bd2dfc9e9ce42365da5df0a2e872967e857bb97;
    let block_number: u64 = 100_000_u64;

    start_cheat_signature(login_address , signature) ;
    start_cheat_transaction_hash(login_address , tx_hash);
    start_cheat_block_number(login_address , block_number);
    call_login(login_address, login_dispatcher);
}


#[test]
#[should_panic(expected:  'Login: usser has a debt')]
fn user_has_debt() {
    let (login_address, login_dispatcher) = setup_login();
    let signature = signature();
    start_cheat_signature(login_address , signature) ;
    let _account_address: ContractAddress  = login_dispatcher.deploy();
    
    let tx_hash: felt252 = 0x2418c6772ea47ddc9e3ea548bd2dfc9e9ce42365da5df0a2e872967e857bb97;
    let block_number: u64 = 100_000_u64;

    start_cheat_signature(login_address , signature) ;
    start_cheat_transaction_hash(login_address , tx_hash);
    start_cheat_block_number(login_address , block_number);
    call_login(login_address, login_dispatcher);
}

// now test for admin.
//TODO: We have to define what an adming signature should look like. the first elemetn is selector!(signature/admin)


#[test]
fn valid_admin_signature() {
    let (login_address, login_dispatcher) = setup_login();
    
    let signature = correct_admin_signature();
    let tx_hash: felt252 = 0x2418c6772ea47ddc9e3ea548bd2dfc9e9ce42365da5df0a2e872967e857bb97;
    let block_number: u64 = 100_000_u64;

    start_cheat_signature(login_address , signature) ;
    start_cheat_transaction_hash(login_address , tx_hash);
    start_cheat_block_number(login_address , block_number);
    call_admin_entrypoint(login_address, login_dispatcher);
}

#[test]
#[should_panic(expected: 'Login: sellector not allowed')]
fn wrong_admin_selector() {
    let (login_address, login_dispatcher) = setup_login();
    
    let signature = correct_admin_signature();
    let tx_hash: felt252 = 0x2418c6772ea47ddc9e3ea548bd2dfc9e9ce42365da5df0a2e872967e857bb97;
    let block_number: u64 = 100_000_u64;

    start_cheat_signature(login_address , signature) ;
    start_cheat_transaction_hash(login_address , tx_hash);
    start_cheat_block_number(login_address , block_number);

    let zero = contract_address_const::<0>();
    start_cheat_caller_address(login_address, zero);
    let call_1: Call = Call{to:login_address, selector:selector!("update_oauth_public_key"),calldata:array![].span()};
    let call_2: Call = Call{to:login_address, selector:selector!("deploy"),calldata:array![].span()};
    login_dispatcher.__validate__(array![call_1,call_2].span());
}

#[test]
#[should_panic(expected:  'Login: invalid admin signature')]
fn invalid_admin_signature() {
    let (login_address, login_dispatcher) = setup_login();
    
    let signature = incorrect_admin_signature();
    let tx_hash: felt252 = 0x2418c6772ea47ddc9e3ea548bd2dfc9e9ce42365da5df0a2e872967e857bb97;
    let block_number: u64 = 100_000_u64;

    start_cheat_signature(login_address , signature) ;
    start_cheat_transaction_hash(login_address , tx_hash);
    start_cheat_block_number(login_address , block_number);
    call_admin_entrypoint(login_address, login_dispatcher);
}

#[test]
#[should_panic(expected:  'Login: invalid signature type')]
fn invalid_signature_type() {
    let (login_address, login_dispatcher) = setup_login();
    
    let signature = incorrect_signature_type();
    let tx_hash: felt252 = 0x2418c6772ea47ddc9e3ea548bd2dfc9e9ce42365da5df0a2e872967e857bb97;
    let block_number: u64 = 100_000_u64;

    start_cheat_signature(login_address , signature) ;
    start_cheat_transaction_hash(login_address , tx_hash);
    start_cheat_block_number(login_address , block_number);
    call_admin_entrypoint(login_address, login_dispatcher);
}
