#!/bin/bash

# Step 1: Create a new user 'nubit' and ask for a password
echo "Creating a new user called 'nubit'."
sudo adduser nubit
sudo usermod -aG sudo nubit

# Step 2: Update the system and install curl and wget if needed
echo "Updating package list and installing required packages..."
sudo apt-get update -y
sudo apt-get install -y curl wget

# Step 3: Ask the user if they want to run a Nubit light node
read -p "Do you want to run a Nubit light node? (Y/n) " answer
if [[ ! $answer =~ ^[Yy]$ ]]; then
    echo "You chose not to run a Nubit light node. Exiting..."
    exit 0
fi

# Step 4: Clone the Nubit repository and build the project
echo "Cloning the Nubit repository and building the project..."
sudo -u nubit git clone -b nubit-alphatestnet-1 https://github.com/RiemaLabs/nubit-node.git /home/nubit/nubit-node
if [[ $? -ne 0 ]]; then
    echo "Error: Failed to clone the repository. Please check your access rights."
    exit 1
fi

cd /home/nubit/nubit-node || { echo "Error: Directory not found. Exiting..."; exit 1; }
sudo make build install
if [[ $? -ne 0 ]]; then
    echo "Error: Build process failed. Exiting..."
    exit 1
fi

# Step 5: Set up the environment
echo "Setting up the environment..."
sudo -u nubit bash -c "
export VALIDATOR_IP=validator.nubit-alphatestnet-1.com
export NODE_TYPE=light
export NETWORK=nubit-alphatestnet-1
export FLAGS=\"--p2p.network \${NETWORK} --core.ip \${VALIDATOR_IP} --metrics --metrics.endpoint otel.nubit-alphatestnet-1.com:4318\"
export NUBIT_DATA_HOME=\"\$HOME/.nubit-\${NODE_TYPE}-\${NETWORK}\"

# Step 6: Clean setup
echo 'Cleaning up any existing data...'
rm -rf \$NUBIT_DATA_HOME

# Step 7: Initialize the light node
echo 'Initializing the Nubit light node...'
/usr/local/bin/nubit light init --p2p.network \$NETWORK
if [[ $? -ne 0 ]]; then
    echo 'Error: Node initialization failed!'
    exit 1
fi

# Step 8: Remove old data directories
echo 'Removing old data directories...'
rm -rf \$NUBIT_DATA_HOME/blocks \$NUBIT_DATA_HOME/data \$NUBIT_DATA_HOME/index \$NUBIT_DATA_HOME/inverted_index \$NUBIT_DATA_HOME/transients

# Step 9: Download the light node snapshot
echo 'Downloading the snapshot...'
wget -O lightnode_data.tgz https://nubit-cdn.com/nubit-data/lightnode_data.tgz
if [[ $? -ne 0 ]]; then
    echo 'Error: Snapshot download failed!'
    exit 1
fi

# Step 10: Extract the snapshot
echo 'Extracting the snapshot...'
tar -zxf lightnode_data.tgz -C \$NUBIT_DATA_HOME
if [[ $? -ne 0 ]]; then
    echo 'Error: Failed to extract the snapshot!'
    exit 1
fi
rm -f lightnode_data.tgz

# Step 11: Create a systemd service file
echo 'Creating a systemd service file for the Nubit node...'
echo \"[Unit]
Description=Nubit Node
After=network.target

[Service]
User=nubit
WorkingDirectory=/home/nubit/nubit-node
ExecStart=/usr/local/bin/nubit light start \$FLAGS
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target\" | sudo tee /etc/systemd/system/nubit.service

# Step 12: Start and enable the Nubit service
sudo systemctl daemon-reload
sudo systemctl enable nubit
sudo systemctl start nubit
"

echo "Nubit light node setup is complete."
