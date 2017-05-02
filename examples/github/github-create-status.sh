#!/bin/sh

# Available variables
#
#    CRAFTY_BUILD_PROJECT
#    CRAFTY_BUILD_REV
#    CRAFTY_BUILD_BRANCH
#    CRAFTY_BUILD_AUTHOR
#    CRAFTY_BUILD_MESSAGE
#    CRAFTY_BUILD_STATUS
#    CRAFTY_BUILD_STATUS_NAME

GITHUB_REPO="username/reponame"
GITHUB_TOKEN="...YOUR TOKEN HERE..."
GITHUB_STATE="error"
GITHUB_CONTEXT="crafty"

case $CRAFTY_BUILD_STATUS_NAME in
    "Success")
        GITHUB_STATE="success"
        ;;
    "Failure")
        GITHUB_STATE="failure"
        ;;
    *)
        ;;
esac

curl -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/$GITHUB_REPO/statuses/$CRAFTY_BUILD_REV" \
    -d "{\"state\":\"$GITHUB_STATE\",\"context\":\"$GITHUB_CONTEXT\"}"
