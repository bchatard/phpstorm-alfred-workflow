#!/bin/bash

# inlude workflowHandler (https://github.com/markokaestner/bash-workflow-handler)
. ./lib/workflowHandler.sh

# Path to PhpStorm script
PHPSTORM_SCRIPT="/usr/local/bin/pstorm"
# XPath to projects location in other.xml
XPATH_PROJECTS="//component[@name='RecentDirectoryProjectsManager']/option[@name='names']/map/entry/@key"
XPATH_RECENT_PROJECTS="//component[@name='RecentDirectoryProjectsManager']/option[@name='recentPaths']/list/option/@value"
# Current nocasematch status
CURRENT_NOCASEMATCH='off'

ORIG_IFS=${IFS}

################################################################################
# Adds a result to the result array
# Overloaded to manage icon as fileicon (remove if pull request is merged)
#
# $1 uid
# $2 arg
# $3 title
# $4 subtitle
# $5 icon
# $6 valid
# $7 autocomplete
###############################################################################
addResult()
{
    RESULT="<item uid=\"$(xmlEncode "$1")\" arg=\"$(xmlEncode "$2")\" valid=\"$6\" autocomplete=\"$7\"><title>$(xmlEncode "$3")</title><subtitle>$(xmlEncode "$4")</subtitle>"
    if [[ $5 =~ fileicon:* ]]; then
        icon=`echo $5 | sed -e 's/fileicon://g'`
        RESULT="${RESULT}<icon type=\"fileicon\">$(xmlEncode "${icon}")</icon>"
    elif [[ $5 =~ filetype:* ]]; then
        icon=`echo $5 | sed -e 's/filetype://g'`
        RESULT="${RESULT}<icon type=\"filetype\">$(xmlEncode "${icon}")</icon>"
    else
        RESULT="${RESULT}<icon>$(xmlEncode "$5")</icon>"
    fi
    RESULT="${RESULT}</item>"

    RESULTS+=("$RESULT")
}

##
# Retrieve project from PhpStorm configuration
#  return a string with paths separate by a =
#
# @return string
getProjectsPath()
{
    escapedHome=`echo $HOME | sed -e 's/[/]/\\\\\//g'`
    basePath="$(grep -F -m 1 'CONFIG_PATH =' ${PHPSTORM_SCRIPT})"
    basePath="${basePath#*\'}"
    basePath="${basePath%\'*}"
    optionsOther="${basePath}/options/other.xml"
    recentProjectDirectories="${basePath}/options/recentProjectDirectories.xml"

    if [ -r ${recentProjectDirectories} ]; then # v9
        projects=`xmllint --xpath ${XPATH_RECENT_PROJECTS} ${recentProjectDirectories}`
        projects=`echo ${projects} | sed -e 's/key=//g' -e 's/value=//g' -e 's/" "/;/g' -e 's/^ *//g' -e 's/ *$//g' -e 's/"//g' -e "s/[$]USER_HOME[$]/${escapedHome}/g"`
        echo ${projects}
    elif [ -r ${optionsOther} ]; then #v7 & v8
        projects=`xmllint --xpath ${XPATH_PROJECTS} ${optionsOther} 2>/dev/null`
        if [[ -z ${projects} ]]; then
            projects=`xmllint --xpath ${XPATH_RECENT_PROJECTS} ${optionsOther}`
        fi
        projects=`echo ${projects} | sed -e 's/key=//g' -e 's/value=//g' -e 's/" "/;/g' -e 's/^ *//g' -e 's/ *$//g' -e 's/"//g' -e "s/[$]USER_HOME[$]/${escapedHome}/g"`
        echo ${projects}
    fi
}

##
# Retrieve project name from project configuration
#  search project name in this file because project name can be different than folder name
#   ex: folder: my-project ; project name: My Private Project
#
# @return string
extractProjectName()
{
    nameFile="$1/.idea/.name"
    if [ -r ${nameFile} ]; then
        projectName=`cat ${nameFile}`
        echo ${projectName}
    fi
}

##
# Enable nocasematch
enableNocasematch()
{
    CURRENT_NOCASEMATCH=`shopt | grep 'nocasematch' | sed -e 's/nocasematch//' -e 's/^ *//g' -e 's/ *$//g' | tr -d '\011'`
    shopt -s nocasematch
}

##
# Restore nocasematch
restoreNocasematch()
{
    if [ "${CURRENT_NOCASEMATCH}" == "off" ]; then
        shopt -u nocasematch
    fi
}

##
# Entry point
#  return XML string for Alfred
#
# @return string
findProjects()
{
    # enable insensitive comparaison
    enableNocasematch

    QUERY="$1"
    nbProjet=0
    projectsPath="$(getProjectsPath)"
    if [[ ! -z "${projectsPath}" ]]; then
        IFS=';'
        read -a projectsPath<<<"${projectsPath}"
        IFS=$''
        for projectPath in "${projectsPath[@]}"; do
            projectName=$(extractProjectName ${projectPath})
            if [ -n "${projectName}" ] && [ "${projectName}" != "" ]; then
                if [[ ${projectName} == *${QUERY}* ]] || [[ -z "${QUERY}" ]]; then
                    addResult ${projectName} ${projectPath} ${projectName} ${projectPath} 'fileicon:/Applications/PhpStorm.app' 'yes' ${projectName}
                    ((nbProjet++))
                fi
            fi
        done

        # if there is no project display information
        if [ ${nbProjet} -eq 0 ]; then
            addResult 'none' '' "No project match '${QUERY}'" "No project match '${QUERY}'" 'fileicon:/Applications/PhpStorm.app' 'yes' ${QUERY}
        fi
    else
        addResult 'none' '' "Can't find projects" "check configuration or contact developer" 'fileicon:/Applications/PhpStorm.app' 'yes' ''
    fi

    # restore nocasematch value
    restoreNocasematch

    getXMLResults
}

#getProjectsPath $1 # test

IFS=${ORIG_IFS}