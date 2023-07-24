// Copyright 2021-2023, Offchain Labs, Inc.
// For license information, see https://github.com/nitro/blob/master/LICENSE
// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./Value.sol";
import "./Instructions.sol";
import "./Module.sol";

struct MerkleProof {
    bytes32[] counterparts;
}

library MerkleProofLib {
    using ModuleLib for Module;
    using ValueLib for Value;

    function computeRootFromValue(
        MerkleProof memory proof,
        uint256 index,
        Value memory leaf
    ) internal pure returns (bytes32) {
        return computeRootUnsafe(proof, index, leaf.hash(), "Value merkle tree:");
    }

    function computeRootFromOpcode(
        MerkleProof memory proof,
        uint256 index,
        bytes32 opcodes
    ) internal pure returns (bytes32) {
        return computeRootUnsafe(proof, index, opcodes, "Opcode merkle tree:");
    }

    function computeRootFromArgData(
        MerkleProof memory proof,
        uint256 index,
        bytes32 argData
    ) internal pure returns (bytes32) {
        return computeRootUnsafe(proof, index, argData, "Argument data merkle tree:");
    }

    function computeRootFromFunction(
        MerkleProof memory proof,
        uint256 index,
        bytes32 codeRoot,
        bytes32 argDataRoot,
        bytes32 emptyLocalsRoot
    ) internal pure returns (bytes32) {
        bytes32 h = keccak256(abi.encodePacked("Function:", codeRoot, argDataRoot, emptyLocalsRoot));
        return computeRootUnsafe(proof, index, h, "Function merkle tree:");
    }

    function computeRootFromFunctionType(
        MerkleProof memory proof,
        uint256 index,
        bytes32 funcTypeHash
    ) internal pure returns (bytes32) {
        return computeRootUnsafe(proof, index, funcTypeHash, "Function type merkle tree:");
    }

    function computeRootFromMemory(
        MerkleProof memory proof,
        uint256 index,
        bytes32 contents
    ) internal pure returns (bytes32) {
        bytes32 h = keccak256(abi.encodePacked("Memory leaf:", contents));
        return computeRootUnsafe(proof, index, h, "Memory merkle tree:");
    }

    function computeRootFromElement(
        MerkleProof memory proof,
        uint256 index,
        bytes32 funcTypeHash,
        Value memory val
    ) internal pure returns (bytes32) {
        bytes32 h = keccak256(abi.encodePacked("Table element:", funcTypeHash, val.hash()));
        return computeRootUnsafe(proof, index, h, "Table element merkle tree:");
    }

    function computeRootFromTable(
        MerkleProof memory proof,
        uint256 index,
        uint8 tableType,
        uint64 tableSize,
        bytes32 elementsRoot
    ) internal pure returns (bytes32) {
        bytes32 h = keccak256(abi.encodePacked("Table:", tableType, tableSize, elementsRoot));
        return computeRootUnsafe(proof, index, h, "Table merkle tree:");
    }

    function computeRootFromModule(
        MerkleProof memory proof,
        uint256 index,
        Module memory mod
    ) internal pure returns (bytes32) {
        return computeRootUnsafe(proof, index, mod.hash(), "Module merkle tree:");
    }

    // WARNING: leafHash must be computed in such a way that it cannot be a non-leaf hash.
    function computeRootUnsafe(
        MerkleProof memory proof,
        uint256 index,
        bytes32 leafHash,
        string memory prefix
    ) internal pure returns (bytes32 h) {
        h = leafHash;
        for (uint256 layer = 0; layer < proof.counterparts.length; layer++) {
            if (index & 1 == 0) {
                h = keccak256(abi.encodePacked(prefix, h, proof.counterparts[layer]));
            } else {
                h = keccak256(abi.encodePacked(prefix, proof.counterparts[layer], h));
            }
            index >>= 1;
        }
        require(index == 0, "PROOF_TOO_SHORT");
    }

    function growToNewRoot(
        bytes32 root,
        uint256 leaf,
        bytes32 hash,
        bytes32 zero,
        string memory prefix
    ) internal pure returns (bytes32) {
        bytes32 h = hash;
        uint256 node = leaf;
        while (node > 1) {
            h = keccak256(abi.encodePacked(prefix, h, zero));
            zero = keccak256(abi.encodePacked(prefix, zero, zero));
            node >>= 1;
        }
        return keccak256(abi.encodePacked(prefix, root, h));
    }
}
