#!/usr/bin/env zsh

# Get the operating system name
os_name=$(uname -s)

# Get the machine hardware name (processor architecture)
arch_name=$(uname -m)

if [[ "$os_name" == "Darwin" ]]; then
    if [[ "$arch_name" != "arm64" ]]; then
        echo "This script is only intended to run on an Apple Silicon processor."
        exit 1
    fi
else
    echo "This script is not running on a Mac."
    exit 1
fi

START_TIME=$(date +"%Y-%m-%d %H:%M:%S")
echo "Script started at: $START_TIME"

chmod +x ~/install-learn-ultra/main.zsh

# Define the file to store the inputs
input_file="$HOME/learn_install_input.txt"

# Check if the file exists
if [ -f "$input_file" ]; then
    # Read the inputs from the file
    lines=()
    while IFS= read -r line; do
        lines+=("$line")
    done < "$input_file"
    password=${lines[1]}
    userEmail=${lines[2]}
    userName=${lines[3]}
else
    # Ask the user for the inputs
    echo "Enter your System password: "
    read -s password

    echo "Enter your email (Anthology email): "
    read userEmail

    echo "Enter your user name that will be used/configured with you local Git : "
    read userName

    # Write the inputs to the file
    echo "$password" > "$input_file"
    echo "$userEmail" >> "$input_file"
    echo "$userName" >> "$input_file"
fi

# Updating to extent the sudo timeout to 180 minutes
echo $password | sudo -S -v
echo 'Defaults        timestamp_timeout=180' | sudo tee /etc/sudoers.d/timeout

# This script is used to check and generate SSH key for the user. This is a pre-requisite script that should be ran before running the main script.
# Check if SSH key is present
echo -e "\e[33mChecking SSH key\e[0m"
if [  ! -f ~/.ssh/id_ed25519 ]; then

  ssh-keygen -t ed25519 -C "$userEmail" -N "" -f ~/.ssh/id_ed25519

  # Start SSH agent
  eval "$(ssh-agent -s)" &&

  # Configure SSH
  touch $HOME/.ssh/config &&
  echo -e 'Host github.com
  \nAddKeysToAgent yes
  \nUseKeychain yes
  \nIdentityFile ~/.ssh/id_ed25519' >> $HOME/.ssh/config &&

  # Add SSH key to agent
  ssh-add --apple-use-keychain $HOME/.ssh/id_ed25519 &&
  open "https://github.com/settings/ssh/new"

else
  echo "\n SSH key already present."
  open "https://github.com/settings/ssh" 
fi
  pbcopy < ~/.ssh/id_ed25519.pub
  echo "\a \a \a \a"
  echo -e "\e[33m Go Back to the document and follow Step 5 https://anthologyinc.sharepoint.com/sites/bb-lrnctl/SitePages/Development-Environment-Setup.aspx \e[0m"

# Define the function to prompt the user and capture input
prompt_continue() {
  echo -e "\e[1;33m$1\e[0m"  
  read continue_key
}

# Sleep for 30 secs
sleep 30

# Example usage: Prompt the user and capture input
prompt_continue "\n \n After adding the ssh key in GitHub by following the above document please Press return to continue here..."

# Check if the user pressed Enter (continue_key will be empty)
if [ -z "$continue_key" ]; then


END_TIME=$(date +"%Y-%m-%d %H:%M:%S")
echo "Script ended at: $END_TIME"

# Calculate duration of the script
START_SEC=$(date -j -f "%Y-%m-%d %H:%M:%S" "$START_TIME" "+%s")
END_SEC=$(date -j -f "%Y-%m-%d %H:%M:%S" "$END_TIME" "+%s")
DURATION=$(($END_SEC - $START_SEC))
echo "$DURATION" > ~/pre_script_duration.txt

~/install-learn-ultra/main.zsh "$password" "$userEmail" "$userName"
else
  echo "Continuation aborted."
fi
