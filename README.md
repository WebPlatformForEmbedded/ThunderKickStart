# ThunderKickStart
Build environment to kick start Thunder Plugin development.

## Prerequisites
You need the following packets
1. repo
2. git
3. python3
## Supported IDE
1. vscode
## Get started
``` shell
repo init -u git@github.com:WebPlatformForEmbedded/ThunderKickStart.git -m thunder-ml-development.xml
repo sync
./prepare.env
code ${USER}-Thunder.code-workspace
```

## Update sources
``` shell
repo sync
```

## Install Repo
``` shell
curl https://storage.googleapis.com/git-repo-downloads/repo > ~/.local/bin/repo
chmod a+rx ~/.local/bin/repo
```
