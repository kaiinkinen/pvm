#/bin/bash -x
# Play Version Manager
# Bash function for managing play framework versions 
# 
# This started off as a fork of the excellent 
# Node Version Manager (https://github.com/creationix/nvm.git)
# which has been implemented by Tim Caswell <tim@creationix.com> 
# and Matthew Ranney
#
# Auto detect the PVM_DIR
DEBUG=false

if [ ! -d "${PVM_DIR}" ]; then
    export PVM_DIR=$(cd $(dirname ${BASH_SOURCE[0]:-$0}); pwd)
fi

ALIAS_DIR_NAME=alias
INSTALL_DIR_NAME=install
SRC_DIR_NAME=src
export PVM_INSTALL_DIR=${PVM_DIR}/${INSTALL_DIR_NAME}

ensure_directories() 
{
    mkdir -p ${PVM_DIR}/{${INSTALL_DIR_NAME},${ALIAS_DIR_NAME},${SRC_DIR_NAME}}
}

# Download the file
download_file_if_needed() 
{
    url=$1
    file=$2
    file_http_head=${file}.http_head
    
    tempfile=$(TEMPDIR=/tmp && mktemp -t pvm_curl.XXXXXX)

    echo -en "Checking download url ${url} ..."
    
    # What's currently on the server?
    http_code=$(curl -w '%{http_code}' -sIL "${url}" -o ${tempfile})
    if (( $? != 0 || ${http_code} != 200 )); then 
        echo -e "\tdownload failed with status ${http_code}"
        rm -f ${tempfile}
        return 10
    fi

    if [ ! -f ${file_http_head} ]; then 
        cp -f ${tempfile} ${file_http_head}
    fi

    echo -e "\tSuccess!\n\nStarting the download"

    if [ -f $file ]; then 
        $DEBUG && echo "Getting file size stats for '${file}':"'stat -f %z ${file})'
        actual_file_length=$(stat -f '%z' ${file})
        $DEBUG && echo "File size is ${actual_file_length}"

        if [ -f ${file_http_head} ] ; then 
            $DEBUG && echo "Head file exists"

            # Downloaded by pvm, lines terminated by \r\n, so we need to take some precautions
            etag=$(grep 'ETag' ${file_http_head} | cut -d \" -f 2 || '0')
            content_length=$(grep 'Content-Length' ${file_http_head} | awk '{sub("\r",""); print $2}' || 0)
            
            # Current head
            previous_etag=$(grep 'ETag' ${tempfile} | cut -d \" -f 2 || '0')

            $DEBUG && echo "Checking file ($file) whether etags match ('${etag}' and '${previous_etag}') and content lengths match ('${content_length}' and '${actual_file_length}')"

            if [[ "${etag}" == "${previous_etag}" && "$content_length" -eq "$actual_file_length" ]]; then 
                echo -e "\nFile '${file}' already downloaded and valid. Using cached version\n"
                return 0;
            elif [[ "${etag}" != "${previous_etag}" ]]; then 
                rm -f ${file}
                
            elif [ "$content_length" -gt "$actual_file_length" ]; then 
                # Still in progress
                echo > /dev/null
            else
                # Something fishy here, just redownload
                rm -f ${file}
            fi
                
            curl -C - --progress-bar ${url} -o "${file}" || \
                (echo -e "\nRestart download" && rm -f "${file}" && curl --progress-bar ${url} -o "${file}" ) || \
                mv ${tempfile} ${file_http_head} && return 0 # Success

            return 255 # fail
           
        fi
    fi

    # No file. Just download
    curl -C - --progress-bar ${url} -o "${file}" || \
        (echo -e "\Restart download" &&  $rm -f "${file}" && curl --progress-bar ${url} -o "${file}" ) || \
        mv ${tempfile} ${file_http_head} && return 0 # Success
    
    return 255 # fail
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
            zipfile_location=${PVM_DIR}/${SRC_DIR_NAME}/${zipfile}
            
	    MAJOR_VERSION=$(echo "$VERSION" | cut -d '.' -f 1)
	    MINOR_VERSION=$(echo "$VERSION" | cut -d '.' -f 2)
            
            return_code=255
            cd "${PVM_DIR}" 
            for download_url in "http://downloads.typesafe.com/play/${VERSION}/${zipfile}" "http://downloads.typesafe.com/releases/${zipfile}"; do 
                $DEBUG && echo "download_file_if_needed '$download_url' '$zipfile_location'"
                download_file_if_needed $download_url $zipfile_location
                if (( $? == 0)); then 
                    return_code=0
                    break
                fi
            done

	    if (( $return_code != 0 )); then 
		echo -e "\nCannot download version ${VERSION} of "'Play! Framework'" None of the configured download URLs worked"
		return 1
	    fi

	    if (cd $(TEMPDIR=/tmp && mktemp -d -t pvm.XXXXXX) && \
                unzip -u -qq "${zipfile_location}" && \
                rm -rf ${PVM_INSTALL_DIR}/${VERSION} && \
	        mv -f ${appname} ${PVM_INSTALL_DIR}/${VERSION})
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
		echo "Play Framework version ${VERSION} is not installed yet"
		return;
	    fi

            # Delete all files related to target version
	    (cd "${PVM_DIR}" && \
		( [ -d ${INSTALL_DIR_NAME}/${VERSION} ] && echo "Removing installed version at '${PVM_DIR}/${INSTALL_DIR_NAME}/${VERSION}'" && rm -rf "${INSTALL_DIR_NAME}/${VERSION}" 2>/dev/null ) ; \
		( [ -f play-${VERSION}.zip ] && rm -f "play-${VERSION}.zip*" 2>/dev/null ) ; \
		( [ -f src/play-${VERSION}.zip ] && echo "Removing downloaded zip at '${PVM_DIR}/src/play-${VERSION}.zip'" && rm -f src/play-${VERSION}.zip* 2>/dev/null ))
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
