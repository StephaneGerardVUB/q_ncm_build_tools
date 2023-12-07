#!/bin/bash

##-- INITIALIZATION

REPO='configuration-modules-core'
RELEASE_ROOT=$(dirname $(readlink -f "$0"))
GIT_USER_NAME='Stephane GERARD'
GIT_USER_EMAIL='stephane.gerard@vub.be'
CLEAN=1
# the following is to skip the tests
MVN_ARGS='-P-module-test'


shopt -s expand_aliases
source maven-illuminate.sh
source ./mvn_test.sh


##-- FUNCTIONS

function echo_warning {
    echo -e "\033[1;33mWARNING\033[0m  $1"
}

function echo_error {
    echo -e "\033[1;31mERROR\033[0m  $1"
}

function echo_success {
    echo -e "\033[1;32mSUCCESS\033[0m  $1"
}

function echo_info {
    echo -e "\033[1;34mINFO\033[0m  $1"
}

function echo_usage {
    echo
    echo "Usage: $(basename $0) -g arg -b arg [-v arg] [-n arg]"
    echo "    -g <name of the github repository>"
    echo "    -b <name of the branch>"
    echo "    -v <version string>"
    echo "    -n <space separated list of ncm-components surrounded by quotes>"
    echo
}


##-- CHECKING SCRIPT ARGUMENTS

while getopts ':g:b:v:n:h' opt; do
    case $opt in
        g)
            GITHUBREPO=$OPTARG;;

        b)
            BRANCH=$OPTARG;;

        v)
            VERSION=$OPTARG;;

        n)
            NCMCOMPONENTS=$OPTARG;;

        h)
            echo_usage
            exit 0
            ;;

        :)
            echo -e "option requires an argument.\n"
            echo_usage
            exit 1
            ;;

        ?)
            echo -e "Invalid command option.\n"
            echo_usage
            exit 1
            ;;
    esac
done
shift "$(($OPTIND -1))"

if [[ -z $GITHUBREPO ]]; then
    echo "Missing -g argument" >&2
    echo_usage
    exit 1
fi
if [[ -z $BRANCH ]]; then
    echo "Missing -b argument" >&2
    echo_usage
    exit 1
fi


##-- CHECK AND PREPARE TOOLS (git, mvn,...)

# Set git user and mail address
git config --global user.name $GIT_USER_NAME
git config --global user.email $GIT_USER_EMAIL

# Check that dependencies required to perform a release are available
missing_deps=0
for cmd in {git,mvn,createrepo,tar,sed}; do
    hash $cmd 2>/dev/null || {
        echo_error "Command '$cmd' is required but could not be found"
        missing_deps=$(($missing_deps + 1))
    }
done
if [ $missing_deps -gt 0 ]; then
    echo_error "Aborted due to $missing_deps missing dependencies (see above)"
    exit 2
fi

##-- CHECKOUT OF REPOSITORY

echo_info "Preparing repositories for release..."
cd $RELEASE_ROOT
mkdir -p src/
cd src/
if [ -d $REPO ]; then
    if [ $CLEAN -eq 1 ]; then
        rm -rf $REPO
    fi
fi
git clone -q https://github.com/$GITHUBREPO/$REPO.git
cd $REPO
git checkout -q $BRANCH
cd ..


##-- ADAPT POM.XML
if ! [ -z $NCMCOMPONENTS ]; then
    $RELEASE_ROOT/pomedit.pl $NCMCOMPONENTS
fi
#%define _unpackaged_files_terminate_build 0

##-- GENERATION OF RPM

echo_info "---------------- Building RPMs ----------------"
cd $REPO
mvn_pack  > "$RELEASE_ROOT/${REPO}_build.log" 2>&1
if [ $? -gt 0 ]; then
    echo_error "BUILD FAILURE"
    exit 1
fi
cd ..
echo
echo_info "BUILD COMPLETED"
