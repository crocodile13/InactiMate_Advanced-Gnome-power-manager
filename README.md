# PowerPolicyManager
An interactive manager for inactivity and power-saving policies for Linux systems, allowing quick and easy configuration of sleep, hibernation, and power management behaviors. I designed it for Archlinux to simplify my life, but it should work with any gnome+systemd environment I think. AI (Claude 3.7 Sonnet and GPT4o) was a great help as you probably see from the code, it gets the job done...

![Version](https://img.shields.io/badge/version-1.1-blue.svg)
![Platform](https://img.shields.io/badge/platform-Linux-green.svg)
![GNOME](https://img.shields.io/badge/GNOME-Compatible-orange.svg)
![systemd](https://img.shields.io/badge/systemd-Compatible-purple.svg)

## 📋 Features
- ⚡ Complete configuration of GNOME power-saving settings
- 🔄 Management of behaviors on battery and when plugged in
- 💤 Configuration of actions when closing the laptop lid
- ⏱️ Setting sleep delay timers
- 🛠️ Configuration of systemd-logind (power button actions, etc.)
- 📱 Preconfigured profiles for laptops and desktop PCs
- 📤 Export configurations for backup or sharing

## 🖼️ Screenshots
<center>
<em>Main application menu</em>
</center>

## 🚀 Installation
### Simple method
```bash
# Download the script
wget https://raw.githubusercontent.com/your-name/PowerPolicyManager/main/power-policy-manager.sh
# Make the script executable
chmod +x power-policy-manager.sh
# Run the script
./power-policy-manager.sh
```

### From source
```bash
# Clone the repository
git clone https://github.com/your-name/PowerPolicyManager.git
# Enter the directory
cd PowerPolicyManager
# Make the script executable
chmod +x power-policy-manager.sh
# Run the script
./power-policy-manager.sh
```

## 📝 Prerequisites
- A Linux system with GNOME and/or systemd
- The `gsettings-desktop-schemas` or `gnome-settings-daemon` package
- Sudo rights to modify systemd-logind settings

## 🔧 Usage
The interface is fully interactive and guided. After launching the script, you can:
1. Browse the settings available on your system
2. Individually modify each setting
3. Apply predefined configurations (laptop or desktop PC)
4. View configuration tips adapted to your hardware
5. Export your current configuration

## 📚 Configurable Settings
### GNOME Settings
- Sleep delay timers (when plugged in and on battery)
- Actions after inactivity (sleep, hibernation, shutdown...)
- Behavior when closing the laptop lid
- Screen dimming during inactivity
- Power-saving profile on low battery

### systemd-logind Settings
- Actions when pressing the power button
- Actions when closing the laptop lid (with or without external screen)
- Actions after prolonged inactivity
- Behavior of sleep/hibernation keys

## 🔍 Usage Tips
- On a laptop, favor short delays on battery (5-10 minutes)
- To save battery, use the "suspend" action after inactivity
- For security, configure at least screen locking
- On a desktop PC, longer delays are generally preferable

## 🤝 Contribution
Contributions are welcome! Feel free to:
1. Fork the project
2. Create a branch for your feature (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License
This project is distributed under the MIT license. See the `LICENSE` file for more information.

## 🙏 Acknowledgements
- Thanks to the GNOME community for the documentation on GSettings
- Thanks to the systemd community for the documentation on logind.conf
