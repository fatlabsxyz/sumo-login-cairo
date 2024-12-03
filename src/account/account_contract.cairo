use core::starknet::{ContractAddress};
use starknet::account::Call;

#[starknet::interface]
pub trait ExternalTrait<TContractState> {
    //standar interface
    fn is_valid_signature(self: @TContractState, msg_hash: felt252, signature: Array<felt252>) -> felt252;
    fn __validate__(self: @TContractState, calls: Span<Call>) -> felt252 ;
    fn __execute__(ref self: TContractState, calls: Span<Call>) -> Array<Span<felt252>> ;

    //required by sumo
    fn change_pkey(ref self: TContractState, new_key: felt252, expiration_block:felt252);
    fn get_my_debt(self: @TContractState) -> u64;
    fn cancel_debt(self: @TContractState, amount:felt252);

    //for testing
    fn get_pkey(self: @TContractState) -> felt252;
    fn get_deployer_address(self: @TContractState) -> ContractAddress;
}

#[starknet::contract(account)]
pub mod Account {
    const ETH_ADDRRESS: felt252= 0x49D36570D4E46F48E99674BD3FCC84644DDD6B96F7C741B1562B82F9E004DC7;
    use core::ecdsa::check_ecdsa_signature;
    use core::starknet::{syscalls,SyscallResultTrait};
    use core::starknet::{ContractAddress};
    use core::starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use core::starknet::{get_caller_address, get_tx_info, VALIDATED, get_contract_address, get_block_number};
    use core::num::traits::Zero;
    use starknet::account::Call;
    use crate::utils::execute::execute_calls;

    #[storage]
    struct Storage {
        public_key: felt252,
        deployer_address: ContractAddress,
        expiration_block: u64,
    }

    #[constructor]
    fn constructor(ref self: ContractState) -> ContractAddress {
//        println!("entering: constructor");
        //Might be the universal deployer address if deploy is made with a DEPLOY_ACCOUNT transaction
        //If the deploy is made with an INVOKE transaction the caller addres is the sumo_Login address.
        //Si se cambian la cantidad de argumentos del constructor recordar que el hash finaliza con hash(cantidad),
        //ir a cambiarlo
        let deployer_address = get_caller_address();
        self.deployer_address.write(deployer_address);
        //Esto va a cambiar
//        println!("leaving: constructor");
        deployer_address
    }

    #[abi(embed_v0)]
    impl ExternalImpl of super::ExternalTrait<ContractState> {
        fn is_valid_signature(
            self: @ContractState, msg_hash: felt252, signature: Array<felt252>) -> felt252 {
            let public_key = self.public_key.read();
            if check_ecdsa_signature(msg_hash, public_key, *signature.at(0_u32), *signature.at(1_u32)) {
                VALIDATED
            } else {
                0
            }
        }

        fn change_pkey(ref self: ContractState, new_key: felt252, expiration_block:felt252) {
//            println!("entering change_pkey");
            let caller = get_caller_address();
            if caller == get_contract_address() {
                self.public_key.write(new_key);
                self.expiration_block.write(expiration_block.try_into().unwrap());
            } else if caller == self.deployer_address.read() {
                self.public_key.write(new_key);
                self.expiration_block.write(expiration_block.try_into().unwrap());
            } else {
                assert(false, 'Not allowed to set pkey');
            }
//            println!("leaving: change_pkey");
        }


        fn get_pkey(self: @ContractState) -> felt252 {
            self.public_key.read()
        }

        fn get_deployer_address(self: @ContractState) -> ContractAddress {
            self.deployer_address.read()
        }

        fn __validate__(self: @ContractState, calls: Span<Call>) -> felt252 {
            self.only_protocol();
            self.validate_tx_version();
            self.validate_tx_signature();
            self.validate_block_time();
            VALIDATED
        }

        fn __execute__(ref self: ContractState, mut calls: Span<Call>) -> Array<Span<felt252>> {
            self.only_protocol();
            self.validate_tx_version();
            self.pay_debt();
            execute_calls(calls)
        }

        fn get_my_debt(self: @ContractState) -> u64 {
//            println!("entering: get_my_debt");
            let to = self.deployer_address.read();
            let res = syscalls::call_contract_syscall(
               to,
               selector!("get_user_debt"),
               array![get_contract_address().into()].span()
            ).unwrap_syscall();
            let debt:u64 = (*res.at(0)).try_into().unwrap();
//            println!("leaving: get_my_debt");
            debt
        }

        fn cancel_debt(self: @ContractState, amount:felt252) {
//            println!("entering: cancel_debt");
            let amount:u256 = OptionTrait::unwrap(amount.try_into());
            let low:felt252 = amount.low.into();
            let high:felt252 = amount.high.into();
            assert(get_caller_address() == self.deployer_address.read(), 'Login addres fail ');
            let sumo_address = self.deployer_address.read();
            //TODO: checkear que tengas plata antes
            let calldata:Array<felt252> = array![sumo_address.into(), low, high];
            syscalls::call_contract_syscall(
               ETH_ADDRRESS.try_into().unwrap(),
               selector!("transfer"),
               calldata.span()
            ).unwrap_syscall();
//            println!("leaving: cancel_debt");
        }
    }


    #[generate_trait]
    impl PrivateImpl of IPrivate {
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

        fn validate_block_time(self: @ContractState) {
            let max_block = self.expiration_block.read();
            if max_block != 0 {
                let current = get_block_number();
                assert(max_block > current, 'Expirated Login')
            }
        }


        fn pay_debt(self: @ContractState) {
            let debt = self.get_my_debt();
            if debt > 0 {
                //TODO: checkear que tengas plata antes
                syscalls::call_contract_syscall(
                    self.deployer_address.read(),
                    selector!("collect_debt"),
                    array![get_contract_address().into()].span()
                ).unwrap_syscall();
            }
        }
    }
}
