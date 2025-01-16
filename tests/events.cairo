use crate::signatures::garaga_signature::{signature};
use sumo::login::login_contract::ILoginDispatcherTrait;
use sumo::account::account_contract::IAccountDispatcher;
use core::starknet::{syscalls,SyscallResultTrait};
use snforge_std::{start_cheat_signature,start_cheat_caller_address, stop_cheat_caller_address};
use sumo::login::login_contract::Login::{Event as LoginEvents, DeployAccount, DebtCollected, LoginAccount};
use sumo::account::account_contract::Account::{Event as AccountEvents, DebtPayed};
use snforge_std::{spy_events, EventSpyAssertionsTrait};
use crate::setup::{setup_login};
use core::starknet::{ContractAddress};
use sumo::utils::constants::{STRK_ADDRESS};


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

#[test]
fn deploy() {
    let (login_address, login_dispatcher) = setup_login();
    let signature = signature();
    start_cheat_signature(login_address , signature) ;
    let mut spy = spy_events();
    let account_address: ContractAddress  = login_dispatcher.deploy();
    let expected = LoginEvents::DeployAccount(DeployAccount{ address : account_address });
    spy.assert_emitted(@array![(login_address, expected)])
}


#[test]
fn pay_and_collect_debt() {
    let (login_address, login_dispatcher) = setup_login();
    let signature = signature();
    start_cheat_signature(login_address , signature) ;
    let account_address: ContractAddress  = login_dispatcher.deploy();

    let _account_dispatcher = IAccountDispatcher {contract_address: account_address};

    let transfer_amount: u256 = 3_000_000_u256;
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

    let transfer_amount: u256 = 3_000_000_u256;
    transfer(login_address, account_address, transfer_amount);

    start_cheat_caller_address(login_address, login_address);
    login_dispatcher.collect_debt(account_address);

    let mut spy = spy_events();
    login_dispatcher.login();
    let expected_login = LoginEvents::LoginAccount(LoginAccount{ address : account_address });
    spy.assert_emitted(@array![(login_address, expected_login)]);
}

