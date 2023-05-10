#!/bin/bash

# --- CONSTANTS --- #
BROWN="\033[0;33m"
NOCOLOR="\033[0m"

MIRROR="https://pypi.org"

# --- Cleaning the Terminal --- #
printf "\033c"

# --- File check --- #
if [ ! -n "$1" ] || [ ! -f "$1" ]; then
  printf "[%s %s] [ERROR] File not found. Program exit.\n" "$(date +"%F")" "$(date +"%T")"
  exit 404
elif [ ! -s "$1" ]; then
  printf "[%s %s] [ERROR] File ${BROWN}%s${NOCOLOR} is empty. Program exit.\n" "$(date +"%F")" "$(date +"%T")" "$1"
  exit 400
else
  filename="$1"
fi

# --- Read File --- #
declare -a packages

while IFS= read -r line; do
  printf "[%s %s] [DEBUG] Read line from file: ${BROWN}%s${NOCOLOR}\n" "$(date +"%F")" "$(date +"%T")" "$line"

  # Package name: https://packaging.python.org/en/latest/specifications/name-normalization/
  # Package version: https://peps.python.org/pep-0440/#version-scheme | https://peps.python.org/pep-0440/#appendix-b-parsing-version-strings-with-regular-expressions
  # Package version specifiers: https://peps.python.org/pep-0440/#version-specifiers
  if [[ "${line,,}" =~ ^([a-z0-9]|[a-z0-9][a-z0-9._-]*[a-z0-9])((<|<=|!=|==|>=|>|~=|===)(([1-9][0-9]*!)?(0|[1-9][0-9]*)(\.(0|[1-9][0-9]*))*((a|b|rc)(0|[1-9][0-9]*))?(\.post(0|[1-9][0-9]*))?(\.dev(0|[1-9][0-9]*))?))?$ ]]; then
    packageName="${BASH_REMATCH[1]}"
    packageVersion="${BASH_REMATCH[4]}"

    if [ -z "$packageVersion" ]; then
      packageVersion=None
    fi

    printf "[%s %s] [DEBUG] Parsing a package: name=${BROWN}%s${NOCOLOR}, version=${BROWN}%s${NOCOLOR}\n" "$(date +"%F")" "$(date +"%T")" "$packageName" "$packageVersion"

    pypiAnswer="$(curl -s "$MIRROR/pypi/$packageName/json")"
    if [ "$(printf "%s" "$pypiAnswer" | jq '.message' | tr -d \")" == "Not Found" ]; then
      printf "[%s %s] [WARNING] The package ${BROWN}%s${NOCOLOR} does not exist\n\n" "$(date +"%F")" "$(date +"%T")" "$packageName"
      continue
    fi

    lastVersionPackage="$(printf "%s" "$pypiAnswer" | jq '.info.version' | tr -d \")"

    if [ "$packageVersion" == "None" ]; then
      printf "[%s %s] [WARNING] The version of the package ${BROWN}%s${NOCOLOR} is not specified\n" "$(date +"%F")" "$(date +"%T")" "$packageName"
    elif [ "$packageVersion" != "$lastVersionPackage" ]; then
      printf "[%s %s] [WARNING] The ${BROWN}%s${NOCOLOR} package version ${BROWN}%s${NOCOLOR} is old. New version=${BROWN}%s${NOCOLOR}\n" "$(date +"%F")" "$(date +"%T")" "$packageName" "$packageVersion" "$lastVersionPackage"
    fi

    packages+=("$packageName==$lastVersionPackage")
  else
    printf "[%s %s] [WARNING] The name of the package is invalid\n" "$(date +"%F")" "$(date +"%T")"
  fi
  printf "\n"
done < "$filename"

# --- Interactive output --- #
for (( i=0; i<${#packages[@]}; i++ ));
do
  read -p $"[INTERACTIVE] The final result (change, press the 'Enter' key): " -e -i "${packages[$i]}" packages[$i]
  printf "%s\n" "${packages[$i]}" >> requirements.new
done

printf "[%s %s] [NOTIFICATION] The change is saved in 'requirements.new'\n" "$(date +"%F")" "$(date +"%T")"
