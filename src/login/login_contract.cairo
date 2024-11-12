use core::starknet::{ContractAddress};
use core::pedersen::PedersenTrait;
use core::hash::{HashStateTrait, HashStateExTrait};

#[starknet::interface]
pub trait ILogin<TContractState> {
    fn login(ref self: TContractState, user_address: felt252, new_pk:felt252) -> Span<felt252>;
    fn deploy(ref self: TContractState, salt:felt252, arg1:felt252,arg2:felt252) -> ContractAddress ;
    fn get_deployed(self: @TContractState) -> Array<ContractAddress>;
    fn get_targets(self: @TContractState) -> Array<ContractAddress>;
}


#[derive(Drop, Hash, Serde, Copy)]
pub struct ConstructorCallData{
    arg1:felt252,
    arg2:felt252,
}

#[derive(Drop, Hash, Serde, Copy)]
struct StructForHash {
    prefix: felt252,
    deployer_address: felt252,
    salt: felt252,
    class_hash:felt252,
    constructor_calldata_hash:felt252,
}

trait ConstructorCallDataTrait{
    fn to_array(self: ConstructorCallData)-> Array<felt252>;
    fn hash(self: ConstructorCallData)-> felt252;
}

impl ConstructorCallDataTraitImpl of ConstructorCallDataTrait{
    fn to_array(self: ConstructorCallData)-> Array<felt252>{
        let array: Array<felt252> = array![
            self.arg1,
            self.arg2,
        ];
        return array;
    }
    fn hash(self:ConstructorCallData) -> felt252{
        let hash = PedersenTrait::new(0).update_with(self).update_with(2).finalize();
        return hash;
    }
}



#[starknet::contract]
mod Login {
    use core::pedersen::PedersenTrait;
    use core::hash::{HashStateTrait, HashStateExTrait};
    use super::{StructForHash, ConstructorCallData,ConstructorCallDataTraitImpl};
    use core::starknet::storage::{StoragePointerReadAccess,
        StoragePointerWriteAccess,
        StoragePathEntry,
        Vec,
        VecTrait,
        MutableVecTrait,
        Map
        };
    use core::starknet::{syscalls,SyscallResultTrait};
    use core::starknet::{ContractAddress};
    use core::starknet::class_hash::ClassHash;

    const DEPLOY_FEE: u64 = 1_000_000;

    #[storage]
    struct Storage {
        sumo_account_class_hash: felt252,
        user_debt: Map<ContractAddress, u64>,
        user_list: Map<ContractAddress, bool>,

        //esta es temportal
        deployed: Vec<ContractAddress>,
        target: Vec<ContractAddress>,
    }

    #[constructor]
    fn constructor(ref self: ContractState, sumo_account_class_hash: felt252) {
        self.sumo_account_class_hash.write(sumo_account_class_hash)
    }

    #[abi(embed_v0)]
    impl LoginImpl of super::ILogin<ContractState> {

        fn get_deployed(self: @ContractState) -> Array<ContractAddress> {
            let mut addresses = array![];
            for i in 0..self.deployed.len(){
                addresses.append(self.deployed.at(i).read())
            };
            addresses
        }

        fn get_targets(self: @ContractState) -> Array<ContractAddress> {
            let mut addresses = array![];
            for i in 0..self.deployed.len(){
                addresses.append(self.deployed.at(i).read())
            };
            addresses
        }

        fn login( ref self:ContractState, user_address:felt252, new_pk:felt252,)  -> Span<felt252> {
                let address: ContractAddress = user_address.try_into().unwrap();
                let calldata : Array<felt252> = array![new_pk];
                let mut res = syscalls::call_contract_syscall(
                   address,
                   selector!("change_pkey"),
                   calldata.span()
                   ).unwrap_syscall();
                return res;
        }

        fn deploy(ref self: ContractState, salt:felt252, arg1:felt252, arg2:felt252) -> ContractAddress {
            let class_hash : ClassHash = self.sumo_account_class_hash.read().try_into().unwrap();
            let constructor_arguments = ConstructorCallData {arg1: arg1, arg2:arg2};
            let target_addres = self.precompute_account_address(salt, constructor_arguments);
            let (address,_) = syscalls::deploy_syscall(class_hash,
                    salt,
                    constructor_arguments.to_array().span(),
                    core::bool::True
                ).unwrap_syscall();

            self.target.append().write(target_addres.try_into().unwrap());
            self.deployed.append().write(address);
            self.user_list.entry(address).write(true);
//            self.add_debt(address, DEPLOY_FEE);
            address
        }
    }
    #[generate_trait]
    pub impl PrivateImpl of IPrivate {
        fn add_debt(ref self: ContractState, address: ContractAddress, value: u64) {
            let current_debt: u64 = self.user_debt.entry(address).read();
            self.user_debt.entry(address).write(current_debt + value);
        }

        fn precompute_account_address(ref self:ContractState,salt:felt252, constructor_calldata: ConstructorCallData) -> felt252 {
            let struct_to_hash = StructForHash { prefix: 'STARKNET_CONTRACT_ADDRESS',
                deployer_address: 0,
                salt: salt,
                class_hash: self.sumo_account_class_hash.read(),
                constructor_calldata_hash: constructor_calldata.hash(),
            };
            let hash = PedersenTrait::new(0).update_with(struct_to_hash).update_with(5).finalize();
            return hash;
        }

    }

}

