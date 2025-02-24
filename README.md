# scripts

This project contains the bash scripts used by the ansible collections tesseract-system, tesseract-app and tesseract-network. These scripts can also be used manually by following the instructions below.

## Installation

Install the required system packages:

```sh
sudo apt install make python3 python3-pip python3-venv
```

Set up the virtual environment and install the required Python packages:

```sh
make install-venv
```

Lint the scripts:

```sh
make lint
```

## Usage

Create a file named `.env` in the root of the repository and add the environment variables required by the script. For example:

```sh
TESSERACT_SCRIPTS_PATH=/path/to/tesseract-scripts
```

Finally, run the script reqiured. For example:

```sh
bash ./local_bakcup.sh /home/tesseract
```

## License

This project is licensed under the Unlicense. See the [LICENSE](LICENSE) file for details.

## Authors

- Ben Wadsworth
