use starknet::{account::Call, ContractAddress, VALIDATED, storage::Map};

#[starknet::interface]
trait IPublic<TState> {
    fn get_user_debt(self: @TState, address: ContractAddress) -> u64;
    fn deploy(ref self: TState, address: ContractAddress);
    fn login(ref self: TState, address: ContractAddress);
}

#[starknet::contract(account)]
mod SumoLoginAccount {
    use starknet::storage::StoragePointerReadAccess;
    use starknet::storage::StoragePathEntry;
    use starknet::storage::StoragePointerWriteAccess;

    use sumo_login_starknet::sumo_login::account::interface::{ILogger, ISRC6};

    use starknet::{account::Call, ContractAddress, VALIDATED, storage::Map};
    const REJECTED: felt252 = 'REJECTED';
    const DEPLOY_FEE: u64 = 1_000_000;

    #[storage]
    struct Storage {
        sumo_account_class_hash: felt252,
        user_debt: Map<ContractAddress, u64>,
        user_list: Map<ContractAddress, bool>
    }

    #[constructor]
    fn constructor(ref self: ContractState, sumo_account_class_hash: felt252) {
        self.sumo_account_class_hash.write(sumo_account_class_hash)
    }

    #[abi(embed_v0)]
    impl SRC6Impl of ISRC6<ContractState> {
        fn is_valid_signature(
            self: @ContractState, hash: felt252, signature: Array<felt252>
        ) -> felt252 {
            if self._validate_bool() {
                return VALIDATED;
            }
            REJECTED
        }

        fn __validate__(ref self: ContractState, calls: Array<Call>) -> felt252 {
            self.add_debt((0x12345).try_into().unwrap(), 1000);
            VALIDATED
        }

        fn __execute__(ref self: ContractState, calls: Array<Call>) -> Array<Span<felt252>> {
            println!("{}", self.get_user_debt((0x12345).try_into().unwrap()));
            self._execute()
        }

    // fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
    //     true
    // }

    // fn __validate_declare__(self: @ContractState, class_hash: felt252) -> felt252 {
    //     VALIDATED
    // }

    // fn __validate_deploy__(
    //     self: @ContractState, class_hash: felt252, salt: felt252, _class_hash: felt252,
    // ) -> felt252 {
    //     VALIDATED
    // }

    }

    #[abi(embed_v0)]
    pub impl LoggerImpl of ILogger<ContractState> {

        fn get_user_debt(self: @ContractState, address: ContractAddress) -> u64 {
            self.user_debt.entry(address).read()
        }

        fn login(ref self: ContractState, address: ContractAddress) {
            // deploy sumo account with proper address (should be extractable from signature)
            // let address: ContractAddress = (0x0).try_into().unwrap();
            self.add_debt(address, DEPLOY_FEE);
            self.user_list.entry(address).write(true);
        }

        fn deploy(ref self: ContractState, address: ContractAddress) {
            //XXX: address should not be a parameter, it should be extracted from the tx_info
            // deploy sumo account with proper address (should be extractable from signature)
            // let address: ContractAddress = (0x0).try_into().unwrap();
            self.add_debt(address, DEPLOY_FEE);
            self.user_list.entry(address).write(true);
        }

        fn _is_valid_signature(self: @ContractState, hash: felt252, signature: Array<felt252>) -> bool {
            true
        }

    }

    #[generate_trait]
    pub impl PrivateImpl of IPrivate {
        fn _execute(ref self: ContractState) -> Array<Span<felt252>> {
            array![]
        }

        fn _validate_bool(self: @ContractState) -> bool {
            true
        }

        fn is_valid_sumo_signature(self: @ContractState) -> bool {
            // XXX: we should do all sumo checks here, except for debt check and oracle
            false
        }

        fn has_debt(self: @ContractState, address: felt252) -> bool {
            true
        }

        fn add_debt(ref self: ContractState, address: ContractAddress, value: u64) {
            let current_debt: u64 = self.user_debt.entry(address).read();
            self.user_debt.entry(address).write(current_debt + value);
        }
    }
}
