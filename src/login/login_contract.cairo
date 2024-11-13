use core::starknet::{ContractAddress};

#[starknet::interface]
pub trait ILogin<TContractState> {
    fn login(ref self: TContractState, user_address: felt252, new_pk:felt252) -> Span<felt252>;
    fn deploy(ref self: TContractState, salt:felt252, calldata: Array<felt252>) -> ContractAddress ;
    fn get_deployed(self: @TContractState) -> Array<ContractAddress>;
    fn get_targets(self: @TContractState) -> Array<ContractAddress>;
}


#[starknet::contract]
mod Login {
    use crate::utils::{StructForHashImpl, ConstructorCallDataImpl};
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

        fn deploy(ref self: ContractState, salt:felt252, calldata: Array<felt252>) -> ContractAddress {
            let class_hash : ClassHash = self.sumo_account_class_hash.read().try_into().unwrap();
            let span = calldata.span();
            let target_addres = self.precompute_account_address(salt, calldata);
            let (address,_) = syscalls::deploy_syscall(class_hash,
                    salt,
                    span,
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

        fn precompute_account_address(ref self:ContractState,salt:felt252, calldata: Array<felt252>) -> felt252 {
            let constructor_calldata = ConstructorCallDataImpl::from_array(calldata);
            let struct_to_hash = StructForHashImpl::new (
                prefix: 'STARKNET_CONTRACT_ADDRESS',
                deployer_address: 0,
                salt: salt,
                class_hash: self.sumo_account_class_hash.read(),
                constructor_calldata_hash: constructor_calldata.hash(),
            );
            let precomputed_address= struct_to_hash.hash();
            return precomputed_address;
        }
    }
}

