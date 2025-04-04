#!/bin/bash

USER_CONFIG1_PATH="${HOME}/e3pro_data/config"
USER_CONFIG2_PATH="${HOME}/e3max_data/config"
MOONRAKER_CONFIG1="${HOME}/e3pro_data/config/moonraker.conf"
MOONRAKER_CONFIG2="${HOME}/e3max_data/config/moonraker.conf"
KLIPPER_PATH="${HOME}/klipper"
KLIPPER_VENV_PATH="${KLIPPER_VENV:-${HOME}/klippy-env}"

OLD_K_SHAKETUNE_VENV="${HOME}/klippain_shaketune-env"
K_SHAKETUNE_PATH="${HOME}/klippain_shaketune"

SOURCE_URL="https://github.com/Wes-3D/klippain-shaketune.git"

set -eu
export LC_ALL=C


function preflight_checks {
    if [ "$EUID" -eq 0 ]; then
        echo "[PRE-CHECK] This script must not be run as root!"
        exit -1
    fi

    if ! command -v python3 &> /dev/null; then
        echo "[ERROR] Python 3 is not installed. Please install Python 3 to use the Shake&Tune module!"
        exit -1
    fi

    if [ "$(sudo systemctl list-units --full -all -t service --no-legend | grep -F 'klipper-e3pro.service')" ]; then
        printf "[PRE-CHECK] Klipper service found! Continuing...\n\n"
    else
        echo "[ERROR] Klipper service not found, please install Klipper first!"
        exit -1
    fi

    install_package_requirements
}

# Function to check if a package is installed
function is_package_installed {
    dpkg -s "$1" &> /dev/null
    return $?
}

function install_package_requirements {
    packages=("libopenblas-dev" "libatlas-base-dev")
    packages_to_install=""

    for package in "${packages[@]}"; do
        if is_package_installed "$package"; then
            echo "$package is already installed"
        else
            packages_to_install="$packages_to_install $package"
        fi
    done

    if [ -n "$packages_to_install" ]; then
        echo "Installing missing packages: $packages_to_install"
        sudo apt update && sudo apt install -y $packages_to_install
    fi
}

function check_download {
    local shaketunedirname shaketunebasename
    shaketunedirname="$(dirname ${K_SHAKETUNE_PATH})"
    shaketunebasename="$(basename ${K_SHAKETUNE_PATH})"

    if [ ! -d "${K_SHAKETUNE_PATH}" ]; then
        echo "[DOWNLOAD] Downloading Klippain Shake&Tune module repository..."
        if git -C $shaketunedirname clone https://github.com/Wes-3D/klippain-shaketune.git $shaketunebasename; then
            chmod +x ${K_SHAKETUNE_PATH}/install.sh
            printf "[DOWNLOAD] Download complete!\n\n"
        else
            echo "[ERROR] Download of Klippain Shake&Tune module git repository failed!"
            exit -1
        fi
    else
        printf "[DOWNLOAD] Klippain Shake&Tune module repository already found locally. Continuing...\n\n"
    fi
}

function setup_venv {
    if [ ! -d "${KLIPPER_VENV_PATH}" ]; then
        echo "[ERROR] Klipper's Python virtual environment not found!"
        exit -1
    fi

    if [ -d "${OLD_K_SHAKETUNE_VENV}" ]; then
        echo "[INFO] Old K-Shake&Tune virtual environement found, cleaning it!"
        rm -rf "${OLD_K_SHAKETUNE_VENV}"
    fi

    source "${KLIPPER_VENV_PATH}/bin/activate"
    echo "[SETUP] Installing/Updating K-Shake&Tune dependencies..."
    pip install --upgrade pip
    pip install -r "${K_SHAKETUNE_PATH}/requirements.txt"
    deactivate
    printf "\n"
}

function link_extension1 {
    # Reusing the old linking extension function to cleanup and remove the macros for older S&T versions

    if [ -d "${HOME}/klippain_config" ] && [ -f "${USER_CONFIG1_PATH}/.VERSION" ]; then
        if [ -d "${USER_CONFIG1_PATH}/scripts/K-ShakeTune" ]; then
            echo "[INFO] Old K-Shake&Tune macro folder found, cleaning it!"
            rm -d "${USER_CONFIG1_PATH}/scripts/K-ShakeTune"
        fi
    else
        if [ -d "${USER_CONFIG1_PATH}/K-ShakeTune" ]; then
            echo "[INFO] Old K-Shake&Tune macro folder found, cleaning it!"
            rm -d "${USER_CONFIG1_PATH}/K-ShakeTune"
        fi
    fi
}


function link_extension2 {
    # Reusing the old linking extension function to cleanup and remove the macros for older S&T versions

    if [ -d "${HOME}/klippain_config" ] && [ -f "${USER_CONFIG2_PATH}/.VERSION" ]; then
        if [ -d "${USER_CONFIG2_PATH}/scripts/K-ShakeTune" ]; then
            echo "[INFO] Old K-Shake&Tune macro folder found, cleaning it!"
            rm -d "${USER_CONFIG2_PATH}/scripts/K-ShakeTune"
        fi
    else
        if [ -d "${USER_CONFIG2_PATH}/K-ShakeTune" ]; then
            echo "[INFO] Old K-Shake&Tune macro folder found, cleaning it!"
            rm -d "${USER_CONFIG2_PATH}/K-ShakeTune"
        fi
    fi
}

function link_module {
    if [ ! -d "${KLIPPER_PATH}/klippy/extras/shaketune" ]; then
        echo "[INSTALL] Linking Shake&Tune module to Klipper extras"
        ln -frsn ${K_SHAKETUNE_PATH}/shaketune ${KLIPPER_PATH}/klippy/extras/shaketune
    else
        printf "[INSTALL] Klippain Shake&Tune Klipper module is already installed. Continuing...\n\n"
    fi
}

function add_updater1 {
    update_section=$(grep -c '\[update_manager[a-z ]* Klippain-ShakeTune\]' $MOONRAKER_CONFIG1 || true)
    if [ "$update_section" -eq 0 ]; then
        echo -n "[INSTALL] Adding update manager to moonraker.conf..."
        cat <<EOF >>$MOONRAKER_CONFIG1

## Klippain Shake&Tune automatic update management
[update_manager Klippain-ShakeTune]
type: git_repo
origin: ${SOURCE_URL}
path: ~/klippain_shaketune
virtualenv: ${KLIPPER_VENV_PATH}
requirements: requirements.txt
system_dependencies: system-dependencies.json
primary_branch: main
managed_services: klipper
EOF
    fi
}

function add_updater2 {
    update_section=$(grep -c '\[update_manager[a-z ]* Klippain-ShakeTune\]' $MOONRAKER_CONFIG2 || true)
    if [ "$update_section" -eq 0 ]; then
        echo -n "[INSTALL] Adding update manager to moonraker.conf..."
        cat <<EOF >>$MOONRAKER_CONFIG2

## Klippain Shake&Tune automatic update management
[update_manager Klippain-ShakeTune]
type: git_repo
origin: ${SOURCE_URL}
path: ~/klippain_shaketune
virtualenv: ${KLIPPER_VENV_PATH}
requirements: requirements.txt
system_dependencies: system-dependencies.json
primary_branch: main
managed_services: klipper
EOF
    fi
}

function restart_klipper {
    echo "[POST-INSTALL] Restarting Klipper..."
    sudo systemctl restart klipper-e3pro
    sudo systemctl restart klipper-e3max
}

function restart_moonraker {
    echo "[POST-INSTALL] Restarting Moonraker..."
    sudo systemctl restart moonraker-e3pro
    sudo systemctl restart moonraker-e3max
}


printf "\n=============================================\n"
echo "- Klippain Shake&Tune module install script -"
printf "=============================================\n\n"


# Run steps
preflight_checks
check_download
setup_venv
link_extension1
link_extension2
link_module
add_updater1
add_updater2
restart_klipper
restart_moonraker
