// Copyright 2021-2022, Offchain Labs, Inc.
// For license information, see https://github.com/OffchainLabs/nitro-contracts/blob/main/LICENSE
// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./Value.sol";
import "./ValueStack.sol";
import "./Machine.sol";
import "./Instructions.sol";
import "./StackFrame.sol";
import "./GuardStack.sol";
import "./MerkleProof.sol";
import "./ModuleMemoryCompact.sol";
import "./Module.sol";
import "./GlobalState.sol";

library Deserialize {
    function u8(bytes calldata proof, uint256 startOffset)
        internal
        pure
        returns (uint8 ret, uint256 offset)
    {
        offset = startOffset;
        ret = uint8(proof[offset]);
        offset++;
    }

    function u16(bytes calldata proof, uint256 startOffset)
        internal
        pure
        returns (uint16 ret, uint256 offset)
    {
        offset = startOffset;
        for (uint256 i = 0; i < 16 / 8; i++) {
            ret <<= 8;
            ret |= uint8(proof[offset]);
            offset++;
        }
    }

    function u32(bytes calldata proof, uint256 startOffset)
        internal
        pure
        returns (uint32 ret, uint256 offset)
    {
        offset = startOffset;
        for (uint256 i = 0; i < 32 / 8; i++) {
            ret <<= 8;
            ret |= uint8(proof[offset]);
            offset++;
        }
    }

    function u64(bytes calldata proof, uint256 startOffset)
        internal
        pure
        returns (uint64 ret, uint256 offset)
    {
        offset = startOffset;
        for (uint256 i = 0; i < 64 / 8; i++) {
            ret <<= 8;
            ret |= uint8(proof[offset]);
            offset++;
        }
    }

    function u256(bytes calldata proof, uint256 startOffset)
        internal
        pure
        returns (uint256 ret, uint256 offset)
    {
        offset = startOffset;
        for (uint256 i = 0; i < 256 / 8; i++) {
            ret <<= 8;
            ret |= uint8(proof[offset]);
            offset++;
        }
    }

    function b32(bytes calldata proof, uint256 startOffset)
        internal
        pure
        returns (bytes32 ret, uint256 offset)
    {
        offset = startOffset;
        uint256 retInt;
        (retInt, offset) = u256(proof, offset);
        ret = bytes32(retInt);
    }

    function boolean(bytes calldata proof, uint256 startOffset)
        internal
        pure
        returns (bool ret, uint256 offset)
    {
        offset = startOffset;
        ret = uint8(proof[offset]) != 0;
        offset++;
    }

    function value(bytes calldata proof, uint256 startOffset)
        internal
        pure
        returns (Value memory val, uint256 offset)
    {
        offset = startOffset;
        uint8 typeInt = uint8(proof[offset]);
        offset++;
        require(typeInt <= uint8(ValueLib.maxValueType()), "BAD_VALUE_TYPE");
        uint256 contents;
        (contents, offset) = u256(proof, offset);
        val = Value({valueType: ValueType(typeInt), contents: contents});
    }

    function valueStack(bytes calldata proof, uint256 startOffset)
        internal
        pure
        returns (ValueStack memory stack, uint256 offset)
    {
        offset = startOffset;
        bytes32 remainingHash;
        (remainingHash, offset) = b32(proof, offset);
        uint256 provedLength;
        (provedLength, offset) = u256(proof, offset);
        Value[] memory proved = new Value[](provedLength);
        for (uint256 i = 0; i < proved.length; i++) {
            (proved[i], offset) = value(proof, offset);
        }
        stack = ValueStack({proved: ValueArray(proved), remainingHash: remainingHash});
    }

    function stackFrame(bytes calldata proof, uint256 startOffset)
        internal
        pure
        returns (StackFrame memory window, uint256 offset)
    {
        offset = startOffset;
        Value memory returnPc;
        bytes32 localsMerkleRoot;
        uint32 callerModule;
        uint32 callerModuleInternals;
        (returnPc, offset) = value(proof, offset);
        (localsMerkleRoot, offset) = b32(proof, offset);
        (callerModule, offset) = u32(proof, offset);
        (callerModuleInternals, offset) = u32(proof, offset);
        window = StackFrame({
            returnPc: returnPc,
            localsMerkleRoot: localsMerkleRoot,
            callerModule: callerModule,
            callerModuleInternals: callerModuleInternals
        });
    }

    function stackFrameWindow(bytes calldata proof, uint256 startOffset)
        internal
        pure
        returns (StackFrameWindow memory window, uint256 offset)
    {
        offset = startOffset;
        bytes32 remainingHash;
        (remainingHash, offset) = b32(proof, offset);
        StackFrame[] memory proved;
        if (proof[offset] != 0) {
            offset++;
            proved = new StackFrame[](1);
            (proved[0], offset) = stackFrame(proof, offset);
        } else {
            offset++;
            proved = new StackFrame[](0);
        }
        window = StackFrameWindow({proved: proved, remainingHash: remainingHash});
    }

    function errorGuard(bytes calldata proof, uint256 startOffset)
        internal
        pure
        returns (ErrorGuard memory guard, uint256 offset)
    {
        offset = startOffset;
        Value memory onErrorPc;
        bytes32 frameStack;
        bytes32 valueStack;
        bytes32 interStack;
        (frameStack, offset) = b32(proof, offset);
        (valueStack, offset) = b32(proof, offset);
        (interStack, offset) = b32(proof, offset);
        (onErrorPc, offset) = value(proof, offset);
        guard = ErrorGuard({
            frameStack: frameStack,
            valueStack: valueStack,
            interStack: interStack,
            onErrorPc: onErrorPc
        });
    }

    function guardStack(bytes calldata proof, uint256 startOffset)
        internal
        pure
        returns (GuardStack memory window, uint256 offset)
    {
        offset = startOffset;
        bytes32 remainingHash;
        bool enabled;
        bool empty;
        (enabled, offset) = boolean(proof, offset);
        (empty, offset) = boolean(proof, offset);
        (remainingHash, offset) = b32(proof, offset);

        ErrorGuard[] memory proved;
        if (empty) {
            proved = new ErrorGuard[](0);
        } else {
            proved = new ErrorGuard[](1);
            (proved[0], offset) = errorGuard(proof, offset);
        }
        window = GuardStack({proved: proved, remainingHash: remainingHash, enabled: enabled});
    }

    function moduleMemory(bytes calldata proof, uint256 startOffset)
        internal
        pure
        returns (ModuleMemory memory mem, uint256 offset)
    {
        offset = startOffset;
        uint64 size;
        uint64 maxSize;
        bytes32 root;
        (size, offset) = u64(proof, offset);
        (maxSize, offset) = u64(proof, offset);
        (root, offset) = b32(proof, offset);
        mem = ModuleMemory({size: size, maxSize: maxSize, merkleRoot: root});
    }

    function module(bytes calldata proof, uint256 startOffset)
        internal
        pure
        returns (Module memory mod, uint256 offset)
    {
        offset = startOffset;
        bytes32 globalsMerkleRoot;
        ModuleMemory memory mem;
        bytes32 tablesMerkleRoot;
        bytes32 functionsMerkleRoot;
        bytes32 typesMerkleRoot;
        uint32 internalsOffset;
        (globalsMerkleRoot, offset) = b32(proof, offset);
        (mem, offset) = moduleMemory(proof, offset);
        (tablesMerkleRoot, offset) = b32(proof, offset);
        (functionsMerkleRoot, offset) = b32(proof, offset);
        (typesMerkleRoot, offset) = b32(proof, offset);
        (internalsOffset, offset) = u32(proof, offset);
        mod = Module({
            globalsMerkleRoot: globalsMerkleRoot,
            moduleMemory: mem,
            tablesMerkleRoot: tablesMerkleRoot,
            functionsMerkleRoot: functionsMerkleRoot,
            typesMerkleRoot: typesMerkleRoot,
            internalsOffset: internalsOffset
        });
    }

    function globalState(bytes calldata proof, uint256 startOffset)
        internal
        pure
        returns (GlobalState memory state, uint256 offset)
    {
        offset = startOffset;

        // using constant ints for array size requires newer solidity
        bytes32[2] memory bytes32Vals;
        uint64[2] memory u64Vals;

        for (uint8 i = 0; i < GlobalStateLib.BYTES32_VALS_NUM; i++) {
            (bytes32Vals[i], offset) = b32(proof, offset);
        }
        for (uint8 i = 0; i < GlobalStateLib.U64_VALS_NUM; i++) {
            (u64Vals[i], offset) = u64(proof, offset);
        }
        state = GlobalState({bytes32Vals: bytes32Vals, u64Vals: u64Vals});
    }

    function machine(bytes calldata proof, uint256 startOffset)
        internal
        pure
        returns (Machine memory mach, uint256 offset)
    {
        offset = startOffset;
        MachineStatus status;
        {
            uint8 statusU8;
            (statusU8, offset) = u8(proof, offset);
            if (statusU8 == 0) {
                status = MachineStatus.RUNNING;
            } else if (statusU8 == 1) {
                status = MachineStatus.FINISHED;
            } else if (statusU8 == 2) {
                status = MachineStatus.ERRORED;
            } else if (statusU8 == 3) {
                status = MachineStatus.TOO_FAR;
            } else {
                revert("UNKNOWN_MACH_STATUS");
            }
        }
        ValueStack memory values;
        ValueStack memory internalStack;
        bytes32 globalStateHash;
        uint32 moduleIdx;
        uint32 functionIdx;
        uint32 functionPc;
        StackFrameWindow memory frameStack;
        GuardStack memory guards;
        bytes32 modulesRoot;
        (values, offset) = valueStack(proof, offset);
        (internalStack, offset) = valueStack(proof, offset);
        (frameStack, offset) = stackFrameWindow(proof, offset);
        (guards, offset) = guardStack(proof, offset);
        (globalStateHash, offset) = b32(proof, offset);
        (moduleIdx, offset) = u32(proof, offset);
        (functionIdx, offset) = u32(proof, offset);
        (functionPc, offset) = u32(proof, offset);
        (modulesRoot, offset) = b32(proof, offset);
        mach = Machine({
            status: status,
            valueStack: values,
            internalStack: internalStack,
            frameStack: frameStack,
            guardStack: guards,
            globalStateHash: globalStateHash,
            moduleIdx: moduleIdx,
            functionIdx: functionIdx,
            functionPc: functionPc,
            modulesRoot: modulesRoot
        });
    }

    function merkleProof(bytes calldata proof, uint256 startOffset)
        internal
        pure
        returns (MerkleProof memory merkle, uint256 offset)
    {
        offset = startOffset;
        uint8 length;
        (length, offset) = u8(proof, offset);
        bytes32[] memory counterparts = new bytes32[](length);
        for (uint8 i = 0; i < length; i++) {
            (counterparts[i], offset) = b32(proof, offset);
        }
        merkle = MerkleProof(counterparts);
    }
}
