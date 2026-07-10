/****** Script for SelectTopNRows command from SSMS  ******/
SELECT TOP (1000) [Id]
      ,[Name]
      ,[Url]
      ,[Hosts]
      ,[CompanyName]
      ,[CompanyAddress]
      ,[CompanyPhoneNumber]
      ,[CompanyVat]
      ,[SslEnabled]
      ,[DefaultLanguageId]
      ,[DisplayOrder]
      ,[Deleted]
      ,[DefaultTitle]
      ,[DefaultMetaDescription]
      ,[DefaultMetaKeywords]
      ,[HomepageDescription]
      ,[HomepageTitle]
  FROM [Theme_Beautyshop_470].[dbo].[Store]


  -- USE [Theme_FreshLand_470] 
  GO

INSERT INTO [dbo].[NS_License]
           ([Key])
     VALUES
           ('SQ3zcCaL1xx8EgIFBqXfjo+2Eb8V9GS4kpFnOBHimYAGo2KEJIaF4kGVdHTqhrmBauYzjtsmdsQ9vZNwII0VTnmqRXFVbdj96Tgc2/OQFDD05r42m/rY1kZjPbrExl7pX4HEtuzUw6PCWHZEhsgV2Fy7gXKZ5msOEpC5x2KL5F7t6IVSOZk4AHyuVqz3WruKkmpwVIJnanGkpe4k7BnfLmf/XnTfP3/UEoPurWb6rPI=')
GO



USE [Nop_Demo_470] 
  GO

delete from [dbo].[NS_License] 
where [Key] = 'SQ3zcCaL1xx8EgIFBqXfjo+2Eb8V9GS4kpFnOBHimYAGo2KEJIaF4kGVdHTqhrmBauYzjtsmdsQ9vZNwII0VTnmqRXFVbdj96Tgc2/OQFDD05r42m/rY1kZjPbrExl7pX4HEtuzUw6PCWHZEhsgV2Fy7gXKZ5msOEpC5x2KL5F7t6IVSOZk4AHyuVqz3WruKkmpwVIJnanGkpe4k7BnfLmf/XnTfP3/UEoPurWb6rPI=';

go

INSERT INTO [dbo].[NS_License]
           ([Key])
     VALUES
           ('SQ3zcCaL1xx8EgIFBqXfjo+2Eb8V9GS4kpFnOBHimYAGo2KEJIaF4kGVdHTqhrmBauYzjtsmdsQ9vZNwII0VTnmqRXFVbdj96Tgc2/OQFDD05r42m/rY1kZjPbrExl7pX4HEtuzUw6PCWHZEhsgV2Fy7gXKZ5msOEpC5x2KL5F7t6IVSOZk4AHyuVqz3WruKkmpwVIJnanGkpe4k7BnfLmf/XnTfP3/UEoPurWb6rPI=')
GO

update Store set SslEnabled = 0
go



#/var/opt/mssql/bak/

  wget http://35.238.55.41:2004/images.zip -P /home/nopapp/Downloads/
  wget http://35.238.55.41:2004/Themes.eShopper_450.bak -P /var/opt/mssql/bak/
  
  wget http://35.238.55.41:2004/Nop_Demo_POS_460.bak -P /var/opt/mssql/bak/
  
  
  wget http://35.238.55.41:2004/NopStation.Core.zip -P /home/nopapp/Downloads/
  sudo -S unzip -o "/home/nopapp/Downloads/NopStation.Core.zip" -d "/var/www/NopSites/Demo/470/Demo_470/Plugins"
  
  
  sudo -S unzip -o "/home/ubuntu/downloads/Nop_470_GrapeDeals.zip" -d "/var/www/Nop_470_GrapeDeals"
  
  /home/nopapp/Downloads/NopStation.Core.zip
  
  
  wget http://35.238.55.41:2004/Azure.Core.dll -P /home/nopapp/Downloads/
  
  sudo -S unzip -o "/home/nopapp/Downloads/Demo.zip" -d "/var/www/NopSites/Demo/470/Demo_470/"
  
  sudo -S unzip -o /home/nopapp/Downloads/Demo.zip -d "/var/www/NopSites/Demo/470/"
  
  
  http://35.238.55.41:2004/NopStation.Core.zip
  
  
  
  wget -O /home/nopapp/Downloads/images.zip http://35.238.55.41:2004/images.zip
  sudo -S unzip -o "/home/nopapp/Downloads/images.zip" -d /var/www/NopSites/Theme/470/Theme_Kingdom/wwwroot/
  
  
  
  wget -O /home/nopapp/Downloads/Plugins.zip http://35.238.55.41:2004/Plugins.zip
  sudo -S unzip -o "/home/nopapp/Downloads/Plugins.zip" -d /var/www/NopSites/Demo/460/Demo_Pos_freshland
  
  
  wget -O /home/nopapp/Downloads/Plugins.zip http://35.238.55.41:2004/Plugins.zip
  sudo -S unzip -o "/home/nopapp/Downloads/Plugins.zip" -d /var/www/NopSites/Demo/460/Demo_Pos_freshland
  
  
  sudo -S unzip -o /home/nopapp/Downloads/Demo.zip -d /var/www/NopSites/Demo/470/Demo_470/
  
  
  wget -O /home/bs23/Downloads/maxBrakesCommerce.zip http://172.18.102.150/maxBrakesCommerce.zip
  sudo -S unzip -o "/home/bs23/Downloads/maxBrakesCommerce.zip" -d /home/bs23/Desktop/Fuad/maxBrakes
  
  
  wget -O /home/nopapp/Downloads/Themes.zip http://35.238.55.41:2004/Themes.zip
  sudo -S unzip -o "/home/nopapp/Downloads/Themes.zip" -d /var/www/NopSites/Theme/450/Theme_Eshopper/
  
  mkdir /var/www/NopSites/Theme/450/Theme_Eshopper/bin
  mkdir /var/www/NopSites/Theme/450/Theme_Eshopper/logs
  mkdir /var/www/NopSites/Theme/450/Theme_Eshopper/Logs
  sudo chmod -R 755 /var/www/NopSites/Demo/470/Demo_470/ && sudo chown -R www-data:www-data /var/www/NopSites/Demo/470/Demo_470/
  sudo chmod -R 755 /var/www/NopSites/Theme/450/Theme_Eshopper/ && sudo chown -R www-data:www-data /var/www/NopSites/Theme/450/Theme_Eshopper/
  sudo chmod -R 755 /var/www/nop_4.70.4_radioWaveHub/ && sudo chown -R www-data:www-data /var/www/nop_4.70.4_radioWaveHub/
  sudo chmod -R 755 /var/www/NopSites/Theme/470/Theme_Kingdom/ && sudo chown -R www-data:www-data /var/www/NopSites/Theme/470/Theme_Kingdom/
  sudo chmod -R 755 /var/www/NopSites/AppSite/470/AppSite_DrinkSpot_Test/ && sudo chown -R www-data:www-data /var/www/NopSites/AppSite/470/AppSite_DrinkSpot_Test/
  sudo chmod -R 755 /var/www/Nop_470_GrapeDeals_Stage/ && sudo chown -R www-data:www-data /var/www/Nop_470_GrapeDeals_Stage/
  sudo chmod -R 755 /var/www/NopSites/nop_4.70.4_radioWaveHub/ && sudo chown -R www-data:www-data /var/www/NopSites/nop_4.70.4_radioWaveHub/
  
  
  
  sudo chmod -R 755 /var/www/Nop_470_GrapeDeals/ && sudo chown -R www-data:www-data /var/www/Nop_470_GrapeDeals/
  
  
  
  Copy-Item -Path "G:\ICPC_2024\Banner\Front_Banner_Old_design/*" -Destination "G:\ICPC_2024\Banner\Front_Banner_Old_design_Copy/" -Recurse
  
  mkdir /var/www/NopSites/Demo/450/
  mkdir /var/www/NopSites/Theme/450/Theme_Eshopper
  
  cp -R /var/www/NopSites/Test/450/Test_450/ /var/www/NopSites/Theme/450/Theme_Eshopper/

Homepage.Head.scripts.js?v=fvb1CU4RVr6msIrhUwAjKJ5E2RA

  -- Theme_Zwart_470

  --Themes_Rosea_450
  --areum.fuadwasi.xyz
  --Theme_Rosea_470
  --Theme_Areum_470

  --Themes.Aureum_450
  --Theme_Crimson_470
  --Theme_Valley_470
  --Theme_Orchid_470
  --Theme_FreshLand_470

  --
  
  DrinkSpot
  
  
  demo470.nop-station.com
  
  plugin.nop-station.com
  
  
	sudo systemctl start nop_Theme_*_470.service
  
  
	sudo systemctl start nop_Theme_Aureum_470.service
    sudo systemctl start nop_Theme_Beautyshop_470.service
    sudo systemctl start nop_Theme_CapetownBooks_470.service
    sudo systemctl start nop_Theme_Noproot_470.service
    sudo systemctl start nop_Theme_BerryPharmacy_470.service
    sudo systemctl start nop_Theme_Rosea_470.service
    sudo systemctl start nop_Theme_Viridi_470.service
    sudo systemctl start nop_Theme_Zwart_470.service
    sudo systemctl start 
    sudo systemctl start 
    sudo systemctl start 
    sudo systemctl start 
    sudo systemctl start 
    sudo systemctl start 
    sudo systemctl start 
    sudo systemctl start 
    sudo systemctl start 
    sudo systemctl start 
	
	
	sudo systemctl restart nop_Theme_Aureum_470.service
    sudo systemctl restart nop_Theme_Beautyshop_470.service
    sudo systemctl restart nop_Theme_CapetownBooks_470.service
    sudo systemctl restart nop_Theme_Noproot_470.service
    sudo systemctl restart nop_Theme_BerryPharmacy_470.service
    sudo systemctl restart nop_Theme_Rosea_470.service
    sudo systemctl restart nop_Theme_Viridi_470.service
    sudo systemctl restart nop_Theme_Zwart_470.service
	
	
	
sudo systemctl stop nop_Theme_BerryGrocery_470.service
sudo systemctl stop nop_Theme_Capetown_470.service
sudo systemctl stop nop_Theme_CookiesBakery_470.service
sudo systemctl stop nop_Theme_Crimson_470.service
sudo systemctl stop nop_Theme_KidsToys_470.service
sudo systemctl stop nop_Theme_NopKalles_470.service
sudo systemctl stop nop_Theme_Orchid_470.service
sudo systemctl stop nop_Theme_Tulip_470.service
sudo systemctl stop nop_Theme_Valley_470.service
	
	
	
sudo systemctl disable nop_Theme_BerryGrocery_470.service
sudo systemctl disable nop_Theme_Capetown_470.service
sudo systemctl disable nop_Theme_CookiesBakery_470.service
sudo systemctl disable nop_Theme_Crimson_470.service
sudo systemctl disable nop_Theme_KidsToys_470.service
sudo systemctl disable nop_Theme_NopKalles_470.service
sudo systemctl disable nop_Theme_Orchid_470.service
sudo systemctl disable nop_Theme_Tulip_470.service
sudo systemctl disable nop_Theme_Valley_470.service

curl -o "https://drinkspot-db-backups.s3.ap-southeast-2.amazonaws.com/GrapeDeals_Prod_470_12012026.bak?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Content-Sha256=UNSIGNED-PAYLOAD&X-Amz-Credential=ASIAU6GDYFVD4WNZJSKI%2F20260128%2Fap-southeast-2%2Fs3%2Faws4_request&X-Amz-Date=20260128T134302Z&X-Amz-Expires=300&X-Amz-Security-Token=IQoJb3JpZ2luX2VjEKb%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FwEaDmFwLXNvdXRoZWFzdC0yIkgwRgIhAKKdKlJjeY42w91dGnpVLQ98vRHwEw%2B0yRXD17yLGY%2BGAiEA%2FIPWHYqHqlH8KTW30aL4VxUh6tJZoGM%2BdTTTjgn4pS4q%2BwIIbxAAGgwzMzk3MTI5NDU0NzkiDC92BxSWISEjx2cnvirYAkNL%2F90RQcJFtpULi7yXWYeNowfCIEn7QMbn0%2BMiySaVXzGI2SaBuEgTAgyTGdWf90%2Bv6K%2FH2g5%2B1S4SzvfnuAa0pfZyiBbANru%2BNqf%2Be3vaYMoKnmyWanw2Jiy%2BbRVas1W8DHvCSVYR2QRgA93V99MTwHLv8MfWQIUynx%2BaF6zvXyoRGNflI7G%2FsF%2FbAAfcVv%2BDuhJmwyjNBDZnAbFwbun2wSTFdy509AEG3tk%2FFZZ73CTUwgJv%2BtHyXGQSEvqEUSC%2BiqbSwS%2Fest%2F81gv4%2Fo%2FKiHyjs%2F28jQ%2F13uuRVWRjgAb%2FHugYeClif2BFmjblx5Vhdo62jxb1JIGnzWoXjSa%2BA8bFaAMBx%2BCCo5HyJRq62JKabqhbcmZ8gG6vrPcTxBQjIW8VVpEIcPaOAhZoadaO1RJE89LJbKNWDT31BspA3O8sHGKVeJFGi7hkM3sPk71iYEfrl5hyML2Z6MsGOqwCmrZ1i2Cxs8HOzputOIE1D8XKRe%2BpkfBW8R%2FHQ7ZEuYhLt9u%2Fczvmvb5fZnwkY6FrctTECMooLP%2FqzUfwAS%2FMJbp%2Fug45NDY1S06VIrweDyxNNU%2BYVDV4BOdRbbhkjjBXUeHCQnzyAyUUTsjI1e0Ocf1qs1obPM0HCHyWAlAm5g8VmQJmGAqrh14mPPP3x8FtUr%2FhE5ywvrtsHfcDe1DmYESdTgi15XtahTyKZktrlhl6lALoeo3EmE84fNf7nkgwnb0gkDTg96KazGalaaw65oI0onl50H%2FdlaBb60BP9E9wXuWJGeWJ0xaxB%2BN9ISv6hmcPrgMLJ5FXiaZ5Ql5Ru8NhNbn%2B4YeSDTokenFoiWqQwD%2FotHlGVMpAGzK2WIGJj65%2BlckA4uGvFmnT&X-Amz-Signature=0abaab310451c76e7fd3754ee3a69add777d378a269daddc50aec20d1b91a0e3&X-Amz-SignedHeaders=host&response-content-disposition=attachment"
   
   
   
   sudo -S unzip -o "/home/nopapp/Downloads/sonar/sonarqube-developer-10.7.0.96327.zip" -d "/opt/sonarqube"
   
   sudo -S unzip -o "/home/nopapp/Downloads/DB_bak/Theme_Orchid_470.zip" -d "/var/opt/mssql/bak"
   
   
   
   /var/opt/mssql/bak
   
   
   sudo systemctl daemon-reload
   sudo systemctl restart nop_Theme_BerryPharmacy_470.service
   
   
   
   
   /etc/systemd/system/
   
   
   
   nop_Theme_Aureum_470.service
   nop_Theme_Beautyshop_470.service
   nop_Theme_CapetownBooks_470.service
   nop_Theme_Noproot_470.service
   nop_Theme_BerryPharmacy_470.service
   nop_Theme_Rosea_470.service
   nop_Theme_Viridi_470.service
   nop_Theme_Zwart_470.service
   
   
   [Service]
MemoryLimit=600M       # Hard limit of 650 MB
MemoryHigh=300M        # Soft limit of 300 MB

   
   
   nano /etc/systemd/system/nop_Theme_Aureum_470.service
   nano /etc/systemd/system/nop_Theme_Beautyshop_470.service
   nano /etc/systemd/system/nop_Theme_CapetownBooks_470.service
   nano /etc/systemd/system/nop_Theme_Noproot_470.service
   nano /etc/systemd/system/nop_Theme_BerryPharmacy_470.service
   nano /etc/systemd/system/nop_Theme_Rosea_470.service
   nano /etc/systemd/system/nop_Theme_Viridi_470.service
   nano /etc/systemd/system/nop_Theme_Zwart_470.service
   
   
   
   
   nano /etc/systemd/system/nop_Theme_BerryGrocery_470.service
   nano /etc/systemd/system/nop_Theme_Capetown_470.service
   nano /etc/systemd/system/nop_Theme_CookiesBakery_470.service
   nano /etc/systemd/system/nop_Theme_Crimson_470.service
   nano /etc/systemd/system/nop_Theme_KidsToys_470.service
   nano /etc/systemd/system/nop_Theme_NopKalles_470.service
   nano /etc/systemd/system/nop_Theme_Orchid_470.service
   nano /etc/systemd/system/nop_Theme_Tulip_470.service
   nano /etc/systemd/system/nop_Theme_Valley_470.service
   
   
   sudo systemctl restart nop_4.70.4_radioWaveHub.service
   sudo systemctl restart nop_4.70.5_lily.service 
   sudo systemctl restart nop_4.70.4_training.service 
   sudo systemctl restart nop_4.70.5_theme_nop_gadget.service
   sudo systemctl restart 
   sudo systemctl restart 
   sudo systemctl restart 
   
   nano /etc/systemd/system/nop_Theme_Zwart_470.service
   
   
   
   nop_Theme_BerryGrocery_470.service
   nop_Theme_Capetown_470.service
   nop_Theme_CookiesBakery_470.service
   nop_Theme_Crimson_470.service
   nop_Theme_KidsToys_470.service
   nop_Theme_NopKalles_470.service
   nop_Theme_Orchid_470.service
   nop_Theme_Tulip_470.service
   nop_Theme_Valley_470.service
   nop_Theme_eShopper_450.service
   
   
   /var/www/NopSites/Test/470/Client_NopStore
   
   
   
 NopAdvanceCart.init(@advanceCartSettings.AllowCustomersToSelectQuantityFromProductBox.ToString().ToLowerInvariant(),
    '@Html.Raw(@advanceCartSettings.ProductBoxSelector)',
    '@Html.Raw(@advanceCartSettings.TopCartSelector)',
    '@Html.Raw(@advanceCartSettings.FlyoutCartSelector)',
    '@Html.Raw(Url.Action("AddProductToCart_Catalog", "AdvanceCart"))',
    '@Html.Raw(Url.Action("AddProductToCart_Details", "AdvanceCart"))',
    localized_data);

initAdvanceCartPrimaryData();

$(document).ajaxStop(function () {
    initAdvanceCartPrimaryData();
});

$(document).on('swiper_initialized', function () {
    initAdvanceCartPrimaryData();
});

@if (advanceCartSettings.EnableAdvanceFlyoutCart)
{
    <text>
        NopAdvanceCart.getflyoutcart('@Html.Raw(Url.Action("GetFlyoutCart", "AdvanceCart"))');
    </text>
}


sudo cp ../Areas/ ./
sudo cp ../Views/ ./
sudo cp ../plugins/ ./

mkdir Areas Components Contents Controllers Data Domains Dtos Factories Infrastructure Models Services Tasks Themes Views Validators
cd Areas
mkdir Admin
cd Admin
mkdir Components Controllers Factories Infrastructure Models Views Validators

curl -o "GrapeDeals_Prod_470_12012026_01.bak" "https://drinkspot-db-backups.s3.ap-southeast-2.amazonaws.com/GrapeDeals_Prod_470_12012026.bak?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Content-Sha256=UNSIGNED-PAYLOAD&X-Amz-Credential=ASIAU6GDYFVD6GXXGD7Z%2F20260130%2Fap-southeast-2%2Fs3%2Faws4_request&X-Amz-Date=20260130T115308Z&X-Amz-Expires=300&X-Amz-Security-Token=IQoJb3JpZ2luX2VjENT%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FwEaDmFwLXNvdXRoZWFzdC0yIkcwRQIgFb2L5TrN1M%2Blw4agmG8VfVyqJ9eY9XGPofSJexvAQjgCIQCOSpk4k5DjG0qyZE9%2FkaP1FutPC9%2Bg5EqSDCPtDigZkyqEAwid%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F8BEAAaDDMzOTcxMjk0NTQ3OSIMizrMN9X%2B7xhWTPbpKtgCv0xOinbyhzz8sZwn88grQ5aNWXeQmkarQLcnM7AXmoTvD0%2FED8FSA0g6t8o9Pf0IeI54WPRBoCubDJWimIfjeLooHKWVaPNgK2Vvv9NqX%2F3mXqdv49LiuIsQwb%2BnRnUGdATmD6xu533j6bUoYcZX1EM8hPwxvrUApa7FWRQUac%2Bgjpl8K4BAQJQ7he%2BZRqEEBqatRNlAuEq%2BPmXT3MYIGdN77z8A40lkrjHYuyuf4wvTCNI4c70MATZeUef%2B73ecwGV9YsEnNONesmvFeQCrkl8MzuNG16VM7g0Y3KL5A5zUs9iRYveusXhUGnvAsuY9e%2BmnDRMccZePE0NvngOcIWh0qTQ0cS5xla%2BFLf6ZszSIT8wCx4opOlavlQGOZC%2FkJ2tW0FYOsd2DOtvYRXcXBADqT1Wg9Zx8Ln0VFOnh8ihE8MLxJoCgS8B9umiwe22iU%2BV%2B4Wor4sswj7PyywY6rQK%2FAwjBY%2FSsduqtnWa3fnJPHiJxBB1uyPz36W0VCJO6ea80%2FWbKee6JgqvCnuo6%2FqeNwummo4S6qWvcy4uTxpNlitxngF%2FjJvEd6xC98ISzaZ8l5tjdKOJASK06B1jUAd0JLuCu8Pj%2BhJN1KzBhm2TKCLFrR1KCkba2Evf3ZqUP3C8Teu5%2Bnz4SEL4UtAh9eTnCF8cdYPjO%2Fk4vrGvHgbIP%2Fu6xa%2Bk6jxe8RkwMIgQEpR1vyWE2YeGsPFQZX9NBEYcJR4S2Afi%2Bv15Tly1jlG9oZYGWQ42UEZ4HrOpMfIEzkfTvzb2rCOIuOH5aWi7qMNm0FOXIf%2FMIqbKtHhR1Gx%2BzwnB8hNvew50m%2BwUKNt1Q19HA67Vlr1b4wHmLu3o82Q4Os3epazmmK3qH0Y9u&X-Amz-Signature=aa29d79554bae6a4a8ba63a96fe9de714b41b712c2e8d7391ca3b877e39d5dcc&X-Amz-SignedHeaders=host&response-content-disposition=attachment"


server {
    listen 80;
    listen [::]:80;

    root /var/www/html;
    server_name  shop.example.com;

    location / {
		proxy_pass         http://localhost:5000;
		proxy_http_version 1.1;
		proxy_set_header   Upgrade $http_upgrade;
		proxy_set_header   Connection keep-alive;
		proxy_set_header   Host $host;
		proxy_cache_bypass $http_upgrade;
		proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
		proxy_set_header   X-Forwarded-Proto $scheme;
    }
}