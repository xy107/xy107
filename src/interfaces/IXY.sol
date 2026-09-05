// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IXY {
    function CREATOR() external view returns (address);
    function admin() external view returns (address);
    function operator() external view returns (address);
    function burnSongjiangLock() external;
}
