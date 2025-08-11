include .env

.PHONY: fund-contract initialize calculate-rewards reset-game is-ready is-active help

FUND_AMOUNT ?= 1.0ether
fund-contract:
	@echo "Funding contract with $(FUND_AMOUNT)..."
	cast send $(CONTRACT_ADDRESS) \
		"fundContract()" \
		--rpc-url $(SEPOLIA_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--value $(FUND_AMOUNT)

initialize:
	@echo "Initializing game..."
	cast send $(CONTRACT_ADDRESS) \
		"initializeGame()" \
		--rpc-url $(SEPOLIA_RPC_URL) \
		--private-key $(PRIVATE_KEY)

calculate-rewards:
	@echo "Calculating rewards..."
	cast send $(CONTRACT_ADDRESS) \
		"calculateRewards()" \
		--rpc-url $(SEPOLIA_RPC_URL) \
		--private-key $(PRIVATE_KEY)

reset-game:
	@echo "Resetting game..."
	cast send $(CONTRACT_ADDRESS) \
		"resetGame()" \
		--rpc-url $(SEPOLIA_RPC_URL) \
		--private-key $(PRIVATE_KEY)

is-ready:
	@echo "Checking if game is ready for start..."
	cast call $(CONTRACT_ADDRESS) \
		"isReadyForStart()" \
		--rpc-url $(SEPOLIA_RPC_URL)

is-active:
	@echo "Checking if game is active..."
	cast call $(CONTRACT_ADDRESS) \
		"isGameActive()" \
		--rpc-url $(SEPOLIA_RPC_URL)
