#!/bin/bash

# Script to install Git, configure basic user info, and set up Overleaf authentication
# for cloning a specific project.

# --- Configuration ---
OVERLEAF_PROJECT_ID="683581efaba44761da964c7d"
CLONE_DIR_NAME="Team_Achievements"
# The username 'git' is derived from your desired clone URL format: https://git@git.overleaf.com/...
OVERLEAF_GIT_USERNAME="git"
OVERLEAF_HOST="git.overleaf.com"

# --- Helper Functions ---
check_command_success() {
    # $? is the exit status of the last executed command. 0 means success.
    if [ $? -ne 0 ]; then
        echo "Error: The last command failed. Exiting script."
        exit 1
    fi
}

prompt_for_confirmation() {
    while true; do
        read -r -p "$1 [y/N]: " response
        case "$response" in
            [yY][eE][sS]|[yY])
                return 0
                ;;
            [nN][oO]|[nN]|"") # Default to No if Enter is pressed
                return 1
                ;;
            *)
                echo "Invalid input. Please answer 'y' or 'n'."
                ;;
        esac
    done
}

# --- Main Script ---
echo "Starting Overleaf Git Setup Script..."

# 1. Update package list and install Git
if ! command -v git &> /dev/null; then
    echo -e "\nGit is not installed."
    if prompt_for_confirmation "Do you want to install Git?"; then
        echo "Updating package list (requires sudo)..."
        sudo apt update
        check_command_success

        echo "Installing Git (requires sudo)..."
        sudo apt install -y git
        check_command_success
        echo "Git installed successfully."
    else
        echo "Git installation skipped. The script cannot proceed without Git. Exiting."
        exit 1
    fi
else
    echo -e "\nGit is already installed."
fi

# 2. Configure Git user details (good practice, though not strictly for cloning)
echo -e "\n--- Configuring Global Git User Details ---"
echo "These details will be used for your commits."

CURRENT_GIT_USER_NAME=$(git config --global user.name)
CURRENT_GIT_USER_EMAIL=$(git config --global user.email)

if [ -z "$CURRENT_GIT_USER_NAME" ] || prompt_for_confirmation "Current Git user name is '$CURRENT_GIT_USER_NAME'. Update it?"; then
    read -p "Enter your Git user name (e.g., Your Name): " GIT_CONFIG_USER_NAME
    git config --global user.name "$GIT_CONFIG_USER_NAME"
    check_command_success
fi

if [ -z "$CURRENT_GIT_USER_EMAIL" ] || prompt_for_confirmation "Current Git user email is '$CURRENT_GIT_USER_EMAIL'. Update it?"; then
    read -p "Enter your Git user email (e.g., your.email@example.com): " GIT_CONFIG_USER_EMAIL
    git config --global user.email "$GIT_CONFIG_USER_EMAIL"
    check_command_success
fi
echo "Git global user details configured."

# 3. Get Overleaf Token from user
echo -e "\n--- Overleaf Authentication Setup ---"
echo "To clone the private Overleaf project, you need an authentication token."
echo "This token will be stored locally using Git's credential helper."
# The token you provided earlier: olp_2a17ZDVY0Y13IQByBAFj6bpRKWND07e10RsFK
# It's better to ask the user to input it, in case it changes or they want to use a different one.
read -s -p "Enter your Overleaf authentication token: " OVERLEAF_TOKEN
echo # Newline after secret input
if [ -z "$OVERLEAF_TOKEN" ]; then
    echo "Error: No Overleaf authentication token provided. Exiting."
    exit 1
fi

# 4. Configure Git credential helper to store credentials
echo -e "\nConfiguring Git credential helper to 'store' credentials..."
echo "This will save your token for ${OVERLEAF_HOST} in plain text in ~/.git-credentials."
git config --global credential.helper store
check_command_success
echo "Git credential helper configured."

# 5. Pre-approve/store the credentials for Overleaf
echo -e "\nStoring Overleaf credentials for user '${OVERLEAF_GIT_USERNAME}' on host '${OVERLEAF_HOST}'..."
# The input format for 'git credential approve' is line-by-line key-value pairs.
# This command feeds the credential details to the helper configured above (store).
printf "protocol=https\nhost=%s\nusername=%s\npassword=%s\n" "$OVERLEAF_HOST" "$OVERLEAF_GIT_USERNAME" "$OVERLEAF_TOKEN" | git credential approve
check_command_success
echo "Overleaf credentials should now be stored."

# Secure the .git-credentials file
if [ -f "$HOME/.git-credentials" ]; then
    chmod 600 "$HOME/.git-credentials"
    echo "Permissions for ~/.git-credentials set to 600 (read/write for user only)."
fi

# 6. Clone the Overleaf project
TARGET_CLONE_URL="https://${OVERLEAF_GIT_USERNAME}@${OVERLEAF_HOST}/${OVERLEAF_PROJECT_ID}" # Using the username in the URL
echo -e "\nAttempting to clone Overleaf project..."
echo "URL: ${TARGET_CLONE_URL}"
echo "Target directory: ${CLONE_DIR_NAME}"

if [ -d "$CLONE_DIR_NAME" ]; then
    if prompt_for_confirmation "Directory '${CLONE_DIR_NAME}' already exists. Do you want to remove it and re-clone?"; then
        echo "Removing existing directory: ${CLONE_DIR_NAME}..."
        rm -rf "$CLONE_DIR_NAME"
        check_command_success
    else
        echo "Clone aborted as directory '${CLONE_DIR_NAME}' already exists and was not removed."
        echo "Setup partially complete. Git is installed and credentials might be stored."
        exit 0
    fi
fi

# GIT_TERMINAL_PROMPT=0 can be prepended to git clone to prevent interactive password prompts
# if the credential helper somehow fails, but with 'approve' it should work.
GIT_TERMINAL_PROMPT=0 git clone "${TARGET_CLONE_URL}" "${CLONE_DIR_NAME}"
if [ $? -ne 0 ]; then
    echo "Error: Git clone failed."
    echo "Please check the following:"
    echo "1. Your Overleaf authentication token ('${OVERLEAF_TOKEN:0:3}...${OVERLEAF_TOKEN: -3}') is correct and has not expired."
    echo "2. The Overleaf Project ID ('${OVERLEAF_PROJECT_ID}') is correct."
    echo "3. You have network access to ${OVERLEAF_HOST}."
    echo "4. If the directory '${CLONE_DIR_NAME}' was re-created, ensure it was removed properly."
    echo "5. Review the contents of ~/.git-credentials (use with caution as it contains your token)."
    exit 1
fi

echo -e "\nSuccessfully cloned Overleaf project into '${CLONE_DIR_NAME}' directory."
echo "You can now navigate to the project directory using: cd ${CLONE_DIR_NAME}"
echo -e "\n--- Setup Complete! ---"

exit 0
