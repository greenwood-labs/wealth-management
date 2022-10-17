// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "openzeppelin-contracts/interfaces/IERC20Metadata.sol";
import "openzeppelin-contracts/token/ERC20/extensions/draft-IERC20Permit.sol";

import "src/libraries/Counters.sol";
import "src/vault/base/Initializable.sol";

abstract contract BeakerERC20 is IERC20Metadata, IERC20Permit, Initializable {
    using Counters for Counters.Counter;

    mapping(address => mapping(address => uint256)) public override allowance;

    mapping(address => uint256) public override balanceOf;

    string public override name;

    string public override symbol;

    uint8 public override decimals;

    uint256 public override totalSupply;

    // solhint-disable-next-line var-name-mixedcase
    uint256 private CACHED_CHAIN_ID;

    // solhint-disable-next-line var-name-mixedcase
    bytes32 private CACHED_DOMAIN_SEPARATOR;

    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 private constant PERMIT_TYPEHASH =
        0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    mapping(address => Counters.Counter) private _nonces;

    // solhint-disable-next-line func-name-mixedcase
    function __ERC20_init(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) internal onlyInitializing {
        __ERC20_init_unchained(_name, _symbol, _decimals);
    }

    // solhint-disable-next-line func-name-mixedcase
    function __ERC20_init_unchained(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) internal onlyInitializing {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;

        CACHED_CHAIN_ID = _getChainId();
        CACHED_DOMAIN_SEPARATOR = _computeDomainSeparator();
    }

    function approve(address spender, uint256 amount)
        external
        override
        returns (bool)
    {
        allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);

        return true;
    }

    function transfer(address to, uint256 amount)
        external
        override
        returns (bool)
    {
        balanceOf[msg.sender] -= amount;

        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(msg.sender, to, amount);

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external override returns (bool) {
        uint256 allowed = allowance[from][msg.sender];

        if (allowed != type(uint256).max)
            allowance[from][msg.sender] = allowed - amount;

        balanceOf[from] -= amount;

        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);

        return true;
    }

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override {
        // solhint-disable-next-line not-rely-on-time
        require(deadline >= block.timestamp, "deadline expired");

        unchecked {
            address recoveredAddress = ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                PERMIT_TYPEHASH,
                                owner,
                                spender,
                                value,
                                _useNonce(owner),
                                deadline
                            )
                        )
                    )
                ),
                v,
                r,
                s
            );

            require(
                recoveredAddress != address(0) && recoveredAddress == owner,
                "invalid signer"
            );

            allowance[recoveredAddress][spender] = value;
        }

        emit Approval(owner, spender, value);
    }

    function _mint(address to, uint256 amount) internal {
        totalSupply += amount;

        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        balanceOf[from] -= amount;

        unchecked {
            totalSupply -= amount;
        }

        emit Transfer(from, address(0), amount);
    }

    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() public view override returns (bytes32) {
        return
            _getChainId() == CACHED_CHAIN_ID
                ? CACHED_DOMAIN_SEPARATOR
                : _computeDomainSeparator();
    }

    function nonces(address owner) external view override returns (uint256) {
        return _nonces[owner].current();
    }

    function _useNonce(address owner) private returns (uint256 current) {
        Counters.Counter storage nonce = _nonces[owner];
        current = nonce.current();
        nonce.increment();
    }

    function _computeDomainSeparator() private view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256(
                        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                    ),
                    keccak256(bytes(name)),
                    keccak256("1"),
                    _getChainId(),
                    address(this)
                )
            );
    }

    function _getChainId() private view returns (uint256 chainId) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            chainId := chainid()
        }
    }
}
