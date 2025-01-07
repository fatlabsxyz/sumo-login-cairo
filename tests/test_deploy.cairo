use crate::setup::{setup_login};
use crate::signature::{signature};
use core::starknet::{ContractAddress};
//use core::starknet::account::Call;
use snforge_std::{start_cheat_signature,start_cheat_caller_address};
use core::starknet::{syscalls,SyscallResultTrait};
//use sumo::login::login_contract::ILoginDispatcher;
use sumo::login::login_contract::ILoginDispatcherTrait;
use sumo::account::account_contract::IAccountDispatcher;
use sumo::account::account_contract::IAccountDispatcherTrait;

const DEPLOY_FEE: u128 = 1_000_000;
const LOGIN_FEE: u128 = 1_000_000;
const ETH_ADDRRESS: felt252= 0x49D36570D4E46F48E99674BD3FCC84644DDD6B96F7C741B1562B82F9E004DC7;
const INITIAL_BALANCE : u256 = 1_000_000_000_u256;

fn balance_of(address: ContractAddress) -> u256 {
    let balance = syscalls::call_contract_syscall(
               ETH_ADDRRESS.try_into().unwrap(),
               selector!("balance_of"),
               array![address.into()].span()
            ).unwrap_syscall();
    let low: u128 = (*balance[0]).try_into().unwrap();
    let high: u128 = (*balance[1]).try_into().unwrap();
    let amount = u256{ low , high }; 
    return amount; 
}
fn transfer(to:ContractAddress, amount: u256) {
    let recipient: felt252 = to.try_into().unwrap();
    let low: felt252 = amount.low.try_into().unwrap();
    let high: felt252 = amount.high.try_into().unwrap();
    let calldata: Array<felt252> = array![recipient,low,high];

    let _ = syscalls::call_contract_syscall(
               ETH_ADDRRESS.try_into().unwrap(),
               selector!("transfer"),
               calldata.span(),
            ).unwrap_syscall();
}

#[test]
fn initial_balance() {
    let (login_address , _login_dispatcher) = setup_login();
    let amount = balance_of(login_address);
    assert(amount == INITIAL_BALANCE, 'Balance: Initial does not match')
}


#[test]
fn deploy() {
    let (login_address, login_dispatcher) = setup_login();
    let signature = signature();
    start_cheat_signature(login_address , signature) ;
    let account_address: ContractAddress  = login_dispatcher.deploy();
    let account_dispatcher = IAccountDispatcher {contract_address: account_address};
    
    let deployer_address_u = account_dispatcher.get_deployer_address();
    if deployer_address_u != login_address { assert(false, 'Account knows no master') } 

    let initial_debt = login_dispatcher.get_user_debt(account_address);
    if initial_debt != DEPLOY_FEE {assert(false, 'Debt: Not Asigned') };

    let initial_debt_u = account_dispatcher.get_my_debt();
    if initial_debt_u != initial_debt {assert(false, 'Debt: Does not match')}

    let amount = balance_of(account_address);
    if amount != 0 { assert(false, 'Balance: Initial not zero') } 

    start_cheat_caller_address(ETH_ADDRRESS.try_into().unwrap(), login_address);
    let transfer_amount: u256 = 3_000_000_u256;
    transfer(account_address, transfer_amount);

    let amount = balance_of(account_address);
    if amount != transfer_amount { assert(false, 'Transfer: Wrong amount') } 

}

