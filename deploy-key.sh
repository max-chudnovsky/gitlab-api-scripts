#!/bin/bash
# script lets you add or enable deploy key on gitlab project
# Requires: curl and Go-based yq (Mike Farah's yq, version 4 or later).
# written by: Max Chudnovsky

### Initialize variables
GROUP=""
PROJECT=""
ACT=""
DEPLOY_KEY_TITLE=""
DEPLOY_KEY_FILE=""
DEPLOY_KEY_ID=""

# lets make sure access token variable set.  if not, add "export GL_ACCESS_TOKEN=xxx" variable to your .bashrc
[ "$GL_ACCESS_TOKEN" ] || { 
	echo "$0: Error.  GL_ACCESS_TOKEN variable is not set in your environment.  It needs to contain gitlab access token."
	exit 1
}
[ "$GITLAB_API" ] || { 
	echo "$0: Error.  GITLAB_API variable is not set in your environment.  It needs to contain gitlab API path.  For example: https://server/api/v4"
	exit 1
}

### FUNCTIONS
list_deploy_keys_for_project() {
    local project_id="$1"
    local project_path="$2"

    keys=$(curl --silent --header "PRIVATE-TOKEN: $GL_ACCESS_TOKEN" \
        "$GITLAB_API/projects/$project_id/deploy_keys")

    echo "------------------------------------------------------------"
    echo "Deploy keys for project: $project_path (ID: $project_id)"
    if [[ -z "$keys" || "$keys" == "[]" ]]; then
        echo "  No deploy keys found."
    else
        echo "  $keys" | yq -o=json -r '.[] | "  ID: \(.id)  Title: \(.title)"'
    fi
}

get_all_projects() {
    local page=1
    local result=1
    while [[ $result -gt 0 ]]; do
        projects=$(curl --silent --header "PRIVATE-TOKEN: $GL_ACCESS_TOKEN" \
            "$GITLAB_API/groups/$GROUP/projects?include_subgroups=true&per_page=200&page=$page")
        result=$(echo "$projects" | yq -o=json -r 'length')
        if [[ $result -eq 0 ]]; then
            break
        fi
        echo "$projects" | yq -o=json -r '.[] | "\(.id) \(.path_with_namespace)"'
        ((page++))
    done
}

# Add deploy key to project
add_deploy_key_to_project() {
    local project_id="$1"

    # Make the API call and capture the response and status code
    response=$(curl --silent --write-out "HTTPSTATUS:%{http_code}" --request POST "$GITLAB_API/projects/$project_id/deploy_keys" \
        --header "PRIVATE-TOKEN: $GL_ACCESS_TOKEN" \
        --header "Content-Type: application/json" \
        --data "{
            \"title\": \"$DEPLOY_KEY_TITLE\",
            \"key\": \"$(cat "$DEPLOY_KEY_FILE")\",
            \"can_push\": false
        }")

    # Extract the body and status code
    body=$(echo "$response" | sed -e 's/HTTPSTATUS\:.*//g')
    status_code=$(echo "$response" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')

    # Handle response
    if [[ "$status_code" -eq 201 ]]; then
        echo "added"
    elif [[ "$status_code" -eq 400 ]]; then
        echo "already there, skipped"
        echo "Response: $body"
    else
        echo "failed (Status: $status_code)"
        echo "Response: $body"
    fi
}

# Enable existing deploy key for a project
enable_deploy_key_for_project() {
    local project_id="$1"
    local deploy_key_id="$2"  # You need the key ID, not the full key content

    response=$(curl --silent --write-out "HTTPSTATUS:%{http_code}" --request POST \
        "$GITLAB_API/projects/$project_id/deploy_keys/$deploy_key_id/enable" \
        --header "PRIVATE-TOKEN: $GL_ACCESS_TOKEN")

    body=$(echo "$response" | sed -e 's/HTTPSTATUS\:.*//g')
    status_code=$(echo "$response" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')

    if [[ "$status_code" -eq 201 ]]; then
        echo "enabled"
    elif [[ "$status_code" -eq 409 ]]; then
        echo "already there, skipped"
    else
        echo "failed (Status: $status_code)"
        echo "Response: $body"
    fi
}

# Disable (remove) deploy key from a project
disable_deploy_key_from_project() {
    local project_id="$1"
    local deploy_key_id="$2"
    response=$(curl --silent --write-out "HTTPSTATUS:%{http_code}" --request DELETE \
        "$GITLAB_API/projects/$project_id/deploy_keys/$deploy_key_id" \
        --header "PRIVATE-TOKEN: $GL_ACCESS_TOKEN")
    body=$(echo "$response" | sed -e 's/HTTPSTATUS\:.*//g')
    status_code=$(echo "$response" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
    if [[ "$status_code" -eq 204 ]]; then
        echo "disabled"
    elif [[ "$status_code" -eq 404 ]]; then
        echo "not found, skipped"
    else
        echo "failed (Status: $status_code)"
        echo "Response: $body"
    fi
}

print_usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Add, enable, disable, or list deploy keys on GitLab projects.

Options:
  -g <group>           Group ID or path (operate on all projects in group)
  -p <project_id>      Project ID (operate on a single project)
  -a <title> <keyfile> Add deploy key with <title> and public key file
  -e <deploy_key_id>   Enable existing deploy key by ID
  -d <deploy_key_id>   Disable (remove) deploy key by ID
  -l                   List deploy keys (for group or project)
  -h                   Show this help message

Examples:
  $0 -g mygroup -a "My Key" /path/to/key.pub
  $0 -p 1234 -a "My Key" /path/to/key.pub
  $0 -p 1234 -e 5678
  $0 -g 1234 -l
  $0 -p 5678 -l
  $0 -g 1234 -d 5678
  $0 -p 5678 -d 9999

Notes:
  - You must set the GL_ACCESS_TOKEN and GITLAB_API (example: https://gitlab_server/api/v4") environment variables.
      example: export GL_ACCESS_TOKEN=your_token
               export GITLAB_API=https://gitlab_server/api/v4
      add these lines to your .bashrc or .bash_profile
  - Either -g or -p is required. One of -a, -e, -d, or -l is required.
EOF
}

# Show usage if -h is given or no arguments
if [[ "$1" == "-h" || "$1" == "--help" || $# -eq 0 ]]; then
  print_usage
  exit 0
fi

LIST_KEYS=0
DISABLE_KEY=0

### Parse options
while getopts ":g:p:a:e:d:l" opt; do
  case "$opt" in
    g)
      GROUP="$OPTARG"
      ;;
    p)
      PROJECT="$OPTARG"
      ;;
    a)
      ACT="add"
      DEPLOY_KEY_TITLE="$OPTARG"
      DEPLOY_KEY_FILE="${!OPTIND}"
      ((OPTIND++))
      ;;
    e)
      ACT="enable"
      DEPLOY_KEY_ID="$OPTARG"
      ;;
    d)
      ACT="disable"
      DISABLE_KEY=1
      DEPLOY_KEY_ID="$OPTARG"
      ;;
    l)
      LIST_KEYS=1
      ;;
    :)
      echo "Error: -$OPTARG requires an argument" >&2
      exit 1
      ;;
    \?)
      echo "Error: Invalid option -$OPTARG" >&2
      exit 1
      ;;
  esac
done

### Validate required group or project option
if [[ -z "$GROUP" && -z "$PROJECT" ]]; then
  echo "Error: Either -g <group> or -p <project_id> is required" >&2
  exit 1
fi

# Validate action and its arguments
if [[ "$ACT" == "add" ]]; then
  if [[ -z "$DEPLOY_KEY_TITLE" || -z "$DEPLOY_KEY_FILE" ]]; then
    echo "Error: -a requires <title> and <keyfile>" >&2
    exit 1
  fi
  if [[ ! -f "$DEPLOY_KEY_FILE" || ! -r "$DEPLOY_KEY_FILE" ]]; then
    echo "Error: Key file '$DEPLOY_KEY_FILE' does not exist or is not readable" >&2
    exit 1
  fi
elif [[ "$ACT" == "enable" ]]; then
  if [[ -z "$DEPLOY_KEY_ID" ]]; then
    echo "Error: -e requires <deploy_key_id>" >&2
    exit 1
  fi
elif [[ "$ACT" == "disable" ]]; then
  if [[ -z "$DEPLOY_KEY_ID" ]]; then
    echo "Error: -d requires <deploy_key_id>" >&2
    exit 1
  fi
else
  if [[ $LIST_KEYS -eq 0 ]]; then
    echo "Error: One of -a, -e, -d, or -l must be specified" >&2
    exit 1
  fi
fi

### MAIN
if [[ $DISABLE_KEY -eq 1 ]]; then
  if [[ -n "$PROJECT" ]]; then
    # Disable key for single project
    echo -n "Disabling deploy key $DEPLOY_KEY_ID for project ID: $PROJECT: "
    disable_deploy_key_from_project "$PROJECT" "$DEPLOY_KEY_ID"
  elif [[ -n "$GROUP" ]]; then
    # Disable key for all projects in group
    while IFS=" " read -r pid full_path; do
      echo -n "Disabling deploy key $DEPLOY_KEY_ID for project: $full_path (ID: $pid): "
      disable_deploy_key_from_project "$pid" "$DEPLOY_KEY_ID"
    done < <(get_all_projects)
  else
    echo "Error: -g <group> or -p <project_id> is required for -d" >&2
    exit 1
  fi
  exit 0
fi

if [[ $LIST_KEYS -eq 1 ]]; then
  if [[ -n "$PROJECT" ]]; then
    # List keys for single project
    # Try to get project path_with_namespace for display
    project_path=$(curl --silent --header "PRIVATE-TOKEN: $GL_ACCESS_TOKEN" "$GITLAB_API/projects/$PROJECT" | yq -o=json -r '.path_with_namespace // "(single project)"')
    list_deploy_keys_for_project "$PROJECT" "$project_path"
  elif [[ -n "$GROUP" ]]; then
    # List keys for all projects in group
    while IFS=" " read -r pid full_path; do
      list_deploy_keys_for_project "$pid" "$full_path"
    done < <(get_all_projects)
  else
    echo "Error: -g <group> or -p <project_id> is required for -l" >&2
    exit 1
  fi
  exit 0
fi

if [[ -n "$PROJECT" ]]; then
  # Single project mode
  echo -n "Deploy key $DEPLOY_KEY_TITLE for project ID: $PROJECT: "
  if [ "$ACT" = "add" ]; then
    add_deploy_key_to_project "$PROJECT"
  elif [ "$ACT" = "enable" ]; then
    enable_deploy_key_for_project "$PROJECT" "$DEPLOY_KEY_ID"
  fi
else
  # Group mode
  while IFS=" " read -r pid full_path; do
      echo -n "Deploy key $DEPLOY_KEY_TITLE for project: $full_path (ID: $pid): "
      if [ "$ACT" = "add" ]; then
        add_deploy_key_to_project "$pid"
      elif [ "$ACT" = "enable" ]; then
        enable_deploy_key_for_project "$pid" "$DEPLOY_KEY_ID"
      fi
  done < <(get_all_projects)
fi