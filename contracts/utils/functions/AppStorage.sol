// contracts/utils/AppStorage.sol
pragma solidity ^0.8.9;

import {LibAppStorage} from "../../libraries/LibAppStorage.sol";

contract AppStorage {
    LibAppStorage.Layout internal _appStorage;
}
