use core::starknet::{ContractAddress};
use core::starknet::account::Call;

#[starknet::interface]
pub trait ILogin<TContractState> {
    fn is_valid_signature(self: @TContractState, msg_hash: felt252, signature: Array<felt252>) -> felt252;
    fn __validate__(self: @TContractState, calls: Span<Call>) -> felt252 ;
    fn __execute__(ref self: TContractState, calls: Span<Call>) -> Array<Span<felt252>> ;
    fn __validate_declare__(ref self: TContractState, declared_class_hash: felt252) -> felt252;

    fn deploy(ref self: TContractState) -> ContractAddress ;
    fn login(ref self: TContractState) ;
    fn is_sumo_user(self: @TContractState, user_address: ContractAddress) -> bool;
    fn update_oauth_public_key(ref self: TContractState);
    fn get_user_debt(self: @TContractState, user_address: ContractAddress) -> u128;
    fn collect_debt(ref self: TContractState, user_address: ContractAddress);
}

#[starknet::contract(account)]
pub mod Login {
    use crate::utils::structs::{StructForHashImpl, PublicInputImpl};
    use crate::utils::structs::{Signature};
    use crate::utils::execute::execute_calls;
    use core::starknet::storage::{StoragePointerReadAccess,
        StoragePointerWriteAccess,
        StoragePathEntry,
        Map
        };
    use core::ecdsa::check_ecdsa_signature;
    use core::starknet::{syscalls,SyscallResultTrait};
    use core::starknet::{ContractAddress};
    use core::starknet::class_hash::{ClassHash};
    use core::starknet::VALIDATED;
    use core::starknet::account::Call;
    use core::starknet::{get_caller_address, get_tx_info, get_block_number, get_contract_address};
//    use core::starknet::TxInfo;
    use core::num::traits::Zero;
    use crate::utils::errors::{LoginErrors};
    use crate::utils::utils::{validate_all_inputs_hash, mask_address_seed, precompute_account_address};

    const USER_ENDPOINTS : [felt252;2] = [selector!("deploy"), selector!("login")];
    const TWO_POWER_128: felt252 = 340282366920938463463374607431768211456;
    const MASK_250: u256 = 1809251394333065553493296640760748560207343510400633813116524750123642650623;
    const GARAGA_VERIFY_CLASSHASH: felt252= 0x013da60eb4381fca5d1e87941579bf09b5218b62db1f812bf6b59999002d230c;
    const ETH_ADDRRESS: felt252= 0x49D36570D4E46F48E99674BD3FCC84644DDD6B96F7C741B1562B82F9E004DC7;
    const MODULUS_F: u256 = 6472322537804972268794034248194861302128540584786330577698326766016488520183;
    const PKEY: felt252 = 0x6363cb464857bb5eddfa351b098bc10c155d61de554640a1f78df62891cd03f;
    const DEPLOY_FEE: u128 = 1_000_000;
    const LOGIN_FEE: u128 = 1_000_000;

    #[storage]
    struct Storage {
        public_key: felt252,
        sumo_account_class_hash: felt252,
        user_debt: Map<ContractAddress, u128>,
        user_list: Map<ContractAddress, bool>,
        oauth_modulus_F: u256,
    }


    #[constructor]
    fn constructor(ref self: ContractState, sumo_account_class_hash: felt252) {
        self.sumo_account_class_hash.write(sumo_account_class_hash);
        self.oauth_modulus_F.write(MODULUS_F);
    }

    #[abi(embed_v0)]
    impl LoginImpl of super::ILogin<ContractState> {
        fn __validate_declare__(ref self: ContractState, declared_class_hash: felt252) -> felt252 {
            self.sumo_account_class_hash.write(declared_class_hash);
            VALIDATED
        }

        fn __validate__(self: @ContractState, calls: Span<Call>) -> felt252 {
            self.only_protocol();
            self.validate_tx_version();
            let signature = self.get_serialized_signature();

            if signature.signature_type == selector!("signature/user") {
                assert(calls.len() == 1, LoginErrors::MULTICALLS);
                let call = calls[0];
                self.only_self_call(*call);
                assert(self.is_user_entrypoint(*call.selector) , LoginErrors::SELECTOR_NOT_ALLOWED);
                self.validate_tx_user_signature(signature.eph_key, signature.r, signature.s);
                self.validate_login_deploy_call(*call);

            } else if signature.signature_type == selector!("signature/admin") {
                self.validate_tx_admin_signature(signature.r, signature.s);
                for call in calls {
                    //admin cannot call login/deploy selector with his key
                    assert(!self.is_user_entrypoint(*call.selector), LoginErrors::SELECTOR_NOT_ALLOWED)
                }
            } else {
                assert(false, LoginErrors::INVALID_SIGNATURE_TYPE);
            };
            VALIDATED
        }

        fn __execute__(ref self: ContractState, mut calls: Span<Call>) -> Array<Span<felt252>> {
//            println!("entering __execute__");
            self.only_protocol();
            self.validate_tx_version();
            execute_calls(calls)
        }
        
        fn is_sumo_user(self: @ContractState, user_address: ContractAddress) -> bool {
            self.user_list.entry(user_address).read()
        }

        fn login(ref self:ContractState) {
            let signature = self.get_serialized_signature();
            let (eph_key_0,eph_key_1) = signature.eph_key;
            let reconstructed_eph_key: felt252 = eph_key_0 * TWO_POWER_128 + eph_key_1;
            let expiration_block:u64 = signature.max_block.try_into().unwrap();

            let user_address: ContractAddress = self.get_target_address(signature.address_seed);

            self.set_user_pkey(user_address, reconstructed_eph_key, expiration_block);
            self.add_debt(user_address,LOGIN_FEE);
        }

        fn deploy(ref self: ContractState) -> ContractAddress {
//            println!("Entering deploy");
            let signature = self.get_serialized_signature();
            let address_seed_masked = mask_address_seed(signature.address_seed);
            let class_hash : ClassHash = self.sumo_account_class_hash.read().try_into().unwrap();
            let (address,_) = syscalls::deploy_syscall(class_hash,
                    address_seed_masked,
                    array![].span(),
                    core::bool::False
                ).unwrap_syscall();
            let precomputed_address = self.get_target_address(signature.address_seed);
            assert!(precomputed_address == address, "Precomputed Address does not match");
            self.user_list.entry(address).write(true);

            let (eph_key_0,eph_key_1) = signature.eph_key;
            let reconstructed_eph_key: felt252 = eph_key_0 * TWO_POWER_128 + eph_key_1;
            let expiration_block:u64 = signature.max_block.try_into().unwrap();
            self.set_user_pkey(address, reconstructed_eph_key ,expiration_block);
            self.add_debt(address,DEPLOY_FEE);
            println!("Deployed address {:?}", address);
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

        fn get_user_debt(self: @ContractState, user_address:ContractAddress) -> u128 {
            self.user_debt.entry(user_address).read()
        }

        fn collect_debt(ref self: ContractState, user_address:  ContractAddress) {
            let caller = get_caller_address();
            if ( caller != get_contract_address()) && (caller != user_address) {
                assert(false, LoginErrors::SELECTOR_NOT_ALLOWED);
            } 

            if !self.user_list.entry(user_address).read() { 
                assert(false, LoginErrors::NOT_USER);
            }

            let debt = self.user_debt.entry(user_address).read();
            if debt == 0 { return;} 

            syscalls::call_contract_syscall(
               user_address,
               selector!("pay"),
               array![].span()
            ).unwrap_syscall();

            self.user_debt.entry(user_address).write(0);
        }

        fn  update_oauth_public_key(ref self: ContractState) {
            let old_key = self.oauth_modulus_F.read();
            let new_key = self.oracle_check();
            if old_key != new_key {
                self.oauth_modulus_F.write(new_key)
            }
        }
    }

    #[generate_trait]
    pub impl PrivateImpl of IPrivate {
        fn add_debt(ref self: ContractState, address: ContractAddress, value: u128) {
//            println!("adding debt");
            let current_debt: u128 = self.user_debt.entry(address).read();
            self.user_debt.entry(address).write(current_debt + value);
        }

        fn only_protocol(self: @ContractState) {
            let sender = get_caller_address();
            assert(sender.is_zero(), LoginErrors::INVALID_CALLER);
            //println!("only_protocol [OK]");
        }

        fn validate_tx_version(self: @ContractState) {
            let tx_info = get_tx_info().unbox();
            let tx_version: u256 = tx_info.version.into();
            assert(tx_version >= 1_u256, LoginErrors::INVALID_TX_VERSION);
            //println!("validate_tx_version [OK]");
        }

        fn validate_tx_user_signature(self: @ContractState, eph_key:(felt252,felt252), r:felt252, s:felt252){
            let tx_info = get_tx_info().unbox();
            let tx_hash = tx_info.transaction_hash;
            let (eph_key_0, eph_key_1) = eph_key;
            let reconstructed_eph_key: felt252 = eph_key_0 * TWO_POWER_128 + eph_key_1;
            if !check_ecdsa_signature(tx_hash, reconstructed_eph_key, r, s) {
                assert(false, LoginErrors::INVALID_USER_SIGNATURE)
            }
        }

        fn validate_tx_admin_signature(self: @ContractState, r:felt252, s:felt252){
            let tx_info = get_tx_info().unbox();
            let tx_hash = tx_info.transaction_hash;
            let rs:Array<felt252> = array![r,s];
            assert(self.is_valid_signature(tx_hash,rs) == VALIDATED, 'Wrong: Signature');
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
            assert(current_block_number <= masked_max_block, LoginErrors::EXPIRED_PROOF);
            //println!("validate_block_time [OK]");
            VALIDATED
        }

        fn garaga_verify_get_public_inputs(self: @ContractState, calldata: Span<felt252>) ->  Span<u256> {
            let mut _res = syscalls::library_call_syscall(
                GARAGA_VERIFY_CLASSHASH.try_into().unwrap(),
                selector!("verify_groth16_proof_bn254"),
                calldata
            )
                .unwrap_syscall();
            let (verified, res) = Serde::<(bool, Span<u256>)>::deserialize(ref _res).unwrap();
            assert(verified, LoginErrors::INVALID_PROOF);
            //println!("Garaga Verifier [OK]");
            return res;
        }

        fn oracle_check(self: @ContractState)  -> u256 {
//            core::starknet::syscalls::call_contract_syscall(
//                ORACLE_ADDRESS.try_into().unwrap(), selector!("get"), ArrayTrait::new().span()
//            )
//                .unwrap_syscall();
            let key:u256 = 123456_256;
            return key;
        }

        fn only_self_call(self: @ContractState, call: Call) {
            let target_address: ContractAddress = call.to;
            assert(target_address == get_contract_address(), LoginErrors::OUTSIDE_CALL);
            //println!("only_self [OK]");
        }

        fn validate_login_deploy_call(self: @ContractState, call:Call) {
            let signature = self.get_serialized_signature();

            self.validate_block_time(signature.max_block.into(),get_block_number());
            self.validate_oauth_modulus_F(signature.modulus_F);

            let all_inputs_hash_garaga = self.garaga_verify_get_public_inputs(signature.garaga);
            assert(validate_all_inputs_hash(@signature, all_inputs_hash_garaga), LoginErrors::INVALID_ALL_INPUTS_HASH);

            let target_address = self.get_target_address(signature.address_seed);
            let is_user = self.user_list.entry(target_address).read();

            if call.selector == selector!("deploy") {
                assert(is_user == false, LoginErrors::IS_USER );
            }

            if call.selector == selector!("login"){
                assert(is_user, LoginErrors::NOT_USER );
                let debt = self.user_debt.entry(target_address).read();
                assert(debt == 0, LoginErrors::HAS_DEBT);
            }
            println!("Ready to deploy/login at: {:?}", target_address);
        }

        fn is_user_entrypoint(self:@ContractState, selector: felt252) -> bool {
            let mut is_contained: bool = false;
            for entry_point in USER_ENDPOINTS.span() {
                if selector == *entry_point {
                    is_contained = true;
                }
            };
            return is_contained;
        }

        fn get_serialized_signature(self:@ContractState) -> Signature {
            let tx = get_tx_info().unbox();
            let mut signer = tx.signature;
            let signature: Signature = Serde::<Signature>::deserialize(ref signer).unwrap();
            return signature;
        }

        fn validate_oauth_modulus_F(self: @ContractState, modulus_f: u256) {
            assert(self.oauth_modulus_F.read() == modulus_f, LoginErrors::INVALID_OAUTH_SIGNATURE);
        }

        fn get_target_address(self: @ContractState, address_seed: u256) -> ContractAddress {
            let login_address = get_contract_address();
            let account_class = self.sumo_account_class_hash.read();
            precompute_account_address(login_address, account_class, address_seed)
        }
    }
}

