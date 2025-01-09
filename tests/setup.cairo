//use sumo::account::account_contract::ExternalTraitDispatcher;
//use sumo::account::account_contract::ExternalTraitDispatcherTrait;

use sumo::login::login_contract::ILoginDispatcher;
use sumo::utils::constants::STRK_ADDRESS;
//use sumo::login::login_contract::ILoginDispatcherTrait;
use core::starknet::{ContractAddress};


use snforge_std::{
    declare,
    ContractClassTrait,
    DeclareResultTrait,
    ContractClass,
};


const LOGIN_ADDRESS: felt252 = 0x75662cc8b986d55d709d58f698bbb47090e2474918343b010192f487e30c23f;
const PKEY: felt252 = 0x6363cb464857bb5eddfa351b098bc10c155d61de554640a1f78df62891cd03f;

pub fn declare_class(contract_name: ByteArray) -> (ContractClass, felt252) {
    let contract = declare(contract_name.clone()).unwrap().contract_class();
    let class_hash: felt252 = (*contract.class_hash).into();
//    println!("{:?},  class_hash {:?}", contract_name, class_hash);
    (*contract, class_hash)
}

pub fn deploy_login_account(contract_class: ContractClass, address: felt252, calldata: Array<felt252>) -> ContractAddress {
    let (deployed_address, _) = contract_class
        .deploy_at(@calldata, address.try_into().unwrap())
        .expect('Couldnt deploy');
    deployed_address
}

pub fn setup_erc20() {
    let (_erc20_contract, _ ) = declare_class("ERC20Contract");
    let _ = _erc20_contract
        .deploy_at( @array![LOGIN_ADDRESS], STRK_ADDRESS.try_into().unwrap())
        .expect('Couldnt deploy');
}

fn setup_verifier() {
    let _ = declare_class("UniversalECIP");
    let _ = declare_class("Groth16VerifierBN254");
}

pub fn setup_login() -> (ContractAddress,ILoginDispatcher) {
    setup_verifier();
    setup_erc20();

    let (_account_contract, account_class_hash) = declare_class("Account");
    let (login_contract, _login_class_hash) = declare_class("Login");
    let calldata = array![account_class_hash, PKEY];
    let login_address= deploy_login_account(login_contract, LOGIN_ADDRESS.try_into().unwrap(),calldata);
    let login_dispatcher = ILoginDispatcher {contract_address: login_address};
    (login_address,login_dispatcher)
}
