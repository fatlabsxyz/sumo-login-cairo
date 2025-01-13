#[starknet::interface]
pub trait OracleTrait<TContractState> {
    fn get_modulus_F(self: @TContractState) -> u256;
}


#[starknet::contract]
pub mod OracleContract{
    const MODULUS_F: u256 = 6472322537804972268794034248194861302128540584786330577698326766016488520183;

    #[storage]
    pub struct Storage { }

    #[constructor]
    fn constructor(ref self: ContractState) { }

    #[abi(embed_v0)]
    impl OracleImpl of super::OracleTrait<ContractState> {
        fn get_modulus_F(self: @ContractState) -> u256 {
            return MODULUS_F;
        }
    }
}
