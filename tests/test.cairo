use crate::setup::{setup_login,deploy_with_salt};
use sumo::login::login_contract::ILoginDispatcherTrait;
use sumo::account::account_contract::ExternalTraitDispatcherTrait;

use snforge_std::start_cheat_caller_address;

const DEPLOY_FEE: u64 = 1_000_000;
const LOGIN_FEE: u64 = 1_000_000;

#[test]
fn precopute_addresses() {
    let accounts_to_deploy:u64 = 10_u64;
    let (_login_address, login_dispatcher) = setup_login();
    let mut salt:felt252 = 1234;
    let mut index: u64 = 0;
    while index <= accounts_to_deploy { 
        let (deployed_address , _ ) = deploy_with_salt(login_dispatcher, salt);
        let is_user = login_dispatcher.is_sumo_user(deployed_address.try_into().unwrap());
        assert!(is_user == true, "Addresses Incorrectlye computed");
        salt = salt +1;
        index = index + 1;
    };
}

#[test]
fn debt_asignation_on_deploy() {
    let (_login_address, login_dispatcher) = setup_login();
    let (account_address, account_dispatcher) = deploy_with_salt(login_dispatcher, 12345);
    let debt = login_dispatcher.get_user_debt(account_address.try_into().unwrap());
    assert!(debt == DEPLOY_FEE, "Debt not asigned");
    let user_debt = account_dispatcher.get_my_debt();
    assert!(user_debt == debt, "User cannot read they debt")
}

#[test]
fn user_knows_deployer() {
    let (login_address, login_dispatcher) = setup_login();
    let (_account_address, account_dispatcher) = deploy_with_salt(login_dispatcher, 12345);
    let deployer = account_dispatcher.get_deployer_address();
    assert!(login_address == deployer, "User dont know they deployer");
}

#[test]
fn user_change_pkey() {
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
