use core::starknet::{ContractAddress};

#[starknet::interface]
pub trait IAccount<TContractState> {
    fn increase_balance(ref self: TContractState, amount: felt252);
    fn get_balance(self: @TContractState) -> felt252;
    fn change_pkey(ref self: TContractState, new_key: felt252);
    fn get_pkey(self: @TContractState) -> felt252;
    fn get_login_address(self: @TContractState) -> ContractAddress;
}

#[starknet::contract]
mod Account {
    use core::starknet::{ContractAddress};
    use core::starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use core::starknet::get_caller_address;

    #[storage]
    struct Storage {
        balance: felt252,
        pkey: felt252,
        login_address: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, arg1:felt252, arg2:felt252) -> ContractAddress {
        let login_address = get_caller_address();
        self.login_address.write(login_address);
        login_address
    }

    #[abi(embed_v0)]
    impl AccountImpl of super::IAccount<ContractState> {
        fn increase_balance(ref self: ContractState, amount: felt252) {
            assert(amount != 0, 'Amount cannot be 0');
            self.balance.write(self.balance.read() + amount);
        }

        fn get_balance(self: @ContractState) -> felt252 {
            self.balance.read()
        }

        fn change_pkey(ref self: ContractState, new_key: felt252) {
            assert(get_caller_address() == self.login_address.read(), 'Login addres fail ');
            self.pkey.write(new_key);
        }

        fn get_pkey(self: @ContractState) -> felt252 {
            self.pkey.read()
        }

        fn get_login_address(self: @ContractState) -> ContractAddress {
            self.login_address.read()
        }
    }
}
