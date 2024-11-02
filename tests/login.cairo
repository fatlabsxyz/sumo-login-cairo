use crate::setup::{constants::{ADDRESS_SEED, SUMO_SIGNATURE_RAW}, accounts::{setup_sumo_duo,}};

use sumo_login_starknet::sumo_login::account::interface::{ILoginDispatcherTrait, ILoginDispatcher};
use sumo_login_starknet::sumo_account::account::interface::{
    IAccountDispatcherTrait, IAccountDispatcher
};

use snforge_std::{start_cheat_caller_address};

#[test]
fn test_is_valid_signature() {

    let (sumo_login, sumo_account): (ILoginDispatcher, IAccountDispatcher) = setup_sumo_duo(
        ADDRESS_SEED
    );

    assert!(sumo_login._is_valid_signature(0, SUMO_SIGNATURE_RAW().into()));

    // let is_valid = sumo_login.__validate__(SUMO_SIGNATURE);
    // assert_eq!(is_valid, starknet::VALIDATED);
}
