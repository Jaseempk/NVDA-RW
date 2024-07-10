-include .env

.PHONY: all test clean deploy fund help install snapshot format anvil 

DEFAULT_KEY := 

help:
	@echo "Usage:"
	@echo "  make deploy [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""
	@echo ""
	@echo "  make fund [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""

all: clean remove install update build

# Clean the repo
clean  :; forge clean

# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install :; 

# Update Dependencies
update:; forge update

build:; forge build

test :; forge test 

snapshot :; forge snapshot

format :; forge fmt

anvil :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

NETWORK_ARGS := --rpc-url $(ALCHEMY_RPC_URL) --private-key $(METAMASK_PRIVATE_KEY) --broadcast

ifeq ($(findstring --network base-sepolia,$(ARGS)),--network base-sepolia)
	NETWORK_ARGS := --rpc-url $(ALCHEMY_RPC_URL) --private-key $(METAMASK_PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

deploy:
	@forge script script/DeploydNvda.s.sol:DeploydNvda $(NETWORK_ARGS)



verify:
	@forge verify-contract --chain-id 84532 --watch --constructor-args `cast abi-encode "constructor(string,string,string,string,uint64,uint64,uint8,bytes32,address,address,address,address)" "$(TOKEN_NAME)" "$(TOKEN_SYMBOL)" $(MINT_SOURCE_CODE) "$(REDEEM_SOURCE_CODE)" "$(SUB_ID)" "$(SECRET_VERSION)" "$(SLOT_ID)" "$(DON_ID)" "$(FN_ROUTER)" "$(NVDA_PRICEFEED)" "$(REDEMPTION_COIN)" "$(USDC_PRICEFEED)"` --etherscan-api-key $(ETHERSCAN_API_KEY) --compiler-version 0.8.24 $(dNVDA_CONTRACT_ADDRESS) src/dNVDA.sol:dNVDA




