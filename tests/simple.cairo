// use super::setup::accounts::;
use crate::setup::accounts::{
    setup_sumo_duo,
};

use sumo_login_starknet::sumo_login::account::interface::{ILoginDispatcherTrait};
use sumo_login_starknet::sumo_account::account::interface::{IAccountDispatcherTrait};

use snforge_std::{start_cheat_caller_address};

#[test]
fn simple() {
    let (sumo_login, sumo_account) = setup_sumo_duo(0);
    assert!(1 == 1, "OK");
}

#[test]
#[should_panic(expected: 'NOPE')]
fn simple_fail() {
    assert(1 == 0, 'NOPE');
}

#[test]
fn get_new_address_debt() {
    let (sumo_login, sumo_account) = setup_sumo_duo(0);
    let unknown_address_debt = sumo_login.get_user_debt((0x1234).try_into().unwrap());
    assert!(unknown_address_debt == 0, "OK");
}

#[test]
fn tx_add_debt() {
    let (sumo_login, sumo_account) = setup_sumo_duo(0);
    start_cheat_caller_address(sumo_login.contract_address, sumo_login.contract_address);
    sumo_login.deploy(sumo_account.contract_address);
    let address_debt = sumo_login.get_user_debt(sumo_account.contract_address);
    assert!(address_debt == 1_000_000, "OK");
    let address_debt_2 = sumo_login.get_user_debt(0x12345.try_into().unwrap());
    assert!(address_debt_2 == 1_000, "OK");
}
