use core::starknet::{ContractAddress};
use core::starknet::account::Call;

#[starknet::interface]
pub trait ILogin<TContractState> {
    fn login(ref self: TContractState, user_address: ContractAddress, eph_pkey:felt252) ;
    //starkli requiere que le mandes dos felts para armar un u256
    //starkli invoke ADDRESS deploy 1234 1234 1234 1234
    fn deploy(ref self: TContractState, address_seed:u256, arg1: felt252, arg2:felt252 ) -> ContractAddress ;
    fn get_deployed(self: @TContractState) -> Array<ContractAddress>;
    fn get_targets(self: @TContractState) -> Array<ContractAddress>;
    fn get_declared_address(self: @TContractState) -> felt252;
    fn __validate__(self: @TContractState, calls: Span<Call>) -> felt252 ;
    fn __execute__(ref self: TContractState, calls: Span<Call>) -> Array<Span<felt252>> ;
    fn __validate_declare__(ref self: TContractState, declared_class_hash:felt252) -> felt252;
    fn is_valid_signature(self: @TContractState, msg_hash: felt252, signature: Array<felt252>) -> felt252;
}


#[starknet::contract(account)]
mod Login {
    use crate::utils::{StructForHashImpl, ConstructorCallDataImpl, PublicInputImpl};
//    use crate::utils::{PublicInputs};
    use core::starknet::storage::{StoragePointerReadAccess,
        StoragePointerWriteAccess,
        StoragePathEntry,
        Vec,
        VecTrait,
        MutableVecTrait,
        Map
        };
    use core::ecdsa::check_ecdsa_signature;
    use core::starknet::{syscalls,SyscallResultTrait};
    use core::starknet::{ContractAddress};
    use core::starknet::class_hash::ClassHash;
    use core::starknet::VALIDATED;
    use core::starknet::account::Call;
    use core::starknet::{get_caller_address, get_tx_info, get_block_number};
    use core::num::traits::Zero;

    const PKEY: felt252 = 0x6363cb464857bb5eddfa351b098bc10c155d61de554640a1f78df62891cd03f;
    const DEPLOY_FEE: u64 = 1_000_000;

    #[storage]
    struct Storage {
        public_key: felt252,
        sumo_account_class_hash: felt252,
        user_debt: Map<ContractAddress, u64>,
        user_list: Map<ContractAddress, bool>,

        //esta es temportal
        deployed: Vec<ContractAddress>,
        target: Vec<ContractAddress>,
    }

    #[constructor]
    fn constructor(ref self: ContractState, sumo_account_class_hash: felt252) {
        self.sumo_account_class_hash.write(sumo_account_class_hash)
    }

    #[abi(embed_v0)]
    impl LoginImpl of super::ILogin<ContractState> {
        fn __validate_declare__(ref self: ContractState, declared_class_hash: felt252) -> felt252 {
            //Agregar validates aca o nos van a limpiar declarando contratos.
            //No es necesario que use este contrato para delcarar el account, lo hago ahora
            //para que sea mas facil y rapido testear y tener guardado el class_hash de la account
            //se le puede pasar como constructor argument a este o hardcodearlo una vez declarado el otro.
            self.sumo_account_class_hash.write(declared_class_hash);
            VALIDATED
        }

        fn __validate__(self: @ContractState, calls: Span<Call>) -> felt252 {
            self.only_protocol();
            self.validate_tx_version();
            self.validate_tx_signature();
            //validate_garaga
            //validate inputs == validated_inpusts_garaga
            //Cuando sale de aca se tiene que estar seguro que es valido tomar los inputs del calldata
            //No deberiamos correr el validador de garaga en el execute otra vez
            let public_inputs = PublicInputImpl::new(
                eph_public_key0: 1234,
                eph_public_key1: 1234,
                address_seed: 1234,
                max_epoch: 1234,
                iss_b64_F: 1234,
                iss_index_in_payload_mod_4: 1234,
                header_F: 1234,
                modulus_F: 1234
            );
            //Aca tenemos que hacer que el verifier de garaca devuelva la estructira PublicInputs
            //O armar un metodo from garaga en PublicInputs
            let public_inputs_verified = public_inputs.clone();
            //Esto verifica que la prueva que viene en el calldata corresponde a los inputs que vienen en el calldata
            assert(public_inputs.all_inputs_hash()== public_inputs_verified.all_inputs_hash(),
                'AIH not matching');
            let max_block = public_inputs.max_epoch;
            self.validate_block_time(max_block,get_block_number());
            VALIDATED
        }

        fn __execute__(ref self: ContractState, mut calls: Span<Call>) -> Array<Span<felt252>> {
            self.only_protocol();
            self.validate_tx_version();
            self.execute_calls(calls)
        }
        
        fn get_deployed(self: @ContractState) -> Array<ContractAddress> {
            let mut addresses = array![];
            for i in 0..self.deployed.len(){
                addresses.append(self.deployed.at(i).read())
            };
            addresses
        }

        fn get_targets(self: @ContractState) -> Array<ContractAddress> {
            let mut addresses = array![];
            for i in 0..self.deployed.len(){
                addresses.append(self.deployed.at(i).read())
            };
            addresses
        }
        fn get_declared_address(self: @ContractState) -> felt252 {
            self.sumo_account_class_hash.read()
        }

        fn login( ref self:ContractState, user_address: ContractAddress, eph_pkey:felt252,) {
            //Aca se tiene que reconstuir la address partiendo del tx_info
            assert(self.user_list.entry(user_address).read() ,'Loggin: not a sumoer' );
            self.set_user_pkey(user_address, eph_pkey )
//            self.add_debt(user_address, DEPLOY_FEE);
        }

        fn deploy(ref self: ContractState, address_seed: u256, arg1:felt252, arg2:felt252) -> ContractAddress {
            let eph_pkey: felt252 = 12345;
            let salt = self.salt_from_address_seed(address_seed);
            let calldata = array![arg1, arg2];
            let span = calldata.span();
            let class_hash : ClassHash = self.sumo_account_class_hash.read().try_into().unwrap();
            let (address,_) = syscalls::deploy_syscall(class_hash,
                    salt,
                    span,
                    core::bool::True
                ).unwrap_syscall();

            self.deployed.append().write(address);
            self.user_list.entry(address).write(true);
            self.set_user_pkey(address, eph_pkey);
            //This is for testing
            let target_address = self.precompute_account_address(salt, calldata);
            self.target.append().write(target_address.try_into().unwrap());
            //

            address
        }

        fn is_valid_signature(
            self: @ContractState, msg_hash: felt252, signature: Array<felt252>) -> felt252 {
            //TODO: Acomodar esto
            //let public_key = self.public_key.read();
            let public_key = PKEY;
            if check_ecdsa_signature(msg_hash, public_key, *signature.at(0_u32), *signature.at(1_u32)) {
                VALIDATED
            } else {
                0
            }
        }
    }

    #[generate_trait]
    pub impl PrivateImpl of IPrivate {
        fn add_debt(ref self: ContractState, address: ContractAddress, value: u64) {
            let current_debt: u64 = self.user_debt.entry(address).read();
            self.user_debt.entry(address).write(current_debt + value);
        }

        fn precompute_account_address(ref self:ContractState,salt:felt252, calldata: Array<felt252>) -> felt252 {
            let constructor_calldata_hash = ConstructorCallDataImpl::from_array(calldata).hash();
            let struct_to_hash = StructForHashImpl::new (
                prefix: 'STARKNET_CONTRACT_ADDRESS',
                deployer_address: 0,
                salt: salt,
                class_hash: self.sumo_account_class_hash.read(),
                constructor_calldata_hash: constructor_calldata_hash,
            );
            struct_to_hash.hash()
        }

        fn only_protocol(self: @ContractState) {
              let sender = get_caller_address();
              assert(sender.is_zero(), 'Account: invalid caller');
        }

        fn validate_tx_version(self: @ContractState) {
            let tx_info = get_tx_info().unbox();
            let tx_version: u256 = tx_info.version.into();
            assert(tx_version >= 1_u256, 'Fail: Tx_version mismatch');
        }

        fn validate_tx_signature(self: @ContractState){
            let tx_info = get_tx_info().unbox();
            let signature = tx_info.signature;
            let tx_hash = tx_info.transaction_hash;
            assert(self.is_valid_signature(tx_hash,signature.into())==VALIDATED, 'Wrong: Signature');
        }

        fn execute_call(ref self: ContractState, call: @Call) -> Span<felt252> {
            let Call { to, selector, calldata } = *call;
            starknet::syscalls::call_contract_syscall(to, selector, calldata).unwrap_syscall()
        }

        fn execute_calls(ref self: ContractState, mut calls: Span<Call>) -> Array<Span<felt252>> {
            let mut res = array![];
            loop {
                match calls.pop_front() {
                    Option::Some(call) => {
                        let _res = self.execute_call(call);
                        res.append(_res);
                    },
                    Option::None => { break (); },
                };
            };
            res
        }

        fn set_user_pkey(ref self: ContractState, user_address:ContractAddress, eph_pkey: felt252){
            let calldata : Array<felt252> = array![eph_pkey];
                syscalls::call_contract_syscall(
                   user_address,
                   selector!("change_pkey"),
                   calldata.span()
                ).unwrap_syscall();
        }

        fn salt_from_address_seed(ref self: ContractState, address_seed: u256) -> felt252 {
            let MASK_250: u256 = 1809251394333065553493296640760748560207343510400633813116524750123642650623;
            let masked_address_seed: felt252 = (address_seed & MASK_250).try_into().unwrap();
            return masked_address_seed;
        }

        fn validate_block_time(
            self: @ContractState, max_block: u256, current_block_number: u64
        ) -> felt252 {
            let masked_max_block: u64 = max_block.try_into().unwrap();
            assert(current_block_number <= masked_max_block,'Proof expired');
            VALIDATED
        }
    }

}

