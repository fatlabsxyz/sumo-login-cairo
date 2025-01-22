use core::starknet::{ ContractAddress , account::Call };

#[starknet::interface]
pub trait ILogin<TContractState> {
    fn is_valid_signature(self: @TContractState, msg_hash: felt252, signature: Array<felt252>) -> felt252;
    fn __validate__(self: @TContractState, calls: Span<Call>) -> felt252 ;
    fn __execute__(ref self: TContractState, calls: Span<Call>) -> Array<Span<felt252>> ;
    fn __validate_declare__(ref self: TContractState, declared_class_hash: felt252) -> felt252;

    fn is_sumo_user(self: @TContractState, user_address: ContractAddress) -> bool;
    fn update_oauth_public_key(ref self: TContractState);
    fn get_user_debt(self: @TContractState, user_address: ContractAddress) -> u128;
    fn collect_debt(ref self: TContractState, user_address: ContractAddress);

    //user entrypoint
    fn deploy(ref self: TContractState) -> ContractAddress ;
    fn login(ref self: TContractState) ;
}

#[starknet::contract(account)]
pub mod Login {
    use core::starknet::{
        syscalls,
        SyscallResultTrait,
        ContractAddress,
        ClassHash,
        VALIDATED,
        get_tx_info,
        get_block_number,
        get_caller_address,
        get_contract_address,
        account::Call,
        storage::StoragePointerReadAccess,
        storage::StoragePointerWriteAccess,
        storage::StoragePathEntry,
        storage::Map
    };
    use crate::utils::utils::{
        validate_all_inputs_hash,
        mask_address_seed,
        precompute_account_address,
        oracle_check,
        get_gas_price,
    };
    use crate::utils::{
        execute::execute_calls,
        errors::LoginErrors,
        structs::StructForHashImpl,
        structs::PublicInputImpl,
        structs::Signature,
        constants::TWO_POWER_128,
        constants::LOGIN_FEE_GAS,
        constants::DEPLOY_FEE_GAS,
        constants::GARAGA_VERIFY_CLASSHASH,
    };
    use core::num::traits::{ Zero };
    use core::ecdsa::{ check_ecdsa_signature };

    const USER_ENDPOINTS : [felt252;2] = [selector!("deploy"), selector!("login")];

    #[storage]
    struct Storage {
        public_key: felt252,
        sumo_account_class_hash: felt252,
        user_debt: Map<ContractAddress, u128>,
        user_list: Map<ContractAddress, bool>,
        oauth_modulus_F: u256,
    }

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    pub enum Event {
        DeployAccount: DeployAccount,
        LoginAccount: LoginAccount,
        ModulusUptdated: ModulusUptdated,
        DebtCollected: DebtCollected
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct DeployAccount {
        pub address: ContractAddress,
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct LoginAccount {
        pub address: ContractAddress,
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct ModulusUptdated{
        pub modulus: u256,
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct DebtCollected {
        pub address: ContractAddress,
        pub ammount: u128
    }

    #[constructor]
    /// Initializes this contract.
    ///
    /// The deployer has to provide:
    /// - The class hash of the sumo Account contract.
    /// - The public key of this account.
    fn constructor(ref self: ContractState, sumo_account_class_hash: felt252, public_key: felt252) {
        self.public_key.write(public_key);
        self.sumo_account_class_hash.write(sumo_account_class_hash);
        self.update_oauth_public_key();
    }

    #[abi(embed_v0)]
    impl LoginImpl of super::ILogin<ContractState> {
        //TODO: Sacar esto si no se va a declarar ningun contrato
        fn __validate_declare__(ref self: ContractState, declared_class_hash: felt252) -> felt252 {
            VALIDATED
        }

        /// Verifies that the signature of the transaction is valid.
        ///
        /// There are two signature types that are valid. The first felt of each signature is ussed to classify them in:
        /// - Admin signature: Is the signature associated to the owner of this account. It is the ussual ECDSA. 
        /// - User signature: Is the signature associated to an user that pretends to deploy or login
        ///   to his/her sumo account. It is a span of felts necesary for the validation of the ZK proof.
        ///
        /// User transactions can only call the Deploy/Login methods of this account while Admin transaction are 
        /// normal transaction with the exception that cannot call the Deploy/Login methods of this account.
        fn __validate__(self: @ContractState, calls: Span<Call>) -> felt252 {
            self.only_protocol();
            self.validate_tx_version();

            let tx = get_tx_info().unbox();
            let mut signer = tx.signature;

            if *signer.at(0) == selector!("signature/user") {
                let signature = self.get_serialized_signature();
                assert(calls.len() == 1, LoginErrors::MULTICALLS);
                let call = calls[0];
                self.only_self_call(*call);
                assert(self.is_user_entrypoint(*call.selector) , LoginErrors::SELECTOR_NOT_ALLOWED);
                self.validate_tx_user_signature(signature.eph_key, signature.r, signature.s);
                self.validate_login_deploy_call(*call);

            } else if *signer.at(0) == selector!("signature/admin") {
                let r = *signer.at(1);
                let s = *signer.at(2);
                self.validate_tx_admin_signature(r, s);
                for call in calls {
                    //admin cannot call login/deploy selector with his key
                    assert(!self.is_user_entrypoint(*call.selector), LoginErrors::SELECTOR_NOT_ALLOWED)
                }
            } else {
                assert(false, LoginErrors::INVALID_SIGNATURE_TYPE);
            };
            VALIDATED
        }

        /// Executes a list of calls from the account.
        ///
        /// - The transaction version must be greater than or equal to 1.
        /// - The function ins only accesible by the protocol.
        fn __execute__(ref self: ContractState, mut calls: Span<Call>) -> Array<Span<felt252>> {
            self.only_protocol();
            self.validate_tx_version();
            execute_calls(calls)
        }
        
        /// Verifies if a given address is a sumo account deployed by this Login account.
        fn is_sumo_user(self: @ContractState, user_address: ContractAddress) -> bool {
            self.user_list.entry(user_address).read()
        }

        /// Executes the Log In of the usser
        ///
        /// This function can olny be reach by an usser with a valid ZK proof with a previous debt free sumo 
        /// Account. The function changes user's public key (and expiration time) to the new one given
        /// in the transaction.
        ///
        /// Emits LoginAccount event
        fn login(ref self:ContractState) {
            //to reach this function the user has to have no debt. Otherwise it is rejected in the 
            //validate. We cannot check in the validate if he has a way to pay for the login in the validate.
            //If he has a way to pay, collect_debt will succeed. If not, he will have a new debt a he will not
            //be abble to use login if he does not pays his debt before.
            let signature = self.get_serialized_signature();
            let (eph_key_0,eph_key_1) = signature.eph_key;
            let reconstructed_eph_key: felt252 = eph_key_0 * TWO_POWER_128 + eph_key_1;
            let expiration_block:u64 = signature.max_block.try_into().unwrap();

            let user_address: ContractAddress = self.get_target_address(signature.address_seed);

            self.set_user_pkey(user_address, reconstructed_eph_key, expiration_block);
            self.add_debt(user_address,LOGIN_FEE_GAS);
            self.emit(LoginAccount { address : user_address });
            //TODO: que hacer con esto? si ponemos el collect la transaccion puede tirar error por saldo insuficiente
            // pero al usuario se le cambio la pkey
            //self.collect_debt(user_address);
        }

        /// Deploys a new sumo Account with the data given in the ZK proof.
        ///
        /// This function can olny be reach by an usser with a valid ZK proof without a previous sumo Account.
        /// After deploy, sets the public key (and expiration time) to given in the transaction.
        /// Emits DeployAccount event
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
            assert(precomputed_address == address, LoginErrors::PRECOMP_ADDRESS_FAIL);
            self.user_list.entry(address).write(true);

            let (eph_key_0,eph_key_1) = signature.eph_key;
            let reconstructed_eph_key: felt252 = eph_key_0 * TWO_POWER_128 + eph_key_1;
            let expiration_block:u64 = signature.max_block.try_into().unwrap();
            self.set_user_pkey(address, reconstructed_eph_key ,expiration_block);
            self.add_debt(address,DEPLOY_FEE_GAS);
//            println!("Deployed address {:?}", address);
            self.emit(DeployAccount { address : address });
            address
        }


        /// Verifies that the given signature is valid for the given hash and the secret key paired whit
        /// the public key of this account.
        fn is_valid_signature(
            self: @ContractState, msg_hash: felt252, signature: Array<felt252>) -> felt252 {
            let public_key = self.public_key.read();
            if check_ecdsa_signature(msg_hash, public_key, *signature.at(0_u32), *signature.at(1_u32)) {
                VALIDATED
            } else {
                0
            }
        }

        /// Recovers the debt of the given address.
        fn get_user_debt(self: @ContractState, user_address:ContractAddress) -> u128 {
            self.user_debt.entry(user_address).read()
        }

        /// Makes the given sumo account to pay its debt if posible.
        ///
        /// This function can be called by:
        /// - The owner the given account, each time it tries to execute a transaction.
        ///   This enforces that the account will pay its debt as soon as posible.
        /// - The owner of this sumo Login account. 
        ///
        /// Emits DebtCollected event
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
            self.emit( DebtCollected { address : user_address , ammount : debt})
        }

        /// Updates the stored public key of the OAuth provider.
        ///
        /// Emits LoginAccount event
        fn  update_oauth_public_key(ref self: ContractState) {
            let old_key = self.oauth_modulus_F.read();
            let new_key = oracle_check();
            if old_key != new_key {
                self.emit( ModulusUptdated { modulus : new_key });
                self.oauth_modulus_F.write(new_key)
            }
        }
    }

    #[generate_trait]
    pub impl PrivateImpl of IPrivate {
        /// Adds a debt to the given contract address. 
        ///
        /// This occurs in two ocations:
        /// - When deploying a new account DEPLOY_FEE is added as debt to that account.
        /// - When updating the publick key a pre-existing user.
        /// In both of these situations the user has to provide a valid ZK proof of his/her identity.
        fn add_debt(ref self: ContractState, address: ContractAddress, value: u128) {
            let gas_price = get_gas_price();
            let current_debt: u128 = self.user_debt.entry(address).read();
            self.user_debt.entry(address).write(current_debt + value * gas_price);
        }

        ///Verifies that the caller address is zero. i.e. the caller is the protocol.
        fn only_protocol(self: @ContractState) {
            let sender = get_caller_address();
            assert(sender.is_zero(), LoginErrors::INVALID_CALLER);
            //println!("only_protocol [OK]");
        }

        /// Verifies that the transaction version is at least 1.
        fn validate_tx_version(self: @ContractState) {
            let tx_info = get_tx_info().unbox();
            let tx_version: u256 = tx_info.version.into();
            assert(tx_version >= 1_u256, LoginErrors::INVALID_TX_VERSION);
            //println!("validate_tx_version [OK]");
        }

        /// Verifies that the incoming transaction is signed by the private key paired with the public key
        /// that is part of the ZK proof.
        ///
        /// As part of the sumo ZK protocol the user generates a pair (pk,sk). The transaction Deploy/Login
        /// is signed by the newly generated secret key and the public key is send in the transaction.
        fn validate_tx_user_signature(self: @ContractState, eph_key:(felt252,felt252), r:felt252, s:felt252){
            let tx_info = get_tx_info().unbox();
            let tx_hash = tx_info.transaction_hash;
            let (eph_key_0, eph_key_1) = eph_key;
            let reconstructed_eph_key: felt252 = eph_key_0 * TWO_POWER_128 + eph_key_1;
            if !check_ecdsa_signature(tx_hash, reconstructed_eph_key, r, s) {
                assert(false, LoginErrors::INVALID_USER_SIGNATURE)
            }
        }

        /// Verifies that the incoming transaction is signed by the private key of this account.
        fn validate_tx_admin_signature(self: @ContractState, r:felt252, s:felt252){
            let tx_info = get_tx_info().unbox();
            let tx_hash = tx_info.transaction_hash;
            let rs:Array<felt252> = array![r,s];
            assert(self.is_valid_signature(tx_hash,rs) == VALIDATED, LoginErrors::INVALID_ADMING_SIGNATURE);
        }

        /// Updates the publick (and its expiration block) stored in the given account address.
        fn set_user_pkey(self: @ContractState, user_address: ContractAddress, eph_pkey: felt252, expiration_block:u64) {
            let calldata : Array<felt252> = array![eph_pkey, expiration_block.try_into().unwrap()];
                syscalls::call_contract_syscall(
                   user_address,
                   selector!("change_pkey"),
                   calldata.span()
                ).unwrap_syscall();
        }

        /// Verifies that the ZK proof is not expired.
        fn validate_block_time(
            self: @ContractState, max_block: u256, current_block_number: u64
        ) -> felt252 {
            let masked_max_block: u64 = max_block.try_into().unwrap();
            assert(current_block_number <= masked_max_block, LoginErrors::EXPIRED_PROOF);
            VALIDATED
        }

        /// Verifies that the ZK proof is valid and recovers the public inputs bounded to the proof.
        fn garaga_verify_get_public_inputs(self: @ContractState, calldata: Span<felt252>) ->  Span<u256> {
            let mut _res = syscalls::library_call_syscall(
                GARAGA_VERIFY_CLASSHASH.try_into().unwrap(),
                selector!("verify_groth16_proof_bn254"),
                calldata
            )
                .unwrap_syscall();
            let (verified, res) = Serde::<(bool, Span<u256>)>::deserialize(ref _res).unwrap();
            assert(verified, LoginErrors::INVALID_PROOF);
            return res;
        }

        /// Verifies that the target of the call is this account
        ///
        /// As we need to allow user with a valid ZK proof to use the entry points Deploy or Login while they
        /// are impersonating us, we have to block them to call Deploy/Login functions of another contracts.
        fn only_self_call(self: @ContractState, call: Call) {
            let target_address: ContractAddress = call.to;
            assert(target_address == get_contract_address(), LoginErrors::OUTSIDE_CALL);
        }

        /// Verifies that ZK proof for the Deploy/Login transaction is valid.
        ///
        /// It has to verify:
        /// - The proof is not expired.
        /// - The proof is signed by a valid OAuth provider.
        /// - The ZK proof itself is valid.
        /// - The newly generated public key is part of the proof.
        /// The validation fails if the user has a previous debt.
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
//            println!("Ready to deploy/login at: {:?}", target_address);
        }

        /// Verifies that the user is trying to access to the allowed entry points.
        //TODO: Ver si se puede remover eso ya que solo hay 2 entrypoints
        fn is_user_entrypoint(self:@ContractState, selector: felt252) -> bool {
            let mut is_contained: bool = false;
            for entry_point in USER_ENDPOINTS.span() {
                if selector == *entry_point {
                    is_contained = true;
                }
            };
            return is_contained;
        }

        /// Serializes the Deploy/Login signature.
        fn get_serialized_signature(self:@ContractState) -> Signature {
            let tx = get_tx_info().unbox();
            let mut signer = tx.signature;
            //TODO: handle the error that might occur if the  signature is incomplete.
            //otherwise it will throw 'unwraped failed' which is a really confussing error.
            let signature: Signature = Serde::<Signature>::deserialize(ref signer).unwrap();
            return signature;
        }

        /// Verifies that the given modulus_F is the same as the stored one.
        fn validate_oauth_modulus_F(self: @ContractState, modulus_f: u256) {
            assert(self.oauth_modulus_F.read() == modulus_f, LoginErrors::INVALID_OAUTH_SIGNATURE);
        }

        /// Computed the final account_address for the given address_seed
        fn get_target_address(self: @ContractState, address_seed: u256) -> ContractAddress {
            let login_address = get_contract_address();
            let account_class = self.sumo_account_class_hash.read();
            precompute_account_address(login_address, account_class, address_seed)
        }
    }
}


