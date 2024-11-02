use snforge_std::{
    declare,
    ContractClassTrait,
    DeclareResultTrait,
    ContractClass,
};

use sumo_login_starknet::sumo_login::account::interface::{ILoginDispatcher};
use sumo_login_starknet::sumo_account::account::interface::{IAccountDispatcher};

use crate::utils;


pub fn setup_sumo_duo(address_seed: felt252) -> (ILoginDispatcher, IAccountDispatcher)  {

    let _login_address = 0b101010;
    let _account_address = 0x121212;

    let (login_contract, _) = utils::declare_class("SumoLoginAccount");
    let (account_contract, account_class_hash) = utils::declare_class("SumoAccount");

    let mut login_calldata = array![
        account_class_hash
    ];
    let login_address = utils::deploy(login_contract, _login_address, login_calldata);

    let account_address = utils::deploy(account_contract, _account_address, array![]);

    (
        ILoginDispatcher { contract_address: login_address },
        IAccountDispatcher { contract_address: account_address }
    )
}
