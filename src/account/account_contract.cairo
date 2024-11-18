use core::starknet::{ContractAddress};
use starknet::account::Call;


#[starknet::interface]
trait ExternalTrait<TContractState> {
    //standar interface
    fn is_valid_signature(self: @TContractState, msg_hash: felt252, signature: Array<felt252>) -> felt252;
    fn __validate__(self: @TContractState, calls: Span<Call>) -> felt252 ;
    fn __execute__(ref self: TContractState, calls: Span<Call>) -> Array<Span<felt252>> ;

    //required by sumo
    fn change_pkey(ref self: TContractState, new_key: felt252);
    //Podemos poner una funciona saldar_deuda que haga un transfer y solo se pueda llamar desde la cuenta que deployeo a esta.
    //Suena medio cuckeado de todas formas. Si hacemos eso desde el lado del logion podemos tener una funcion que sea
    //colect_all_debts.

    //for testing
    fn get_pkey(self: @TContractState) -> felt252;
    fn get_deployer_address(self: @TContractState) -> ContractAddress;
}

#[starknet::contract(account)]
mod Account {
    const DEPLOY_FEE: u64 = 1_000_000;
    const LOGIN_FEE: u64 = 1_000_000;
    const ETH_ADDRRESS: felt252= 0x49D36570D4E46F48E99674BD3FCC84644DDD6B96F7C741B1562B82F9E004DC7;
    use core::ecdsa::check_ecdsa_signature;
    use core::starknet::{syscalls,SyscallResultTrait};
    use core::starknet::{ContractAddress};
    use core::starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use core::starknet::{get_caller_address, get_tx_info, VALIDATED};
    use core::num::traits::Zero;
    use starknet::account::Call;

    #[storage]
    struct Storage {
        public_key: felt252,
        deployer_address: ContractAddress,
        sumo_debt: u64,
    }

    #[constructor]
    fn constructor(ref self: ContractState, arg1:felt252, arg2:felt252) -> ContractAddress {
        //Might be the universal deployer address if deploy is made with a DEPLOY_ACCOUNT transaction
        //If the deploy is made with an INVOKE transaction the caller addres is the sumo_Login address.
        //Si se cambian la cantidad de argumentos del constructor recordar que el hash finaliza con hash(cantidad),
        //andar a cambiarlo
        let deployer_address = get_caller_address();
        self.deployer_address.write(deployer_address);
        self.sumo_debt.write(DEPLOY_FEE);
        //Esto va a cambiar
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

        fn change_pkey(ref self: ContractState, new_key: felt252) {
            assert(get_caller_address() == self.deployer_address.read(), 'Login addres fail ');
            self.public_key.write(new_key);
            let previous_debt = self.sumo_debt.read();
            self.sumo_debt.write(previous_debt + LOGIN_FEE);
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
            VALIDATED
        }

        fn __execute__(ref self: ContractState, mut calls: Span<Call>) -> Array<Span<felt252>> {
            self.only_protocol();
            self.validate_tx_version();
            self.pay_debt();
            self.execute_calls(calls)
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

        fn validate_tx_signature(self: @ContractState){
            let tx_info = get_tx_info().unbox();
            let signature = tx_info.signature;
            let tx_hash = tx_info.transaction_hash;
            assert(self.is_valid_signature(tx_hash,signature.into())==VALIDATED, 'Wrong: Signature');
        }

        fn pay_debt(ref self: ContractState) {
            let debt = self.sumo_debt.read();
            if debt > 0 {
                let ammount: felt252 = debt.try_into().unwrap();
                let sumo_address = self.deployer_address.read();
                //TODO: Pasar debt (u256) to 2 felt252
                let calldata:Array<felt252> = array![sumo_address.into(), ammount];
                //transfer to sumo the debt
                syscalls::call_contract_syscall(
                   ETH_ADDRRESS.try_into().unwrap(),
                   selector!("transfer"),
                   calldata.span()
                ).unwrap_syscall();
                //TODO: if transfer succeded
                self.sumo_debt.write(0)
            }
        }
    }
}
