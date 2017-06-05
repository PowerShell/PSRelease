cat /etc/*-release

# Install PowerShell

curl -o download.sh https://raw.githubusercontent.com/PowerShell/PowerShell/master/tools/download.sh
if [[ $? -ne 0 ]] ; then
    exit 1
fi

chmod +x ./download.sh
if [[ $? -ne 0 ]] ; then
    exit 1
fi

./download.sh
if [[ $? -ne 0 ]] ; then
    exit 1
fi