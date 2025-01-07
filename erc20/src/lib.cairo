use starknet::ContractAddress;

#[starknet::interface]
pub trait IERC20<TContractState> {
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
}


#[starknet::contract]
pub mod ERC20Contract {
    use starknet::storage::StoragePathEntry;
    use starknet::ContractAddress;
    use core::starknet::storage::{Map};
    use core::starknet::storage::{StoragePointerReadAccess,
        StoragePointerWriteAccess,
        };
    const INITIAL_BALANCE : u256 = 1_000_000_000_u256;

    #[storage]
    pub struct Storage {
        pub ERC20_balances: Map<ContractAddress, u256>,
    }

    #[constructor]
    fn constructor(ref self: ContractState, paymaster: ContractAddress) {
        self.ERC20_balances.entry(paymaster).write(INITIAL_BALANCE)
    }

    #[abi(embed_v0)]
    impl Erc20Impl of super::IERC20<ContractState> {

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            let balance = self.ERC20_balances.entry(account).read();
            return balance;
        }

        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool{
            let sender = starknet::get_caller_address();
            let from_balance = self.ERC20_balances.entry(sender).read();
            assert(from_balance >= amount, 'ERC20: Insuficient Balance');
            self.ERC20_balances.entry(sender).write(from_balance - amount);
            let to_balance = self.ERC20_balances.entry(recipient).read();
            self.ERC20_balances.entry(recipient).write(to_balance + amount);
            true
        }
    }
}
