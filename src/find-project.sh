#!/bin/bash

# inlude workflowHandler (https://github.com/markokaestner/bash-workflow-handler)
. ./lib/workflowHandler.sh

# Path to PhpStorm script
PHPSTORM_SCRIPT="/usr/local/bin/pstorm"
# XPath to projects location in other.xml
XPATH_PROJECTS="//component[@name='RecentDirectoryProjectsManager']/option[@name='names']/map/entry/@key"
# XPath to project name in workspace.xml
XPATH_PROJECT_NAME="//component[@name='FavoritesManager']/favorites_list/@name"
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
    otherOptions="$(grep -F -m 1 'CONFIG_PATH =' ${PHPSTORM_SCRIPT})"
    otherOptions="${otherOptions#*\'}"
    otherOptions="${otherOptions%\'*}"
    otherOptions="${otherOptions}/options/other.xml"
    if [ -r ${otherOptions} ]; then
        escapedHome=`echo $HOME | sed -e 's/[/]/\\\\\//g'`
        projects=`xmllint --xpath ${XPATH_PROJECTS} ${otherOptions} | sed -e 's/key=//g' -e 's/" "/;/g' -e 's/^ *//g' -e 's/ *$//g' -e 's/"//g' -e "s/[$]USER_HOME[$]/${escapedHome}/g"`
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
    nameFile="$1/.idea/workspace.xml"
    if [ -r ${nameFile} ]; then
        projectName=`xmllint --xpath ${XPATH_PROJECT_NAME} ${nameFile} | sed -e 's/name="//g' -e 's/^ *//g' -e 's/ *$//g' -e 's/"//g'`
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
                if [[ ${projectName} == *${QUERY}* ]]; then
                    addResult ${projectName} ${projectPath} ${projectName} ${projectPath} 'fileicon:/Applications/PhpStorm.app' 'yes' 'autocomplete'
                    ((nbProjet++))
                fi
            fi
        done

        # if there is no project display information
        if [ ${nbProjet} -eq 0 ]; then
            addResult 'none' '' "No project match '${QUERY}'" "No project match '${QUERY}'" 'fileicon:/Applications/PhpStorm.app' 'yes' 'autocomplete'
        fi
    else
        addResult 'none' '' "Can't find projects" "check configuration or contact developer" 'fileicon:/Applications/PhpStorm.app' 'yes' 'autocomplete'
    fi

    # restore nocasematch value
    restoreNocasematch

    getXMLResults
}

#findProjects $1 # test

IFS=${ORIG_IFS}