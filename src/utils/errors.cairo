pub mod LoginErrors {
    pub const INVALID_TX_VERSION : felt252 = 'Login: invalid tx version';
    pub const INVALID_USER_SIGNATURE : felt252 = 'Login: invalid user signature';
    pub const INVALID_ADMIN_SIGNATURE : felt252 = 'Login: invalid admin signature';
    pub const INVALID_CALLER : felt252 = 'Login: invalid caller';
    pub const INVALID_SIGNATURE_TYPE : felt252 = 'Login: invalid signature type';
    pub const INVALID_ALL_INPUTS_HASH : felt252 = 'Login: invalid AIH';
    pub const INVALID_OAUTH_SIGNATURE : felt252 = 'Login: invalid oauth signature';
    pub const INVALID_PROOF : felt252 = 'Login: invalid zk proof';
    pub const EXPIRED_PROOF : felt252 = 'Login: proof expired';
    pub const MULTICALLS : felt252 = 'Login: multicalls not allowed';
    pub const NOT_USER : felt252 = 'Login: not a sumo user';
    pub const IS_USER : felt252 = 'Login: already an user';
    pub const HAS_DEBT : felt252 = 'Login: user has a debt';
    pub const HAS_NOT_DEBT : felt252 = 'Login: user has no debt';
    pub const OUTSIDE_CALL : felt252 = 'Login: outside call not allowed';
    pub const SELECTOR_NOT_ALLOWED : felt252 = 'Login: selector not allowed';
    pub const PRECOMP_ADDRESS_FAIL : felt252 = 'Login: precomputed address fail';
}

pub mod AccountErrors {
    pub const INVALID_TX_VERSION : felt252 = 'Account: invalid tx version';
    pub const INVALID_CALLER : felt252 = 'Account: invalid caller';
    pub const INVALID_SIGNATURE : felt252 = 'Account: invalid signature';
    pub const INVALID_DEPLOYER : felt252 = 'Account: invalid deployer';
    pub const EXPIRED_SESSION : felt252 = 'Account: session expired';
    pub const NOT_ALLOWED : felt252 = 'Account: not allowed';
    pub const NOT_ENOUGH_MONEY : felt252 = 'Account: not enough to repay';
}
