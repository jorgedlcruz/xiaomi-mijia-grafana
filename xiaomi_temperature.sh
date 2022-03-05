#!/bin/bash
##      .SYNOPSIS
##      Grafana Dashboard for Xiaomi Mijia - Using RestAPI to InfluxDB Script
## 
##      .DESCRIPTION
##      This Script will query the Xiaomi Mijia Bluetooth and send the data directly to InfluxDB, which can be used to present it to Grafana. 
##      The Script and the Grafana Dashboard it is provided as it is, and bear in mind you can not open support Tickets regarding this project. It is a Community Project
##
##      .THANKS
##      Thank you to http://www.d0wn.com for the help reaching the data out
##	
##      .Notes
##      NAME:  xiaomi_temperature.sh
##      ORIGINAL NAME: xiaomi_temperature.sh
##      LASTEDIT: 05/03/2022
##      VERSION: 0.1
##      KEYWORDS: Xiaomi, InfluxDB, Grafana
   
##      .Link
##      https://jorgedelacruz.es/
##      https://jorgedelacruz.uk/

##
# Configurations
##
# Endpoint URL for InfluxDB
InfluxDBURL="http://YOURINFLUXSERVERIP" #Your InfluxDB Server, http://FQDN or https://FQDN if using SSL
InfluxDBPort="8086" #Default Port
InfluxDBBucket="telegraf" # InfluxDB bucket name (not ID)
InfluxDBToken="TOKEN" # InfluxDB access token with read/write privileges for the bucket
InfluxDBOrg="ORG NAME" # InfluxDB organisation name (not ID)

# Xiaomi Bluetooth Addresses
declare -a array=("A4:C1:38:D4:B7:7F" "A4:C1:38:CD:9B:92" "A4:C1:38:DF:A0:16" "A4:C1:38:30:12:65")
declare -a device=("Master\ Bedroom" "Living\ Room" "Office\ Room" "Kids\ Bedroom")
arraylength=${#array[@]}

# Restarting the interface, just in case
hciconfig hci0 down
service bluetooth restart
service dbus restart
rfkill unblock all
hciconfig hci0 up

for (( i=0; i<${arraylength}; i++ )); 
  do
    bt=$(timeout 15 gatttool -b ${array[$i]} --char-write-req --handle='0x0038' --value="0100" --listen)
    if [ -z "$bt" ]; then
        echo "The reading failed for ${array[$i]}"
    else
        declare -i temperature100
        declare -i humidity
        temphexa=$(echo $bt | awk -F ' ' '{print $12$11}'| tr [:lower:] [:upper:] )
        temperature100=$(echo "ibase=16; $temphexa" | bc)
        finaltemp=$(echo "scale=2;$temperature100" | bc)
        humhexa=$(echo $bt | awk -F ' ' '{print $13}'| tr [:lower:] [:upper:])
        humidity=$(echo "ibase=16; $humhexa" | bc)

        if [ "$finaltemp" -ge 0 ] && [ "$humidity" -le 100 ]; then
    
            ## Sending data to InfluxDB
            ## Un comment this line for debug
            #echo "xiaomi_temphum,btaddress=${array[$i]} temperature=$finaltemp,humidty=$humidity"

            ##Comment the Curl while debugging
            echo "Writing xiaomi_temphum to InfluxDB"
            curl -i -XPOST "$InfluxDBURL:$InfluxDBPort/api/v2/write?org=$InfluxDBOrg&bucket=$InfluxDBBucket&precision=s" -H "Authorization: Token $InfluxDBToken" --data-binary "xiaomi_temphum,xiaomi_device="xiaomiDevice$i"\ ${device[$i]},btaddress=${array[$i]} temperature=$finaltemp,humidity=$humidity"
        fi
    fi
done