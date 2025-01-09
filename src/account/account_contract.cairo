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
    use core::ecdsa::check_ecdsa_signature;
    use core::starknet::{syscalls,SyscallResultTrait};
    use core::starknet::{ContractAddress};
    use core::starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use core::starknet::{get_caller_address, get_tx_info, VALIDATED, get_contract_address, get_block_number};
    use core::array::{ArrayTrait};
    use core::num::traits::Zero;
    use starknet::account::Call;
    use crate::utils::execute::execute_calls;
    use crate::utils::errors::AccountErrors;
    use crate::utils::constants::STRK_ADDRESS;

    #[storage]
    struct Storage {
        deployer_address: ContractAddress,
        public_key: felt252,
        expiration_block: u64,
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
        fn is_valid_signature(
            self: @ContractState, msg_hash: felt252, signature: Array<felt252>) -> felt252 {
            let public_key = self.public_key.read();
            if check_ecdsa_signature(msg_hash, public_key, *signature.at(0_u32), *signature.at(1_u32)) {
                VALIDATED
            } else {
                0
            }
        }

        fn __validate__(self: @ContractState, calls: Span<Call>) -> felt252 {
            self.only_protocol();
            self.validate_block_time();
            self.validate_tx_signature();
            VALIDATED
        }

        fn __execute__(ref self: ContractState, mut calls: Span<Call>) -> Array<Span<felt252>> {
            self.only_protocol();
            self.validate_tx_version();
            self.call_for_collect();
            execute_calls(calls)
        }

        fn change_pkey(ref self: ContractState, new_key: felt252, expiration_block: felt252) {
            let caller = get_caller_address();
            if (caller == get_contract_address()) | (caller == self.deployer_address.read()) {
                self.public_key.write(new_key);
                self.expiration_block.write(expiration_block.try_into().unwrap());
            } else {
                assert(false, AccountErrors::NOT_ALLOWED);
            }
        }

        fn pay(ref self: ContractState) {
            let caller = get_caller_address();
            if caller != self.deployer_address.read() {  assert(false, AccountErrors::INVALID_DEPLOYER) }

            let debt: u256 = self.get_my_debt();
            let balance  = self.get_my_balance();

            if balance < 2*debt { assert(false, AccountErrors::NOT_ENOGHT_MONEY) } 

            let calldata = array![
                caller.into(),
                debt.low.into(),
                debt.high.into(),];
            syscalls::call_contract_syscall(
               STRK_ADDRESS.try_into().unwrap(),
               selector!("transfer"),
               calldata.span()
            ).unwrap_syscall();
            //TODO: return payed_amount. This way Login Contract can store how much of the debt was payed.
        }
    }

    #[generate_trait]
    pub impl PrivateImpl of IPrivate {
        fn only_protocol(self: @ContractState) {
              let sender = get_caller_address();
              assert(sender.is_zero(), AccountErrors::INVALID_CALLER);
        }

        fn validate_tx_version(self: @ContractState) {
            let tx_info = get_tx_info().unbox();
            let tx_version: u256 = tx_info.version.into();
            assert(tx_version >= 1_u256, AccountErrors::INVALID_TX_VERSION);
        }

        fn validate_tx_signature(self: @ContractState){
            let tx_info = get_tx_info().unbox();
            let signature = tx_info.signature;
            let tx_hash = tx_info.transaction_hash;
            assert(self.is_valid_signature(tx_hash, signature.into()) == VALIDATED, AccountErrors::INVALID_SIGNATURE);
        }

        fn validate_block_time(self: @ContractState) {
            let max_block = self.expiration_block.read();
            if max_block != 0 {
                let current = get_block_number();
                assert(current < max_block, AccountErrors::EXPIRATED_SESSION)
            }
        }

        fn call_for_collect(self: @ContractState) {
            syscalls::call_contract_syscall(
               self.deployer_address.read(),
               selector!("collect_debt"),
               array![get_contract_address().into()].span()
            ).unwrap_syscall();
        }

        fn get_my_debt(ref self: ContractState) -> u256 {
            let to = self.deployer_address.read();
            let res = syscalls::call_contract_syscall(
               to,
               selector!("get_user_debt"),
               array![get_contract_address().into()].span()
            ).unwrap_syscall();
            let amount: u128 = (*res.at(0)).try_into().unwrap();
            let debt: u256 = amount.into();
            return debt;
        }

        fn get_my_balance(self: @ContractState) -> u256 {
            let response = syscalls::call_contract_syscall(
               STRK_ADDRESS.try_into().unwrap(),
               selector!("balance_of"),
               array![get_contract_address().into()].span(),
            ).unwrap_syscall();

            let low: u128 = (*response[0]).try_into().unwrap();
            let high: u128 = (*response[1]).try_into().unwrap();
            let amount = u256{ low , high }; 
            return amount;
        }
    }
}
