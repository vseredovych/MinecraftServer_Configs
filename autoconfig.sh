#!/bin/bash
# -------–––––––––––––––––––––––––––––––––––––––––––––––––––––––
# Define some variables manually
# -------–––––––––––––––––––––––––––––––––––––––––––––––––––––––
# minecraft variables
minecraft_server_version="1.12.2"

# Get the forge installer download link here - http://files.minecraftforge.net/maven/net/minecraftforge/forge/index_1.12.2.html 
forge_installer_download_url="https://files.minecraftforge.net/maven/net/minecraftforge/forge/1.12.2-14.23.5.2854/forge-1.12.2-14.23.5.2854-installer.jar"
# Get the vanilla server download link here - https://www.minecraft.net/ru-ru/article/minecraft-1122-released
vanilla_server_download_url="https://launcher.mojang.com/mc/game/1.12.2/server/886945bfb2b978778c3a0288fd7fab09d315b25f/server.jar"

# gcp variables manually
gcp_persistant_volume_name="google-mine-disk"
gcp_project_id="minecraft-server-298410"
gcp_bucket_name="${gcp_project_id}-backups"

# system variables
minecraft_server_user="minecraft"
systemd_service_name="minecraft"
ram_min=1
ram_max=2
screen_name="mcs"


# -------–––––––––––––––––––––––––––––––––––––––––––––––––––––––
# Cleanup everything
# -------–––––––––––––––––––––––––––––––––––––––––––––––––––––––

if [[ $1 == "help" ]]; then
    echo "Use clean option to clean all change made by script"
fi

if [[ $1 == "clean" ]]; then
    umount /home/${minecraft_server_user}
    rm -rf /home/${{minecraft_server_user}}
    userdel ${minecraft_server_user}
    exit 0;
fi

# -------–––––––––––––––––––––––––––––––––––––––––––––––––––––––
# Create gcp bucket
# -------–––––––––––––––––––––––––––––––––––––––––––––––––––––––
gsutil mb -c standard -l us-central1 gs://${gcp_bucket_name}

# -------–––––––––––––––––––––––––––––––––––––––––––––––––––––––
# Prerequisites
# -------–––––––––––––––––––––––––––––––––––––––––––––––––––––––

# Create minecraft user 
sudo adduser ${minecraft_server_user} --gecos "FirstName LastName,RoomNumber,WorkPhone,HomePhone" --disabled-password

# Format disk to ext4 format
sudo mkfs.ext4 -F -E lazy_itable_init=0,lazy_journal_init=0,discard /dev/disk/by-id/${gcp_persistant_volume_name}

# Mount persistant volume for the first time
sudo mount -o discard,defaults /dev/disk/by-id/${gcp_persistant_volume_name} /home/${minecraft_server_user}

# -------–––––––––––––––––––––––––––––––––––––––––––––––––––––––
# Install dependencies
# -------–––––––––––––––––––––––––––––––––––––––––––––––––––––––
sudo apt-get install zip unzip wget screen -y

# Install jdk-8 and set alternatives
sudo apt-get install openjdk-8-jdk -y
sudo update-java-alternatives -s java-1.8.0-openjdk-amd64 --jre-headless

# -------–––––––––––––––––––––––––––––––––––––––––––––––––––––––
# Install minecraft server
# -------–––––––––––––––––––––––––––––––––––––––––––––––––––––––
( cd /home/${minecraft_server_user} && wget -O "forge-installer-${minecraft_server_version}.jar" ${forge_installer_download_url} )
( cd /home/${minecraft_server_user} && wget ${vanilla_server_download_url} )

( cd /home/${minecraft_server_user} && /usr/bin/java -jar "forge-installer-1.12.2.jar" --installServer )

# -------–––––––––––––––––––––––––––––––––––––––––––––––––––––––
# Create systemd service
# -------–––––––––––––––––––––––––––––––––––––––––––––––––––––––
sudo cp -rf ./templates/minecraft-server.service /etc/systemd/system/${systemd_service_name}.service

sed -i "s/{{ user }}/${minecraft_server_user}/" /etc/systemd/system/${systemd_service_name}.service
sed -i "s/{{ group }}/${minecraft_server_user}/" /etc/systemd/system/${systemd_service_name}.service
sed -i "s/{{ minecraft_server_home }}/\/home\/${minecraft_server_user}/" /etc/systemd/system/${systemd_service_name}.service

sed -i "s/{{ ram_min }}/${ram_min}/" /etc/systemd/system/${systemd_service_name}.service
sed -i "s/{{ ram_max }}/${ram_max}/" /etc/systemd/system/${systemd_service_name}.service
sed -i "s/{{ screen_name }}/${screen_name}/" /etc/systemd/system/${systemd_service_name}.service

sudo chown -R ${minecraft_server_user}:${minecraft_server_user} /home/${minecraft_server_user} 

sudo systemctl daemon-reload
sudo service enable ${systemd_service_name}

# -------–––––––––––––––––––––––––––––––––––––––––––––––––––––––
# Configure backup script
# -------–––––––––––––––––––––––––––––––––––––––––––––––––––––––
sudo cp -rf ./templates/backup.sh /home/${minecraft_server_user}/backup.sh

sed -i "s/{{ screen_name }}/${screen_name}/" /home/${minecraft_server_user}/backup.sh
sed -i "s/{{ gcp_bucket_name }}/${gcp_bucket_name}/" /home/${minecraft_server_user}/backup.sh
sed -i "s/{{ minecraft_server_home }}/\/home\/${minecraft_server_user}/" /home/${minecraft_server_user}/backup.sh
