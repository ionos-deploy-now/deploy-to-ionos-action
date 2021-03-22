#!/bin/sh

dist_folder=$1
remote_host=$2

password=$(pwgen -s 30 1)

branch=${GITHUB_REF/refs\/heads\//}
branch=${branch/\//%2F}

username=$(http POST https://${SERVICE_HOST}/v1/projects/$PROJECT/branches/$branch/users password=$password Authorization:"API-Key $API_KEY" Content-Type:application/json --ignore-stdin | jq -r .username)

export SSHPASS=$password

rsync -av --delete --exclude=logs --rsh="/usr/bin/sshpass -e ssh -o StrictHostKeyChecking=no" $dist_folder/ $username@$remote_host:

if [[ $? -gt 0 ]] ; then
  echo "rsync Failure"
  exit 1
fi

http PUT https://${SERVICE_HOST}/v1/projects/$PROJECT/branches/$branch/hooks/DEPLOYED Authorization:"API-Key $API_KEY"

