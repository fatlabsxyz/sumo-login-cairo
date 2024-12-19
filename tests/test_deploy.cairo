use crate::setup::{setup_login};
use crate::signature::{signature};
use snforge_std::{start_cheat_signature};
use sumo::login::login_contract::ILoginDispatcherTrait;
const ETH_ADDRRESS: felt252= 0x49D36570D4E46F48E99674BD3FCC84644DDD6B96F7C741B1562B82F9E004DC7;


//#[test]
fn test_deploy() {
    let (login_address, login_dispatcher) = setup_login();
    start_cheat_signature(login_address , signature()) ;
    let _deployed_addres = login_dispatcher.deploy();
}
