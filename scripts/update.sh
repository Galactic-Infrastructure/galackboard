#!/bin/sh

cd /home/npinsker/codex-blackboard

git fetch

UPSTREAM=${1:-'@{u}'}
LOCAL=$(git rev-parse @)
REMOTE=$(git rev-parse "$UPSTREAM")
BASE=$(git merge-base @ "$UPSTREAM")

if [ $LOCAL = $REMOTE ]; then
    echo "Up to date"
elif [ $LOCAL = $BASE ]; then
    echo "Pulling and reloading..."
    git pull && bash /home/npinsker/codex-blackboard/private/update.sh
elif [ $REMOTE = $BASE ]; then
    echo "Need to push"
else
    echo "Diverged; trying to pull..."
    git pull && bash /home/npinsker/codex-blackboard/private/update.sh
fi
