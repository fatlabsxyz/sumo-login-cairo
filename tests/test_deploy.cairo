use crate::setup::{setup_login};
use starknet::{contract_address_const};
use crate::signature::{signature};
use core::starknet::account::Call;
use core::starknet::{ContractAddress};
//use core::starknet::account::Call;
use snforge_std::{start_cheat_signature,start_cheat_caller_address, stop_cheat_caller_address};
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

fn transfer(from: ContractAddress, to:ContractAddress, amount: u256) {
    start_cheat_caller_address(ETH_ADDRRESS.try_into().unwrap(), from);
    let recipient: felt252 = to.try_into().unwrap();
    let low: felt252 = amount.low.try_into().unwrap();
    let high: felt252 = amount.high.try_into().unwrap();
    let calldata: Array<felt252> = array![recipient,low,high];

    let _ = syscalls::call_contract_syscall(
               ETH_ADDRRESS.try_into().unwrap(),
               selector!("transfer"),
               calldata.span(),
            ).unwrap_syscall();
    stop_cheat_caller_address(ETH_ADDRRESS.try_into().unwrap());
}



#[test]
fn initial_balance() {
    let (login_address , _login_dispatcher) = setup_login();
    let amount = balance_of(login_address);
    assert(amount == INITIAL_BALANCE, 'Balance: Initial does not match')
}


#[test]
fn collect_debt() {
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
    println!("Debt L :{:?} --- Debt U {:?}",initial_debt, initial_debt_u);
    if initial_debt_u != initial_debt {assert(false, 'Debt: Does not match')}

    let balance_account = balance_of(account_address);
    if balance_account != 0 { assert(false, 'Balance: Initial not zero') } 

    println!("Account Deployed");
    println!("Account Balance {:?} --- Account Debt {:?} ", balance_account, initial_debt_u);

    println!("Funding Account");
    let transfer_amount: u256 = 3_000_000_u256;
    transfer(login_address, account_address, transfer_amount);

    let balance_account = balance_of(account_address);
    if balance_account != transfer_amount { assert(false, 'Transfer: Wrong amount') } 
    println!("Account Balance {:?} --- Account Debt {:?} ", balance_account, initial_debt_u);
//
    start_cheat_caller_address(login_address, login_address);
    login_dispatcher.collect_debt(account_address);
//
    let new_balance_account = balance_of(account_address);
    let new_debt = login_dispatcher.get_user_debt(account_address);
    println!("Account Balance {:?} --- Account Debt {:?} ", new_balance_account, new_debt);
    if new_balance_account != balance_account - initial_debt.into() { assert(false,'Transfer: Debt not payed') }
    if new_debt != 0 { assert(false, 'Debt not cleansed') }

}

fn call_execute(address: ContractAddress) {
    let zero = contract_address_const::<0>();
    start_cheat_caller_address(address, zero);
    let call: Call = Call{to:address.try_into().unwrap(),
        selector:selector!("get_my_debt"),
        calldata:array![].span()};
    let dispatcher = IAccountDispatcher {contract_address: address};
    dispatcher.__execute__(array![call].span());
}

//#[test]
//#[should_panic(expected: 'Account: not enoght to repay')]
//fn account_blocked() {
//    let (login_address, login_dispatcher) = setup_login();
//    let signature = signature();
//    start_cheat_signature(login_address , signature) ;
//    let account_address: ContractAddress  = login_dispatcher.deploy();
//    let account_dispatcher = IAccountDispatcher {contract_address: address};
//    account_dispatcher.call_for_collect();
//}

//#[test]
//fn repay_on_execute() {
//    let (login_address, login_dispatcher) = setup_login();
//    let signature = signature();
//    start_cheat_signature(login_address , signature) ;
//    let account_address: ContractAddress  = login_dispatcher.deploy();
//    transfer(login_address, account_address, 3_000_000_u256);
//    let initial_balance = balance_of(account_address);
//    let initial_debt = login_dispatcher.get_user_debt(account_address);
//    call_execute(account_address);
//    let balance = balance_of(account_address);
//    let debt = login_dispatcher.get_user_debt(account_address);
//    if balance != initial_balance - initial_debt.into() { assert(false,'Transfer: Debt not payed') }
//    if debt != 0 { assert(false, 'Debt not cleansed') }
//}
