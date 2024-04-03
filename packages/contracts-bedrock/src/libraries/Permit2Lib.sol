// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IAllowanceTransfer {
    /// @notice Transfer approved tokens from one address to another
    /// @param from The address to transfer from
    /// @param to The address of the recipient
    /// @param amount The amount of the token to transfer
    /// @param token The token address to transfer
    /// @notice Requires the from address to have approved at least the desired amount
    ///         of tokens to msg.sender.
    function transferFrom(address from, address to, uint160 amount, address token) external;
}

/// @title Permit2Lib
/// @author Uniswap
/// @notice Enables efficient transfers and EIP-2612/DAI permits for any token by
///         falling back to Permit2. Modified from the following code:
///         https://github.com/Uniswap/permit2/blob/cc56ad0f3439c502c246fc5cfcc3db92bb8b7219/src/libraries/Permit2Lib.sol
library Permit2Lib {
    /// @notice Error message for failed unsafe cast.
    error UnsafeCast();

    /// @notice The address of the Permit2 contract the library will use.
    IAllowanceTransfer internal constant PERMIT2 =
        IAllowanceTransfer(address(0x000000000022D473030F116dDEE9F6B43aC78BA3));

    /// @notice Transfer a given amount of tokens from one user to another.
    /// @param _token The token to transfer.
    /// @param _from The user to transfer from.
    /// @param _to The user to transfer to.
    /// @param _amount The amount to transfer.
    function safeTransferFrom2(address _token, address _from, address _to, uint256 _amount) internal {
        // Generate calldata for a standard transferFrom call.
        bytes memory inputData = abi.encodeCall(IERC20.transferFrom, (_from, _to, _amount));
        // Call the token contract as normal, capturing whether it succeeded.
        // The assembly is meant to handle non standard ERC20 tokens, similar to OpenZeppelin's SafeERC20.
        bool success;
        assembly {
            success :=
                and(
                    // Set success to whether the call reverted, if not we check it either
                    // returned exactly 1 (can't just be non-zero data), or had no return data.
                    or(eq(mload(0), 1), iszero(returndatasize())),
                    // Counterintuitively, this call() must be positioned after the or() in the
                    // surrounding and() because and() evaluates its arguments from right to left.
                    // We use 0 and 32 to copy up to 32 bytes of return data into the first slot of scratch space.
                    call(gas(), _token, 0, add(inputData, 32), mload(inputData), 0, 32)
                )
        }

        // We'll fall back to using Permit2 if calling transferFrom on the token directly reverted.
        if (!success) {
            if (_amount > type(uint160).max) revert UnsafeCast();
            PERMIT2.transferFrom(_from, _to, uint160(_amount), address(_token));
        }
    }
}