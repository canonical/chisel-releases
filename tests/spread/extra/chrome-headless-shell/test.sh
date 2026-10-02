if [ $(uname -m) != "x86_64" ]; then
    echo "Skipping test: incompatible architecture"
    exit 0
fi

apt-get update
apt-get install -y --no-install-recommends unzip

required_slices=( \
    libasound2t64_libs \
    libatk-bridge2.0-0t64_libs \
    libatk1.0-0t64_libs \
    libatspi2.0-0t64_libs \
    libcairo2_libs \
    libcups2t64_libs \
    libdbus-1-3_libs \
    libdrm2_libs \
    libfontconfig1_libs \
    libgbm1_libs \
    libglib2.0-0t64_libs \
    libnspr4_libs \
    libnss3_libs \
    libpango-1.0-0_libs \
    libx11-6_libs \
    libxcb1_libs \
    libxcomposite1_libs \
    libxdamage1_libs \
    libxext6_libs \
    libxfixes3_libs \
    libxkbcommon0_libs \
    libxrandr2_libs \
    libudev1_libs \
    fonts-liberation_fonts \
    fonts-freefont-ttf_fonts \
    fonts-noto-color-emoji_fonts \
    fonts-unifont_fonts \
    fonts-ipafont-gothic_fonts \
    fonts-wqy-zenhei_fonts \
    fonts-tlwg-loma-otf_fonts \
  )

# install slices
rootfs="$(install-slices ${required_slices[@]})"

# download chrome-headless-shell . Link is from https://googlechromelabs.github.io/chrome-for-testing/ .
chrome_version=145.0.7632.77
chrome_sha256sum="6652fb5003107bc775318af76176e09a7769b01723dac2e2838883314191413e"

mkdir $rootfs/chrome
curl \
    --fail \
    --output $rootfs/chrome/chrome-headless-shell.zip \
    https://storage.googleapis.com/chrome-for-testing-public/$chrome_version/linux64/chrome-headless-shell-linux64.zip

# Validate checksum
sha256sum $rootfs/chrome/chrome-headless-shell.zip | grep $chrome_sha256sum

unzip -d $rootfs/chrome/ $rootfs/chrome/chrome-headless-shell.zip
rm $rootfs/chrome/chrome-headless-shell.zip

# chrome crashes without /proc and /dev mounted
mkdir -p "${rootfs}"/proc
mount --bind /proc "${rootfs}"/proc
mkdir -p "${rootfs}/dev"
mount --bind /dev "${rootfs}/dev"

chroot "${rootfs}" /chrome/chrome-headless-shell-linux64/chrome-headless-shell \
    --no-sandbox \
    --single-process \
    --print-to-pdf https://google.com

# Cleanup
umount "${rootfs}"/proc
umount "${rootfs}"/dev
apt-get remove -y unzip
