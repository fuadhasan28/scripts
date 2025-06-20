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