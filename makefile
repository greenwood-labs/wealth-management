# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# deps
install:; forge install
update:; forge update

# Running a test node
fork-node :; anvil --fork-url ${RPC_MAINNET} --base-fee ${BASE_FEE} 

# Build & test
build  :; forge build
test   :; forge test
fork-test   :; forge test --fork-url ${RPC_MAINNET} --gas-report -vvv
fork-block :; forge test --fork-url ${RPC_MAINNET} --fork-block-number ${FORKED_BLOCK_NUMBER} -vvv
trace   :; forge test -vvv
clean  :; forge clean
snapshot :; forge snapshot
fmt    :; forge fmt

deploy-multisig-mainnet :; forge script script/DeployMultisig.s.sol:DeployMultisig -f ${RPC_MAINNET} --slow --private-key ${DEPLOYER_PRIVATE_KEY} --with-gas-price ${GAS_PRICE} --broadcast --verify -vvvv
# make sure to run `fork node` first
deploy-multisig-local :; forge script script/DeployMultisig.s.sol:DeployMultisig -f http://localhost:8545 --slow --private-key ${ANVIL_PRIVATE_KEY} --with-gas-price ${GAS_PRICE} --broadcast