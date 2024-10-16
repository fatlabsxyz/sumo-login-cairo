use starknet::account::Call;

#[starknet::interface]
pub trait ISumoSession<TState> {
    fn init(ref self: TState);
}
