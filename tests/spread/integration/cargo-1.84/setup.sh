export PROJECT_PATH=$(realpath "$FILE_DIR"/../../../..)
export PATH="$FILE_DIR/../../lib/:$PATH"  # add lib to PATH
# setup TMPDIR to avoid using /tmp which we might not have write access to
mkdir -p "$PROJECT_PATH/tests/tmp"
export TMPDIR="$PROJECT_PATH/tests/tmp"
# check if we need sudo to do chroot
chroot "$PROJECT_PATH" true 2>/dev/null || SUDO="sudo"
# use trap to echo a message on exit
on_exit() {
    if [[ $? -ne 0 ]]; then
        echo -e "\e[31mTest failed\e[0m: $0"
    else
        echo -e "\e[32mTest passed\e[0m: $0"
    fi
}
trap on_exit EXIT
set -euxo pipefail