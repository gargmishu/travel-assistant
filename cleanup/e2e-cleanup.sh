#! /bin/sh

./delete-database.sh
./cleanup-network.sh
./cleanup-permissions.sh
./delete-accounts.sh
./delete-project.sh