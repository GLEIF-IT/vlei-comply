// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {ICredentialRequirements} from "./interfaces/ICredentialRequirements.sol";
import {IIdentityValidator} from "./interfaces/IIdentityValidator.sol";
import {ICredentialDataValidator} from "./interfaces/ICredentialDataValidator.sol";
import {IIdentityRegistry} from "./interfaces/IIdentityRegistry.sol";
import {ICredentialRegistry} from "./interfaces/ICredentialRegistry.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title CredentialRegistryIdentityValidator
 * @notice Validates accounts against configurable credential requirements across credential sources.
 * @dev This Chainlink-style validator resolves an account to a CCID through configured identity
 * registries, checks credential presence/expiry in credential registries, and optionally validates
 * credential payload bytes through data validators. The vLEI policy does not currently
 * depend on this validator for Legal Entity pass/fail decisions.
 */
contract CredentialRegistryIdentityValidator is OwnableUpgradeable, ICredentialRequirements, IIdentityValidator {
  /// @notice Maximum number of configured credential requirements.
  uint256 private constant MAX_REQUIREMENTS = 8;

  /// @notice Maximum number of credential sources per credential type.
  uint256 private constant MAX_REQUIREMENT_SOURCES = 8;

  /// @notice Maximum credential type ids accepted by a single requirement.
  uint256 private constant MAX_CREDENTIAL_TYPES_PER_REQUIREMENT = 32;

  /// @notice ERC-7201 storage bucket for validator requirements and sources.
  /// @custom:storage-location erc7201:chainlink.ace.CredentialRegistryIdentityValidator
  struct CredentialRegistryIdentityValidatorStorage {
    /// @notice Configured requirement ids.
    bytes32[] requirements;
    /// @notice Requirement configuration by id.
    mapping(bytes32 requirementId => CredentialRequirement credentialRequirement) credentialRequirementMap;
    /// @notice Credential sources by credential type id.
    mapping(bytes32 credential => CredentialSource[] sources) credentialSources;
  }

  // keccak256(abi.encode(uint256(keccak256("chainlink.ace.CredentialRegistryIdentityValidator")) - 1)) &
  // ~bytes32(uint256(0xff))
  // solhint-disable-next-line const-name-snakecase
  bytes32 private constant credentialRegistryIdentityValidatorStorageLocation =
    0xd345ab5a3e8073283824dcc06e7ac0c586290818c864e9d2ee66361ecca47600;

  /// @notice Returns the ERC-7201 storage bucket.
  /// @return $ Storage pointer for validator state.
  function _credentialRegistryIdentityValidatorStorage()
    private
    pure
    returns (CredentialRegistryIdentityValidatorStorage storage $)
  {
    // solhint-disable-next-line no-inline-assembly
    assembly {
      $.slot := credentialRegistryIdentityValidatorStorageLocation
    }
  }

  /// @notice Disables initialization on the implementation contract.
  constructor() {
    // disabling initializers on the implementation contract itself
    _disableInitializers();
  }

  /**
   * @notice Initializes the credential validator and sets initial credential sources and requirements.
   * @dev The initializer owns the validator with `msg.sender`.
   * @param credentialSourceInputs The credential sources to add.
   * @param credentialRequirementInputs The credential requirements to add.
   */
  function initialize(
    CredentialSourceInput[] memory credentialSourceInputs,
    CredentialRequirementInput[] memory credentialRequirementInputs
  )
    public
    virtual
    initializer
  {
    __CredentialRegistryIdentitityValidator_init(credentialSourceInputs, credentialRequirementInputs);
  }

  /// @notice Internal initializer for inherited ownership and validator state.
  /// @param credentialSourceInputs Initial credential source configurations.
  /// @param credentialRequirementInputs Initial credential requirement configurations.
  function __CredentialRegistryIdentitityValidator_init(
    CredentialSourceInput[] memory credentialSourceInputs,
    CredentialRequirementInput[] memory credentialRequirementInputs
  )
    internal
    onlyInitializing
  {
    __Ownable_init(msg.sender);
    __CredentialRegistryIdentitityValidator_init_unchained(credentialSourceInputs, credentialRequirementInputs);
  }

  /// @notice Internal unchained initializer that writes initial sources and requirements.
  /// @param credentialSourceInputs Initial credential source configurations.
  /// @param credentialRequirementInputs Initial credential requirement configurations.
  function __CredentialRegistryIdentitityValidator_init_unchained(
    CredentialSourceInput[] memory credentialSourceInputs,
    CredentialRequirementInput[] memory credentialRequirementInputs
  )
    internal
    onlyInitializing
  {
    uint256 length = credentialSourceInputs.length;
    for (uint256 i = 0; i < length; i++) {
      _addCredentialSource(credentialSourceInputs[i]);
    }
    length = credentialRequirementInputs.length;
    for (uint256 i = 0; i < length; i++) {
      _addCredentialRequirement(credentialRequirementInputs[i]);
    }
  }

  /// @notice Adds one credential requirement after enforcing implementation limits.
  /// @param input Requirement configuration to add.
  function _addCredentialRequirement(CredentialRequirementInput memory input) internal {
    uint256 minValidations = input.minValidations;
    if (minValidations == 0) {
      revert InvalidRequirementConfiguration("minValidations must be greater than 0");
    }
    uint256 length = _credentialRegistryIdentityValidatorStorage().requirements.length;
    if (length >= MAX_REQUIREMENTS) {
      revert InvalidRequirementConfiguration("Max requirements reached");
    }
    bytes32 requirementId = input.requirementId;
    for (uint256 i = 0; i < length; i++) {
      if (_credentialRegistryIdentityValidatorStorage().requirements[i] == requirementId) {
        revert RequirementExists(requirementId);
      }
    }
    bytes32[] memory credentialTypeIds = input.credentialTypeIds;
    uint256 credentialTypesLength = credentialTypeIds.length;

    if (credentialTypesLength == 0 || credentialTypesLength > MAX_CREDENTIAL_TYPES_PER_REQUIREMENT) {
      revert InvalidRequirementConfiguration("Invalid credential types length");
    }
    _credentialRegistryIdentityValidatorStorage().requirements.push(requirementId);
    _credentialRegistryIdentityValidatorStorage().credentialRequirementMap[requirementId] =
      CredentialRequirement(credentialTypeIds, minValidations, input.invert);
    emit CredentialRequirementAdded(requirementId, credentialTypeIds, minValidations, input.invert);
  }

  /// @inheritdoc ICredentialRequirements
  function addCredentialRequirement(CredentialRequirementInput memory input) public virtual override onlyOwner {
    _addCredentialRequirement(input);
  }

  /// @inheritdoc ICredentialRequirements
  function removeCredentialRequirement(bytes32 requirementId) public virtual override onlyOwner {
    uint256 length = _credentialRegistryIdentityValidatorStorage().requirements.length;
    for (uint256 i = 0; i < length; i++) {
      if (_credentialRegistryIdentityValidatorStorage().requirements[i] == requirementId) {
        _credentialRegistryIdentityValidatorStorage().requirements[i] =
          _credentialRegistryIdentityValidatorStorage().requirements[length - 1];
        _credentialRegistryIdentityValidatorStorage().requirements.pop();

        CredentialRequirement memory requirement =
          _credentialRegistryIdentityValidatorStorage().credentialRequirementMap[requirementId];

        emit CredentialRequirementRemoved(
          requirementId, requirement.credentialTypeIds, requirement.minValidations, requirement.invert
        );
        delete _credentialRegistryIdentityValidatorStorage().credentialRequirementMap[requirementId];
        return;
      }
    }
    revert RequirementNotFound(requirementId);
  }

  /// @inheritdoc ICredentialRequirements
  function getCredentialRequirement(bytes32 requirementId)
    public
    view
    virtual
    override
    returns (CredentialRequirement memory)
  {
    return _credentialRegistryIdentityValidatorStorage().credentialRequirementMap[requirementId];
  }

  /// @inheritdoc ICredentialRequirements
  function getCredentialRequirementIds() public view virtual override returns (bytes32[] memory) {
    return _credentialRegistryIdentityValidatorStorage().requirements;
  }

  /// @notice Adds one credential source after enforcing implementation limits.
  /// @param input Credential source configuration to add.
  function _addCredentialSource(CredentialSourceInput memory input) internal {
    address identityRegistry = input.identityRegistry;
    address credentialRegistry = input.credentialRegistry;
    bytes32 credentialTypeId = input.credentialTypeId;
    bytes32 sourceId = keccak256(abi.encodePacked(identityRegistry, credentialRegistry));
    uint256 length = _credentialRegistryIdentityValidatorStorage().credentialSources[credentialTypeId].length;
    if (length >= MAX_REQUIREMENT_SOURCES) {
      revert InvalidRequirementConfiguration("Max credential sources reached for credential type");
    }
    for (uint256 i = 0; i < length; i++) {
      // Load the entire source struct into memory once
      CredentialSource memory existingSource =
        _credentialRegistryIdentityValidatorStorage().credentialSources[credentialTypeId][i];

      bytes32 foundSourceId =
        keccak256(abi.encodePacked(existingSource.identityRegistry, existingSource.credentialRegistry));
      if (foundSourceId == sourceId) {
        revert SourceExists(credentialTypeId, identityRegistry, credentialRegistry);
      }
    }
    address dataValidator = input.dataValidator;
    _credentialRegistryIdentityValidatorStorage().credentialSources[credentialTypeId].push(
      CredentialSource(identityRegistry, credentialRegistry, dataValidator)
    );
    emit CredentialSourceAdded(credentialTypeId, identityRegistry, credentialRegistry, dataValidator);
  }

  /// @inheritdoc ICredentialRequirements
  function addCredentialSource(CredentialSourceInput memory input) public virtual override onlyOwner {
    _addCredentialSource(input);
  }

  /// @inheritdoc ICredentialRequirements
  function removeCredentialSource(
    bytes32 credentialTypeId,
    address identityRegistry,
    address credentialRegistry
  )
    public
    virtual
    override
    onlyOwner
  {
    bytes32 sourceId = keccak256(abi.encodePacked(identityRegistry, credentialRegistry));
    uint256 length = _credentialRegistryIdentityValidatorStorage().credentialSources[credentialTypeId].length;
    for (uint256 i = 0; i < length; i++) {
      // Load the entire source struct into memory once
      CredentialSource memory existingSource =
        _credentialRegistryIdentityValidatorStorage().credentialSources[credentialTypeId][i];

      bytes32 foundSourceId =
        keccak256(abi.encodePacked(existingSource.identityRegistry, existingSource.credentialRegistry));
      if (foundSourceId == sourceId) {
        _credentialRegistryIdentityValidatorStorage().credentialSources[credentialTypeId][i] =
          _credentialRegistryIdentityValidatorStorage().credentialSources[credentialTypeId][length - 1];
        _credentialRegistryIdentityValidatorStorage().credentialSources[credentialTypeId].pop();
        emit CredentialSourceRemoved(
          credentialTypeId, identityRegistry, credentialRegistry, existingSource.dataValidator
        );
        return;
      }
    }
    revert CredentialSourceNotFound(credentialTypeId, identityRegistry, credentialRegistry);
  }

  /// @inheritdoc ICredentialRequirements
  function getCredentialSources(bytes32 credential) public view virtual override returns (CredentialSource[] memory) {
    return _credentialRegistryIdentityValidatorStorage().credentialSources[credential];
  }

  /// @inheritdoc IIdentityValidator
  function validate(address account, bytes calldata context) public view virtual override returns (bool) {
    uint256 length = _credentialRegistryIdentityValidatorStorage().requirements.length;
    for (uint256 i = 0; i < length; i++) {
      if (!_validateRequirement(account, _credentialRegistryIdentityValidatorStorage().requirements[i], context)) {
        return false;
      }
    }
    return true;
  }

  /// @notice Validates one configured requirement for an account.
  /// @param account Account to validate.
  /// @param requirementId Requirement id to evaluate.
  /// @param context Additional validation context passed through to registries and data validators.
  /// @return True when the requirement is satisfied.
  function _validateRequirement(
    address account,
    bytes32 requirementId,
    bytes calldata context
  )
    internal
    view
    virtual
    returns (bool)
  {
    CredentialRequirement memory requirement =
      _credentialRegistryIdentityValidatorStorage().credentialRequirementMap[requirementId];
    uint256 validations = 0;
    for (uint256 i = 0; i < requirement.credentialTypeIds.length; i++) {
      validations = _validateCredential(
        account, requirement.credentialTypeIds[i], validations, requirement.minValidations, requirement.invert, context
      );
      if (validations >= requirement.minValidations) {
        return true;
      }
    }
    return false;
  }

  /// @notice Counts valid sources for one credential type until the requirement threshold is met.
  /// @param account Account to validate.
  /// @param credentialTypeId Credential type identifier being evaluated.
  /// @param currentValidations Number of validations already counted.
  /// @param minValidations Threshold needed to satisfy the enclosing requirement.
  /// @param invert True when absence of the credential should count as valid.
  /// @param context Additional validation context.
  /// @return Number of validations counted after checking configured sources.
  function _validateCredential(
    address account,
    bytes32 credentialTypeId,
    uint256 currentValidations,
    uint256 minValidations,
    bool invert,
    bytes calldata context
  )
    internal
    view
    virtual
    returns (uint256)
  {
    uint256 validations = currentValidations;
    uint256 length = _credentialRegistryIdentityValidatorStorage().credentialSources[credentialTypeId].length;
    for (uint256 i = 0; i < length; i++) {
      CredentialSource memory source =
        _credentialRegistryIdentityValidatorStorage().credentialSources[credentialTypeId][i];
      bytes32 ccid = IIdentityRegistry(source.identityRegistry).getIdentity(account);
      if (ccid == 0) {
        continue; // identity not found in this registry
      }

      if (
        _validateCredentialWithRegistry(
          ccid, account, source.credentialRegistry, source.dataValidator, credentialTypeId, invert, context
        )
      ) {
        validations++;
      }
      if (validations >= minValidations) {
        return validations;
      }
    }
    return validations;
  }

  /// @notice Validates one credential against one registry/source pair.
  /// @dev Registry and data-validator reverts are treated as validation failure.
  /// @param ccid Cross-chain identity resolved for the account.
  /// @param account Account being validated.
  /// @param credentialRegistry Credential registry source.
  /// @param dataValidator Optional payload validator.
  /// @param credential Credential type identifier.
  /// @param invert True when absence of the credential should be accepted.
  /// @param context Additional validation context.
  /// @return True when the credential source satisfies the requirement condition.
  function _validateCredentialWithRegistry(
    bytes32 ccid,
    address account,
    address credentialRegistry,
    address dataValidator,
    bytes32 credential,
    bool invert,
    bytes calldata context
  )
    internal
    view
    virtual
    returns (bool)
  {
    // Check if credential exists and is valid in registry
    bool credentialExists;
    try ICredentialRegistry(credentialRegistry).validate(ccid, credential, context) returns (bool valid) {
      credentialExists = valid;
    } catch {
      // If validation throws, we return false because the credential is not valid despite the value of invert
      return false;
    }

    // For inverted credentials: return true only if credential doesn't exist
    if (invert) {
      return !credentialExists;
    }

    // For normal credentials: credential must exist to proceed
    if (!credentialExists) {
      return false;
    }

    // No data validator means credential is valid
    if (dataValidator == address(0)) {
      return true;
    }

    // Validate credential data
    bytes memory credentialData = ICredentialRegistry(credentialRegistry).getCredential(ccid, credential).credentialData;

    try ICredentialDataValidator(dataValidator).validateCredentialData(
      ccid, account, credential, credentialData, context
    ) returns (bool valid) {
      return valid;
    } catch {
      return false;
    }
  }
}
