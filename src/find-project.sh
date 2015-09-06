#!/bin/bash

# inlude workflowHandler (https://github.com/markokaestner/bash-workflow-handler)
. ./lib/workflowHandler.sh

# Path to PhpStorm script
PHPSTORM_SCRIPT="/usr/local/bin/pstorm"
# XPath to projects location in other.xml
XPATH_PROJECTS="//component[@name='RecentDirectoryProjectsManager']/option[@name='names']/map/entry/@key"
XPATH_RECENT_PROJECTS="//component[@name='RecentDirectoryProjectsManager']/option[@name='recentPaths']/list/option/@value"
# App Icon
APP_ICON='fileicon:/Applications/PhpStorm.app'
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
# Check if PhpStorm app exists
#  return string if app not found
#
# @return string|void
appExists ()
{
    runPath="$(grep -F -m 1 'RUN_PATH =' ${PHPSTORM_SCRIPT})"
    runPath="${runPath#*\'}"
    runPath="${runPath%\'*}"
    runPath="${runPath}/Contents/MacOS/phpstorm"
    if [[ ! -f "${runPath}" ]]; then
        echo "${runPath}"
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

    appPath=$(appExists)
    if [[ -z "${appPath}" ]]; then
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
                        addResult ${projectName} ${projectPath} ${projectName} ${projectPath} ${APP_ICON} 'yes' ${projectName}
                        ((nbProjet++))
                    fi
                fi
            done

            # if there is no project display information
            if [ ${nbProjet} -eq 0 ]; then
                addResult 'none' '' "No project match '${QUERY}'" "No project match '${QUERY}'" ${APP_ICON} 'yes' ${QUERY}
            fi
        else
            addResult 'none' '' "Can't find projects" "check configuration or contact developer" ${APP_ICON} 'yes' ''
        fi
    else
        addResult 'none' '' "Can't find projects" "Not a valid path: ${appPath}" ${APP_ICON} 'yes' ''
    fi

    # restore nocasematch value
    restoreNocasematch

    getXMLResults
}

# tests
#getProjectsPath $1
#findProjects $1
#appExists

IFS=${ORIG_IFS}