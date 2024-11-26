use sumo::account::account_contract::ExternalTraitDispatcher;
use sumo::account::account_contract::ExternalTraitDispatcherTrait;

use sumo::login::login_contract::ILoginDispatcher;
use sumo::login::login_contract::ILoginDispatcherTrait;
use core::starknet::{ContractAddress};


use snforge_std::{
    declare,
    ContractClassTrait,
    DeclareResultTrait,
    ContractClass,
};

use snforge_std::{start_cheat_caller_address,mock_call,start_cheat_block_number};

const DEPLOY_FEE: u64 = 1_000_000;
const LOGIN_FEE: u64 = 1_000_000;
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

fn deploy_with_salt(login_dispatcher: ILoginDispatcher, salt:felt252 ) -> (ContractAddress, ExternalTraitDispatcher ){
    let account_address = login_dispatcher.deploy(salt);
    let account_dispatcher = ExternalTraitDispatcher { contract_address: account_address};
    (account_address, account_dispatcher)
}

fn deploy_n(login_dispatcher: ILoginDispatcher, number:felt252 ) {
    let mut salt:felt252 = 1234;
    let mut index: u64 = 0;
    let max:u64 = number.try_into().unwrap();
    while index <= max { 
        deploy_with_salt(login_dispatcher, salt);
        salt = salt +1;
        index = index + 1;
    }

}
fn setup_login() -> (ContractAddress,ILoginDispatcher) {
    let (_account_contract, account_class_hash) = declare_class("Account");
    let (login_contract, _login_class_hash) = declare_class("Login");
    let login_address= deploy(login_contract, LOGIN_ADDRESS.try_into().unwrap(),array![account_class_hash]);
    let login_dispatcher = ILoginDispatcher {contract_address: login_address};
    (login_address,login_dispatcher)
}

#[test]
fn test_precopute_addresses() {
    let (_login_address, login_dispatcher) = setup_login();
    deploy_n(login_dispatcher,10);
    let deployed = login_dispatcher.get_deployed();
    let targets = login_dispatcher.get_targets();
    assert!(deployed==targets, "Addresses incorrectly computed");
}

#[test]
fn test_debt_asignation() {
    let (_login_address, login_dispatcher) = setup_login();
    let (account_address, account_dispatcher) = deploy_with_salt(login_dispatcher, 12345);
    let debt = login_dispatcher.get_user_debt(account_address.try_into().unwrap());
    assert!(debt == DEPLOY_FEE, "Debt not asigned");
    let user_debt = account_dispatcher.get_my_debt();
    assert!(user_debt == debt, "User cannot read they debt")
}

#[test]
fn test_user_knows_deployer() {
    let (login_address, login_dispatcher) = setup_login();
    let (_account_address, account_dispatcher) = deploy_with_salt(login_dispatcher, 12345);
    let deployer = account_dispatcher.get_deployer_address();
    assert!(login_address == deployer, "User dont know they deployer");
}

#[test]
fn test_user_change_pkey() {
    //The user itself decides to change de key or extend the expiration
    let (_login_address, login_dispatcher) = setup_login();
    let (account_address, account_dispatcher) = deploy_with_salt(login_dispatcher, 12345);
    start_cheat_caller_address(account_address, account_address);
    let new_pkey = 123456789;
    account_dispatcher.change_pkey(new_pkey,1234);
    let pkey = account_dispatcher.get_pkey();
    assert!(pkey == new_pkey,"User couldnt change they key");
}

#[test]
fn test_login_change_pkey() {
    //Login change the pkey of the user 
    let (login_address, login_dispatcher) = setup_login();
    let (account_address, account_dispatcher) = deploy_with_salt(login_dispatcher, 12345);
    start_cheat_caller_address(account_address, login_address);
    let new_pkey = 123456789;
    account_dispatcher.change_pkey(new_pkey,1234);
    let pkey = account_dispatcher.get_pkey();
    assert!(pkey == new_pkey,"User couldnt change they key");
}
