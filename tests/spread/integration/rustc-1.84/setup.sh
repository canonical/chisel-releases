# Setup which mimics the spread environment

# check FILE_DIR is set
if [[ -z "$FILE_DIR" ]]; then
    echo "Error: FILE_DIR is not set"
    exit 1
fi

# find PROJECT_PATH by walking up until you find chisel.yaml
PROJECT_PATH=$(realpath "$FILE_DIR")
# walk up until you find chisel.yaml
while [[ ! -f "$PROJECT_PATH/chisel.yaml" ]]; do
    PROJECT_PATH=$(dirname "$PROJECT_PATH")
    if [[ "$PROJECT_PATH" == "/" ]]; then
        echo "Error: Could not find chisel.yaml"
        exit 1
    fi
done
export PROJECT_PATH

# add lib to PATH
export PATH="$FILE_DIR/../../lib/:$PATH"

# setup TMPDIR to avoid using /tmp which we might not have write access to
mkdir -p "$PROJECT_PATH/tests/tmp"
export TMPDIR="$PROJECT_PATH/tests/tmp"

# patch chroot with sudo if needed
if ! chroot "$PROJECT_PATH" true 2>/dev/null; then
    # shellcheck disable=SC2032
    function chroot() {
       # shellcheck disable=SC2033
        sudo chroot "$@"
    }
fi

# all tests expect to run from their directory
# shellcheck disable=SC2064
trap "cd \"$PWD\" || true" EXIT
cd "$FILE_DIR" || exit 1

# use trap to echo a message on exit
on_exit() {
    case $? in
        0) echo -e "\e[32mTest passed\e[0m: $0" ;;
        130) echo -e "\e[33mTest interrupted\e[0m: $0" ;;
        *) echo -e "\e[31mTest failed\e[0m: $0" ;;
    esac
}
trap on_exit EXIT
trap 'exit 130' INT TERM

# Set bash options
set -euxo pipefail
