use snforge_std::{
    declare,
    ContractClassTrait,
    DeclareResultTrait,
};

use sumo_login_starknet::sumo_login::account::interface::ISumoLoginAccount;


// TODO figure a way to mirror same interface from actual account
#[starknet::interface]
trait IContract<TContractState> {
}

pub fn setup_sumo_login() -> IContractDispatcher {
    let contract = declare("SumoLoginAccount").unwrap().contract_class();
    let class_hash: felt252 = (*contract.class_hash).try_into().unwrap();
    let account_address = 0b101010;
    let mut calldata = array![];
    println!("class_hash {:?}", class_hash);
    println!("account_address {:?}", account_address);
    let (contract_address, _) = contract
        .deploy_at(@calldata, account_address.try_into().unwrap())
        .expect('Couldnt deploy AccountPrototype');
    IContractDispatcher { contract_address }
}
