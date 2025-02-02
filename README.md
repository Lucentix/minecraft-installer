# Minecraft Installer

This script automates the installation and setup of a Minecraft server on a Linux machine.

## Features

- Checks if Java is installed and installs it if necessary.
- Downloads the specified version of the Minecraft server.
- Creates a `server.properties` file with default settings.
- Prompts the user to accept the Minecraft EULA.
- Creates a `eula.txt` file to accept the EULA.
- Sets up crontab for automatic server startup.
- Provides start, stop, and attach scripts for managing the server.

## Usage

To use this installer, run the following command:

```bash
bash <(curl -s https://raw.githubusercontent.com/Lucentix/minecraft-installer/main/install.sh)
```

### Options

- `-h, --help`: Display the help message.
- `--non-interactive`: Skip all interactive prompts by providing all required inputs as options.
- `-v, --version <URL|latest>`: Choose a Minecraft server version. Default: latest.
- `-u, --update <path>`: Update the Minecraft server version and specify the directory. Use `-v` or `--version` to specify the version or it will use the latest version.
- `-c, --crontab`: Enable or disable crontab autostart.
- `--kill-port`: Forcefully stop any process running on the Minecraft server port (25565).
- `--delete-dir`: Forcefully delete the `/home/minecraft` directory if it exists.

## Acknowledgements

This installer was adapted from the FiveM installer created by Twe3x. You can find the original FiveM installer [here](https://github.com/Twe3x/fivem-installer).

Special thanks to Twe3x for providing the original script that served as the foundation for this Minecraft installer.