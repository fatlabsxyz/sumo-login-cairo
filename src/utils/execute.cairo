use core::starknet::{ syscalls , SyscallResultTrait };
use core::starknet::account::Call;

pub fn execute_calls(mut calls: Span<Call>) -> Array<Span<felt252>> {
    let mut res = array![];
    loop {
        match calls.pop_front() {
            Option::Some(call) => {
                let _res = execute_single_call(call);
                res.append(_res);
            },
            Option::None => { break (); },
        };
    };
    res
}

pub fn execute_single_call(call: @Call) -> Span<felt252> {
    let Call { to, selector, calldata } = *call;
    syscalls::call_contract_syscall(to, selector, calldata).unwrap_syscall()
}
