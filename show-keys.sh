#!/bin/bash
# Script takes project group id number parameter and lists all projects with corresponding deploy keys
# written by Max Chudnovsky

# Config
GROUP=""
PROJECT=""

if [ $# -lt 2 ] || [ $# -gt 3 ]; then
	echo "$0: Error.  Missing or too many arguments."
	echo "  Usage:"
    echo "  $0 -g <group_id>            # List all projects in group and their deploy keys"
    echo "  $0 -p <project_id>           # List deploy keys for a single project"
    echo "  Example: $0 -g 1234"
    echo "  Example: $0 -p 5678"
    echo -e "\n  This script lists all projects in the group (and subgroups) and their deploy keys, or for a single project if -p is used."
    echo -e "\n  Environment variables required:"
    echo "  GL_ACCESS_TOKEN   Your GitLab personal access token."
    echo "  GITLAB_API        GitLab API base URL, e.g. https://gitlab.example.com/api/v4"
    exit 1
fi

if [ "$1" = "-p" ]; then
    if [ $# -ne 2 ]; then
        echo "$0: Error.  -p requires a project id argument."
        exit 1
    fi
    PROJECT="$2"
elif [ "$1" = "-g" ]; then
    if [ $# -ne 2 ]; then
        echo "$0: Error.  -g requires a group id argument."
        exit 1
    fi
    GROUP="$2"
else
    echo "$0: Error.  Invalid option. Use -g <group_id> or -p <project_id>." >&2
    exit 1
fi

# lets make sure variable set
[ "$GL_ACCESS_TOKEN" ] || { 
	echo "$0: Error.  GL_ACCESS_TOKEN variable is not set in your environment.  It needs to contain gitlab access token."
	exit
}
[ "$GITLAB_API" ] || { 
    echo "$0: Error.  GITLAB_API variable is not set in your environment.  It needs to contain gitlab API path.  For example: https://server/api/v4"
    exit
}

# --- Get all project IDs and paths in the group and subgroups ---
get_all_projects() {
    local page=1
    local result=1
    while [[ $result -gt 0 ]]; do
        projects=$(curl --silent --header "PRIVATE-TOKEN: $GL_ACCESS_TOKEN" \
            "$GITLAB_API/groups/$GROUP/projects?include_subgroups=true&per_page=100&page=$page")
        result=$(echo "$projects" | yq -o=json -r 'length')
        if [[ $result -eq 0 ]]; then
            break
        fi
        echo "$projects" | yq -o=json -r '.[] | "\(.id) \(.path_with_namespace)"'
        ((page++))
    done
}

# --- List deploy keys for a given project ---
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

# --- MAIN ---
if [ -n "$PROJECT" ]; then
    # Single project mode
    list_deploy_keys_for_project "$PROJECT" "(single project)"
elif [ -n "$GROUP" ]; then
    # Group mode
    while IFS=" " read -r pid full_path; do
        list_deploy_keys_for_project "$pid" "$full_path"
    done < <(get_all_projects)
fi
