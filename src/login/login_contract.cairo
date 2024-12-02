use core::starknet::{ContractAddress};
use core::starknet::account::Call;

#[starknet::interface]
pub trait ILogin<TContractState> {
    fn is_valid_signature(self: @TContractState, msg_hash: felt252, signature: Array<felt252>) -> felt252;
    fn __execute__(ref self: TContractState, calls: Span<Call>) -> Array<Span<felt252>> ;
    fn __validate__(self: @TContractState, calls: Span<Call>) -> felt252 ;
    fn __validate_declare__(ref self: TContractState, declared_class_hash:felt252) -> felt252;

    fn deploy(ref self: TContractState, salt:felt252) -> ContractAddress ;
    fn login(ref self: TContractState, salt:felt252, eph_pkey:felt252, expiration_block: u64) ;
    fn update_oauth_public_key(ref self: TContractState);
    fn get_user_debt(self: @TContractState, user_address:felt252) -> u64;
    fn collect_debt(ref self: TContractState, user_address:felt252);

    //for testing
    fn get_deployed(self: @TContractState) -> Array<ContractAddress>;
    fn get_targets(self: @TContractState) -> Array<ContractAddress>;
    fn get_declared_address(self: @TContractState) -> felt252;
}


#[starknet::contract(account)]
pub mod Login {
    use crate::utils::{StructForHashImpl, PublicInputImpl};
    use crate::utils::{PublicInputs,StructForHash};
    use core::starknet::storage::{StoragePointerReadAccess,
        StoragePointerWriteAccess,
        StoragePathEntry,
        Vec,
        VecTrait,
        MutableVecTrait,
        Map
        };
    use core::ecdsa::check_ecdsa_signature;
    use core::starknet::{syscalls,SyscallResultTrait};
    use core::starknet::{ContractAddress};
    use core::starknet::class_hash::ClassHash;
    use core::starknet::VALIDATED;
    use core::starknet::account::Call;
    use core::starknet::{get_caller_address, get_tx_info, get_block_number, get_contract_address};
//    use core::starknet::TxInfo;
    use core::num::traits::Zero;

    const USER_ENDPOINTS : [felt252;2] = [selector!("deploy"), selector!("login")];
    const GARAGA_VERIFY_CLASSHASH: felt252 = 0x640bdf3362f2de1e043bd158fb00297099a35f600edb6acdd56149c4dc0a459;
    const PKEY: felt252 = 0x6363cb464857bb5eddfa351b098bc10c155d61de554640a1f78df62891cd03f;
    const DEPLOY_FEE: u64 = 1_000_000;
    const LOGIN_FEE: u64 = 1_000_000;

    #[storage]
    struct Storage {
        public_key: felt252,
        sumo_account_class_hash: felt252,
        user_debt: Map<ContractAddress, u64>,
        user_list: Map<ContractAddress, bool>,
        oauth_public_key: felt252,
        first_deploy:bool,

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
        fn __validate_declare__(ref self: ContractState, declared_class_hash: felt252) -> felt252 {
            self.only_protocol();
            self.validate_tx_signature();
            println!("entering __validate_declare__");
            assert(!self.first_deploy.read(), 'Only one deploy allowed');
            self.sumo_account_class_hash.write(declared_class_hash);
            self.first_deploy.write(true);
            println!("leaving: __validate_declare__");
            VALIDATED
        }

        fn __validate__(self: @ContractState, calls: Span<Call>) -> felt252 {
            println!("entering __validate__");
            self.only_protocol();
            self.validate_tx_version();
            for call in calls { 
                let selector = *call.selector;
//                if  (selector != selector!("login")) & (selector != selector!("deploy")) {
                if  !self.is_user_endpoint(selector) {
                    println!("entering __validate__ for admin");
                    self.validate_tx_signature();
                } else {
                    println!("entering __validate__ for users");
                    self.only_self_call(*call);
                    self.validate_login_deploy_call(*call);
                }
            };
            VALIDATED
        }

        fn __execute__(ref self: ContractState, mut calls: Span<Call>) -> Array<Span<felt252>> {
            println!("entering __execute__");
            self.only_protocol();
            self.validate_tx_version();
            self.execute_calls(calls)
        }
        
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
        fn get_declared_address(self: @ContractState) -> felt252 {
            self.sumo_account_class_hash.read()
        }

        fn login(ref self:ContractState, salt: felt252, eph_pkey:felt252, expiration_block: u64) {
//            println!("entering: login");
            //Aca se tiene que reconstuir la address partiendo del tx_info
            let user_address: ContractAddress = self.precompute_account_address(salt);
            assert(self.user_list.entry(user_address).read() ,'Loggin: not a sumoer' );
            self.set_user_pkey(user_address, eph_pkey,expiration_block);
            self.add_debt(user_address,LOGIN_FEE);
//            println!("leaving: login");
        }

        fn deploy(ref self: ContractState, salt: felt252) -> ContractAddress {
//            println!("entering: deploy");
            //TODO: get from calldata
            let eph_pkey: felt252 = 12345;
            let expiration_block:u64 = 20_u64;
//            let constructor_arguments = array![1234,1234];
            let constructor_arguments = array![];
            let class_hash : ClassHash = self.sumo_account_class_hash.read().try_into().unwrap();
            let (address,_) = syscalls::deploy_syscall(class_hash,
                    salt,
                    constructor_arguments.span(),
                    core::bool::False
                ).unwrap_syscall();
            self.user_list.entry(address).write(true);
            self.set_user_pkey(address, eph_pkey,expiration_block);
            self.add_debt(address,DEPLOY_FEE);

            //This is for testing
            self.deployed.append().write(address);
            let target_address = self.precompute_account_address(salt);
            self.target.append().write(target_address);
            assert(target_address==address,'Addresses dont match');

//            println!("leaving: deploy");
            address
        }

        fn is_valid_signature(
            self: @ContractState, msg_hash: felt252, signature: Array<felt252>) -> felt252 {
            //TODO: Acomodar esto
            //let public_key = self.public_key.read();
            let public_key = PKEY;
            if check_ecdsa_signature(msg_hash, public_key, *signature.at(0_u32), *signature.at(1_u32)) {
                VALIDATED
            } else {
                0
            }
        }

        fn get_user_debt(self: @ContractState, user_address:felt252) -> u64 {
//            println!("entering: get_user_debt");
            let caller: ContractAddress = user_address.try_into().unwrap();
            let debt = self.user_debt.entry(caller).read();
//            println!("leaving: get_user_debt");
            debt
        }

        fn collect_debt(ref self: ContractState, user_address:felt252) {
//            println!("entering: collect_debt");
            let user_address: ContractAddress = OptionTrait::unwrap(user_address.try_into());
            let caller = get_caller_address();
            if (caller != user_address) & (caller != get_contract_address()){
                assert(false,'you are not allowed');
            }
            let debt = self.user_debt.entry(user_address).read();
            if debt <= 0 { assert(false,'user has no debt') }
            let debt:felt252 = debt.try_into().unwrap();
            syscalls::call_contract_syscall(
               user_address,
               selector!("cancel_debt"),
               array![debt].span()
            ).unwrap_syscall();
            self.user_debt.entry(user_address).write(0);
//            println!("leaving: collect_debt");
        }

        fn  update_oauth_public_key(ref self: ContractState) {
            let old_key = self.oauth_public_key.read();
            let new_key = self.oracle_check();
            if old_key != new_key{
                self.oauth_public_key.write(new_key)
            }
        }
    }

    #[generate_trait]
    pub impl PrivateImpl of IPrivate {
        fn add_debt(ref self: ContractState, address: ContractAddress, value: u64) {
//            println!("adding debt");
            let current_debt: u64 = self.user_debt.entry(address).read();
            self.user_debt.entry(address).write(current_debt + value);
        }

        fn precompute_account_address(self: @ContractState,salt:felt252) -> ContractAddress {
//            let constructor_arguments: Array<felt252> = array![1234,1234];
//            let _constructor_calldata_hash = ConstructorCallDataImpl::from_array(constructor_arguments).hash();
            let hash_zero_array: felt252 = 2089986280348253421170679821480865132823066470938446095505822317253594081284;
            let struct_to_hash = StructForHash {
                prefix: 'STARKNET_CONTRACT_ADDRESS',
                deployer_address: get_contract_address().try_into().unwrap(),
                salt: salt,
                class_hash: self.sumo_account_class_hash.read(),
//                constructor_calldata_hash: constructor_calldata_hash,
                constructor_calldata_hash: hash_zero_array,
            };
            let hash = struct_to_hash.hash();
            hash.try_into().unwrap()
        }

        fn only_protocol(self: @ContractState) {
              let sender = get_caller_address();
              assert(sender.is_zero(), 'Account: invalid caller');
        }

        fn validate_tx_version(self: @ContractState) {
            let tx_info = get_tx_info().unbox();
            let tx_version: u256 = tx_info.version.into();
            assert(tx_version >= 1_u256, 'Fail: Tx_version mismatch');
        }

        fn validate_tx_signature(self: @ContractState){
            let tx_info = get_tx_info().unbox();
            let signature = tx_info.signature;
            let tx_hash = tx_info.transaction_hash;
            assert(self.is_valid_signature(tx_hash,signature.into())==VALIDATED, 'Wrong: Signature');
        }

        fn execute_call(ref self: ContractState, call: @Call) -> Span<felt252> {
            let Call { to, selector, calldata } = *call;
            starknet::syscalls::call_contract_syscall(to, selector, calldata).unwrap_syscall()
        }

        fn execute_calls(ref self: ContractState, mut calls: Span<Call>) -> Array<Span<felt252>> {
            let mut res = array![];
            loop {
                match calls.pop_front() {
                    Option::Some(call) => {
                        let _res = self.execute_call(call);
                        res.append(_res);
                    },
                    Option::None => { break (); },
                };
            };
            res
        }

        fn set_user_pkey(self: @ContractState, user_address: ContractAddress, eph_pkey: felt252, expiration_block:u64) {
            let calldata : Array<felt252> = array![eph_pkey, expiration_block.try_into().unwrap()];
                syscalls::call_contract_syscall(
                   user_address,
                   selector!("change_pkey"),
                   calldata.span()
                ).unwrap_syscall();
        }

        fn validate_block_time(
            self: @ContractState, max_block: u256, current_block_number: u64
        ) -> felt252 {
            let masked_max_block: u64 = max_block.try_into().unwrap();
            assert(current_block_number <= masked_max_block,'Proof expired');
            VALIDATED
        }

        fn garaga_verify_get_public_inputs(
            self: @ContractState, calldata: Span<felt252>
        ) -> PublicInputs {
            //println!("{:?}", calldata.slice(0, 4));
            let mut _res = core::starknet::syscalls::library_call_syscall(
                GARAGA_VERIFY_CLASSHASH.try_into().unwrap(),
                selector!("verify_groth16_proof_bn254"),
                calldata
            )
                .unwrap_syscall();
            let (verified, res) = Serde::<(bool, Span<u256>)>::deserialize(ref _res).unwrap();
            assert(verified,'Garagant');
            //return res;
            //TODO: Esto no fue testeado, habria que compilar y levantar el contrato de garaga?
            return PublicInputImpl::from_span(res);
        }

        fn oracle_check(self: @ContractState)  -> felt252 {
//            core::starknet::syscalls::call_contract_syscall(
//                ORACLE_ADDRESS.try_into().unwrap(), selector!("get"), ArrayTrait::new().span()
//            )
//                .unwrap_syscall();
            let key:felt252 = 123456;
            return key;
        }

        fn only_self_call(self: @ContractState, call: Call) {
            let target_address: ContractAddress = call.to;
            assert(target_address == get_contract_address(), 'Not Allowed Outside Call');
        }

        fn validate_login_deploy_call(self: @ContractState, call:Call) {
            let public_inputs = PublicInputs{
                eph_public_key0: 1234,
                eph_public_key1: 1234,
                address_seed: 1234,
                max_epoch: 1234,
                iss_b64_F: 1234,
                iss_index_in_payload_mod_4: 1234,
                header_F: 1234,
                modulus_F: 1234
            };
            //validate_garaga
            //let public_inputs_verified = self.garaga_verify_get_public_inputs(ACOMODAR EL INPUT);
            let public_inputs_verified = public_inputs.clone();

            assert(public_inputs.all_inputs_hash() == public_inputs_verified.all_inputs_hash(), 'AIH not matching');
            let max_block = public_inputs.max_epoch;
            self.validate_block_time(max_block,get_block_number());
            let salt = call.calldata.at(0).clone();
            let target_address = self.precompute_account_address(salt);

            if call.selector == selector!("deploy") {
                let is_user = self.user_list.entry(target_address).read();
                assert(!is_user, 'Allready an user');
            }
            if call.selector == selector!("login"){
                let debt = self.user_debt.entry(target_address).read();
                assert(debt == 0, 'User has a debt');
            }
        }

        fn is_user_endpoint(self:@ContractState, selector: felt252) -> bool {
            let mut is_contained: bool = false;
            for entry_point in USER_ENDPOINTS.span() {
                if selector == *entry_point {
                    is_contained = true;
                }
            };
            return is_contained;
        }

    }
}

#[cfg(test)]
mod test {
    const ASD : [felt252;4] = [selector!("asd"), selector!("asd1") , selector!("asd2"), selector!("asd3")];

//    #[test]
    fn test() {
        let  mut contains: bool = false;
        for element in ASD.span() {
            if *element == selector!("asd4") {
                contains = true ;
            }
        };
        assert(contains, 'is not contained');
    }
}
