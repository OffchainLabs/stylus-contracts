// Copyright 2022-2023, Offchain Labs, Inc.
// For license information, see https://github.com/nitro/blob/master/LICENSE
// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;
import "../precompiles/ArbSys.sol";

contract ProgramTest {
    event Hash(bytes32 result);

    function callKeccak(address program, bytes calldata data) external {
        // in keccak.rs
        //     the input is the # of hashings followed by a preimage
        //     the output is the iterated hash of the preimage
        (bool success, bytes memory result) = address(program).call(data);
        require(success, "call failed");
        bytes32 hash = bytes32(result);
        emit Hash(hash);
        require(hash == keccak256(data[1:]));
    }

    function staticcallProgram(address program, bytes calldata data)
        external
        view
        returns (bytes memory)
    {
        (bool success, bytes memory result) = address(program).staticcall(data);
        require(success, "call failed");
        return result;
    }

    function assert256(
        bytes memory data,
        string memory text,
        uint256 expected
    ) internal pure returns (bytes memory) {
        uint256 value = abi.decode(data, (uint256));
        require(value == expected, text);

        bytes memory rest = new bytes(data.length - 32);
        for (uint256 i = 32; i < data.length; i++) {
            rest[i - 32] = data[i];
        }
        return rest;
    }

    function staticcallEvmData(
        address program,
        address fundedAccount,
        uint64 gas,
        bytes calldata data
    ) external view returns (bytes memory) {
        (bool success, bytes memory result) = address(program).staticcall{gas: gas}(data);

        address arbPrecompile = address(0x69);
        address ethPrecompile = address(0x01);

        result = assert256(result, "block number ", block.number - 1);
        result = assert256(result, "block hash   ", uint256(blockhash(block.number - 1)));
        result = assert256(result, "chain id     ", block.chainid);
        result = assert256(result, "base fee     ", block.basefee);
        result = assert256(result, "gas price    ", tx.gasprice);
        result = assert256(result, "gas limit    ", block.gaslimit);
        result = assert256(result, "value        ", 0);
        result = assert256(result, "difficulty   ", block.difficulty);
        result = assert256(result, "timestamp    ", block.timestamp);
        result = assert256(result, "balance      ", fundedAccount.balance);
        result = assert256(result, "rust address ", uint256(uint160(program)));
        result = assert256(result, "sender       ", uint256(uint160(address(this))));
        result = assert256(result, "origin       ", uint256(uint160(tx.origin)));
        result = assert256(result, "coinbase     ", uint256(uint160(address(block.coinbase))));
        result = assert256(result, "rust codehash", uint256(program.codehash));
        result = assert256(result, "arb codehash ", uint256(arbPrecompile.codehash));
        result = assert256(result, "eth codehash ", uint256(ethPrecompile.codehash));

        return result;
    }

    function checkRevertData(
        address program,
        bytes calldata data,
        bytes calldata expected
    ) external payable returns (bytes memory) {
        (bool success, bytes memory result) = address(program).call{value: msg.value}(data);
        require(!success, "unexpected success");
        require(result.length == expected.length, "wrong revert data length");
        for (uint256 i = 0; i < result.length; i++) {
            require(result[i] == expected[i], "revert data mismatch");
        }
        return result;
    }

    function fillBlockRecover() external payable {
        bytes32 bridgeToNova = 0xeddecf107b5740cef7f5a01e3ea7e287665c4e75a8eb6afae2fda2e3d4367786;
        address cryptoIsCute = 0x361594F5429D23ECE0A88E4fBE529E1c49D524d8;
        uint8 v = 27;
        bytes32 r = 0xc6178c2de1078cd36c3bd302cde755340d7f17fcb3fcc0b9c333ba03b217029f;
        bytes32 s = 0x5fdbcefe2675e96219cdae57a7894280bf80fd40d44ce146a35e169ea6a78fd3;
        while (true) {
            require(ecrecover(bridgeToNova, v, r, s) == cryptoIsCute, "WRONG_ARBINAUT");
        }
    }

    function fillBlockHash() external payable {
        bytes32 hash = 0xeddecf107b5740cef7f5a01e3ea7e287665c4e75a8eb6afae2fda2e3d4367786;
        while (true) {
            hash = keccak256(abi.encodePacked(hash));
        }
    }
}
