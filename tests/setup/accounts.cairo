use snforge_std::{
    declare,
    ContractClassTrait,
    DeclareResultTrait,
};

// TODO figure a way to mirror same interface from actual account
#[starknet::interface]
trait ITestSumoLoginAccount<TContractState> {
}

// TODO figure a way to mirror same interface from actual account
#[starknet::interface]
trait ITestSumoAccount<TContractState> {
}

pub fn setup_sumo_login() -> ITestSumoLoginAccountDispatcher {
    let contract = declare("SumoLoginAccount").unwrap().contract_class();
    let class_hash: felt252 = (*contract.class_hash).try_into().unwrap();
    let account_address = 0b101010;
    let mut calldata = array![];
    println!("sumo_login class_hash {:?}", class_hash);
    println!("sumo_login account_address {:?}", account_address);
    let (contract_address, _) = contract
        .deploy_at(@calldata, account_address.try_into().unwrap())
        .expect('Couldnt deploy AccountPrototype');
    ITestSumoLoginAccountDispatcher { contract_address }
}

pub fn setup_sumo_account() -> ITestSumoAccountDispatcher {
    let contract = declare("SumoAccount").unwrap().contract_class();
    let class_hash: felt252 = (*contract.class_hash).try_into().unwrap();
    let account_address = 0x121212;
    let mut calldata = array![];
    println!("sumo_account class_hash {:?}", class_hash);
    println!("sumo_account account_address {:?}", account_address);
    let (contract_address, _) = contract
        .deploy_at(@calldata, account_address.try_into().unwrap())
        .expect('Couldnt deploy AccountPrototype');
    ITestSumoAccountDispatcher { contract_address }
}
