#!/bin/bash

# Define colors for output
RED="\e[31m"
GREEN="\e[32m"
CYAN="\e[36m"
NC="\e[0m"

# Target network
NETWORK="192.168.1.0/24"  # Replace with your target subnet
RESULTS_DIR="./iot_scan_results"
CREDENTIALS_FILE="./default_creds.txt"

# Create results directory
mkdir -p "$RESULTS_DIR"

# Load default credentials
if [[ ! -f $CREDENTIALS_FILE ]]; then
    echo -e "${RED}[ERROR] Default credentials file not found!${NC}"
    exit 1
fi

# Function to scan for IoT devices
scan_network() {
    echo -e "${CYAN}[INFO] Scanning network for IoT devices...${NC}"
    nmap -sP "$NETWORK" | grep "Nmap scan report for" | awk '{print $NF}' >"$RESULTS_DIR/devices.txt"

    echo -e "${GREEN}[SUCCESS] Found devices on the network:${NC}"
    cat "$RESULTS_DIR/devices.txt"
}

# Function to check default credentials
check_credentials() {
    local device_ip=$1
    echo -e "${CYAN}[INFO] Checking default credentials for $device_ip...${NC}"

    while IFS=',' read -r service username password; do
        case $service in
        ssh)
            check_ssh "$device_ip" "$username" "$password"
            ;;
        telnet)
            check_telnet "$device_ip" "$username" "$password"
            ;;
        http)
            check_http "$device_ip" "$username" "$password"
            ;;
        *)
            echo -e "${RED}[ERROR] Unsupported service: $service${NC}"
            ;;
        esac
    done <"$CREDENTIALS_FILE"
}

# Function to check SSH login
check_ssh() {
    local ip=$1
    local user=$2
    local pass=$3

    echo -e "${CYAN}[INFO] Attempting SSH login: $user@$ip with password $pass${NC}"
    expect -c "
    spawn ssh -oStrictHostKeyChecking=no $user@$ip
    expect \"password:\"
    send \"$pass\r\"
    expect \"#\" { exit 0 } timeout { exit 1 }
    " && echo -e "${GREEN}[SUCCESS] SSH login successful on $ip with $user:$pass${NC}" || echo -e "${RED}[FAIL] SSH login failed for $user@$ip${NC}"
}

# Function to check Telnet login
check_telnet() {
    local ip=$1
    local user=$2
    local pass=$3

    echo -e "${CYAN}[INFO] Attempting Telnet login: $user@$ip with password $pass${NC}"
    expect -c "
    spawn telnet $ip
    expect \"login:\"
    send \"$user\r\"
    expect \"Password:\"
    send \"$pass\r\"
    expect \"#\" { exit 0 } timeout { exit 1 }
    " && echo -e "${GREEN}[SUCCESS] Telnet login successful on $ip with $user:$pass${NC}" || echo -e "${RED}[FAIL] Telnet login failed for $user@$ip${NC}"
}

# Function to check HTTP login
check_http() {
    local ip=$1
    local user=$2
    local pass=$3

    echo -e "${CYAN}[INFO] Attempting HTTP login on $ip with $user:$pass${NC}"
    response=$(curl -s -o /dev/null -w "%{http_code}" -u "$user:$pass" "http://$ip")
    if [[ "$response" == "200" ]]; then
        echo -e "${GREEN}[SUCCESS] HTTP login successful on $ip with $user:$pass${NC}"
    else
        echo -e "${RED}[FAIL] HTTP login failed for $user@$ip${NC}"
    fi
}

# Main function
main() {
    scan_network

    while IFS= read -r device; do
        check_credentials "$device"
    done <"$RESULTS_DIR/devices.txt"
}

# Run the script
main
