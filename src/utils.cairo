use core::pedersen::PedersenTrait;
use core::hash::{HashStateTrait, HashStateExTrait};
use core::sha256::compute_sha256_byte_array;

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

#[derive(Drop, Hash, Serde, Copy)]
pub struct PublicInputs {
    eph_public_key0: u256,
    eph_public_key1: u256,
    address_seed: u256,
    pub max_epoch: u256,
    iss_b64_F: u256,
    iss_index_in_payload_mod_4: u256,
    header_F: u256,
    modulus_F: u256,
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

#[generate_trait]
pub impl PublicInputImpl of PublicInputTrait {
    fn into_span(self: PublicInputs) -> Span<u256> {
        array![
            self.eph_public_key0,
            self.eph_public_key1,
            self.address_seed,
            self.max_epoch,
            self.iss_b64_F,
            self.iss_index_in_payload_mod_4,
            self.header_F,
            self.modulus_F,
        ].span()
    }

    fn concatenate_inputs(self: PublicInputs) -> ByteArray {
        let inputs = self.into_span();
        let mut byte_array = Default::default();
        let mut index = 0_u32;
        while index < inputs.len() {
            let int_value: u256 = *inputs.at(index);
            byte_array.append_word(int_value.high.into(), 16);
            byte_array.append_word(int_value.low.into(), 16);
            index += 1;
        };
        byte_array
    }

    fn all_inputs_hash(self: PublicInputs) -> u256 {
        let concatenated = self.concatenate_inputs();
        let hash_result = compute_sha256_byte_array(@concatenated);
        let all_inputs_hash: u256 = (*hash_result.span().at(0)).into();
        return all_inputs_hash;
    }

    fn new(
        eph_public_key0: u256,
        eph_public_key1: u256,
        address_seed: u256,
        max_epoch: u256,
        iss_b64_F: u256,
        iss_index_in_payload_mod_4: u256,
        header_F: u256,
        modulus_F: u256
        ) -> PublicInputs {
            PublicInputs {
                eph_public_key0,
                eph_public_key1,
                address_seed,
                max_epoch,
                iss_b64_F,
                iss_index_in_payload_mod_4,
                header_F,
                modulus_F
            }
        }
}


