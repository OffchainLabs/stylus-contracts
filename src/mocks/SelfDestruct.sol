// Copyright 2022-2023, Offchain Labs, Inc.
// For license information, see https://github.com/nitro/blob/master/LICENSE
// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

contract SelfDestruct {
    function callSelfDestruct(address addr) external {
        selfdestruct(payable(addr));
    }
}
