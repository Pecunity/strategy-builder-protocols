// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IAction} from 'strategy-builder-plugin/src/interfaces/IAction.sol';
import {ITokenGetter} from'strategy-builder-plugin/src/interfaces/ITokenGetter.sol';

contract SendCoinAction is IAction {


    function sendCoins(uint256 amount,address to) external pure returns(PluginExecution[] memory)
    {   
        PluginExecution[] memory executions = new PluginExecution[](1);
        executions[0] = PluginExecution({
            target: to,
            data: '',
            value: amount
        });

        return executions;
    }
}