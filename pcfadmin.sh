#!/bin/bash
adminUserName=admin
password="pivotal"

# exit immediately if a command exits with a non-zero status
set -e

################
usage_and_exit() {
  cat <<EOF
Usage: pcfadmin <command> [options]
Note: You need to be logged in as admin. Default user password is 'pivotal'

Examples:
  pcfadmin create-user-org mborges
  pcfadmin delete-org mborges-org
  pcfadmin seed-org-users mborges-org 5
    where: 5 is the number of users
  pcfadmin delete-org-users mborges-org
    note: only 'user-*' users are deleted
EOF
  exit 1
}

################
destroy_org() {
  local orgName=$1
  local userName=$2

  echo "Delete org $orgName and user $userName"
  cf delete-org $orgName
  cf delete-user $userName
}

################
create_org() {
  local orgName=$1
  local userName=$2

  echo "Creating user $userName"
  cf create-user $userName $password
  echo "Creating org $orgName"
  cf create-org $orgName
  echo "setting Org Manager Role"
  cf set-org-role $userName $orgName OrgManager
}

################
create_space() {
  local orgName=$1
  local spaceName=$2

  echo "creating $spaceName space"
  cf create-space $spaceName -o $orgName
  echo "setting $spaceName roles"
  cf set-space-role $adminUserName $orgName $spaceName SpaceManager
  cf set-space-role $adminUserName $orgName $spaceName SpaceDeveloper
  cf set-space-role $userName $orgName $spaceName SpaceManager
  cf set-space-role $userName $orgName $spaceName SpaceDeveloper
}


################
seed_org_users() {
  local orgName=$1
  local numUsers=$2

  echo $numUsers

  for num in $(eval echo "{1..$numUsers}")
  do
     userName="user-$num"
     echo "Creating user $userName"
     cf create-user $userName $password

     echo "setting development roles"
     cf set-space-role $userName $orgName development SpaceDeveloper
  done

  cf org-users $orgName -a
}

################
#### TEST
################

################
delete_org_users() {
  local orgName=$1
  local userLine=false

  cf org-users $orgName -a |
    while IFS= read -r line
    do
      if [ "USERS" = "$line" ]; then
        userLine=true
        continue
      fi
      if $userLine; then
        local userName=$(echo "${line}" | sed -e 's/^[ \t]*//')
        if [ "admin" != "$userName" ] && [[ $userName == 'user'* ]]; then
          echo "Delete '$userName'"
          cf delete-user $userName -f
        fi
      fi
    done
}

################
#### MAIN
################

if [ "$#" -lt 2 ]; then
    usage_and_exit
fi

CMD=$1 ARG=$2

if [ "create-user-org" = "$CMD" ]; then
  userName=$2
  orgName="$userName-org"
  create_org $orgName $userName
  for spaceName in {"development","test","production"}
  do
    create_space $orgName $spaceName $userName
  done
elif [ "delete-org" = "$CMD" ]; then
  userName=$2
  orgName="$userName-org"
  destroy_org orgName userName
elif [ "seed-org-users" = "$CMD" ]; then
  orgName=$2
  users=$3
  seed_org_users $orgName $users
elif [ "delete-org-users" = "$CMD" ]; then
  orgName=$2
  delete_org_users $orgName
else
  usage_and_exit
fi
