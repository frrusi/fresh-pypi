#!/usr/bin/env bash

# --- сonstants --- #
BROWN='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
RESET='\033[0m'
CLEAR='\033c'

MIRROR="https://pypi.org"

function getMessage {
  # $1 - user message
  printf '[%s %s] %b\n' "$(date +"%F")" "$(date +"%T")" "$1"
}

function getErrorMessage {
  # $1 - user message
  getMessage "[${RED}error${RESET}] $1"
  exit 1
}

function getWarningMessage {
  # $1 - user message
  getMessage "[${BROWN}warning${RESET}] $1"
}

function getNotificationMessage {
  # $1 - user message
  getMessage "[${BLUE}notification${RESET}] $1"
}

function clearTerminal {
  printf '%b' $CLEAR
}

# --- main --- #
clearTerminal

# --- File check --- #
if [ -z "$1" ] || [ ! -f "$1" ]; then
  getErrorMessage 'file not found'
elif [ ! -s "$1" ]; then
  getErrorMessage "file ${BROWN}$1${RESET} is empty"
else
  filename="$1"
fi

# --- Read File --- #
declare -a packages

# https://unix.stackexchange.com/a/478732
while IFS= read -r line || [[ -n $line ]]; do
  getNotificationMessage "read line from file: ${BROWN}$line${RESET}"

  # Package name: https://packaging.python.org/en/latest/specifications/name-normalization/
  # Package version: https://peps.python.org/pep-0440/#version-scheme | https://peps.python.org/pep-0440/#appendix-b-parsing-version-strings-with-regular-expressions
  # Package version specifiers: https://peps.python.org/pep-0440/#version-specifiers
  if [[ "${line,,}" =~ ^([a-z0-9]|[a-z0-9][a-z0-9._-]*[a-z0-9])((<|<=|!=|==|>=|>|~=|===)(([1-9][0-9]*!)?(0|[1-9][0-9]*)(\.(0|[1-9][0-9]*))*((a|b|rc)(0|[1-9][0-9]*))?(\.post(0|[1-9][0-9]*))?(\.dev(0|[1-9][0-9]*))?))?$ ]]; then
    packageName="${BASH_REMATCH[1]}"
    packageVersion="${BASH_REMATCH[4]}"

    if [ -z "$packageVersion" ]; then
      packageVersion=None
    fi

    getNotificationMessage "parsing a package: name=${BROWN}$packageName${RESET}, version=${BROWN}$packageVersion${RESET}"

    pypiAnswer="$(curl -s "$MIRROR/pypi/$packageName/json")"
    if [ "$(printf "%s" "$pypiAnswer" | jq '.message' | tr -d \")" == "Not Found" ]; then
      getWarningMessage "the package ${BROWN}$packageName${RESET} does not exist"
      continue
    fi

    lastVersionPackage="$(printf "%s" "$pypiAnswer" | jq '.info.version' | tr -d \")"

    if [ "$packageVersion" == "None" ]; then
      getWarningMessage "the version of the package ${BROWN}$packageName${RESET} is not specified"
    elif [ "$packageVersion" != "$lastVersionPackage" ]; then
      getWarningMessage "the ${BROWN}$packageName${RESET} package version ${BROWN}$packageVersion${RESET} is old. New version=${BROWN}$lastVersionPackage${RESET}"
    fi

    packages+=("$packageName==$lastVersionPackage")
  else
    getWarningMessage "the name of the package is invalid"
  fi
  printf "\n"
done < "$filename"

# --- Interactive output --- #
for (( i=0; i<${#packages[@]}; i++ ));
do
  read -r -p $"[INTERACTIVE] The final result (change, press the 'Enter' key): " -e -i "${packages[$i]}" packages["$i"]
  printf "%s\n" "${packages[$i]}" >> requirements.new
done

getNotificationMessage "the change is saved in 'requirements.new'"
