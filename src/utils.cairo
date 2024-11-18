use core::pedersen::PedersenTrait;
use core::hash::{HashStateTrait, HashStateExTrait};
use core::sha256::compute_sha256_byte_array;

#[derive(Drop, Hash, Serde, Copy)]
pub struct ConstructorCallData{
    pub arg1:felt252,
    pub arg2:felt252,
}

#[derive(Drop, Hash, Serde, Copy)]
pub struct StructForHash {
    pub prefix: felt252,
    pub deployer_address: felt252,
    pub salt: felt252,
    pub class_hash:felt252,
    pub constructor_calldata_hash:felt252,
}

#[derive(Drop, Hash, Serde, Copy)]
pub struct PublicInputs {
    pub eph_public_key0: u256,
    pub eph_public_key1: u256,
    pub address_seed: u256,
    pub max_epoch: u256,
    pub iss_b64_F: u256,
    pub iss_index_in_payload_mod_4: u256,
    pub header_F: u256,
    pub modulus_F: u256,
}

#[generate_trait]
pub impl StructForHashImpl of StrucForHashTrait {
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
    fn from_span(span_inputs: Span<u256>) -> PublicInputs {
        PublicInputs {
            eph_public_key0: *span_inputs.at(0),
            eph_public_key1:  *span_inputs.at(0),
            address_seed:  *span_inputs.at(0),
            max_epoch:  *span_inputs.at(0),
            iss_b64_F:  *span_inputs.at(0),
            iss_index_in_payload_mod_4:  *span_inputs.at(0),
            header_F:  *span_inputs.at(0),
            modulus_F:  *span_inputs.at(0),
        }
    }
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

    fn salt_from_address_seed(self: PublicInputs) -> felt252 {
        let MASK_250: u256 = 1809251394333065553493296640760748560207343510400633813116524750123642650623;
        let masked_address_seed: felt252 = (self.address_seed & MASK_250).try_into().unwrap();
        return masked_address_seed;
    }
}


