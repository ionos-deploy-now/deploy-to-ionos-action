#!/bin/sh
set -o pipefail

deployment_size=$(du -s -B1 --exclude=.git --exclude=.github $DIST_FOLDER | cut -f 1)

if [[ $deployment_size -gt $STORAGE_QUOTA ]] ; then
  echo "The deployment is larger ($deployment_size) than the allowed quota ($STORAGE_QUOTA)"
  exit 1
fi

password=$(pwgen -s 30 1)

create_temporary_user() {
  counter=$1
  if [[ $counter -eq 0 ]] ; then
    echo "Failed to create temporary user" 1>&2
    exit 1
  fi
  username=$(http POST https://$SERVICE_HOST/v1/projects/$PROJECT/branches/$BRANCH_ID/users password=$password Authorization:"API-Key $API_KEY" --ignore-stdin --check-status | jq -r .username)

  if [[ $? -eq 5 ]] ; then
    echo "Retry creating temporary user in 1 second" 1>&2
    sleep 1
    create_temporary_user $(($counter - 1))
  fi
  echo $username
}
export USERNAME=$(create_temporary_user 3)

echo "Created temporary user: $USERNAME"

export SSHPASS=$password

EXCLUDE_FROM=""
if [[ $INITIAL_BUILD  == "true" ]] ; then
  if [[ -f 'initialdeploy.excludes' ]];then
    EXCLUDE_FROM="--exclude-from=initialdeploy.excludes"
  fi
else
  if [[ -f 'deploy.excludes' ]];then
    EXCLUDE_FROM="--exclude-from=deploy.excludes"
  fi
fi

echo "rsync -av --delete --exclude=logs --rsh=\"/usr/bin/sshpass -e ssh -o StrictHostKeyChecking=no\" --exclude=.git --exclude=.github $EXCLUDE_FROM $DIST_FOLDER/ $USERNAME@$REMOTE_HOST:"
rsync -av --delete --exclude=logs --rsh="/usr/bin/sshpass -e ssh -o StrictHostKeyChecking=no" --exclude=.git --exclude=.github $EXCLUDE_FROM $DIST_FOLDER/ $USERNAME@$REMOTE_HOST:

if [[ $? -gt 0 ]] ; then
  echo "rsync Failure"
  exit 1
fi

FILENAME="remote.commands"

if [[ -f $FILENAME ]];then
  IFS=$'\n'
  LINES=$(cat $FILENAME)

  set -o noglob
  for LINE in $LINES
  do
    echo "Running the remote command in the webpsace: $LINE"
    /usr/bin/sshpass -e ssh -o StrictHostKeyChecking=no $USERNAME@$REMOTE_HOST "$LINE"
    if [[ $? -gt 0 ]] ; then
      echo "Error running the remote command in the webspace"
      exit 1
    fi
  done
  set +o noglob
fi

http PUT https://$SERVICE_HOST/v1/projects/$PROJECT/branches/$BRANCH_ID/hooks/DEPLOYED Authorization:"API-Key $API_KEY"
