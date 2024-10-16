#[starknet::component]
pub mod session_component {

    use starknet::storage::StoragePointerWriteAccess;
    use starknet::storage::StoragePointerReadAccess;

    use sumo_account::session::interface::ISumoSession;

    #[storage]
    pub struct Storage {
        key: felt252
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        NewSession: NewSession,
    }

    #[derive(Drop, starknet::Event)]
    struct NewSession {
        #[key]
        eph_key: felt252,
    }

    #[embeddable_as(SessionInternalImpl)]
    impl InternalImpl<TContractState, +HasComponent<TContractState>> of ISumoSession<ComponentState<TContractState>> {
        fn init(ref self: ComponentState<TContractState>) {
            self.key.write(0);
        }
    }

}
