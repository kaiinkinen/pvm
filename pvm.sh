# Play Version Manager
# Bash function for managing play framework versions 
# 
# This started off as a fork of the excellent 
# Node Version Manager (https://github.com/creationix/nvm.git)
# which has been implemented by Tim Caswell <tim@creationix.com> 
# and Matthew Ranney
#
# Auto detect the PVM_DIR
if [ ! -d "${PVM_DIR}" ]; then
    export PVM_DIR=$(cd $(dirname ${BASH_SOURCE[0]:-$0}); pwd)
fi

ALIAS_DIR_NAME=alias
INSTALL_DIR_NAME=install
export PVM_INSTALL_DIR=${PVM_DIR}/${INSTALL_DIR_NAME}

ensure_directories() 
{
    if [ ! -d ${PVM_DIR}/${INSTALL_DIR_NAME} ]; then 
	mkdir -p ${PVM_DIR}/${INSTALL_DIR_NAME}
    fi

    if [ ! -d ${PVM_DIR}/${ALIAS_DIR_NAME} ]; then 
	mkdir -p ${PVM_DIR}/${ALIAS_DIR_NAME} 
    fi
}


# Expand a version using the version cache
pvm_version()
{
    PATTERN=$1
    # The default version is the current one
    if [ ! "${PATTERN}" ]; then
        PATTERN='current'
    fi

    VERSION=$(pvm_ls $PATTERN | tail -n1)
    echo "${VERSION}"
    
    if [ "${VERSION}" = 'N/A' ]; then
        return 13
    fi
}

pvm_ls()
{
    PATTERN=$1
    VERSIONS=''
    
    ensure_directories

    if [ "${PATTERN}" = 'current' ]; then
        echo $PVM_CURRENT_VERSION
        return
    fi

    if [ -f "${PVM_DIR}/alias/${PATTERN}" ]; then
        pvm_version $(cat ${PVM_DIR}/alias/${PATTERN})
        return
    fi

    # If it looks like an explicit version, don't do anything funny
    if [[ "${PATTERN}" == ?*.?* ||
		"${PATTERN}" == ?*.?*.?* ]]; then
        VERSIONS="${PATTERN}"
    else
	if [ -z "${PATTERN}" ]; then 
	    PATTERN="?*."
	fi

        VERSIONS=$((cd ${PVM_INSTALL_DIR} && ls -1 -d ${PATTERN}* 2>/dev/null) | sort -t. -k 1,1n -k 2,2n)
    fi
    if [ ! "${VERSIONS}" ]; then
        echo "N/A"
        return
    fi
    echo "${VERSIONS}"
    return
}

print_versions()
{
    OUTPUT=''
    for VERSION in $1; do
        PADDED_VERSION=$(printf '%10s' ${VERSION})
        if [[ -d "${PVM_INSTALL_DIR}/${VERSION}" ]]; then
            PADDED_VERSION="\033[0;32m${PADDED_VERSION}\033[0m" 
        fi
        OUTPUT="${OUTPUT}\n${PADDED_VERSION}" 
    done
    echo -e "${OUTPUT}" | column 
}

pvm()
{
    if [ $# -lt 1 ]; then
	pvm help
	return
    fi
    case $1 in
	"help" )
	    echo
	    echo "Play Version Manager"
	    echo
	    echo "Usage:"
	    echo "    pvm help                    Show this message"
	    echo "    pvm install <version>       Download and install a <version>"
	    echo "    pvm uninstall <version>     Uninstall a version"
	    echo "    pvm use <version>           Modify PATH to use <version>"
	    echo "    pvm run <version> [<args>]  Run <version> with <args> as arguments"
	    echo "    pvm ls                      List installed versions"
	    echo "    pvm ls <version>            List versions matching a given description"
	    echo "    pvm deactivate              Undo effects of PVM on current shell"
	    echo "    pvm alias [<pattern>]       Show all aliases beginning with <pattern>"
	    echo "    pvm alias <name> <version>  Set an alias named <name> pointing to <version>"
	    echo "    pvm unalias <name>          Deletes the alias named <name>"
	    echo "    pvm clean                   Removes non-installed versions from the cache"
	    echo "    pvm clear-cache             Deletes all cached zip files"
	    echo
	    echo "Example:"
	    echo "    pvm install 1.2.4           Install a specific version number"
	    echo "    pvm use 1.2                 Use the latest available 1.2.x release"
	    echo "    pvm alias default 1.2.4     Auto use the latest installed 1.2 version"
	    echo
	    ;;
	"install" )
	    if [ ! $(which curl) ]; then
		echo 'PVM Needs curl to proceed.' >&2;
	    fi
	    
	    if [ $# -ne 2 ]; then
		pvm help
		return
	    fi

	    ensure_directories
	    VERSION=$(pvm_version $2)

	    [ -d "${PVM_DIR}/${VERSION}" ] && echo "${VERSION} is already installed." && return

	    appname=play-${VERSION}
	    zipfile="${appname}.zip"

	    MAJOR_VERSION=$(echo "$VERSION" | cut -d '.' -f 1)
	    MINOR_VERSION=$(echo "$VERSION" | cut -d '.' -f 2)
	    if [[ "$MAJOR_VERSION" == "1" || ("$MAJOR_VERSION" == "2" && "$MINOR_VERSION" == "0") ]]; then
	        download_url="http://downloads.typesafe.com/releases/${zipfile}"
	    else
	        download_url="http://downloads.typesafe.com/play/${VERSION}/${zipfile}"
	    fi

	    http_code=$(curl -w '%{http_code}' -sIL "${download_url}" -o /dev/null)
	    if (( $? != 0 )); then 
		echo -e "\nCannot download version ${VERSION} of "'Play! Framework'" from '${download_url}'"
		echo -e "Received response code: ${http_code}"
		return 1
	    fi

	    if ([ ! -z ${download_url} ] && \
		cd "${PVM_DIR}" && \
		mkdir -p src ${INSTALL_DIR_NAME} && \
		curl -C - --progress-bar ${download_url} -o "src/${zipfile}" && \
		unzip "src/${zipfile}" && \
		mv ${appname} ${INSTALL_DIR_NAME}/${VERSION})
	    then
		pvm use ${VERSION}
		if [ ! -f "${PVM_DIR}/${ALIAS_DIR_NAME}/default" ]; then 
		    # Set this as default, as we currently don't have one
		    echo "No default installation selected. Using ${VERSION}"
		    mkdir -p "${PVM_DIR}/${ALIAS_DIR_NAME}"
		    pvm alias default ${VERSION}
		fi

	    else
		echo "pvm: install ${VERSION} failed!"
	    fi
	    ;;
	"uninstall" )
	    [ $# -ne 2 ] && pvm help && return
	    if [[ $2 == $(pvm_version) ]]; then
		echo "pvm: Cannot uninstall currently-active play framework version, $2."
		return
	    fi
	    VERSION=$(pvm_version $2)
	    if [ ! -d ${PVM_INSTALL_DIR}/${VERSION} ]; then
		echo "${VERSION} version is not installed yet"
		return;
	    fi

            # Delete all files related to target version, except cached sources
	    (cd "${PVM_DIR}" && \
		( [ -d ${INSTALL_DIR_NAME}/play-${VERSION} ] && rm -rf "${INSTALL_DIR_NAME}/play-${VERSION}" 2>/dev/null ) && \
		( [ -f play-${VERSION}.zip ] && rm -f "play-${VERSION}.zip" 2>/dev/null ) && \
		( [ -f src/play-${VERSION}.zip ] && rm -f src/play-${VERSION}.zip 2>/dev/null ))
	    echo "Uninstalled play ${VERSION}"
	    
           # Rm any aliases that point to uninstalled version.
	    for A in $(grep -l ${VERSION} ${PVM_DIR}/${ALIAS_DIR_NAME}/*)
	    do
		pvm unalias $(basename $A)
	    done

	    ;;
	"deactivate" )
	    if [[ $PATH == *${PVM_DIR}/* ]]; then
		export PATH=${PATH%${PVM_DIR}/*}${PATH#*${PVM_DIR}/*:}
		hash -r
		echo "${PVM_DIR}/* removed from \$PATH"
	    else
		echo "Could not find ${PVM_DIR}/* in \$PATH"
	    fi
	    ;;
	"use" )
	    if [ $# -ne 2 ]; then
		pvm help
		return
	    fi
	    VERSION=$(pvm_version $2)
	    if [ ! -d ${PVM_INSTALL_DIR}/${VERSION} ]; then
		echo "${VERSION} version is not installed yet"
		return;
	    fi
	    if [[ $PATH == *${PVM_INSTALL_DIR}/* ]]; then
		PATH=${PATH%${PVM_INSTALL_DIR}/*}${PATH#*${PVM_DIR}/*:} 
	    fi
	    export PATH="${PVM_INSTALL_DIR}/${VERSION}:$PATH"
	    hash -r
	    export PVM_PATH="${PVM_INSTALL_DIR}/${VERSION}/libexec"
	    export PVM_BIN="${PVM_INSTALL_DIR}/${VERSION}"
	    export PVM_CURRENT_VERSION=${VERSION}

	    echo "Now using play ${VERSION}"
	    ;;
#	"run" )
#      # run given version of play
#	    if [ $# -lt 2 ]; then
#		pvm help
#		return
#	    fi
#	    VERSION=$(pvm_version $2)
#	    if [ ! -d ${PVM_DIR}/${VERSION} ]; then
#		echo "${VERSION} version is not installed yet"
#		return;
#	    fi
#	    echo "Running play ${VERSION}"
#	    ${PVM_DIR}/${VERSION}/bin/play "${@:3}"
#	    ;;
	"ls" | "list" )
	    echo "Available:"
	    print_versions "$(pvm_ls $2)"
	    if [ $# -eq 1 ]; then
		echo -e "\nAliases:"
		pvm alias 
		echo -ne "\nCurrent version: \ncurrent -> "; pvm_version current
		echo 
	    fi
	    return
	    ;;
	"alias" )
	    ensure_directories
	    if [ $# -le 2 ]; then
		(cd ${PVM_DIR}/${ALIAS_DIR_NAME} && for ALIAS in $(\ls $2* 2>/dev/null); do
			DEST=$(cat $ALIAS)
			VERSION=$(pvm_version $DEST)
			if [ "$DEST" = "${VERSION}" ]; then
			    echo -e "${ALIAS} -> ${DEST}"
			else
			    echo -e "${ALIAS} -> ${DEST} (-> ${VERSION})"
			fi
			done)
		return
	    fi
	    if [ ! "$3" ]; then
		rm -f ${PVM_DIR}/${ALIAS_DIR_NAME}/$2
		echo "$2 -> *poof*"
		return
	    fi
	    mkdir -p ${PVM_DIR}/${ALIAS_DIR_NAME}
	    VERSION=$(pvm_version $3)
	    if [ $? -ne 0 ]; then
		echo "! WARNING: Version '$3' does not exist." >&2
	    fi
	    echo $3 > "${PVM_DIR}/${ALIAS_DIR_NAME}/$2"
	    if [ ! "$3" = "${VERSION}" ]; then
		echo "$2 -> $3 (-> ${VERSION})"
	    else
		echo "$2 -> $3"
	    fi
	    ;;
	"unalias" )
	    ensure_directories
	    [ $# -ne 2 ] && pvm help && return
	    [ ! -f ${PVM_DIR}/${ALIAS_DIR_NAME}/$2 ] && echo "Alias $2 doesn't exist!" && return
	    rm -f ${PVM_DIR}/${ALIAS_DIR_NAME}/$2
	    echo "Deleted alias $2"
	    ;;
#    "copy-packages" )
#        if [ $# -ne 2 ]; then
#          pvm help
#          return
#        fi
#        VERSION=$(pvm_version $2)
#        ROOT=$(pvm use ${VERSION} && npm -g root)
#        INSTALLS=$(pvm use ${VERSION} > /dev/null && npm -g -p ll | grep "$ROOT\/[^/]\+$" | cut -d '/' -f 8 | cut -d ":" -f 2 | grep -v npm | tr "\n" " ")
#        npm install -g $INSTALLS
#    ;;
	"clear-cache" )
            rm -f ${PVM_DIR}/src/play*.zip* 2>/dev/null
            echo "Cache cleared."
	    ;;
        "clean" )
	    for file in $(ls ${PVM_DIR}/src/play*.zip); do 
		version=$(basename $file | perl -pe 's!play-([\d\.]+).zip!$1!g')
		if [ ! -d ${PVM_DIR}/install/${version} ]; then 
		    rm -f ${PVM_DIR}/src/play-${version}.zip && echo "Removed version ${version} from cache"
		fi
	    done
	    ;;
	"version" )
            print_versions "$(pvm_version $2)"
	    ;;
	* )
	    pvm help
	    ;;
    esac
}

pvm ls default >/dev/null 2>&1 && pvm use default >/dev/null
