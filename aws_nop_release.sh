#/home/nopapp/azure_dir/Shwapno_development_nop_VM_Linux/azagent/_work/r1/a/_nuPod_test/drop/s.zip

sudo apt-get update -y <<< ""

# *********************************************** Fixed values ***********************************************

artifact_dir="$(SYSTEM.ARTIFACTSDIRECTORY)/$(RELEASE.PRIMARYARTIFACTSOURCEALIAS)/drop";
echo artifact_dir="$(SYSTEM.ARTIFACTSDIRECTORY)/$(RELEASE.PRIMARYARTIFACTSOURCEALIAS)/drop";
ls -l $artifact_dir
webRootPath="/var/www"
etcPath="/etc/systemd/system"
tmpFilePath="$webRootPath/tmp_json_data";

# *********************************************** ------------ ***********************************************



# *********************************************** values need to initial ***********************************************

artifact_name="$(Nop.ArtifactName)"
deployPath="$(Nop.DeployPath)"
nopService="$(Nop.Service)"

# *********************************************** ---------------------- ***********************************************

echo artifact_name="$(Nop.ArtifactName)"
echo deployPath="$(Nop.DeployPath)"
echo nopService="$(Nop.Service)"
appSettingPath="$deployPath/App_Data/appsettings.json";
pluginJsonPath="$deployPath/App_Data/plugins.json";
current_datetime=$(date +"%Y-%m-%d_%H:%M:%S")

# *********************************************** utilite functions ***********************************************

change_permission_and_owner(){
    local dirs="$1"
    for dir in "${dirs[@]}"; do
		if [ ! -d "$dir" ]; then
			echo creating the dir "$dir"
			sudo -S mkdir -m 755 "$dir"
		fi
        echo working with "$dir"
        sudo -S chmod 755 "$dir" && sudo -S chown www-data:www-data "$dir"
        for file in "$dir/"*; do
            echo modifing the file: "$file"
            sudo -S chmod 755 "$file" && sudo -S chown www-data:www-data "$file"
        done
    done
}

check_and_create_directory() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        echo creating the dir "$dir"
        sudo -S mkdir -m 755 "$dir"
    else 
        sudo -S chmod 755 "$dir"
    fi
	#sudo -S chown www-data:www-data "$dir"
}

echo check_and_create_directory "/var/www"
check_and_create_directory "/var/www"
echo check_and_create_directory "/var/www/eCom"
check_and_create_directory "/var/www/eCom"
echo check_and_create_directory "$webRootPath"
check_and_create_directory "$webRootPath"
echo check_and_create_directory "$deployPath"
check_and_create_directory "$deployPath"
echo check_and_create_directory "$tmpFilePath"
check_and_create_directory "$tmpFilePath"
echo ls "$tmpFilePath"
ls "$tmpFilePath"

check_and_create_directory "$deployPath/App_Data"
wwwRootPath="$deployPath/wwwroot"

# *********************************************** main script ***********************************************

sudo systemctl stop "$nopService"

tempFilePrefix="$tmpFilePath/${nopService}_${current_datetime}"
echo tempFilePrefix="$tmpFilePath/${nopService}_${current_datetime}"
sudo cp "$appSettingPath" "${tempFilePrefix}_appsettings.json"
sudo cp "$pluginJsonPath" "${tempFilePrefix}_plugins.json"

echo ls "$tmpFilePath/${tempFileNamePostfix}*"
ls "$tmpFilePath/${tempFileNamePostfix}*"

sudo -S unzip -o "$artifact_dir/$artifact_name" -d "$deployPath/"
cd "$deployPath"

permission_paths=("$wwwRootPath" "$wwwRootPath/css"  "$wwwRootPath/images" "$wwwRootPath/lib" "$wwwRootPath/my-bucket" "$wwwRootPath/images/thumbs" "$wwwRootPath/js" "$wwwRootPath/uploads")
change_permission_and_owner "${permission_paths[@]}" 

echo sudo cp "${tempFilePrefix}_appsettings.json" "$appSettingPath" 
sudo cp "${tempFilePrefix}_appsettings.json" "$appSettingPath" 
echo sudo cp "${tempFilePrefix}_plugins.json" "$pluginJsonPath" 
sudo cp "${tempFilePrefix}_plugins.json" "$pluginJsonPath"

echo sudo chmod -R 755 "$deployPath"
sudo chmod -R 755 "$deployPath" 

echo sudo chown -R www-data:www-data "$deployPath"
sudo chown -R www-data:www-data "$deployPath"


sudo systemctl start "$nopService"
sudo systemctl status "$nopService"
