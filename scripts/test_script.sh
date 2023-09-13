#!/bin/bash

source .env

echo  -n "Borrower Address: "
read borrower_address

echo  -n "Oracle Address: "
read oracle_address

echo  -n "Arbiter Address: "
read arbiter_address

echo  -n "Swap Target Address: "
read swap_target_address

echo -n "Min C Ratio: "
read min_c_ratio

echo -n "Default Split: "
read default_split

echo -n "TTL: "
read ttl

echo -n "owner: "
read owner

echo -n "operator: "
read operator

echo "borrower address: " $borrower_address
echo "oracle address: " $oracle_address
echo "arbiter_address: "  $arbiter_address
echo "swap target address: " $swap_target_address
echo "min c ratio: " $min_c_ratio
echo "default split: " $default_split
echo "ttl: " $ttl
echo "owner: " $owner
echo "operator: " $operator

read -p "Do you wish to continue? [y/N] " answer

case $answer in
    [Yy]* ) echo "Continuing...";;
    [Nn]* ) echo "Exiting..."; exit;;
    * ) echo "Please answer yes or no."; exit;;
esac

echo "Deploying Line of Credit"

