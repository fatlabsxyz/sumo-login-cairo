//Account contract has the functions: 
//  __validate__ (standar)
//  __execute__ (standar)
//  is_valid_signature (standar)
//  pay (tested)
//  change_pkey (tested)


use crate::setup::{ setup_login , transfer };
use sumo::login::login_contract::{ ILoginDispatcherTrait };
use sumo::account::account_contract::{ IAccountDispatcher , IAccountDispatcherTrait };
use crate::signatures::garaga_signature::{signature};
use crate::signatures::user_signatures::{ correct_user_signature, incorrect_user_signature };
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
};




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

    let transfer_amount: u256 = 100_000_000_u256;
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


fn call_validate(account_address: ContractAddress, account_dispatcher: IAccountDispatcher) {
    let zero = contract_address_const::<0>();
    start_cheat_caller_address(account_address, zero);
    let call: Call = Call{to:account_address, selector:selector!("pay"),calldata:array![].span()};
    account_dispatcher.__validate__(array![call].span());
}

#[test]
fn correct_signature() {
    let (login_address, login_dispatcher) = setup_login();
    let signature = signature();
    start_cheat_signature(login_address , signature) ;
    let account_address: ContractAddress  = login_dispatcher.deploy();
    let account_dispatcher = IAccountDispatcher {contract_address: account_address};

    let signature = correct_user_signature();
    let tx_hash: felt252 = 0x2418c6772ea47ddc9e3ea548bd2dfc9e9ce42365da5df0a2e872967e857bb97;
    let block_number: u64 = 100_000_u64;

    start_cheat_signature(account_address, signature);
    start_cheat_transaction_hash(account_address, tx_hash);
    start_cheat_block_number(account_address, block_number);
    call_validate(account_address, account_dispatcher);
}


#[test]
#[should_panic(expected:  'Account: session expirated')]
fn expirated_signature() {
    let (login_address, login_dispatcher) = setup_login();
    let signature = signature();
    start_cheat_signature(login_address , signature) ;
    let account_address: ContractAddress  = login_dispatcher.deploy();
    let account_dispatcher = IAccountDispatcher {contract_address: account_address};

    let signature = correct_user_signature();
    let tx_hash: felt252 = 0x2418c6772ea47ddc9e3ea548bd2dfc9e9ce42365da5df0a2e872967e857bb97;
    let block_number: u64 = 1_100_000_u64;

    start_cheat_signature(account_address, signature);
    start_cheat_transaction_hash(account_address, tx_hash);
    start_cheat_block_number(account_address, block_number);
    call_validate(account_address, account_dispatcher);
}

#[test]
#[should_panic(expected:  'Account: invalid signature')]
fn invalid_signature() {
    let (login_address, login_dispatcher) = setup_login();
    let signature = signature();
    start_cheat_signature(login_address , signature) ;
    let account_address: ContractAddress  = login_dispatcher.deploy();
    let account_dispatcher = IAccountDispatcher {contract_address: account_address};

    let signature = incorrect_user_signature();
    let tx_hash: felt252 = 0x2418c6772ea47ddc9e3ea548bd2dfc9e9ce42365da5df0a2e872967e857bb97;
    let block_number: u64 = 100_000_u64;

    start_cheat_signature(account_address, signature);
    start_cheat_transaction_hash(account_address, tx_hash);
    start_cheat_block_number(account_address, block_number);
    call_validate(account_address, account_dispatcher);
}


#[test]
#[should_panic(expected:  'Account: invalid signature')]
fn invalid_signature_changed() {
    let (login_address, login_dispatcher) = setup_login();
    let signature = signature();
    start_cheat_signature(login_address , signature) ;
    let account_address: ContractAddress  = login_dispatcher.deploy();
    let account_dispatcher = IAccountDispatcher {contract_address: account_address};

    start_cheat_caller_address(account_address, account_address);
    account_dispatcher.change_pkey(1234,1_000_000);

    let signature = correct_user_signature();
    let tx_hash: felt252 = 0x2418c6772ea47ddc9e3ea548bd2dfc9e9ce42365da5df0a2e872967e857bb97;
    let block_number: u64 = 100_000_u64;

    start_cheat_signature(account_address, signature);
    start_cheat_transaction_hash(account_address, tx_hash);
    start_cheat_block_number(account_address, block_number);
    call_validate(account_address, account_dispatcher);
}
