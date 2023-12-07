#!/bin/bash


##-- INITIALIZATION

# We are only interested in a few template libraries.
REPOS="template-library-core template-library-standard template-library-os"
RELEASE=""
BUILD=""
RELEASE_ROOT=$(dirname $(readlink -f "$0"))
LIBRARY_CORE_DIR=$RELEASE_ROOT/src/template-library-core
GIT_USER_NAME='Stephane GERARD'
GIT_USER_EMAIL='stephane.gerard@vub.be'
# the following is to skip the tests
MVN_ARGS='-P-module-test'

shopt -s expand_aliases
source maven-illuminate.sh
source ./mvn_test.sh


##-- FUNCTIONS

# A bunch of messaging functions...

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
    echo
    echo -e "\033[1;34mINFO\033[0m  $1"
}

function exit_usage {
    echo
    echo "USAGE: $(basename $0)"
    exit 3
}


# Remove all current configuration module related templates.
# To be used before starting the update: after the updated
# only the obsolete configuration modules will be missing.

clean_templates() {
    rm -Rf ${LIBRARY_CORE_DIR}/components/*
}

# Commit to template-library-core the removal of obsolete configuration modules

remove_obsolete_components () {
    cd ${LIBRARY_CORE_DIR}
    #FIXME: ideally should check that there is only deleted files left
    git add -A .
    git commit -m 'Remove obsolete components'
    cd ..
}

# Update the templates related to configuration modules.
# This has to be called for every repository containing configuration modules.

update_templates() {
    type=$1
    tag=$2
    cd configuration-modules-$1
    git checkout $tag
    mvn_compile
    # ugly hack
    if [ -d ncm-metaconfig ]; then
        cd ncm-metaconfig
        mvn_test
        cd ..
    fi
    components_root=${LIBRARY_CORE_DIR}/components
    metaconfig_root=${LIBRARY_CORE_DIR}/metaconfig
    mkdir -p ${components_root}
    mkdir -p ${metaconfig_root}
    cp -r ncm-*/target/pan/components/* ${components_root}
    cp -r ncm-metaconfig/target/pan/metaconfig/* ${metaconfig_root}
    git checkout master
    cd ${LIBRARY_CORE_DIR}
    git add .
    git commit -m "Component templates (${type}) for tag ${tag}"
    cd ..
}

# Update templates related to AII and its plugins.
# Existing AII templates are removed before the update so
# that obsolete templates are removed.

update_aii() {
    tag="$1"
    dest_root="${LIBRARY_CORE_DIR}/quattor/aii"

    # It's better to do a rm before copying, in case a template has been suppressed.
    # For aii-core, don't delete subdirectory as some are files not coming from somewhere else...
    rm ${dest_root}/*.pan

    (
        cd aii || return
        git checkout "aii-$tag"
        mvn_compile

        # Copy dedicated AII templates
        cp -r aii-core/target/pan/quattor/aii/* "${dest_root}"

        # Copy AII component templates
        for aii_component in dhcp ks pxelinux; do
            rm -Rf "${dest_root:?}/${aii_component}"
            cp -r "aii-${aii_component}/target/pan/quattor/aii/${aii_component}" "${dest_root}"
        done
        git checkout master
    )

    (
        cd configuration-modules-core || return
        git checkout "configuration-modules-core-$tag"
        mvn_compile
        # Copy shared AII/core component templates
        for component in freeipa opennebula; do
            rm -Rf "${dest_root:?}/${component}"
            cp -r "ncm-${component}/target/pan/quattor/aii/${component}" "${dest_root}"
        done
        git checkout master
    )

    cd "${LIBRARY_CORE_DIR}" || return
    git add -A .
    git commit -m "AII templates for tag $tag"
    cd ..
}

# Build the template version.pan appropriate for the version

update_version_file() {
    release_major=$1
    if [ -z "$(echo $release_major | egrep 'rc[0-9]*$')" ]
    then
      release_minor="-1"
    else
      release_minor="_1"
    fi
    version_template=quattor/client/version.pan
    cd ${LIBRARY_CORE_DIR}

    cat > ${version_template} <<EOF
template quattor/client/version;

variable QUATTOR_RELEASE ?= '${release_major}';
variable QUATTOR_REPOSITORY_RELEASE ?= QUATTOR_RELEASE;
variable QUATTOR_PACKAGES_VERSION ?= QUATTOR_REPOSITORY_RELEASE + '${release_minor}';
EOF

    git add .
    git commit -m "Update Quattor version file for ${release_major}"
    cd -
}


##-- CHECK AND PREPARE TOOLS (git, mvn,...)

# Set git user and mail address
git config --global user.name $GIT_USER_NAME
git config --global user.email $GIT_USER_EMAIL

# Check that dependencies required to perform a release are available
missing_deps=0
for cmd in {gpg,gpg-agent,git,mvn,createrepo,tar,sed}; do
    hash $cmd 2>/dev/null || {
        echo_error "Command '$cmd' is required but could not be found"
        missing_deps=$(($missing_deps + 1))
    }
done
if [[ $missing_deps -gt 0 ]]; then
    echo_error "Aborted due to $missing_deps missing dependencies (see above)"
    exit 2
fi


##-- COLLECTING RPMs AND GENERATING TEMPLATE LIBRARIES

# Cloning template libraries

echo_info "---------------- Cloning the template libraries ----------------"
cd src/
for r in $REPOS; do
    if [[ ! -d $r ]]; then
        git clone -q https://github.com/quattor/$r.git
    fi
done
cd ..

# Version will be determined after what is found in the pom.xml
# of the repo configuration-modules-core.

pompath='src/configuration-modules-core/pom.xml'
VERSION=$(grep 'SNAPSHOT' $pompath | sed -e 's/version//g' | sed -e 's/[<>/ ]//g')

# Collecting RPMs

cd $RELEASE_ROOT
mkdir -p target/

echo_info "------------------------ Collecting RPMs ------------------------"
mkdir -p target/$VERSION
find src/ -type f -name \*.rpm | grep /target/rpm/ | xargs -I @ cp @ target/$VERSION/


# Updating template libraries

cd $RELEASE_ROOT/src

echo_info "---------------- Updating template-library-core  ----------------"

clean_templates
echo_info "--->Update templates of components..."
update_templates "core" "configuration-modules-core-$VERSION"

echo_info "--->Remove templates for obsolete components..."
remove_obsolete_components

echo_info "--->Updating AII templates..."
update_aii "$VERSION" &&  echo_info "    AII templates successfully updated"

echo_info "--->Updating Quattor version template..."
update_version_file "$VERSION" && echo_info "    Quattor version template sucessfully updated"

echo_success "---------------- Update of template-library-core successfully completed ----------------"

echo_success "SCRIPT COMPLETED"
