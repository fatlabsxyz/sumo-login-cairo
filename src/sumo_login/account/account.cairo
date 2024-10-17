#[starknet::contract(account)]
mod SumoLoginAccount {

    use sumo_login_starknet::sumo_login::account::interface::IAccount;

    use starknet::{account::Call, VALIDATED};

    #[storage]
    struct Storage {
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
    }

    #[abi(embed_v0)]
    impl AccountImpl of IAccount<ContractState> {
        fn is_valid_signature(
            self: @ContractState, hash: felt252, signature: Array<felt252>
        ) -> felt252 {
            VALIDATED
        }

        fn __validate__(self: @ContractState, calls: Array<Call>) -> felt252 {
            VALIDATED
        }

        fn __execute__(self: @ContractState, calls: Array<Call>) -> Array<Span<felt252>> {
            array![]
        }

        fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
            true
        }

        fn __validate_declare__(self: @ContractState, class_hash: felt252) -> felt252 {
            VALIDATED
        }

        fn __validate_deploy__(
            self: @ContractState, class_hash: felt252, salt: felt252, _class_hash: felt252,
        ) -> felt252 {
            VALIDATED
        }
    }

}
