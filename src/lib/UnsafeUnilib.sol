// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

library UnsafeUnilib {
    function sortAndGetPair(address tokenA, address tokenB)
        internal
        pure
        returns (address pair)
    {
        (address token0, address token1) = sort(tokenA, tokenB);
        pair = getPair(token0, token1);
    }

    function sort(address tokenA, address tokenB)
        internal
        pure
        returns (address token0, address token1)
    {
        (token0, token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
    }

    function getPair(address token0, address token1)
        internal
        pure
        returns (address pair)
    {
        pair = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f,
                            keccak256(abi.encodePacked(token0, token1)),
                            hex"96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f"
                        )
                    )
                )
            )
        );
    }
}
