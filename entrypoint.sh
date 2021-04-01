#!/bin/sh

deployment_size=$(du -s -B1 $DIST_FOLDER | cut -f 1)

if [[ $deployment_size -gt $STORAGE_QUOTA ]] ; then
  echo "The deployment is larger ($deployment_size) than the allowed quota ($storage_quota)"
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
    create_temporary_user $(($counter) - 1))
  fi
  echo $username
}
username=$(create_temporary_user 3)

echo "Created temporary user: $username"

export SSHPASS=$password

rsync -av --delete --exclude=logs --rsh="/usr/bin/sshpass -e ssh -o StrictHostKeyChecking=no" $DIST_FOLDER/ $username@$REMOTE_HOST:

if [[ $? -gt 0 ]] ; then
  echo "rsync Failure"
  exit 1
fi

http PUT https://$SERVICE_HOST/v1/projects/$PROJECT/branches/$BRANCH_ID/hooks/DEPLOYED Authorization:"API-Key $API_KEY"

