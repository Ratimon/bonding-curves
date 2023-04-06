// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

library Errors {
    error ZeroNumberNotAllowed();

    error ZeroAddressNotAllowed();

    error NotAuthorized(address caller);

    error UnsupportedInterface();
}
