use crate::setup::accounts::{setup_sumo_login, setup_sumo_account};

#[test]
fn simple() {
    let sumo_login = setup_sumo_login();
    let sumo_account = setup_sumo_account();
    assert!(1==1, "OK");
}


#[test]
#[should_panic(expected: 'NOPE')]
fn simple_fail() {
    assert(1==0, 'NOPE');
}
