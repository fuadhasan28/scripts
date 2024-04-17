#/home/nopapp/azure_dir/Shwapno_development_nop_VM_Linux/azagent/_work/r1/a/_nuPod_test/drop/s.zip

sudo apt-get update -y <<< ""

artifact_dir="/home/ubuntu/azagent/_work/r1/a/_nuPod_test/drop";
#scriptBasePath="/home/ubuntu/Shwapno/deploy_files/scripts"

webRootPath="/var/www/nupod_test"
deployPath="/var/www/nupod_test"
appsetBasePath="App_Data/appsettings.json";
tmpFilePath="$webRootPath/nupod_tmp";

change_permission_and_owner(){
    local dirs="$1"
    for dir in "${dirs[@]}"; do
		if [ ! -d "$dir" ]; then
			echo creating the dir "$dir"
			sudo -S mkdir -m 7777 "$dir"
		fi
        echo working with "$dir"
        sudo -S chmod 777 "$dir" && sudo -S chown www-data:www-data "$dir"
        for file in "$dir/"*; do
            echo modifing the file: "$file"
            sudo -S chmod 777 "$file" && sudo -S chown www-data:www-data "$file"
        done
    done
}

check_and_create_directory() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        echo creating the dir "$dir"
        sudo -S mkdir -m 7777 "$dir"
    else 
        sudo -S chmod 7777 "$dir"
    fi
	sudo -S chown www-data:www-data "$dir"
}

check_and_create_directory "/var/www"
check_and_create_directory "$webRootPath"
check_and_create_directory "$tmpFilePath"

check_and_create_directory "$webRootPath"
check_and_create_directory "$webRootPath/App_Data"
check_and_create_directory "$webRootPath/wwwroot"
check_and_create_directory "$webRootPath/wwwroot/images"
check_and_create_directory "$webRootPath/wwwroot/images/thumbs"
check_and_create_directory "$webRootPath/wwwroot/images/thumbs"
check_and_create_directory "$webRootPath/wwwroot/js"
check_and_create_directory "$webRootPath/wwwroot/uploads"
wwwRootPath="$deployPath/wwwroot"


sudo systemctl stop nupod_test.service

sudo -S unzip -o "$artifact_dir/s.zip" -d "$deployPath/"
cd "$deployPath"
sudo -S chown www-data:www-data ./*
sudo -S chown www-data:www-data "$deployPath"
sudo -S chown www-data:www-data "$deployPath/"

permission_paths=("$deployPath" "$wwwRootPath" "$wwwRootPath/css"  "$wwwRootPath/images" "$wwwRootPath/lib" "$wwwRootPath/my-bucket" "$wwwRootPath/images/thumbs" "$wwwRootPath/js" "$wwwRootPath/uploads")
change_permission_and_owner "${permission_paths[@]}" 

sudo systemctl start nupod_test.service
sudo systemctl status nupod_test.service
