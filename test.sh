# Main script
echo "Searching for available port..."
while true; do
    port=$(generate_random_port)
    if [[ -z "$port" ]]; then
        echo "No available port found."
        exit 1
    fi
    if prompt_user "$port"; then
        if [[ "$choice" == "c" ]]; then
            read -p "Enter a port of your choice: " chosen_port
            if [[ "$chosen_port" =~ ^[0-9]+$ ]]; then
                if ! [[ " ${reserved_ports[@]} " =~ " $chosen_port " ]] && is_port_available "$chosen_port"; then
                    echo "Chosen port \e[93m$chosen_port\e[0m is available."
                    break
                else
                    echo "Port \e[93m$chosen_port\e[0m is not available or is reserved. Please choose another port."
                fi
            else
                echo -e "\e[91mInvalid port number. Please enter a valid port number.\e[0m"
            fi
        elif [[ "$choice" == "exit" ]]; then
            echo -e "\e[91mExiting from the script...............\e[0m"
            exit
        else
            echo "Accepted port: $port"
            break
        fi
    else
        echo "Port $port denied. Searching for another available port..."
    fi
done
