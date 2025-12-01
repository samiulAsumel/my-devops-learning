#!/bin/bash

##################################################
# User Management Script
# Purpose: Create and manage user accounts.
# Author: samiulAsumel
##################################################

# Create organizational groups
sudo groupadd -g 3001 developers
sudo groupadd -g 3002 operations
sudo groupadd -g 3003 security
sudo groupadd -g 3004 management

# Create shared directories with group ownership
sudo mkdir -p /company-data/{dev,ops,security}
sudo chgrp developers /company-data/dev
sudo chgrp operations /company-data/ops
sudo chgrp security /company-data/security

# Create development team users
for user in john smith alice; do
	sudo useradd -m -s /bin/bash -g developers "$user"
	sudo passwd "$user"
	echo "Created user: $user"
done

# Create operations team users
for user in bob charlie; do
	sudo useradd -m -s /bin/bash -g operations "$user"
	sudo passwd "$user"
	echo "Created user: $user"
done

# Grant sudo access to operations team
echo "%operations ALL=(ALL) ALL" | sudo tee -a /etc/sudoers.d/operations
sudo chmod 440 /etc/sudoers.d/operations
echo "Granted sudo access to operations team."

