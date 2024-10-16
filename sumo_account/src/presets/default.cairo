#[starknet::contract(account)]
mod SumoAccount {
    // use starknet::storage::StoragePointerWriteAccess;
    // use starknet::storage::StoragePointerReadAccess;
    use starknet::{account::Call, VALIDATED};

    use sumo_account::account::interface::IAccount;

    use sumo_account::session::{
        session::{
            session_component
        },
        interface::ISumoSession
    };

    // Signer storage
    component!(path: session_component, storage: session, event: SessionEvents);
    impl SessionInternal = session_component::SessionInternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        session: session_component::Storage,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.session.init();
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        SessionEvents: session_component::Event,
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
