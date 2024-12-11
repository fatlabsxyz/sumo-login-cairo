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
    fn is_sumo_user(self: @TContractState, user_address:felt252) -> bool;
    fn update_oauth_public_key(ref self: TContractState);
    fn get_user_debt(self: @TContractState, user_address:felt252) -> u128;
    fn collect_debt(ref self: TContractState, user_address:felt252);
}

#[starknet::contract(account)]
pub mod Login {
    use core::sha256::compute_sha256_byte_array;
    use crate::utils::structs::{StructForHashImpl, PublicInputImpl};
    use crate::utils::structs::{StructForHash};
    use crate::utils::execute::execute_calls;
    use core::starknet::storage::{StoragePointerReadAccess,
        StoragePointerWriteAccess,
        StoragePathEntry,
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
    const TWO_POWER_128: felt252 = 340282366920938463463374607431768211456;
    const MASK_250: u256 = 1809251394333065553493296640760748560207343510400633813116524750123642650623;
    const GARAGA_VERIFY_CLASSHASH: felt252 = 0x013da60eb4381fca5d1e87941579bf09b5218b62db1f812bf6b59999002d230c;
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

    #[derive(Serde, Drop, Debug)]
    struct Signature {
        signature_type: felt252,
        r: felt252,
        s: felt252,
        eph_key: (felt252, felt252),
        address_seed: u256,
        max_block: felt252,
        iss_b64_F: u256,
        iss_index_in_payload_mod_4: felt252,
        header_F: u256,
        modulus_F: u256,
        garaga: Span<felt252>
    }

    #[constructor]
    fn constructor(ref self: ContractState, sumo_account_class_hash: felt252) {
        self.sumo_account_class_hash.write(sumo_account_class_hash);
        self.oauth_modulus_F.write(MODULUS_F);
    }

    #[abi(embed_v0)]
    impl LoginImpl of super::ILogin<ContractState> {

        fn __validate_declare__(ref self: ContractState, declared_class_hash: felt252) -> felt252 {
//            println!("entering __validate_declare__");
            self.sumo_account_class_hash.write(declared_class_hash);
//            println!("leaving: __validate_declare__");
            VALIDATED
        }

        fn __validate__(self: @ContractState, calls: Span<Call>) -> felt252 {
            self.only_protocol();
            self.validate_tx_version();

            let signature = self.get_serialized_signature();
//            println!("Selector User Signature:{:?}",selector!("User Signature"));
//            println!("Selector Admin Signature:{:?}",selector!("Admin Signature"));

            if signature.signature_type == selector!("User Signature") {
//                println!("entering __validate__ for Users");
                assert!(calls.len() == 1, "User Multicals Not Allowed");
                let call = calls[0];
                self.only_self_call(*call);
                assert!(self.is_user_entrypoint(*call.selector),"Not Allowed");
                self.validate_tx_user_signature(signature.eph_key, signature.r,signature.s);
                self.validate_login_deploy_call(*call);

            } else if signature.signature_type == selector!("Admin Signature") {
//                println!("entering __validate__ for Admin");
                self.validate_tx_admin_signature(signature.r, signature.s);
                for call in calls {
                    assert!(!self.is_user_entrypoint(*call.selector),"Not Allowed")
                }
            } else {
                assert!(false, "Signature Type Not Recognised");
            };
            VALIDATED
        }

        fn __execute__(ref self: ContractState, mut calls: Span<Call>) -> Array<Span<felt252>> {
//            println!("entering __execute__");
            self.only_protocol();
            self.validate_tx_version();
            execute_calls(calls)
        }
        
        fn is_sumo_user(self: @ContractState, user_address:felt252) -> bool {
            self.user_list.entry(user_address.try_into().unwrap()).read()
        }

        fn login(ref self:ContractState) {
            let signature = self.get_serialized_signature();
            let address_seed_masked = self.mask_address_seed(signature.address_seed);
            let (eph_key_0,eph_key_1) = signature.eph_key;
            let reconstructed_eph_key: felt252 = eph_key_0 * TWO_POWER_128 + eph_key_1;
            let expiration_block:u64 = signature.max_block.try_into().unwrap();

            let user_address: ContractAddress = self.precompute_account_address(address_seed_masked);

            assert(self.user_list.entry(user_address).read() ,'Loggin: not a sumoer' );

            self.set_user_pkey(user_address, reconstructed_eph_key, expiration_block);
            self.add_debt(user_address,LOGIN_FEE);
        }

        fn deploy(ref self: ContractState) -> ContractAddress {
//            println!("Entering deploy");
            let signature = self.get_serialized_signature();
            let address_seed_masked = self.mask_address_seed(signature.address_seed);
            let (eph_key_0,eph_key_1) = signature.eph_key;
            let reconstructed_eph_key: felt252 = eph_key_0 * TWO_POWER_128 + eph_key_1;
            let expiration_block:u64 = signature.max_block.try_into().unwrap();
            let class_hash : ClassHash = self.sumo_account_class_hash.read().try_into().unwrap();
            let (address,_) = syscalls::deploy_syscall(class_hash,
                    address_seed_masked,
                    array![].span(),
                    core::bool::False
                ).unwrap_syscall();
            let precomputed_address = self.precompute_account_address(address_seed_masked);
            assert!(precomputed_address == address, "Precomputed Address does not match");
            self.user_list.entry(address).write(true);
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

        fn get_user_debt(self: @ContractState, user_address:felt252) -> u128 {
//            println!("entering: get_user_debt");
            let caller: ContractAddress = user_address.try_into().unwrap();
            let debt = self.user_debt.entry(caller).read();
//            println!("leaving: get_user_debt");
            debt
        }

        fn collect_debt(ref self: ContractState, user_address: felt252) {
            let user_address: ContractAddress = OptionTrait::unwrap(user_address.try_into());
            let caller = get_caller_address();
            if (caller != user_address) & (caller != get_contract_address()){
                assert(false, 'you are not allowed');
            }
            let debt = self.user_debt.entry(user_address).read();
            if debt <= 0 { assert(false,'user has no debt') }
            syscalls::call_contract_syscall(
               user_address,
               selector!("cancel_debt"),
               array![debt.try_into().unwrap()].span()
            ).unwrap_syscall();
            self.user_debt.entry(user_address).write(0);
//            println!("leaving: collect_debt");
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

        fn precompute_account_address(self: @ContractState , salt:felt252) -> ContractAddress {
            let hash_zero_array: felt252 = 2089986280348253421170679821480865132823066470938446095505822317253594081284;
            let struct_to_hash = StructForHash {
                prefix: 'STARKNET_CONTRACT_ADDRESS',
                deployer_address: get_contract_address().try_into().unwrap(),
                salt: salt,
                class_hash: self.sumo_account_class_hash.read(),
                constructor_calldata_hash: hash_zero_array,
            };
            let hash = struct_to_hash.hash();
            hash.try_into().unwrap()
        }

        fn only_protocol(self: @ContractState) {
            let sender = get_caller_address();
            assert(sender.is_zero(), 'Account: invalid caller');
            //println!("only_protocol [OK]");
        }

        fn validate_tx_version(self: @ContractState) {
            let tx_info = get_tx_info().unbox();
            let tx_version: u256 = tx_info.version.into();
            assert(tx_version >= 1_u256, 'Fail: Tx_version mismatch');
            //println!("validate_tx_version [OK]");
        }

        fn validate_tx_user_signature(self: @ContractState, eph_key:(felt252,felt252), r:felt252, s:felt252){
            let tx_info = get_tx_info().unbox();
            let tx_hash = tx_info.transaction_hash;
            let (eph_key_0, eph_key_1) = eph_key;
            let reconstructed_eph_key: felt252 = eph_key_0 * TWO_POWER_128 + eph_key_1;
            if !check_ecdsa_signature(tx_hash, reconstructed_eph_key, r, s) {
                assert(false,'Wrong Signature')
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
            assert(current_block_number <= masked_max_block,'Proof expired');
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
            assert(verified,'Garagant');
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
            assert(target_address == get_contract_address(), 'Not Allowed Outside Call');
            //println!("only_self [OK]");
        }

        fn validate_login_deploy_call(self: @ContractState, call:Call) {
            let signature = self.get_serialized_signature();

            self.validate_block_time(signature.max_block.into(),get_block_number());

            self.validate_oauth_modulus_F(signature.modulus_F);

            let all_inputs_hash_garaga = self.garaga_verify_get_public_inputs(signature.garaga);
            self.validate_all_inputs_hash(all_inputs_hash_garaga);

            let address_seed_masked = self.mask_address_seed(signature.address_seed);

            let target_address = self.precompute_account_address(address_seed_masked);

            if call.selector == selector!("deploy") {
                let is_user = self.user_list.entry(target_address).read();
                assert(!is_user, 'Allready an user');
                println!("Ready to deploy at: {:?}", target_address);
            }
            if call.selector == selector!("login"){
                let debt = self.user_debt.entry(target_address).read();
                assert(debt == 0, 'User has a debt');
                println!("Ready to login at: {:?}", target_address);
            }
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
        fn mask_address_seed( self: @ContractState, address_seed: u256 ) -> felt252 {
            let masked_address_seed: felt252 = (address_seed & MASK_250).try_into().unwrap();
            return masked_address_seed;
        }

        fn validate_oauth_modulus_F(self: @ContractState, modulus_f: u256) {
            assert(self.oauth_modulus_F.read() == modulus_f, 'Wrong Oauth Signature');
            //println!("validate_oauth_modulus [OK]")
        }

        fn validate_all_inputs_hash( self: @ContractState, all_inputs_hash: Span<u256>)  {
            let signature = self.get_serialized_signature();
            let (eph_0, eph_1) = signature.eph_key;

            let inputs: Array<u256> = array![
                        eph_0.into(),
                        eph_1.into(),
                        signature.address_seed.into(),
                        signature.max_block.into(),
                        signature.iss_b64_F.into(),
                        signature.iss_index_in_payload_mod_4.into(),
                        signature.header_F.into(),
                        signature.modulus_F.into()
                    ];

            let sha256_input = self.concatenate_inputs(inputs.span());
            let hash_result = compute_sha256_byte_array(@sha256_input);

            let left: u256 = *all_inputs_hash.at(0);
            let right: u256 = (*hash_result.span().at(0)).into();
            assert(left == right, 'Wrong All Inputs Hash' );
            //println!("validate_all_inputs_hash [OK]");
        }

        fn concatenate_inputs(self: @ContractState, inputs: Span<u256>) -> ByteArray {
            let mut byte_array = Default::default();
            let mut index = 0_u32;
            while index < inputs.len() {
                let int_value: u256 = *inputs.at(index);
                byte_array.append_word(int_value.high.into(), 16);
                byte_array.append_word(int_value.low.into(), 16);
                index += 1;
            };
            byte_array
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
