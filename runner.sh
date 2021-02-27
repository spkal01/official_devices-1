#!/usr/bin/env bash
# Copyright © 2019 Maestro Creativescape
#
### Script to test and format our jsons

ADMINS="@spkal"
COMMIT_AUTHOR="$(git log -1 --format='%an <%ae>')"
COMMIT_MESSAGE="$(git log -1 --pretty=%B)"
COMMIT_SMALL_HASH="$(git rev-parse --short HEAD)"
COMMIT_HASH="$(git rev-parse --verify HEAD)"

function sendAdmins() {
    curl -s "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendmessage" --data "text=${*}&chat_id=-1001148005546&parse_mode=Markdown"
}

function sendMaintainers() {
    curl -s "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendmessage" --data "text=${*}&chat_id=-1001148005546&&parse_mode=Markdown"
}

printf "\n\n***Spark CI***\n\n"
BUILD_START=$(date +"%s")

if [ -n "$PULL_REQUEST_NUMBER" ]; then
    sendAdmins "\`I have recieved PR $PULL_REQUEST_NUMBER.\`"
    sendMaintainers "\`I have recieved PR $PULL_REQUEST_NUMBER.\`"
else
    git checkout fire  > /dev/null
    git pull origin fire  > /dev/null
    sendAdmins "**I am building fire branch job.** %0A**Commit Point:** [${COMMIT_SMALL_HASH}](https://github.com/SPark-Devices/official_devices/commit/${COMMIT_HASH})"
fi

node json_tester.js

RESULT=$?

if [ -n "$PULL_REQUEST_NUMBER" ]; then
    BUILD_END=$(date +"%s")
    DIFF=$((BUILD_END - BUILD_START))

    if [ "$RESULT" -eq 1 ]; then
        echo "My works took $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds. But its an error!"
        sendAdmins "\`PR $PULL_REQUEST_NUMBER is failing checks. Please don't merge\` %0A%0A**Failed File:** \`$(cat /tmp/failedfile)\`"
        sendMaintainers "\`PR $PULL_REQUEST_NUMBER is failing checks. Maintainer is requested to check it\` %0A%0A**Failed File:** \`$(cat /tmp/failedfile)\` %0A%0A[PR Link](https://github.com/Spark-Devices/official_devices/pull/$PULL_REQUEST_NUMBER)"
        exit 1
    else
        echo "Yay! My works took $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds.~"
        sendAdmins "\`PR $PULL_REQUEST_NUMBER can be merged.\` %0A%0A${ADMINS} %0A%0A[PR Link](https://github.com/Spark-Devices/official_devices/pull/$PULL_REQUEST_NUMBER)"
        sendMaintainers "\`PR $PULL_REQUEST_NUMBER has passed all sanity checks. Please wait for the merge.\`"
        exit 0
    fi

fi

if [ "$RESULT" -eq 1 ]; then
    BUILD_END=$(date +"%s")
    DIFF=$((BUILD_END - BUILD_START))
    sendAdmins "\`Someone has merged a failing file. Please look in ASAP.\` %0A%0A${ADMINS} %0A%0A**Failed File:** \`$(cat /tmp/failedfile)\`"
    echo "My works took $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds. But its an error!"
    exit 1
fi

GIT_CHECK="$(git status | grep "modified")"

# Hack around some derps
if [[ ! "$COMMIT_MESSAGE" =~ "[Spark-CI]" ]] && [ -n "$GIT_CHECK" ]; then
      git reset HEAD~1
    git add .
    git commit -m "[Spark-CI]: ${COMMIT_MESSAGE}" --author="${COMMIT_AUTHOR}" --signoff
    git remote rm origin
    git remote add origin https://github.com/Spark-Devices/official_devices.git
    git config --global user.password "$GH_PERSONAL_TOKEN"
    git config --global user.name "spkal01"
    git push -f origin fire
    sendAdmins "JSON Linted and Force Pushed!"
fi
BUILD_END=$(date +"%s")
DIFF=$((BUILD_END - BUILD_START))
echo "Yay! My works took $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds.~"
