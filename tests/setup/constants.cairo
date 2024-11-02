pub const ADDRESS_SEED: felt252 = 0x3b622486db5a3a52e8df1874fd3dba5e4a22222c6895b242ff7921e6505054b;
pub const SUMO_SIGNATURE_CONST: [felt252; 1] = [0];

pub fn SUMO_SIGNATURE_RAW() -> Span<felt252> {
    SUMO_SIGNATURE_CONST.span()
}

