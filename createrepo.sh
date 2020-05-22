#!/bin/bash

### Parameters =================================================================

use_sasl=0
clean=0
realm=''
directory='.'
userdb=''

### Cleanup ====================================================================

cleanup()
{
    if [[ "${clean}" -gt 0 ]]
    then
        rm -rf "${directory}/${reponame}"
    fi
}

trap cleanup EXIT

### Get arguments ==============================================================

shift

argc=$#
argv=("$@")

for (( i = 0; i < argc; i++ ))
do
    arg="${argv[$i]}"
    if [[ "$arg" == '--sasl' ]]
    then
        use_sasl=1
    elif [[ "$arg" == '--realm' || "$arg" == '-r' ]]
    then
        if [[ $i < $(( argc - 1 )) ]]
        then
            let i++
            realm="${argv[$i]}"
        else
            echo 'Wrong argument' >&2
        fi
    elif [[ "$arg" == '--directory' || "$arg" == '-d' ]]
    then
        if [[ $i < $(( argc - 1 )) ]]
        then
            let i++
            directory="${argv[$i]}"
        else
            echo 'Wrong argument' >&2
        fi
    elif [[ "$arg" == '--userdb' || "$arg" == '-u' ]]
    then
        if [[ $i < $(( argc - 1 )) ]]
        then
            let i++
            userdb="${argv[$i]}"
        else
            echo 'Wrong argument' >&2
        fi
    elif [[ "${arg:0:1}" != '-' ]]
    then
        reponame="${arg}"
    fi
done

### Check parameters ===========================================================

if [[ -z "$reponame" ]]
then
    echo 'Repo name is not set' >&2
    exit 1
fi

if [[ -z "$realm" ]]
then
    echo 'Realm is not set' >&2
    exit 2
fi

if [[ -z "$directory" ]]
then
    echo 'Directory is not set' >&2
    exit 3
fi

### Check repository already exist =============================================

if [[ -e "${directory}/${reponame}" ]]
then
    echo 'Repository already exist' >&2
    exit 4
fi

### Create repository ==========================================================

svnadmin create "${directory}/${reponame}" || exit 5

clean=1

### Create local user database configuration ===================================

cat << _EOF > "${directory}/${reponame}/conf/svnserve.conf" || exit 6
[general]
anon-access = none
auth-access = write
password-db = passwd
realm       = ${realm}

_EOF

### Create user database file --------------------------------------------------

if [[ -n "$userdb" && -f "$userdb" ]]
then
    cp -f "$userdb" "${directory}/${reponame}/conf/passwd" || exit 7
else
    cat << _EOF > "${directory}/${reponame}/conf/passwd" || exit 7
[users]
system=system
_EOF
fi

### Get username and password --------------------------------------------------

username=$(grep '=' "${directory}/${reponame}/conf/passwd" | head -n1 | cut -s -d '=' -f 1 )
password=$(grep '=' "${directory}/${reponame}/conf/passwd" | head -n1 | cut -s -d '=' -f 2 )

if [[ -z "$username" || -z "$password" ]]
then
    echo 'Username and password is empty' >&2
    exit 8
fi

### Create default directories =================================================

repourl="svn://127.0.0.1/${directory}/${reponame}"

svn mkdir "${repourl}/trunk" \
          "${repourl}/branches" \
          "${repourl}/tags" \
          -m 'Created trunk, branches and tags dirs' \
          --non-interactive --no-auth-cache \
          --username "$username" --password "$password" \
    || exit 9

### Configure SASL =============================================================

if [[ "$use_sasl" -gt 0 ]]
then
    cat << _EOF >> "${directory}/${reponame}/conf/svnserve.conf" || exit 10
[sasl]
use-sasl = true

_EOF

fi

clean=0

