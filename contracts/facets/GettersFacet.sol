// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

import {Getters} from "../utils/functions/Getters.sol";

/**
 * @title ProtocolFacet
 * @author Lendbit Finance
 *
 * @dev Core contract of the Lending protocol that integrates operations and data access functions.
 * This contract combines essential functionalities from `Operations` and `Getters`, enabling
 * interactions with the protocol’s core features, such as loan requests and user information retrieval.
 *
 * This contract acts as a primary interface for protocol interactions, while `Operations`
 * contains core operational functions, and `Getters` allows querying data from the protocol.
 */
contract GettersFacet is Getters {
    /**
     * @dev Fallback function that reverts any calls made to undefined functions.
     * This ensures the protocol does not accept or process unsupported function calls.
     *
     * Reverts with "ProtocolFacet: fallback" when an undefined function is called.
     */
    fallback() external {
        revert("ProtocolFacet: fallback");
    }
}
