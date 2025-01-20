use sumo::login::login_contract::{ ILoginDispatcher };
use sumo::utils::constants::{ STRK_ADDRESS , ORACLE_ADDRESS };

use core::starknet::{
    ContractAddress,
    syscalls,
    SyscallResultTrait,
};

use snforge_std::{
    declare,
    ContractClassTrait,
    DeclareResultTrait,
    ContractClass,
    stop_cheat_caller_address,
    start_cheat_caller_address,
};


const LOGIN_ADDRESS: felt252 = 0x75662cc8b986d55d709d58f698bbb47090e2474918343b010192f487e30c23f;
const PKEY: felt252 = 0x6363cb464857bb5eddfa351b098bc10c155d61de554640a1f78df62891cd03f;

fn declare_class(contract_name: ByteArray) -> (ContractClass, felt252) {
    let contract = declare(contract_name.clone()).unwrap().contract_class();
    let class_hash: felt252 = (*contract.class_hash).into();
    (*contract, class_hash)
}

fn deploy_login_account(contract_class: ContractClass, address: felt252, calldata: Array<felt252>) -> ContractAddress {
    let (deployed_address, _) = contract_class
        .deploy_at(@calldata, address.try_into().unwrap())
        .expect('Couldnt deploy');
    deployed_address
}


fn setup_oracle() {
    let (_oracle_contract, _ ) = declare_class("OracleContract");
    let _ = _oracle_contract
        .deploy_at( @array![], ORACLE_ADDRESS.try_into().unwrap())
        .expect('Couldnt deploy');
}

fn setup_erc20() {
    let (_erc20_contract, _ ) = declare_class("ERC20Contract");
    let _ = _erc20_contract
        .deploy_at( @array![LOGIN_ADDRESS], STRK_ADDRESS.try_into().unwrap())
        .expect('Couldnt deploy');
}

fn setup_verifier() {
    let _ = declare_class("UniversalECIP");
    let _ = declare_class("Groth16VerifierBN254");
}

pub fn balance_of(address: ContractAddress) -> u256 {
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

pub fn transfer(from: ContractAddress, to:ContractAddress, amount: u256) {
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

pub fn setup_login() -> (ContractAddress,ILoginDispatcher) {
    setup_verifier();
    setup_erc20();
    setup_oracle();

    let (_account_contract, account_class_hash) = declare_class("Account");
    let (login_contract, _login_class_hash) = declare_class("Login");
    let calldata = array![account_class_hash, PKEY];
    let login_address= deploy_login_account(login_contract, LOGIN_ADDRESS.try_into().unwrap(),calldata);
    let login_dispatcher = ILoginDispatcher {contract_address: login_address};
    (login_address,login_dispatcher)
}
