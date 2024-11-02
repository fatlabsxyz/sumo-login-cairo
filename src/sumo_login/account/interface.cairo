use starknet::{account::Call, ContractAddress};

#[starknet::interface]
pub trait ISRC6<TState> {
    // ISRC6
    fn __execute__(ref self: TState, calls: Array<Call>) -> Array<Span<felt252>>;
    // fn __validate__(self: @TState, calls: Array<Call>) -> felt252;
    fn __validate__(ref self: TState, calls: Array<Call>) -> felt252;
    fn is_valid_signature(self: @TState, hash: felt252, signature: Array<felt252>) -> felt252;
}

#[starknet::interface]
pub trait ISRC5<TState> {
    // ISRC5
    fn supports_interface(self: @TState, interface_id: felt252) -> bool;
}

#[starknet::interface]
pub trait ILogger<TState> {
    fn get_user_debt(self: @TState, address: ContractAddress) -> u64;
    fn deploy(ref self: TState, address: ContractAddress);
    fn login(ref self: TState, address: ContractAddress);
    fn _is_valid_signature(self: @TState, hash: felt252, signature: Array<felt252>) -> bool;
}


#[starknet::interface]
pub trait ILogin<TState> {
    // ISRC6
    fn __execute__(ref self: TState, calls: Array<Call>) -> Array<Span<felt252>>;
    // fn __validate__(self: @TState, calls: Array<Call>) -> felt252;
    fn __validate__(ref self: TState, calls: Array<Call>) -> felt252;
    fn is_valid_signature(self: @TState, hash: felt252, signature: Array<felt252>) -> felt252;

    // // ISRC5
    // fn supports_interface(self: @TState, interface_id: felt252) -> bool;

    // // IDeclarer
    // fn __validate_declare__(self: @TState, class_hash: felt252) -> felt252;

    // IDeployable
    // fn __validate_deploy__(
    //     self: @TState, class_hash: felt252, salt: felt252, _class_hash: felt252
    // ) -> felt252;

    // ILogger
    fn get_user_debt(self: @TState, address: ContractAddress) -> u64;
    fn deploy(ref self: TState, address: ContractAddress);
    fn login(ref self: TState, address: ContractAddress);
    fn _is_valid_signature(self: @TState, hash: felt252, signature: Array<felt252>) -> bool;

}
