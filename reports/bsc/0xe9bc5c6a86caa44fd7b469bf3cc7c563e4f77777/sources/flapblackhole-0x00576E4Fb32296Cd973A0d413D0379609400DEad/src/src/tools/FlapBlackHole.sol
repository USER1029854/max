// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AccessControl} from "@openzeppelin/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";

/**
 * @title FlapBlackHole
 * @notice  A black hole contract for burning tokens and keeping FDV/MCAP calculations fair
 *
 * @dev
 *
 * 1. When a token is burnt, people usually send it to 0xdead directly. Since a lot of terminals have treated
 * 0xdead as a black hole, the burnt tokens are not counted as both FDV and MCAP. This is unfair to these
 * tokens if they are launched via a bonding curve. They have sufficient liquidity, but their
 * FDV and MCAP are artificially low due to the burnt tokens compared to tokens that are not burnt.
 *
 * 2. To solve this issue, we introduce the FlapBlackHole contract. Instead of sending the tokens to 0xdead
 * directly, users directly send the tokens to this contract. The contract holds the tokens temporarily or
 * permanently. Since there is no way to retrieve the tokens from this contract except burning, the tokens
 * are effectively burnt but result in a better FDV and MCAP calculation.
 */
contract FlapBlackHole is AccessControl {
    using SafeERC20 for IERC20;

    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /**
     * @notice Transfers the entire balance of the specified token held by this contract to the 0xdead address.
     * @param token The address of the ERC20 token to eradicate.
     */
    function eradicate(address token) external onlyRole(BURNER_ROLE) {
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            IERC20(token).safeTransfer(address(0x000000000000000000000000000000000000dEaD), balance);
        }
    }
}
