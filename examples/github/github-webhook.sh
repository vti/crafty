#!/bin/sh

STDIN=`cat`

if [ "$HTTP_X_GITHUB_EVENT" = "ping" ]; then
    echo "Status: 200";
    echo
    echo "Pong"
elif [ "$HTTP_X_GITHUB_EVENT" = "push" ]; then
    BRANCH=$(echo $STDIN | jq -r '.ref')
    REV=$(echo $STDIN | jq -r '.head_commit.id')
    AUTHOR=$(echo $STDIN | jq -r '.head_commit.author.name')
    MESSAGE=$(echo $STDIN | jq -r '.head_commit.message')

    echo "Status: 200";
    echo "X-Crafty-Build-Branch: $BRANCH"
    echo "X-Crafty-Build-Rev: $REV"
    echo "X-Crafty-Build-Author: $AUTHOR"
    echo "X-Crafty-Build-Message: $MESSAGE"
    echo
    echo "Ok"
else
    echo "Status: 400";
    echo
    echo "Unknown event"
fi

exit 0
