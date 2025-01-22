
use crate::setup::{ setup_login , transfer };
use sumo::login::login_contract::{ ILoginDispatcherTrait };
use sumo::account::account_contract::{ IAccountDispatcher };
use crate::signatures::garaga_signature::{ signature };
use core::starknet::{ ContractAddress };

use snforge_std::{
    start_cheat_signature,
    start_cheat_caller_address,
    spy_events,
    EventSpyAssertionsTrait,
};

use sumo::login::login_contract::Login::{
    Event as LoginEvents,
    DeployAccount,
    DebtCollected,
    LoginAccount,
    ModulusUptdated
};

use sumo::account::account_contract::Account::{
    Event as AccountEvents,
    DebtPayed,
    PKeyChanged
};


#[test]
fn deploy() {
    let (login_address, login_dispatcher) = setup_login();
    let signature = signature();
    start_cheat_signature(login_address , signature) ;
    let mut spy = spy_events();
    let account_address: ContractAddress  = login_dispatcher.deploy();
    let new_key = 0x06363cb464857bb5eddfa351b098bc10c155d61de554640a1f78df62891cd03f;
    let expected_account = AccountEvents::PKeyChanged(PKeyChanged{new_key: new_key });
    let expected_login = LoginEvents::DeployAccount(DeployAccount{ address : account_address });
    spy.assert_emitted(@array![(login_address, expected_login)]);
    spy.assert_emitted(@array![(account_address, expected_account)]);

}


#[test]
fn pay_and_collect_debt() {
    let (login_address, login_dispatcher) = setup_login();
    let signature = signature();
    start_cheat_signature(login_address , signature) ;
    let account_address: ContractAddress  = login_dispatcher.deploy();

    let _account_dispatcher = IAccountDispatcher {contract_address: account_address};

    let transfer_amount: u256 = 100_000_000_u256;
    transfer(login_address, account_address, transfer_amount);

    let debt = login_dispatcher.get_user_debt( account_address );

    let mut spy = spy_events();
    start_cheat_caller_address(login_address, login_address);
    login_dispatcher.collect_debt(account_address);

    let expected_login = LoginEvents::DebtCollected(DebtCollected{ address : account_address, ammount : debt });
    spy.assert_emitted(@array![(login_address, expected_login)]);

    let expected_account = AccountEvents::DebtPayed(DebtPayed{ammount : debt, to : login_address});
    spy.assert_emitted(@array![(account_address, expected_account)]);
}


#[test]
fn login() {
    let (login_address, login_dispatcher) = setup_login();
    let signature = signature();
    start_cheat_signature(login_address , signature) ;
    let account_address: ContractAddress  = login_dispatcher.deploy();

    let _account_dispatcher = IAccountDispatcher {contract_address: account_address};

    let transfer_amount: u256 = 100_000_000_u256;
    transfer(login_address, account_address, transfer_amount);

    start_cheat_caller_address(login_address, login_address);
    login_dispatcher.collect_debt(account_address);

    let mut spy = spy_events();
    login_dispatcher.login();
    let expected_login = LoginEvents::LoginAccount(LoginAccount{ address : account_address });
    spy.assert_emitted(@array![(login_address, expected_login)]);

    let new_key = 0x06363cb464857bb5eddfa351b098bc10c155d61de554640a1f78df62891cd03f;
    let expected_account = AccountEvents::PKeyChanged(PKeyChanged{new_key: new_key });
    spy.assert_emitted(@array![(account_address, expected_account)]);
}


#[test]
fn modulus_update(){
    let mut spy = spy_events();
    let (login_address, _login_dispatcher) = setup_login();
    let modulus:u256 = 6472322537804972268794034248194861302128540584786330577698326766016488520183;
    let expected_login = LoginEvents::ModulusUptdated(ModulusUptdated{ modulus: modulus });
    spy.assert_emitted(@array![(login_address, expected_login)]);
}
