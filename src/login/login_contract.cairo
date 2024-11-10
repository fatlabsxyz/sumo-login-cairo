use core::starknet::{ContractAddress};
use core::pedersen::PedersenTrait;
use core::hash::{HashStateTrait, HashStateExTrait};

#[starknet::interface]
pub trait ILogin<TContractState> {
    fn login(ref self: TContractState, user_address: felt252, new_pk:felt252) -> Span<felt252>;
    fn deploy(ref self: TContractState) -> ContractAddress ;
    fn get_deployed(self: @TContractState) -> Array<ContractAddress>;
    fn get_deploy(self: @TContractState) -> ContractAddress;
}


#[derive(Drop, Hash, Serde, Copy)]
pub struct ConstructorCallData{
    arg1:felt252,
    arg2:felt252,
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
    use super::{ConstructorCallData,ConstructorCallDataTraitImpl};
    use core::starknet::storage::{StoragePointerReadAccess,
        StoragePointerWriteAccess,
        StoragePathEntry,
        Vec,
        VecTrait,
        MutableVecTrait,
        Map
        };
//    use core::starknet::get_contract_address;
    use core::starknet::{syscalls,SyscallResultTrait};
    use core::starknet::{ContractAddress};
    use core::starknet::class_hash::ClassHash;

    const DEPLOY_FEE: u64 = 1_000_000;
    const SUMO_ACCOUNT_CLASS_HASH: felt252 = 0x009e7ef702d06b14118fdcfcfc5e1fed6252786a388b10fabc5f0af04f68e6f6;

    #[storage]
    struct Storage {
        sumo_account_class_hash: felt252,
        user_debt: Map<ContractAddress, u64>,
        user_list: Map<ContractAddress, bool>,

        //esta es temportal
        deployed: Vec<ContractAddress>,
        deploy_one: ContractAddress,
    }

//    #[constructor]
//    fn constructor(ref self: ContractState, sumo_account_class_hash: felt252) {
//        self.sumo_account_class_hash.write(sumo_account_class_hash)
//    }




    #[derive(Drop, Hash, Serde, Copy)]
    struct StructForHash {
        prefix: felt252,
        deployer_address: felt252,
        salt: felt252,
        class_hash:felt252,
        constructor_calldata_hash:felt252,
    }
    

    #[abi(embed_v0)]
    impl LoginImpl of super::ILogin<ContractState> {
        fn get_deploy(self: @ContractState) -> ContractAddress {
            self.deploy_one.read()
        }

        fn get_deployed(self: @ContractState) -> Array<ContractAddress> {
            let mut addresses = array![];
            for i in 1..self.deployed.len(){
                addresses.append(self.deployed.at(i).read())
            };
            addresses
        }

        fn login(
                ref self:ContractState,
                user_address:felt252,
                new_pk:felt252,
            )  -> Span<felt252> {
                //Here usser_addres must be computable from tx_info
                let address: ContractAddress = user_address.try_into().unwrap();
//                if !self.user_list.entry(address).read() {
//                    self.deploy()
//                }
                let calldata : Array<felt252> = array![new_pk];
                let mut res = syscalls::call_contract_syscall(
                   address,
                   selector!("change_pkey"),
                   calldata.span()
                   ).unwrap_syscall();
                return res;
        }

        fn deploy(ref self: ContractState) -> ContractAddress {
//            let _class_hash : ClassHash = self.sumo_account_class_hash.read().try_into().unwrap();
            let class_hash : ClassHash = SUMO_ACCOUNT_CLASS_HASH.try_into().unwrap();
            let salt:felt252 = 1234;
            let arg1:felt252 = 1234;
            let arg2:felt252 = 1234;
            let salida:Array<felt252> = array![arg1, arg2];
            let calldata =  salida.span();
            let (address,_) = syscalls::deploy_syscall(class_hash,salt,calldata,core::bool::True).unwrap_syscall() ;

            self.deployed.append().write(address);
            self.deploy_one.write(address);
//            self.add_debt(address, DEPLOY_FEE);
//            self.user_list.entry(address).write(true);
            address
        }
    }
    #[generate_trait]
    pub impl PrivateImpl of IPrivate {
        fn add_debt(ref self: ContractState, address: ContractAddress, value: u64) {
            let current_debt: u64 = self.user_debt.entry(address).read();
            self.user_debt.entry(address).write(current_debt + value);
        }

        fn precompute_account_address(ref self:ContractState, constructor_calldata: ConstructorCallData) -> felt252 {
            let struct_to_hash = StructForHash { prefix: 'STARKNET_CONTRACT_ADDRESS',
                deployer_address: 0,
                salt: 1234,
                class_hash: SUMO_ACCOUNT_CLASS_HASH,
                constructor_calldata_hash: constructor_calldata.hash() ,
            };
            let hash = PedersenTrait::new(0).update_with(struct_to_hash).update_with(5).finalize();
            return hash;
        }

    }

}

#[cfg(test)]
mod tests {
    use core::pedersen::PedersenTrait;
    use core::hash::{HashStateTrait, HashStateExTrait};
    const SUMO_ACCOUNT_CLASS_HASH: felt252 = 0x009e7ef702d06b14118fdcfcfc5e1fed6252786a388b10fabc5f0af04f68e6f6;

    #[derive(Drop, Hash, Serde, Copy)]
    struct CalldataForHash {
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

    #[test]
    fn precompute_account_address() {
        //Target is the result of a deploy with calldata {arg1:1234, arg2:1234}
        //This test passes. It depends of old data but it helps to understand the flow
        let target: felt252 = 0x06515a87851fc1154f3604b3719c5db8d578b318afdbb69733e9ab930593e069;
        let calldata_to_hash = CalldataForHash {arg1: 1234, arg2: 1234};
        let constructor_calldata_hash = PedersenTrait::new(0).update_with(calldata_to_hash).update_with(2).finalize();

        let struct_to_hash = StructForHash { prefix: 'STARKNET_CONTRACT_ADDRESS',
            deployer_address: 0,
            salt: 1234,
            class_hash: SUMO_ACCOUNT_CLASS_HASH,
            constructor_calldata_hash: constructor_calldata_hash ,
        };
        let hash = PedersenTrait::new(0).update_with(struct_to_hash).update_with(5).finalize();
        println!("{:?}",hash);
        assert_eq!(hash, target)
    }
}
