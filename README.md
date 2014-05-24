PhpStorm: Open project
========================

Easily open your PhpStorm projects with Alfred2 workflow

## Requirements
This workflow need PhpStorm command line tools to works:

1. Open PhpStorm
2. Go to "Tools" and "Create Command-line Launcher"
3. In the popup windows, just click on OK

### Customisation
If you change command line tools path, you need to update worflow settings:

1. Go to worklows list and select "PhpStorm: Open project"
2. Double click on "Run Script" box
  * Click on "Open workflow folder"
  * Edit `find-project.sh`, and change `PHPSTORM_SCRIPT` value.
  * Save file and return to "Run Script" box
  * In "Script:" field, update line 2 (`/usr/local/bin/pstorm {query}`)
  * Save

## Installation
1. Download workflow from `package` folder
2. Double click on downloaded file (PhpStorm: Open project.alfredworkflow)


## How to use
* Open Alfred with your usual hotkey
* Type keyword `pstorm` followed by your project name
![phpstorm-alfred-workflow](https://lh3.googleusercontent.com/IkTz0dD5G7s0omIkKHTr-lV9cNDTbyHi3PmiHEjmRDA=w568-h207-p-no)

## Credits
This workflow use [Bash Workflow Handler](https://github.com/markokaestner/bash-workflow-handler)
