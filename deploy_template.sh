
#sudo -S apt update -y <<< ""

artifact_dir="/home/ubuntu/azagent_aws/_work/r1/a/_SEC_Services_Gateways_Deploy_Build/drop";
scriptBasePath="/home/ubuntu/Shwapno/deploy_files/scripts"

webRootPath="/var/www/Shwapno"
appsetBasePath="App_Data/appsettings.json";
tmpFilePath="$webRootPath/shwapno_tmp";

change_permission_and_owner(){
    local dirs="$1"
    for dir in "${dirs[@]}"; do
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
}

check_and_create_directory "$webRootPath"
check_and_create_directory "$tmpFilePath"

deployProjectsByTypes() {
    local projectsDir="$1"
    local projectType="$2"
    local projectTypeExt="$3"
    local linuxServiceExt="$4"
    local projects=("${@:5}")
    
    deployprojectsBasePath="$webRootPath/$projectsDir"

    if [ ! -d "$deployprojectsBasePath" ]; then
        sudo -S mkdir -m 777 "$deployprojectsBasePath"
    fi

    for project in "${projects[@]}"; do
        deployDir="$project.$projectTypeExt"
        linuxServiceName=Shwapno.$project.$linuxServiceExt

        #example: /var/www/Shwapno/Gateways/Admin.Api
        deployPath="$deployprojectsBasePath/$deployDir"
        if [ -f "$artifact_dir/$projectType.$project.$projectTypeExt.zip" ]; then
    
            sudo -S systemctl stop "$linuxServiceName"

            sudo find "$deployPath" -mindepth 1 -maxdepth 1 ! -name wwwroot ! -name App_Data -exec rm -r {} \;

            check_and_create_directory "$deployPath"
            check_and_create_directory "$deployPath/App_Data"
            check_and_create_directory "$deployPath/wwwroot"
            check_and_create_directory "$deployPath/wwwroot/images"
            check_and_create_directory "$deployPath/wwwroot/images/thumbs"
            check_and_create_directory "$deployPath/wwwroot/images/thumbs"

            #example: $scriptBasePath/Service.default.appsetting.json
            def_appsetting="$scriptBasePath/$projectType.default.appsetting.json"
            
            if [ ! -f "$deployPath/$appsetBasePath" ]; then
                sudo -S cp "$def_appsetting" "$deployPath/$appsetBasePath"
            elif [ ! -s "$deployPath/$appsetBasePath"  ]; then
                sudo -S cp"$deployPath/$appsetBasePath" "$deployPath/$appsetBasePath.bak" 
                echo "$deployPath/$appsetBasePath file is empty"
                sudo -S cp "$def_appsetting" "$deployPath/$appsetBasePath"
            fi
            sudo -S cp "$deployPath/$appsetBasePath" "$tmpFilePath/$deployDir.appsettings.json"

            sudo -S unzip -o "$artifact_dir/$projectType.$project.$projectTypeExt.zip" -d "$deployPath/"

            wwwRootPath="$deployPath/wwwroot"
            permission_paths=("$wwwRootPath" "$wwwRootPath/images" "$wwwRootPath/images/thumbs" "$wwwRootPath/images/flags")
            change_permission_and_owner "${permission_paths[@]}" 

            if [ -f "$tmpFilePath/$deployPath.appsettings.json" ]; then
                sudo -S cp "$tmpFilePath/$deployDir.appsettings.json" "$deployPath/$appsetBasePath"
            fi
            sudo -S rm -rf "$deployPath/publish"
            sudo -S chmod 777 "$deployPath/$appsetBasePath"
            sudo -S chown www-data:www-data "$deployPath/$appsetBasePath"
            sudo -S systemctl restart "$linuxServiceName"
        else
            echo "$artifact_dir/$projectType.$project.$projectTypeExt.zip file not found"
        fi
    done
}
services=("Catalogs" "Deliveries" "Discounts" "Documents" "Inventories" "Members" "Messages" "Orders")
deployProjectsByTypes "Services" "Service" "Synchronizer" "service" "${services[@]}" 
# Deploying Gateways
gateways=("Admin" "Storefront")
#deployProjectsByTypes $projectDir $projectType $projectTypeExt $linuxServiceExt "${gateways[@]}" 
deployProjectsByTypes "Gateways" "Gateway" "Api" "Api.service" "${gateways[@]}" 
sleep 30
for service in "${services[@]}"; do
    sudo systemctl status "Shwapno.$service.service"
done
sudo systemctl status Shwapno.Admin.Api.service
sudo systemctl status Shwapno.Storefront.Api.service
