#!/bin/env bash

# Deploys the deposit contract and makes deposits for $VALIDATOR_COUNT insecure deterministic validators.
# Produces a testnet specification and a genesis state where the genesis time
# is now + $GENESIS_DELAY.
#
# Generates datadirs for multiple validator keys according to the
# $VALIDATOR_COUNT and $BN_COUNT variables.
#

set -o nounset -o errexit -o pipefail

source /config/vars.env

if [ ! -z "$(ls -A $TESTNET_DIR)" ]; then
    echo "testnet directory already exists. exiting"
    exit 0
fi

NOW=`date +%s`
GENESIS_TIME=`expr $NOW + $GENESIS_DELAY`

lcli \
	new-testnet \
	--spec $SPEC_PRESET \
	--deposit-contract-address $DEPOSIT_CONTRACT_ADDRESS \
	--testnet-dir $TESTNET_DIR \
	--min-genesis-active-validator-count $GENESIS_VALIDATOR_COUNT \
	--min-genesis-time $GENESIS_TIME \
	--genesis-delay $GENESIS_DELAY \
	--genesis-fork-version $GENESIS_FORK_VERSION \
	--altair-fork-epoch $ALTAIR_FORK_EPOCH \
	--bellatrix-fork-epoch $BELLATRIX_FORK_EPOCH \
	--capella-fork-epoch $CAPELLA_FORK_EPOCH \
	--eip4844-fork-epoch $EIP4844_FORK_EPOCH \
	--ttd $TTD \
	--eth1-block-hash $ETH1_BLOCK_HASH \
	--eth1-id $CHAIN_ID \
	--eth1-follow-distance 1 \
	--seconds-per-slot $SECONDS_PER_SLOT \
	--seconds-per-eth1-block $SECONDS_PER_ETH1_BLOCK \
	--validator-count $GENESIS_VALIDATOR_COUNT \
	--interop-genesis-state \
	--force

echo Specification and genesis.ssz generated at $TESTNET_DIR.
echo "Generating $VALIDATOR_COUNT validators concurrently... (this may take a while)"

lcli \
	insecure-validators \
	--count $VALIDATOR_COUNT \
	--base-dir $DATADIR \
	--testnet-dir $TESTNET_DIR \
	--node-count 1

echo Validators generated with keystore passwords at $DATADIR.

GENESIS_TIME=$(lcli pretty-ssz state_merge $TESTNET_DIR/genesis.ssz  | jq | grep -Po 'genesis_time": "\K.*\d')
CAPELLA_TIME=$((GENESIS_TIME + (CAPELLA_FORK_EPOCH * 32 * SECONDS_PER_SLOT)))
EIP4844_TIME=$((GENESIS_TIME + (EIP4844_FORK_EPOCH * 32 * SECONDS_PER_SLOT)))

cp /config/genesis.json $TESTNET_DIR/genesis.json

sed -i 's/"shanghaiTime".*$/"shanghaiTime": '"$CAPELLA_TIME"',/g' $TESTNET_DIR/genesis.json
sed -i 's/"shardingForkTime".*$/"shardingForkTime": '"$EIP4844_TIME"',/g' $TESTNET_DIR/genesis.json

cp $TESTNET_DIR/genesis.json /config/generated-genesis.json

# we need to edit first before copying the file to the bind-mount. Redirects do not work here
cp $TESTNET_DIR/config.yaml /tmp/config.yaml
# unquote strings for easier compatibilty with yaml parsers
sed -i 's/"//g' /tmp/config.yaml
cp /tmp/config.yaml /config/generated-config.yaml