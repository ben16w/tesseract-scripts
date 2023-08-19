# tesseract-scripts

This project contains the bash scripts used by the ansible collections tesseract-system, tesseract-app and tesseract-network. These scripts can also be used manually by following the instructions below.

## Installation

Firstly, clone this repository to your local machine:

    git clone https://github.com/ben16w/tesseract-scripts.git

Then edit create a file named `.env` in the root of the repository and add the environment variables required by the script. For example:

    TESSERACT_SCRIPTS_PATH=/path/to/tesseract-scripts

Finally, run the script reqiured. For example:

    bash ./local_bakcup.sh /home/tesseract

## License

This project is licensed under the Unlicense - see the LICENSE file for details
