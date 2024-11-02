use starknet::{ContractAddress};

use snforge_std::{
    declare,
    ContractClassTrait,
    DeclareResultTrait,
    ContractClass,
};

    // let contract_class = utils::declare_class("DualCaseAccountMock");
    // let calldata = array![key_pair.public_key];
    // let address = utils::deploy(contract_class, calldata);

pub fn declare_class(contract_name: ByteArray) -> (ContractClass, felt252) {
    let contract = declare(contract_name.clone()).unwrap().contract_class();
    let class_hash: felt252 = (*contract.class_hash).into();
    println!("{} class_hash {:?}", contract_name, class_hash);
    (*contract, class_hash)
}


pub fn deploy(contract_class: ContractClass, address: felt252, calldata: Array<felt252>) -> ContractAddress {
    let (deployed_address, _) = contract_class
        .deploy_at(@calldata, address.try_into().unwrap())
        .expect('Couldnt deploy');
    deployed_address
}
