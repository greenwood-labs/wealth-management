# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

#############
## TESTING ##
#############

# run all tests
unit-test :; forge test \
	--no-match-path test/Integration.t.sol \
	--fork-url ${RPC_MAINNET} \
	--fork-block-number 15668500 \
	--gas-report \
	-vvv

# run the integration test only
integration-test :; forge test \
	--match-path test/Integration.t.sol \
	--fork-url ${RPC_MAINNET} \
	--fork-block-number 15668500 \
	-vvv

##################
##  LOCAL NODE  ##
##################

# Running a test node
# node :; anvil \
# 	--fork-url ${RPC_MAINNET} \
# 	--base-fee ${BASE_FEE} 

################
## DEPLOYMENT ##
################

# deploy the multisig contracts on mainnet
# deploy-multisig-mainnet :; forge script script/DeployMultisig.s.sol:DeployMultisig \
	# -f ${RPC_MAINNET} \
	# --slow \
	# --private-key ${DEPLOYER_PRIVATE_KEY} \
	# --with-gas-price ${GAS_PRICE} \
	# --broadcast \
	# --verify \
	# -vvv

# deploy the multisig contract on a local forked mainnet node
# make sure to run `make node` first
# deploy-multisig-local :; forge script script/DeployMultisig.s.sol:DeployMultisig \
# 	-f http://localhost:8545 \
# 	--slow \
# 	--private-key ${ANVIL_PRIVATE_KEY} \
# 	--with-gas-price ${GAS_PRICE} \
# 	--broadcast