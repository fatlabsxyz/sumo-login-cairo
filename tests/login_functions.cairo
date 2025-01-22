//These test shoul test Login fuctions not realed with the validate.

use crate::setup::{ setup_login , transfer , balance_of };
use crate::signatures::garaga_signature::{ signature };
use sumo::login::login_contract::{ ILoginDispatcherTrait } ;
use sumo::account::account_contract::{ IAccountDispatcher };
use sumo::utils::constants::{ DEPLOY_FEE_GAS };
use sumo::utils::utils::{ get_gas_price };
use core::starknet::{ ContractAddress };
use snforge_std::{ start_cheat_signature , start_cheat_caller_address };


const INITIAL_BALANCE : u256 = 1_000_000_000_u256;



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

    let _account_dispatcher = IAccountDispatcher {contract_address: account_address};

    let initial_debt = login_dispatcher.get_user_debt(account_address);
    if initial_debt != DEPLOY_FEE_GAS * get_gas_price() {assert(false, 'Debt: Not Asigned') };

    let balance_account = balance_of(account_address);
    if balance_account != 0 { assert(false, 'Balance: Initial not zero') } 

//    println!("Account Deployed");
//    println!("Account Balance {:?} --- Account Debt {:?} ", balance_account, initial_debt);

//    println!("Funding Account");
    let transfer_amount: u256 = 100_000_000_u256;
    transfer(login_address, account_address, transfer_amount);

    let balance_account = balance_of(account_address);
    if balance_account != transfer_amount { assert(false, 'Transfer: Wrong amount') } 
//    println!("Account Balance {:?} --- Account Debt {:?} ", balance_account, initial_debt);
//
    start_cheat_caller_address(login_address, login_address);
    login_dispatcher.collect_debt(account_address);
//
    let new_balance_account = balance_of(account_address);
    let new_debt = login_dispatcher.get_user_debt(account_address);
//    println!("Account Balance {:?} --- Account Debt {:?} ", new_balance_account, new_debt);
    if new_balance_account != balance_account - initial_debt.into() { assert(false,'Transfer: Debt not payed') }
    if new_debt != 0 { assert(false, 'Debt not cleansed') }

}
