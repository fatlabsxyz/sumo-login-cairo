//this signature was costructed with the private key
//sk = 0x000000000000000000000000000000008d6bfaf9d111629e78aec17af5917076
//whit publick key
//pk = 0x06363cb464857bb5eddfa351b098bc10c155d61de554640a1f78df62891cd03f
//with expiration block 1_000_000
//the transaction was a call to the address
// 0x075662cc8b986d55d709d58f698bbb47090e2474918343b010192f487e30c23f
//with selector "deploy", and zero array calldata
//the nonce was 3
//the transaction hash was
//0x2418c6772ea47ddc9e3ea548bd2dfc9e9ce42365da5df0a2e872967e857bb97

pub fn correct_admin_signature() -> Span<felt252> {
  let signature: Array<felt252> =   array![
        0x027897b74658f764a55921d0baf32eb21f2cf44d62dfba49a9e9ef606da1e8ee,
        0x29428021f4ffa4ece767fffbf194bb16ae8b75dc22454c3cdfcb5f42eb6b5af,
        0x43b37805434b0fa36d5573f2aa17232ec307ba943793732e3fcea1cbd79f3c1,
    ];
    return signature.span();
}


pub fn incorrect_admin_signature() -> Span<felt252> {
  let signature: Array<felt252> =   array![
        0x027897b74658f764a55921d0baf32eb21f2cf44d62dfba49a9e9ef606da1e8ee,
        0x000000000000000000000000000000000000000000000000000000000000001,
        0x43b37805434b0fa36d5573f2aa17232ec307ba943793732e3fcea1cbd79f3c1,
    ];
    return signature.span();
}

pub fn incorrect_signature_type() -> Span<felt252> {
  let signature: Array<felt252> =   array![
        0x0000000000000000000000000000000000000000000000000000000000000001,
        0x29428021f4ffa4ece767fffbf194bb16ae8b75dc22454c3cdfcb5f42eb6b5af,
        0x43b37805434b0fa36d5573f2aa17232ec307ba943793732e3fcea1cbd79f3c1,
    ];
    return signature.span();
}
