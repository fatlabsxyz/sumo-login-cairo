use crate::setup::accounts::setup_sumo_login;

#[test]
fn simple() {
    let dispatcher = setup_sumo_login();
    assert!(1==1, "OK");
}


#[test]
#[should_panic(expected: 'NOPE')]
fn simple_fail() {
    assert(1==0, 'NOPE');
}
