
//this signature was costructed with the private key
//sk = 0x000000000000000000000000000000008d6bfaf9d111629e78aec17af5917076
//whit publick key
//pk = 0x06363cb464857bb5eddfa351b098bc10c155d61de554640a1f78df62891cd03f
//the transaction hash was
//0x2418c6772ea47ddc9e3ea548bd2dfc9e9ce42365da5df0a2e872967e857bb97

pub fn correct_user_signature() -> Span<felt252> {
  let signature: Array<felt252> =   array![
        0x29428021f4ffa4ece767fffbf194bb16ae8b75dc22454c3cdfcb5f42eb6b5af,
        0x43b37805434b0fa36d5573f2aa17232ec307ba943793732e3fcea1cbd79f3c1,
    ];
    return signature.span();
}

pub fn incorrect_user_signature() -> Span<felt252> {
  let signature: Array<felt252> =   array![
        0x00000000000000000000000000000000000000000000000000000000000000f,
        0x43b37805434b0fa36d5573f2aa17232ec307ba943793732e3fcea1cbd79f3c1,
    ];
    return signature.span();
}
