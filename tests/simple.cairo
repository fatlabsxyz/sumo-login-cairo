use crate::setup::accounts::setup_sumo_login;

#[test]
fn simple() {
    setup_sumo_login();
    assert!(1==1, "OK");
}


#[test]
fn simple_fail() {
    assert!(1==0, "NOPE");
}
