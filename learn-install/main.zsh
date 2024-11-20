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

computer_name=$(scutil --get ComputerName)


error() {
  local input_message="$1"
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
   echo -e "\e[31mError at $timestamp: $input_message\e[0m" >> ~/install.log
  tail -10f ~/install.log && exit
  return 1
}

install_corretto() {
  # Check if Amazon Corretto 11 JDK is installed in the /Library/Java/JavaVirtualMachines directory
  if [ -d "/Library/Java/JavaVirtualMachines/amazon-corretto-11.jdk" ] || [ -d "/usr/local/Caskroom/corretto" ]; then
    echo "\e[33m# Amazon Corretto 11 JDK is installed. Removing..."
    echo $password | sudo -S rm -rf /Library/Java/JavaVirtualMachines/amazon-corretto-11.jdk /usr/local/Caskroom/corretto
  else
    echo "Amazon Corretto 11 JDK is not installed."
  fi

  brew install cask
  if [ $? -ne 0 ]; then
    echo "Failed to install Homebrew Cask."
    return 1
  fi
  echo -e "\e[33m# Install Corretto 11\e[0m"
  brew install --cask corretto@11 &&
  if [ $? -ne 0 ]; then
    echo "Failed to install Corretto 11."
    return 1
  fi
  echo -e "\e[33m# Add JAVA_HOME to .zshrc and source it\e[0m"
  echo '\nexport JAVA_HOME=$(/usr/libexec/java_home -v 11)' >> ~/.zshrc &&

  source ~/.zshrc

  if [[ -n "$JAVA_HOME" ]]; then
  echo "\e[33m# JAVA_HOME variable added successfully.\e[0m"
  else
    echo "JAVA_HOME variable not found."
  fi

}

installPostgres() {
  echo -e "\e[33m# Install PostgreSQL 12\e[0m"
  brew install postgresql@12

  echo -e "\e[33m# Add PostgreSQL 12 to PATH in .zshrc\e[0m"
  echo '\nexport PATH="/opt/homebrew/opt/postgresql@12/bin:$PATH"' >> $HOME/.zshrc

  echo -e "\e[33m# Set PGDATA for PostgreSQL 12 in .zshrc\e[0m"
  echo '\nexport PGDATA=/opt/homebrew/var/postgresql@12' >> $HOME/.zshrc

  echo -e "\e[33m# Tap homebrew/services and homebrew/core\e[0m"
  brew tap homebrew/services
  # brew tap homebrew/core // Removing this as it is no longer needed on Homebrew 2.0.0 

  echo -e "\e[33m# Source .zshrc to apply changes\e[0m"
  source ~/.zshrc

  echo -e "\e[33m# Start PostgreSQL 12 as a service\e[0m"
  brew services start postgresql@12

  echo -e "\e[33m# Source .zshrc again to ensure changes are applied\e[0m"
  source ~/.zshrc
}

createUserAndChangePassword() {
  source ~/.zshrc

  echo -e "\e[33m# Create superuser and createuser roles in PostgreSQL\e[0m"
  sleep 1 # Most of the time it is failling to create user so  wait for a second before creating the user
  createuser -s -r postgres
   if [ $? -eq 0 ]; then
    echo "User created successfully."
  else
    echo "Failed to create user. Retrying... "
    sleep 1  # Optional: wait for a second before retrying
    source ~/.zshrc
    createuser -s -r postgres
  fi

  echo -e "\e[33m# Set password for the 'postgres' user in PostgreSQL\e[0m"
  psql -U postgres -c "alter user postgres PASSWORD 'postgres'"
}

updateConfFiles() {
  echo -e "\e[33m# Update authentication method in pg_hba.conf\e[0m"
  sed -i '' 's/trust/password/g' /opt/homebrew/var/postgresql@12/pg_hba.conf

  echo -e "\e[33m# Update max_connections in postgresql.conf\e[0m"
  sed -i '' 's/max_connections = 100/max_connections = 300/g' /opt/homebrew/var/postgresql@12/postgresql.conf

  echo -e "\e[33m# Restart PostgreSQL 12 service\e[0m"
  brew services restart postgresql@12
}

setupPostgres() {
  installPostgres &&
  createUserAndChangePassword &&
  updateConfFiles &&
  source ~/.zshrc
}

start() {
  echo -e "\e[33m# Change the default shell to zsh\e[0m"
  echo $password | sudo -S chsh -s $(which zsh)

  echo -e "\e[33m# Create a 'work' directory and an empty .zshrc file\e[0m"
  mkdir $HOME/work && touch $HOME/.zshrc

  # echo -e "\e[33m# Install Xcode command line tools\e[0m"
  # xcode-select --install

  # echo -e "\e[33m# Allow the specified user to run Homebrew install without a password\e[0m"
  # echo "$USER ALL=(ALL) NOPASSWD: /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)\"" | sudo EDITOR="tee -a" visudo

  echo -e "\e[33m# Install Homebrew with the specified username and password\e[0m"
  echo | /bin/bash -c "$(curl -fsSLu $userName:$password https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"

  echo -e "\e[33m# Add Homebrew shell initialization to .zprofile\e[0m"
  (echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> /Users/$USER/.zprofile

  echo -e "\e[33m# Set up Homebrew environment\e[0m"
  eval "$(/opt/homebrew/bin/brew shellenv)"

  echo -e "\e[33m# Add Homebrew bin directory to PATH in .zshrc\e[0m"
  echo 'export PATH="/opt/homebrew/bin:$PATH"' >> ~/.zshrc

  echo -e "\e[33m# Reload the .zshrc file\e[0m"
  source ~/.zshrc
}

setupGit() {
    local userName="$userName"
    # Source the zshrc file
    source ~/.zshrc

    cd $HOME &&

    # Install or upgrade Git and Git LFS
    echo -e "\e[33mInstalling or upgrading Git and Git LFS\e[0m"
    brew install git || brew upgrade git &&
    brew install git-lfs || brew upgrade git-lfs &&

    # Install Git LFS
    echo -e "\e[33mInstalling Git LFS\e[0m"
    git lfs install &&

    # Configure Git
    echo -e "\e[33mConfiguring Git\e[0m"
    git config --global merge.renamelimit 999999 &&
    git config --global diff.renamelimit 999999 &&
    git config --global "lfs.https://stash.bbpd.io/learn/learn.git/info/lfs.locksverify" false &&
    git config --global "lfs.contenttype" false &&

    # Configure Git user
    echo -e "\e[33mConfiguring Git user\e[0m"
    # read "?Enter your fullname (FirstName LastName) : " firstName &&
    git config --global user.name "$userName"
    git config --global user.email "$userEmail"

    # Configure system settings
    echo -e "\e[33mConfiguring system settings\e[0m"
    echo "$password" | sudo -S sh -c 'echo "kern.maxfiles=65536
    kern.maxfilesperproc=65536" > /etc/sysctl.conf' &&

    # Configure LaunchDaemons
    echo -e "\e[33mConfiguring LaunchDaemons\e[0m"
    echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>Label</key>
        <string>limit.maxfiles</string>
        <key>ProgramArguments</key>
        <array>
            <string>launchctl</string>
            <string>limit</string>
            <string>maxfiles</string>
            <string>65536</string>
            <string>65536</string>
        </array>
        <key>RunAtLoad</key>
        <true/>
        <key>ServiceIPC</key>
        <false/>
    </dict>
    </plist>' | sudo tee /Library/LaunchDaemons/limit.maxfiles.plist &&

    echo '<!DOCTYPE plist PUBLIC "-//Apple/DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>Label</key>
        <string>limit.maxproc</string>
        <key>ProgramArguments</key>
        <array>
            <string>launchctl</string>
            <string>limit</string>
            <string>maxproc</string>
            <string>2048</string>
            <string>2048</string>
        </array>
        <key>RunAtLoad</key>
        <true />
        <key>ServiceIPC</key>
        <false />
    </dict>
    </plist>' | sudo tee /Library/LaunchDaemons/limit.maxproc.plist
}

addHosts() {
  sudo scutil --set HostName $computer_name &&
  sudo sed -i '' 's/127.0.0.1	localhost/127.0.0.1	mylearn.int.bbpd.io/g' /etc/hosts &&
  echo "127.0.0.1   localhost localhost:localdomain $computer_name mylearn.int.bbpd.io" | sudo tee -a  /etc/hosts
}

cloneLearn() {

  cd $HOME/work &&

  GIT_SSH_COMMAND='ssh -o StrictHostKeyChecking=no' caffeinate git clone --recursive --shallow-submodules --depth 1 --jobs 5 git@github.com:blackboard-learn/learn.git &&

  git clone git@github.com:blackboard-learn/learn.util.git &&

  cd learn.util &&

  sudo cp -R users/template users/$USER &&

  cd $HOME &&

  sudo sed -i '' "s/<your username>/$USER/g" $HOME/work/learn.util/users/$USER/gradle/gradle.git.properties &&

  sudo sed -i '' "s/<your username>/$USER/g" $HOME/work/learn.util/users/$USER/learnConfigs/spgit.properties &&

  sudo sed -i '' "s/<your email address>/$userEmail/g" $HOME/work/learn.util/users/$USER/gradle/gradle.git.properties &&

  sudo sed -i '' "s/<your email address>/$userEmail/g" $HOME/work/learn.util/users/$USER/learnConfigs/spgit.properties &&

  mkdir -p $HOME/work/bb/blackboard-data &&

  source ~/.zshrc &&

  cd $HOME/work/learn.util &&

  source sourceall.sh &&

  echo '\nexport GIT_ROOT=$HOME/work/learn \nexport PATH=$PATH:$GIT_ROOT/bin \nsource $HOME/work/learn.util/sourceall.sh \nsource $HOME/scripts/current_sp.sh' >> $HOME/.zshrc &&

  source $HOME/.zshrc

  mkdir -p $HOME/.gradle &&

  touch $HOME/.gradle/gradle.properties &&

  cd ~/work/learn.util &&

  mkdir -p $WORK_HOME/scripts/logs &&

  sp git &&

  source $HOME/.zshrc &&

  echo '\nexport BLACKBOARD_HOME=$HOME/work/bb/blackboard
  \nexport bbHome=$HOME/work/bb/blackboard
  \nexport LEARN_UTIL_HOME=$HOME/work/learn.util/users/$USER
  \nexport YARN_CACHE_FOLDER=$HOME/work/caches/yarn
  \nexport PGHOST=localhost
  \nexport LEARN_URL="https://mylearn.int.bbpd.io"
  \nexport LEARN_USERNAME="administrator"
  \nexport LEARN_PASSWORD="changeme"' >> $HOME/.zshrc &&

  source $HOME/.zshrc &&


}

cloneUltra() {
  
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash &&

  source ~/.zshrc &&

  nvm install lts/iron &&

  nvm alias default lts/iron &&

  brew install yarn &&

  brew install pkg-config cairo pango libpng jpeg giflib librsvg pixman &&

  # Attempt to install setuptools via pip3
  pip3 install setuptools

  # Check if the pip3 install command failed due to an externally-managed-environment error
  if [ $? -ne 0 ]; then
      echo "pip3 install failed, checking Python installation method..."

      # Check if Python is provided by Homebrew
      PYTHON_PATH=$(which python3)
      if [[ $PYTHON_PATH == /opt/homebrew/bin/python3 ]]; then
          echo "Python is provided by Homebrew. Installing setuptools via Homebrew..."
          brew install python-setuptools
      else
          echo "Python is not provided by Homebrew. Please check your Python installation."
      fi
  else
      echo "setuptools installed successfully via pip3."
  fi

  echo 'autoload -U add-zsh-hook
    load-nvmrc() {
      local nvmrc_path
      nvmrc_path="$(nvm_find_nvmrc)"

      if [ -n "$nvmrc_path" ]; then
        local nvmrc_node_version
        nvmrc_node_version=$(nvm version "$(cat "${nvmrc_path}")")

      if [ "$nvmrc_node_version" = "N/A" ]; then
          nvm install
        elif [ "$nvmrc_node_version" != "$(nvm version)" ]; then
          nvm use
        fi
      elif [ -n "$(PWD=$OLDPWD nvm_find_nvmrc)" ] && [ "$(nvm version)" != "$(nvm version \ndefault)" ]; then
        echo "Reverting to nvm default version"
        nvm use default
      fi
    }
    add-zsh-hook chpwd load-nvmrc
    load-nvmrc' | tee -a $HOME/.zshrc &&

  source ~/.zshrc &&

  cd $HOME/work &&

  git clone git@github.com:blackboard-learn/ultra.git &&

  cd ultra &&

  nvm use &&

  cd $HOME &&

  }

cloneUltraRouter() {
  cd $HOME/work &&
  echo -e "\e[33mStarted cloning Ultra-router\e[0m"

  git clone git@github.com:blackboard-learn/ultra-router.git

  echo -e "\e[33mInstalling openresty\e[0m"
  # The below is not required for fresh install
  # brew uninstall openresty
  # brew uninstall openresty-openssl
  # brew untap homebrew/nginx
  # brew untap denji/nginx
  brew tap openresty/brew
  brew install geoip
  brew install openresty
}

cloneProjects() {
  addHosts
  if [ $? -eq 0 ]; then
    cloneLearn &&
    cloneUltra &&
    cloneUltraRouter
  else
    echo "Error: Failed to clone projects" >> ~/install.log
  fi
}


setupZScalar() {
  cp -R ~/learn-install/zscaler-certs ~/work/zscaler-certs &&
  password="changeit"
  echo $password | sudo keytool -import -trustcacerts -alias zscaler_root_ca -file ~/work/zscaler-certs/ZscalerRootCA.cer -cacerts <<< "yes" &&
  export NODE_EXTRA_CA_CERTS=~/work/zscaler-certs/ZscalerRootCA.pem
}

START_TIME=$(date +"%Y-%m-%d %H:%M:%S")
echo "Script started at: $START_TIME"

start || error "Failed to install homebrew"

if [ $? -eq 0 ];
then
  install_corretto || { error "Error: Failed to install JDK or set JAVA_HOME."; exit 1; }
  setupZScalar || { error "Error: Failed to setup ZScalar."; exit 1; }
  setupPostgres || { error "Error: Failed to setup Postgres."; exit 1; }
  setupGit "$userName"|| { error "Error: Failed to setup Git."; exit 1; }
  cloneProjects || { error "Error: Failed to clone projects."; exit 1; }
else
  error "Error: Failed to start"
fi

END_TIME=$(date +"%Y-%m-%d %H:%M:%S")
echo "Script ended at: $END_TIME"

# Optional: Calculate duration
START_SEC=$(date -j -f "%Y-%m-%d %H:%M:%S" "$START_TIME" "+%s")
END_SEC=$(date -j -f "%Y-%m-%d %H:%M:%S" "$END_TIME" "+%s")
DURATION=$(($END_SEC - $START_SEC))
echo "$DURATION" > ~/main_script_duration.txt

~/learn-install/install.zsh


