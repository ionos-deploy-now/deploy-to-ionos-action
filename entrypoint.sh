#!/bin/sh

dist_folder=$1
remote_host=$2

password=$(pwgen -s 30 1)

branch=${GITHUB_REF/refs\/heads\//}

username=$(http POST https://api.buildwith.ionos.com/v1/projects/$PROJECT/git-repository/branches/$branch/users password=$password Authorization:"API-Key $API_KEY" Content-Type:application/vnd.ionos.beat.buildwithionos-v1+json --verify=no --ignore-stdin | jq -r .username)

export SSHPASS=$password

rsync -av --delete --exclude=logs --rsh="/usr/bin/sshpass -e ssh -o StrictHostKeyChecking=no" $dist_folder/ $username@$remote_host:

if [[ $? -gt 0 ]] ; then
  echo "rsync Failure"
  exit 1
fi

http PUT https://api.buildwith.ionos.com/v1/projects/$PROJECT/git-repository/branches/$branch/hooks/DEPLOYED Authorization:"API-Key $API_KEY" --verify=no

