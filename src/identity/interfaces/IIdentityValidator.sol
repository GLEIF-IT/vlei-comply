// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

/**
 * @title IIdentityValidator
 * @notice Interface for validating whether an account satisfies identity requirements.
 * @dev Credential-backed implementations should resolve the account to an identity first and
 * return false for missing identity, missing credential, expired credential, or invalid data.
 */
interface IIdentityValidator {
  /**
   * @notice Validates the identity of an account.
   * @dev This function MUST NOT revert. Use try-catch blocks around external calls and return
   * false for any validation failures instead of allowing exceptions to propagate.
   * @param account The account to validate.
   * @param context Additional information or authorization to perform the operation.
   * @return True if the account is a valid identity, false otherwise.
   */
  function validate(address account, bytes calldata context) external view returns (bool);
}
