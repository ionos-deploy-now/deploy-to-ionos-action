#!/bin/sh

deployment_size=$(du -s -B1 $DIST_FOLDER | cut -f 1)

if [[ $deployment_size -gt $STORAGE_QUOTA ]] ; then
  echo "The deployment is larger ($deployment_size) than the allowed quota ($storage_quota)"
  exit 1
fi

password=$(pwgen -s 30 1)

username=$(http POST https://$SERVICE_HOST/v1/projects/$PROJECT/branches/$BRANCH_ID/users password=$password Authorization:"API-Key $API_KEY" --ignore-stdin | jq -r .username)

if [ -z "$username" ] ; then
  echo "Failed to create temporary user"
  exit 1
fi

echo "Created temporary user: $username"

export SSHPASS=$password

rsync -av --delete --exclude=logs --rsh="/usr/bin/sshpass -e ssh -o StrictHostKeyChecking=no" $DIST_FOLDER/ $username@$REMOTE_HOST:

if [[ $? -gt 0 ]] ; then
  echo "rsync Failure"
  exit 1
fi

http PUT https://$SERVICE_HOST/v1/projects/$PROJECT/branches/$BRANCH_ID/hooks/DEPLOYED Authorization:"API-Key $API_KEY"

