# GitLab Deploy Key Management Script

## Overview
This repository contains a single Bash script to help manage deploy keys for GitLab projects and groups:

- **deploy-key.sh**: Add, enable, disable, or list deploy keys on one or more GitLab projects or groups.

The script uses the GitLab API and requires a personal access token and the Go-based `yq` tool (Mike Farah's yq, version 4+).

---

## Requirements
- **Bash** (tested on bash 5+)
- **curl**
- **yq** (Go-based, version 4 or later: https://github.com/mikefarah/yq)
- **A GitLab personal access token** with appropriate permissions (at least Reporter for reading, Maintainer for adding/removing keys)
- **Environment variables:**
  - `GL_ACCESS_TOKEN` (your GitLab personal access token)
  - `GITLAB_API` (your GitLab API base URL, e.g. `https://gitlab.example.com/api/v4`)

---

## Usage

### `deploy-key.sh`
Add, enable, disable, or list deploy keys on one or more GitLab projects.

#### Usage
```
./deploy-key.sh [OPTIONS]
```

#### Options
- `-g <group>`           Group ID or path (operate on all projects in group)
- `-p <project_id>`      Project ID (operate on a single project)
- `-a <title> <keyfile>` Add deploy key with <title> and public key file
- `-e <deploy_key_id>`   Enable existing deploy key by ID
- `-d <deploy_key_id>`   Disable (remove) deploy key by ID
- `-l`                   List deploy keys (for group or project)
- `-h`                   Show help message

#### Examples
- Add a deploy key to all projects in a group:
  ```
  ./deploy-key.sh -g mygroup -a "My Key" /path/to/key.pub
  ```
- Add a deploy key to a single project:
  ```
  ./deploy-key.sh -p 1234 -a "My Key" /path/to/key.pub
  ```
- Enable an existing deploy key for a project:
  ```
  ./deploy-key.sh -p 1234 -e 5678
  ```
- Disable (remove) a deploy key from a project:
  ```
  ./deploy-key.sh -p 1234 -d 5678
  ```
- Disable (remove) a deploy key from all projects in a group:
  ```
  ./deploy-key.sh -g 1234 -d 5678
  ```
- List all deploy keys for all projects in a group:
  ```
  ./deploy-key.sh -g 1234 -l
  ```
- List all deploy keys for a single project:
  ```
  ./deploy-key.sh -p 5678 -l
  ```

---

## Environment Setup
Add the following lines to your `.bashrc` or `.bash_profile`:
```sh
export GL_ACCESS_TOKEN=your_token
export GITLAB_API=https://gitlab.example.com/api/v4
```

---

## License

Copyright 2024 Max Chudnovsky

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
