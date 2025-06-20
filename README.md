# AutoWifite - Enhanced Wifite SSID Wrapper

A powerful Bash wrapper script that enhances wifite by allowing network testers to quickly target specific wireless networks by SSID with improved automation and error handling.

## Overview

This tool simplifies the wireless network penetration testing process by wrapping the popular wifite tool into a more streamlined command. Instead of having to remember wifite's specific syntax for targeting SSIDs, this wrapper allows you to simply specify the target network name as the first parameter and handles common setup and cleanup tasks automatically.

## Features

- Target specific wireless networks by SSID with a simplified command
- Automatic detection of wireless interfaces
- Automatic monitor mode cleanup when exiting
- Root privilege verification
- Pass through all additional wifite parameters
- Built-in validation to ensure wifite and airmon-ng are installed
- Logging of wifite output to a file for debugging
- Easily extensible for additional functionality

## Prerequisites

- Kali Linux or similar penetration testing distribution
- wifite installed and in your PATH
- airmon-ng and iw tools installed
- Wireless adapter capable of monitor mode
- Root privileges

## Installation

1. Download the script:
   ```bash
   curl -O https://raw.githubusercontent.com/n-cognto/AutoWifite-/main/autowifite.sh
   ```

2. Make the script executable:
   ```bash
   chmod +x autowifite.sh
   ```

3. Optionally, move it to your PATH for system-wide access:
   ```bash
   sudo mv autowifite.sh /usr/local/bin/autowifite
   ```

## Usage

Basic usage:
```bash
sudo ./autowifite.sh <TARGET_SSID>
```

With additional wifite options:
```bash
sudo ./autowifite.sh CoffeeShopWiFi --no-wps --kill -v
```

## Examples

Target a specific network:
```bash
sudo ./autowifite.sh MyHomeNetwork
```

Target a network and run a verbose attack without WPS:
```bash
sudo ./autowifite.sh CompanyWiFi --no-wps -v
```

Target a network and automatically kill conflicting processes:
```bash
sudo ./autowifite.sh GuestNetwork --kill
```

## Troubleshooting

If you encounter issues with network detection:
1. Make sure your wireless adapter supports monitor mode
2. Try running with the `--kill` option to handle conflicting processes
3. Check that the SSID spelling is correct (the current version is case-sensitive)

If wifite returns without finding your network, try:
```bash
sudo ./autowifite.sh PartialNetworkName -v
```

## Customization

The script can be modified to include additional functionality:
- Case-insensitive SSID matching
- Automatic selection of similar SSIDs if exact match isn't found
- Custom attack profiles for different testing scenarios

## Legal Disclaimer

This tool is provided for educational and ethical penetration testing purposes only. Only use this tool on networks you own or have explicit permission to test. Unauthorized network penetration testing is illegal and unethical.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request with improvements or bug fixes.

## Changelog

### Version 1.1
- Added automatic monitor mode cleanup
- Added root privilege check
- Added automatic wireless interface detection
- Improved error handling and messaging
- Added logging of wifite output to a file
- Added check for airmon-ng installation

### Version 1.0
- Initial release
- Basic SSID targeting functionality
