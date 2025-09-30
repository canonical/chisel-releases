# spellchecker: ignore confnew
# shim apt to apt with -o Dpkg::Options::="--force-confnew"
# to avoid interactive prompts about config files in the CI
# https://github.com/canonical/chisel-releases/issues/659
_old_apt=$(command -v apt)
apt() { "$_old_apt" -o Dpkg::Options::="--force-confnew" "$@"; }