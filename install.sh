#!/bin/bash

red="\e[0;91m"
green="\e[0;92m"
bold="\e[1m"
reset="\e[0m"

if [ "$EUID" -ne 0 ]; then
	echo -e "${red}Please run as root";
	exit 1
fi

status(){
  clear
  echo -e $green$@'...'$reset
  sleep 1
}

runCommand(){
    COMMAND=$1

    if [[ ! -z "$2" ]]; then
      status $2
    fi

    eval $COMMAND;
    BASH_CODE=$?
    if [ $BASH_CODE -ne 0 ]; then
      echo -e "${red}An error occurred:${reset} ${white}${COMMAND}${reset}${red} returned${reset} ${white}${BASH_CODE}${reset}"
      exit ${BASH_CODE}
    fi
}

dir=/home/minecraft

update_artifacts=false
non_interactive=false
artifacts_version=0
kill_minecraft=0
delete_dir=0
minecraft_deployment=0
crontab_autostart=0
accept_eula=false

function checkJava() {
    if ! java -version &>/dev/null; then
        runCommand "apt update -y && apt install -y openjdk-17-jre-headless" "Installing Java"
    fi
}

function selectVersion(){
    if [[ "${artifacts_version}" == "0" ]]; then
        if [[ "${non_interactive}" == "false" ]]; then
            status "Select a Minecraft version"
            export OPTIONS=("latest version" "choose custom version" "do nothing")

            bashSelect

            case $? in
                0 )
                    artifacts_version="https://piston-data.mojang.com/v1/objects/4707d00eb834b446575d89a61a11b5d548d8c001/server.jar"
                    ;;
                1 )
                    clear
                    read -p "Enter the download link: " artifacts_version
                    ;;
                2 )
                    exit 0
            esac

            return
        else
            artifacts_version="latest"
        fi
    fi
    if [[ "${artifacts_version}" == "latest" ]]; then
        artifacts_version="https://piston-data.mojang.com/v1/objects/4707d00eb834b446575d89a61a11b5d548d8c001/server.jar"
    fi
}

function createServerProperties() {
  status "Creating server.properties"

  cat << EOF > $dir/server.properties
#Minecraft server properties
#Generated by install script
max-tick-time=60000
generator-settings=
allow-nether=true
level-name=world
enable-query=false
allow-flight=false
announce-player-achievements=true
server-port=25565
max-world-size=29999984
level-type=DEFAULT
enable-rcon=false
level-seed=
force-gamemode=false
server-ip=
network-compression-threshold=256
max-build-height=256
spawn-npcs=true
white-list=false
spawn-animals=true
hardcore=false
snooper-enabled=true
resource-pack-sha1=
online-mode=true
resource-pack=
pvp=true
difficulty=1
enable-command-block=false
gamemode=0
player-idle-timeout=0
max-players=20
spawn-monsters=true
generate-structures=true
view-distance=10
motd=A Minecraft Server
EOF
}

function promptEula() {
    if [[ "${non_interactive}" == "false" ]]; then
        status "Do you accept the Minecraft EULA? (https://account.mojang.com/documents/minecraft_eula)"
        export OPTIONS=("yes" "no")
        bashSelect

        if [[ $? == 0 ]]; then
            accept_eula=true
        else
            echo -e "${red}You must accept the EULA to proceed.${reset}"
            exit 1
        fi
    else
        accept_eula=true
    fi
}

function createEula() {
    if [[ "${accept_eula}" == "true" ]]; then
        status "Creating eula.txt"
        echo "eula=true" > $dir/eula.txt
    else
        echo -e "${red}You must accept the EULA to proceed.${reset}"
        exit 1
    fi
}

function checkPort(){
    lsof -i :25565
    if [[ $( echo $? ) == 0 ]]; then
        if [[ "${non_interactive}" == "false" ]]; then
            if [[ "${kill_minecraft}" == "0" ]]; then
                status "It looks like there already is something running on the default Minecraft port. Can we stop/kill it?" "/"
                export OPTIONS=("Kill PID on port 25565" "Exit the script")
                bashSelect

                case $? in
                    0 )
                        kill_minecraft="true"
                        ;;
                    1 )
                        exit 0
                        ;;
                esac
            fi
        fi
        if [[ "${kill_minecraft}" == "true" ]]; then
            status "killing PID on 25565"
            runCommand "apt -y install psmisc"
            runCommand "fuser -4 25565/tcp -k || true"
            return
        fi

        echo -e "${red}Error:${reset} It looks like there already is something running on the default Minecraft port."
        exit 1
    fi
}

function checkDir(){
    if [[ -e $dir ]]; then
        if [[ "${non_interactive}" == "false" ]]; then
            if [[ "${delete_dir}" == "0" ]]; then
                status "It looks like there already is a $dir directory. Can we remove it?" "/"
                export OPTIONS=("Remove everything in $dir" "Exit the script ")
                bashSelect
                case $? in
                    0 )
                    delete_dir="true"
                    ;;
                    1 )
                    exit 0
                    ;;
                esac
            fi
        fi
        if [[ "${delete_dir}" == "true" ]]; then
            status "Deleting $dir"
            runCommand "rm -r $dir"
            return
        fi

        echo -e "${red}Error:${reset} It looks like there already is a $dir directory."
        exit 1
    fi
}

function createCrontab(){
    if [[ "${crontab_autostart}" == "0" ]]; then
        crontab_autostart="false"

        if [[ "${non_interactive}" == "false" ]]; then
            status "Create crontab to autostart Minecraft server (recommended)"
            export OPTIONS=("yes" "no")
            bashSelect

            if [[ $? == 0 ]]; then
                crontab_autostart="true"
            fi
        fi
    fi
    if [[ "${crontab_autostart}" == "true" ]]; then
        status "Create crontab entry"
        runCommand "echo \"@reboot          root    cd /home/minecraft/ && bash start.sh\" > /etc/cron.d/minecraft.cron"
    fi
}

function install(){
    runCommand "apt update -y" "updating"
    runCommand "apt install -y wget git curl dos2unix net-tools sed screen" "installing necessary packages"

    checkJava
    checkPort
    checkDir
    selectVersion
    promptEula
    createCrontab

    runCommand "mkdir -p $dir" "Create directories for the Minecraft server"
    runCommand "cd $dir"

    runCommand "wget $artifacts_version -O server.jar" "Minecraft server is getting downloaded"

    createServerProperties
    createEula

    status "Creating start, stop and access script"
    cat << EOF > $dir/start.sh
#!/bin/bash
red="\e[0;91m"
green="\e[0;92m"
bold="\e[1m"
reset="\e[0m"
port=\$(lsof -Pi :25565 -sTCP:LISTEN -t)
if [ -z "\$port" ]; then
    screen -dmS minecraft java -Xmx1024M -Xms1024M -jar $dir/server.jar nogui
    echo -e "\n\${green}Minecraft server was started!\${reset}"
else
    echo -e "\n\${red}The default \${reset}\${bold}Minecraft server\${reset}\${red} port is already in use -> Is a \${reset}\${bold}Minecraft Server\${reset}\${red} already started?\${reset}"
fi
EOF
    runCommand "chmod +x $dir/start.sh"

    runCommand "echo \"screen -xS minecraft\" > $dir/attach.sh"
    runCommand "chmod +x $dir/attach.sh"

    runCommand "echo \"screen -XS minecraft quit\" > $dir/stop.sh"
    runCommand "chmod +x $dir/stop.sh"

    port=$(lsof -Pi :25565 -sTCP:LISTEN -t)

    if [[ -z "$port" ]]; then
        if [[ -e '/tmp/minecraft.log' ]]; then
        rm /tmp/minecraft.log
        fi
        screen -L -Logfile /tmp/minecraft.log -dmS minecraft java -Xmx1024M -Xms1024M -jar $dir/server.jar nogui

        sleep 2

        clear

        echo -e "\n${green}${bold}Minecraft server${reset}${green} was started successfully${reset}"
        mcserver="http://$(ip route get 1.1.1.1 | awk '{print $7; exit}'):25565"
        echo -e "\n\n${red}${uline}Commands just usable via SSH\n"
        echo -e "${red}To ${reset}${blue}start${reset}${red} Minecraft server run -> ${reset}${bold}sh $dir/start.sh${reset} ${red}!\n"
        echo -e "${red}To ${reset}${blue}stop${reset}${red} Minecraft server run -> ${reset}${bold}sh $dir/stop.sh${reset} ${red}!\n"
        echo -e "${red}To see the ${reset}${blue}\"Live Console\"${reset}${red} run -> ${reset}${bold}sh $dir/attach.sh${reset} ${red}!\n"

        echo -e "\n${green}Minecraft Server: ${reset}${blue}${mcserver}\n"

        echo -e "\n${green}Server-Data Path: ${reset}${blue}$dir${reset}"

        sleep 1

    else
        echo -e "\n${red}The default ${reset}${bold}Minecraft server${reset}${red} port is already in use -> Is a ${reset}${bold}Minecraft Server${reset}${red} already running?${reset}"
    fi
}

function update() {
    selectVersion

    if [[ "${non_interactive}" == "false" ]]; then
        status "Select the server directory"
        readarray -t directories <<<$(find / -name "server.jar")
        export OPTIONS=(${directories[*]})

        bashSelect

        dir=${directories[$?]}/..
    else
        if [[ "$update_artifacts" == false ]]; then
            echo -e "${red}Error:${reset} Directory must be specified in non-interactive mode using --update <path>."
            exit 1
        fi
        dir=$update_artifacts
    fi

    checkPort

    runCommand "rm -f $dir/server.jar" "${red}Deleting server.jar"
    runCommand "wget --directory-prefix=$dir $artifacts_version -O server.jar" "Downloading server.jar"
    echo "${green}Success"
    clear
    echo "${green}Update success"
    exit 0
}

function main(){
    curl --version
    if [[ $? == 127  ]]; then  apt update -y && apt -y install curl; fi
    clear 

    if [[ "${non_interactive}" == "false" ]]; then
        source <(curl -s https://raw.githubusercontent.com/JulianGransee/BashSelect.sh/main/BashSelect.sh)
        
        if [[ "${update_artifacts}" == "false" ]]; then
            export OPTIONS=("install Minecraft" "update Minecraft" "do nothing")
            bashSelect

            case $? in
                0 )
                    install;;
                1 )
                    update;;
                2 )
                    exit 0
            esac
        fi
        exit 0
    fi
    
    if [[ "${update_artifacts}" == "false" ]]; then
        install
    else
        update
    fi
}

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help)
            echo -e "${bold}Usage: bash <(curl -s https://raw.githubusercontent.com/Lucentix/minecraft-installer/main/install.sh) [OPTIONS]${reset}"
            echo "Options:"
            echo "  -h, --help                      Display this help message."
            echo "      --non-interactive           Skip all interactive prompts by providing all required inputs as options."
            echo "  -v, --version <URL|latest>      Choose a Minecraft server version."
            echo "                                  Default: latest"
            echo "  -u, --update <path>             Update the Minecraft server version and specify the directory."
            echo "                                  Use -v or --version to specify the version or it will use the latest version."
            echo "  -c, --crontab                   Enable or disable crontab autostart."
            echo "      --kill-port                 Forcefully stop any process running on the Minecraft server port (25565)."
            echo "      --delete-dir                Forcefully delete the /home/minecraft directory if it exists."
            exit 0
            ;;
        --non-interactive)
            non_interactive=true
            shift
            ;;
        -v|--version)
            artifacts_version="$2"
            shift 2
            ;;
        -u|--update)
            update_artifacts="$artifacts_version"
            shift 2
            ;;
        -c|--crontab)
            crontab_autostart=true
            shift
            ;;
        --kill-port)
            kill_minecraft=true
            shift
            ;;
        --delete-dir)
            delete_dir=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

main