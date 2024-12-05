use sumo::account::account_contract::ExternalTraitDispatcher;
//use sumo::account::account_contract::ExternalTraitDispatcherTrait;

use sumo::login::login_contract::ILoginDispatcher;
use sumo::login::login_contract::ILoginDispatcherTrait;
use core::starknet::{ContractAddress};


use snforge_std::{
    declare,
    ContractClassTrait,
    DeclareResultTrait,
    ContractClass,
};

const LOGIN_ADDRESS: felt252 = 0x75662cc8b986d55d709d58f698bbb47090e2474918343b010192f487e30c23f;

pub fn declare_class(contract_name: ByteArray) -> (ContractClass, felt252) {
    let contract = declare(contract_name.clone()).unwrap().contract_class();
    let class_hash: felt252 = (*contract.class_hash).into();
    println!("{} class_hash {:?}", contract_name, class_hash);
    (*contract, class_hash)
}

pub fn deploy(contract_class: ContractClass, address: felt252, calldata: Array<felt252>) -> ContractAddress {
    let (deployed_address, _) = contract_class
        .deploy_at(@calldata, address.try_into().unwrap())
        .expect('Couldnt deploy');
    deployed_address
}

pub fn deploy_with_salt(login_dispatcher: ILoginDispatcher, salt:felt252 ) -> (ContractAddress, ExternalTraitDispatcher ){
    let account_address = login_dispatcher.deploy(salt);
    let account_dispatcher = ExternalTraitDispatcher { contract_address: account_address};
    (account_address, account_dispatcher)
}

pub fn setup_login() -> (ContractAddress,ILoginDispatcher) {
    let (_account_contract, account_class_hash) = declare_class("Account");
    let (login_contract, _login_class_hash) = declare_class("Login");
    let login_address= deploy(login_contract, LOGIN_ADDRESS.try_into().unwrap(),array![account_class_hash]);
    let login_dispatcher = ILoginDispatcher {contract_address: login_address};
    (login_address,login_dispatcher)
}
