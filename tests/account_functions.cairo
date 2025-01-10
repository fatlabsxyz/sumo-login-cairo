//Account contract has the functions: 
//  __validate__ (standar)
//  __execute__ (standar)
//  is_valid_signature (standar)
//  pay (tested)
//  change_pkey (tested)

use crate::setup::{setup_login};
use crate::signature::{signature};
use core::starknet::{ContractAddress};
use snforge_std::{start_cheat_signature,start_cheat_caller_address, stop_cheat_caller_address};
use core::starknet::{syscalls,SyscallResultTrait};
//use sumo::login::login_contract::ILoginDispatcher;
use sumo::login::login_contract::ILoginDispatcherTrait;
use sumo::account::account_contract::IAccountDispatcher;
use sumo::account::account_contract::IAccountDispatcherTrait;
use sumo::utils::constants::{STRK_ADDRESS};


const INITIAL_BALANCE : u256 = 1_000_000_000_u256;

fn balance_of(address: ContractAddress) -> u256 {
    let balance = syscalls::call_contract_syscall(
               STRK_ADDRESS.try_into().unwrap(),
               selector!("balance_of"),
               array![address.into()].span()
            ).unwrap_syscall();
    let low: u128 = (*balance[0]).try_into().unwrap();
    let high: u128 = (*balance[1]).try_into().unwrap();
    let amount = u256{ low , high }; 
    return amount; 
}

fn transfer(from: ContractAddress, to:ContractAddress, amount: u256) {
    start_cheat_caller_address(STRK_ADDRESS.try_into().unwrap(), from);
    let recipient: felt252 = to.try_into().unwrap();
    let low: felt252 = amount.low.try_into().unwrap();
    let high: felt252 = amount.high.try_into().unwrap();
    let calldata: Array<felt252> = array![recipient,low,high];

    let _ = syscalls::call_contract_syscall(
               STRK_ADDRESS.try_into().unwrap(),
               selector!("transfer"),
               calldata.span(),
            ).unwrap_syscall();
    stop_cheat_caller_address(STRK_ADDRESS.try_into().unwrap());
}

// --------------------------- TEST FOR PAY FUNCTION ------------------------------------------------
#[test]
#[should_panic(expected: 'Account: not enough to repay')]
fn pay_not_enoguh_money() {
    let (login_address, login_dispatcher) = setup_login();
    let signature = signature();
    start_cheat_signature(login_address , signature) ;
    let account_address: ContractAddress  = login_dispatcher.deploy();
    let account_dispatcher = IAccountDispatcher {contract_address: account_address};
    start_cheat_caller_address(account_address, login_address);
//    println!("login_address:{:?}", login_address);
//    println!("account_addres:{:?}", account_address);
    account_dispatcher.pay();
}

#[test]
#[should_panic(expected:  'Account: invalid deployer')]
fn pay_caller_not_sumo() {
    let (login_address, login_dispatcher) = setup_login();
    let signature = signature();
    start_cheat_signature(login_address , signature) ;
    let account_address: ContractAddress  = login_dispatcher.deploy();
    let account_dispatcher = IAccountDispatcher {contract_address: account_address};
    start_cheat_caller_address(account_address, account_address);
    account_dispatcher.pay();
}

#[test]
fn pay() {
    let (login_address, login_dispatcher) = setup_login();
    let signature = signature();
    start_cheat_signature(login_address , signature) ;
    let account_address: ContractAddress  = login_dispatcher.deploy();
    let account_dispatcher = IAccountDispatcher {contract_address: account_address};

    let transfer_amount: u256 = 3_000_000_u256;
    transfer(login_address, account_address, transfer_amount);

    start_cheat_caller_address(account_address, login_address);
    account_dispatcher.pay();
}
// --------------------------------------------------------------------------------------------------


// --------------------------- TEST FOR CHANGE PKEY FUNCTION ------------------------------------------------
#[test]
#[should_panic(expected:  'Account: not allowed')]
fn change_pkey_not_allowed() {
    let (login_address, login_dispatcher) = setup_login();
    let signature = signature();
    start_cheat_signature(login_address , signature) ;
    let account_address: ContractAddress  = login_dispatcher.deploy();
    let account_dispatcher = IAccountDispatcher {contract_address: account_address};
    let fake: felt252 = 12345;
    let fake_address: ContractAddress = fake.try_into().unwrap();
    start_cheat_caller_address(account_address, fake_address);
    account_dispatcher.change_pkey(1234,1234);
}

#[test]
fn change_pkey_sumo_call() {
    let (login_address, login_dispatcher) = setup_login();
    let signature = signature();
    start_cheat_signature(login_address , signature) ;
    let account_address: ContractAddress  = login_dispatcher.deploy();
    let account_dispatcher = IAccountDispatcher {contract_address: account_address};
    start_cheat_caller_address(account_address, login_address);
    account_dispatcher.change_pkey(1234,1234);
}

#[test]
fn change_pkey_self_call() {
    let (login_address, login_dispatcher) = setup_login();
    let signature = signature();
    start_cheat_signature(login_address , signature) ;
    let account_address: ContractAddress  = login_dispatcher.deploy();
    let account_dispatcher = IAccountDispatcher {contract_address: account_address};
    start_cheat_caller_address(account_address, account_address);
    account_dispatcher.change_pkey(1234,1234);
}
// ----------------------------------------------------------------------------------------------------------

//TODO: Make the signature to test __validate__. you need the tx_hash of a call signed by the s_key
