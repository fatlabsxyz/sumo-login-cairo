use starknet::account::Call;

#[starknet::interface]
pub trait IAccount<TContractState> {
    //SRC6 interface
    fn is_valid_signature(self: @TContractState, msg_hash: felt252, signature: Array<felt252>) -> felt252;
    fn __validate__(self: @TContractState, calls: Span<Call>) -> felt252 ;
    fn __execute__(ref self: TContractState, calls: Span<Call>) -> Array<Span<felt252>> ;

    //SUMO interface
    fn change_pkey(ref self: TContractState, new_key: felt252, expiration_block:felt252);
    fn pay(ref self: TContractState);
}

#[starknet::contract(account)]
pub mod Account {
    use core::starknet::{
        syscalls,
        SyscallResultTrait,
        ContractAddress,
        VALIDATED,
        get_tx_info,
        get_block_number,
        get_caller_address,
        get_contract_address,
        account::Call,
        storage::StoragePointerReadAccess,
        storage::StoragePointerWriteAccess,
    };
    use crate::utils::{
        errors::AccountErrors,
        execute::execute_calls,
        constants::STRK_ADDRESS,
        utils::user_can_repay,
    };
    use core::num::traits::{ Zero };
    use core::ecdsa::{ check_ecdsa_signature };

    #[storage]
    struct Storage {
        deployer_address: ContractAddress,
        public_key: felt252,
        expiration_block: u64,
    }

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    pub enum Event {
        PKeyChanged: PKeyChanged,
        DebtPayed: DebtPayed,
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct PKeyChanged {
        pub new_key: felt252,
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct DebtPayed{
        pub ammount: u128,
        pub to: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        //Might be the universal deployer address if deploy is made with a DEPLOY_ACCOUNT transaction
        //If the deploy is made with an INVOKE transaction the caller addres is the sumo_Login address.
        //Si se cambian la cantidad de argumentos del constructor recordar que el hash finaliza con hash(cantidad),
        //ir a cambiarlo
        let deployer_address = get_caller_address();
        self.deployer_address.write(deployer_address);
    }

    #[abi(embed_v0)]
    impl AccountImpl of super::IAccount<ContractState> {

        /// Verifies that the given signature is valid for the given hash and the secret key paired whit
        /// the public key of this account.
        fn is_valid_signature(
            self: @ContractState, msg_hash: felt252, signature: Array<felt252>) -> felt252 {
            let public_key = self.public_key.read();
            if check_ecdsa_signature(msg_hash, public_key, *signature.at(0_u32), *signature.at(1_u32)) {
                VALIDATED
            } else { 0 }
        }

        /// Verifies the validity of the signature for the current transaction.
        /// This function is used by the protocol to verify `invoke` transactions.
        fn __validate__(self: @ContractState, calls: Span<Call>) -> felt252 {
            self.only_protocol();
            self.validate_block_time();
            self.validate_tx_signature();
            VALIDATED
        }

        /// Executes a list of calls from the account.
        ///
        /// - The transaction version must be greater than or equal to 1.
        /// - The function ins only accesible by the protocol.
        /// - The fuctions first tries to pay its debts and then proceeds to execute the calls.
        fn __execute__(ref self: ContractState, mut calls: Span<Call>) -> Array<Span<felt252>> {
            self.only_protocol();
            self.validate_tx_version();
            self.call_for_collect();
            execute_calls(calls)
        }

        /// Changes the public key and the expiration of this account public key.
        ///
        /// It can be called by:
        /// - This account if the owner has posetion of the private key.
        /// - The sumo Login account after the user verifies the ZK proof.
        ///
        /// Emits PkeyChanged event.
        fn change_pkey(ref self: ContractState, new_key: felt252, expiration_block: felt252) {
            let caller = get_caller_address();
            if (caller == get_contract_address()) | (caller == self.deployer_address.read()) {
                self.public_key.write(new_key);
                self.expiration_block.write(expiration_block.try_into().unwrap());
                self.emit( PKeyChanged {new_key : new_key })
            } else {
                assert(false, AccountErrors::NOT_ALLOWED);
            }
        }

        /// Pays the debt (if exists) to the sumo Login account.
        ///
        /// The pay is made by a "transfer" transaction to the Login account of the erc20 STRK_ADDRESS
        /// If this account cannot pay its debt it cannot execute another transaction.
        ///
        /// Emits DebtPayed event.
        fn pay(ref self: ContractState) {
            let caller = get_caller_address();
            if caller != self.deployer_address.read() {  assert(false, AccountErrors::INVALID_DEPLOYER) }
            let debt: u128 = self.get_my_debt();

            if !user_can_repay(get_contract_address(), debt) { assert(false, AccountErrors::NOT_ENOGHT_MONEY) } 

            let amount : u256 = debt.into();

            let calldata = array![
                caller.into(),
                amount.low.into(),
                amount.high.into(),];
            syscalls::call_contract_syscall(
               STRK_ADDRESS.try_into().unwrap(),
               selector!("transfer"),
               calldata.span()
            ).unwrap_syscall();
            //TODO: return payed_amount. This way Login Contract can store how much of the debt was payed.

            self.emit( DebtPayed { to : caller , ammount : debt })
        }
    }

    #[generate_trait]
    pub impl PrivateImpl of IPrivate {
        ///Verifies that the caller address is zero. i.e. the caller is the protocol.
        fn only_protocol(self: @ContractState) {
              let sender = get_caller_address();
              assert(sender.is_zero(), AccountErrors::INVALID_CALLER);
        }

        /// Verifies that the transaction version is at least 1.
        fn validate_tx_version(self: @ContractState) {
            let tx_info = get_tx_info().unbox();
            let tx_version: u256 = tx_info.version.into();
            assert(tx_version >= 1_u256, AccountErrors::INVALID_TX_VERSION);
        }

        /// Verifies that the incoming transaction is signed by the private key of this account.
        fn validate_tx_signature(self: @ContractState){
            let tx_info = get_tx_info().unbox();
            let signature = tx_info.signature;
            let tx_hash = tx_info.transaction_hash;
            assert(self.is_valid_signature(tx_hash, signature.into()) == VALIDATED, AccountErrors::INVALID_SIGNATURE);
        }

        /// Verifies that the current block time is less that the block time of expiration set by the owner
        fn validate_block_time(self: @ContractState) {
            let max_block = self.expiration_block.read();
            if max_block != 0 {
                let current = get_block_number();
                assert(current < max_block, AccountErrors::EXPIRATED_SESSION)
            }
        }

        /// Calls for Login account to start the process of debt cancellation.
        fn call_for_collect(self: @ContractState) {
            syscalls::call_contract_syscall(
               self.deployer_address.read(),
               selector!("collect_debt"),
               array![get_contract_address().into()].span()
            ).unwrap_syscall();
        }

        /// Ask for the current debt of this account to the Login account.
        fn get_my_debt(ref self: ContractState) -> u128 {
            let to = self.deployer_address.read();
            let res = syscalls::call_contract_syscall(
               to,
               selector!("get_user_debt"),
               array![get_contract_address().into()].span()
            ).unwrap_syscall();
            let debt: u128 = (*res.at(0)).try_into().unwrap();
            return debt;
        }
    }
}
