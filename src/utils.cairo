use core::pedersen::PedersenTrait;
use core::hash::{HashStateTrait, HashStateExTrait};

#[derive(Drop, Hash, Serde, Copy)]
pub struct ConstructorCallData{
    arg1:felt252,
    arg2:felt252,
}

#[derive(Drop, Hash, Serde, Copy)]
pub struct StructForHash {
    prefix: felt252,
    deployer_address: felt252,
    salt: felt252,
    class_hash:felt252,
    constructor_calldata_hash:felt252,
}

#[generate_trait]
pub impl StructForHashImpl of StrucForHashTrait {
    fn new(
            prefix:felt252,
            deployer_address: felt252,
            salt:felt252,
            class_hash:felt252,
            constructor_calldata_hash:felt252
        )-> StructForHash {
           StructForHash {prefix, deployer_address, salt, class_hash, constructor_calldata_hash}
    }
    
    fn hash(self:StructForHash) -> felt252{
        let hash = PedersenTrait::new(0).update_with(self).update_with(5).finalize();
        return hash;
    }
}


#[generate_trait]
pub impl ConstructorCallDataImpl of ConstructorCallDataTrait{
    fn from_array(calldata: Array<felt252>) -> ConstructorCallData {
        return ConstructorCallData {
            arg1:1234,
            arg2:1234,
        };
    }

    fn to_array(self: ConstructorCallData)-> Array<felt252>{
        let array: Array<felt252> = array![
            self.arg1,
            self.arg2,
        ];
        return array;
    }

    fn hash(self:ConstructorCallData) -> felt252{
        let hash = PedersenTrait::new(0).update_with(self).update_with(2).finalize();
        return hash;
    }
}
