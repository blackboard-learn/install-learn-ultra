#!/usr/bin/env zsh
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
echo $password | sudo -S -v

print_congrats() {
echo -e "\e[1m \e[32m **********************    Congratulations!!!   ***********************  \e[0m" 
open "https://mylearn.int.bbpd.io"
echo -e "\e[1m \e[36m Your Learn Application is Up !!! and opened in your default browser\e[0m"  
echo -e "\e[33m Go Back to the document and follow Step 7 \e[0m"                             
}

error() {
  local input_message="$1"
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo -e "\e[31mError at $timestamp: $input_message\e[0m" >> ~/install.log
  return 1
}

# Define the function to prompt the user and capture input
prompt_continue() {
  echo -e "\e[1;33m$1\e[0m"  
  read continue_key
}

install_Learn() {
  echo $password |  sudo -S -v
  source $HOME/.zshrc &&

  echo -e "\e[33m Installing Learn ... \e[0m"

  cd $HOME/work &&
  if [ -d learn ]; then
    cd learn &&
    # echo -e "\a \a \a \a \a "
    # echo -e "\e[33m Go Back to the document and follow Step 6 \e[0m"
    # prompt_continue "After Turning off zscalar internet Security, please Press Enter to continue..."
    # if [ -z "$continue_key" ]; then
    gdl installLearn &&
    echo -e "\e[33m Starting Learn Application... \e[0m"
    gdl startLearn
    # fi
  else
    echo -e "\e[33m There is no Learn Folder ... \e[0m"
  fi

  sed -i '' 's|fetch = +refs/heads/develop:refs/remotes/origin/develop|fetch = +refs/heads/*:refs/remotes/origin/*|' /Users/$USER/work/learn/.git/config

}

install_ultra_router() {
  echo $password |  sudo -S -v
  source $HOME/.zshrc &&
  echo "Starting ultra_router..."
  cd $HOME/work &&
    if [ -d ultra-router ]; then
        cd ultra-router &&
         echo -e "\e[33m Starting Ultra Router... \e[0m"
        yes '' | ./start >> ~/install.log 2>&1 &
    fi

}

install_ultra() {
  echo $password |  sudo -S -v
  source $HOME/.zshrc &&
  echo "Installing Ultra..."
  cd $HOME/work &&
  if [ -d ultra ]; then
    cd ultra &&
    ./update.sh &&
    cd $HOME/work &&
    cd $HOME/work/ultra/apps/ultra-ui &&
    echo -e "\e[33m Starting Ultra Application... \e[0m"
    yarn start >> ~/install.log 2>&1 &
    echo -e "\e[33m Started Ultra Application Successfully... \e[0m"
    ~/work/bb/blackboard/tools/admin/UpdateUltraUIDecision.sh --on
    print_congrats
  fi
}

removeSudoTimerAndInputFile() {
  sudo rm /etc/sudoers.d/timeout
  rm $input_file
}

START_TIME=$(date +"%Y-%m-%d %H:%M:%S")
echo "Script started at: $START_TIME"

# Check if the user pressed Enter (continue_key will be empty)
if [ -z "$continue_key" ]; then
install_Learn || error "Failed to install Learn"
install_ultra_router || error "Failed to install Learn"
install_ultra || error "Failed to install Ultra"
removeSudoTimerAndInputFile || { error "Error: Failed to remove sudo timer."; exit 1; }
else
  echo "Install Learn aborted due to no input from the user."
fi

 END_TIME=$(date +"%Y-%m-%d %H:%M:%S")
  echo "Script ended at: $END_TIME"

  # Optional: Calculate duration
  START_SEC=$(date -j -f "%Y-%m-%d %H:%M:%S" "$START_TIME" "+%s")
  END_SEC=$(date -j -f "%Y-%m-%d %H:%M:%S" "$END_TIME" "+%s")
  DURATION=$(($END_SEC - $START_SEC))
  echo "$DURATION" > ~/install_script_duration.txt

  # Read durations from files
  pre_duration=$(cat ~/pre_script_duration.txt)
  main_duration=$(cat ~/main_script_duration.txt)
  post_duration=$(cat ~/install_script_duration.txt)

  # Sum the durations
  total_duration=$(($pre_duration + $main_duration + $post_duration))

  # Convert total duration to minutes
  total_minutes=$(($total_duration / 60))

  # Get the current date and time
  current_datetime=$(date '+%Y-%m-%d %H:%M:%S')

  echo "Date and Time: $current_datetime, Username: $username, Total duration: $total_minutes minutes"  

  rm ~/pre_script_duration.txt ~/main_script_duration.txt ~/install_script_duration.txt ~/total_minutes.txt