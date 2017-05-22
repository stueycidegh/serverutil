#!/bin/bash
############################### Makes script run with a renice value of -20 #################
renice -20 $$ > /dev/null
######################Creates the report/ All the variables/Paths ####################
date=$(date +"%m_%d_%Y")
touch /var/log/cwcsutilreport_$date.txt
reportlog=/"var/log/cwcsutilreport_$date.txt"
cat /dev/null > $reportlog
################### System and log paths#################
thisHostName=$(hostname)
ubuntuSyslog="/var/log/syslog"
centosSyslog="/var/log/messages"
################### Plesk Paths #########################
accessPathPlesk="/var/www/vhosts/*/logs/access_log"
errorPathPlesk="/var/www/vhosts/*/logs/error_log"
oldAccessPathPlesk="/var/www/vhosts/*/statistics/access_log"
oldErrorPathPlesk="/var/www/vhosts/*/statistics/error_log"
mailLogPlesk="/usr/local/psa/var/log/maillog"
pleskMailQueue="/var/spool/postfix/deferred/*/*"
################## cPanelPaths #########################
accessPathcPanel="/usr/local/apache/domlogs/*"
accessPathcpanel2="/usr/local/apache/domglogs/*/*"
mailLogcPanel="/var/log/exim_mainlog"
raidFile="/proc/mdstat"
###########################FIGURE OUT DISTRIBUTION TYPE CENTOS/UBUNTU##########################
getDistri()
                {
                        local Distri=$(grep DISTRIB_ID /etc/*-release | awk -F '=' '{print $2}' )
                        if [ $Distri == "Ubuntu" ];then
                        echo "Ubuntu"
                        elif [ $Distri == "Centos" ];then
                        echo "Centos"
                        else
                        echo "Broke"
                        fi
                }
thisDistri=$(getDistri)
echo "--------------------Checking Distribution and Control Panel----------------------------------------------"
echo "You are using $thisDistri : server"
echo "------------Checking Distribution and Control Panel-----------" >> $reportlog
echo "You are using $thisDistri : server" >> $reportlog
#######################FIGURE OUT CONTROL PANEL VERSION#######################################
pleskInfoPath="/usr/local/psa/version"
cPanelInfoPath="/usr/local/cpanel/version"
checkControlPanel()
                {
                        if [ -e "$pleskInfoPath" ];then
                        echo "Plesk"
                        elif [ -e "$cPanelInfoPath" ];then
                        echo "cPanel"
                        else
                        echo "No"
                        fi
                }
controlPanelVersion=$(checkControlPanel)
echo "You are using a server with : $controlPanelVersion Control Panel"
echo "You are using a server with : $controlPanelVersion Control Panel" >> $reportlog
echo "Beginning diagnostics"
echo "--------------------------------------------------------------------------------------------"
########################################################## FUNCTION CHECKS###############################################
#Shows how many times xmlrpc shows in the logs
checkForAttacksxmlrpc()
                {
                        if [ "$controlPanelVersion" == "Plesk" ];then
                        local howManyTimesPlesk=$(cat 2>/dev/null $accessPathPlesk | grep xmlrpc | wc -l)
                        local howManyTimesPlesk2=$(cat 2>/dev/null $oldAccessPathPlesk | grep xmlrpc | wc -l)
                        local howManyTimesTotal=$(( howManyTimesPlesk + howManyTimesPlesk2))
                        elif [ "$controlPanelVersion" == "cPanel" ];then
                        local howManyTimesCpanel=$(cat 2>/dev/null $accessPathcPanel | grep xmlrpc | wc -l)
                        local howmanyTimesCpanel2=$(cat 2>/dev/null $accessPathcpanel2 | grep xmlrpc | wc -l)
                        local totalTimesTotal=$(( howManyTimesCpanel + howManyTimesCPanel2))
                        else
                        local howManyTimesTotal=$(cat 2>/dev/null $accessPathPlesk | grep xmlrpc | wc -l)
                        fi
                                if (( howManyTimesTotal > 50 ));then
                                echo "##### Possible xmlrpc attack it showed up : $howManyTimesTotal  times #####" >> $reportlog
                                elif (( howManyTimesTotal < 50));then
                                echo "No evidence of an xmlrpc attack": Only in logs $howManyTimesTotal times >> $reportlog
                                else
                                echo "Some sort of error within the checkForAttacksxmlrpc function"
                                fi
                }
ioWarnings()
                {
                        if [ $thisDistri == "Ubuntu" ];then
                        local ubuntuCount=$(cat $ubuntuSyslog | grep "I/O error" | wc -l)
                        elif [ $thisDistri == "Centos" ];then
                        local centosCount=$(cat $centosSyslog | grep "I/O error" | wc -l)
                        else
                         echo "Some sort of error in IOWarning function" >> $reportlog
                        fi
                                if (( ubuntuCount > 0 ));then
                                echo "##### Possible disk problem see below I/O errors #####" >> $reportlog
                                cat $ubuntuSyslog | grep "I/O error" | uniq >> $reportlog
                                elif (( centosCount > 0 ));then
                                echo "Possible disk problem see below I/O errors"
                                cat $centosSyslog | grep "I/O error" | uniq >> $reportlog
                                else
                                echo "Checked for I/O errors, nothing to report" >> $reportlog
                                fi
                }
checkConnections()      {
                                        local numberOfConnections=$(netstat -nap | grep EST | wc -l)
                                        echo "There are $numberOfConnections : open connections to the server" >> $reportlog
                                        local apacheRamUsage=$(ps aux| awk '/apach[e]/{total+=$4}END{print total}')
                                        echo "Apache is using a total of $apacheRamUsage MB's of RAM" >> $reportlog

                        }
checkRaid()             {

                                        if  grep -q "\<UU\>" $raidFile;then
                                        echo "Raid status is showing as OK" >> $reportlog
                                        elif grep -q "\<U_\>" $raidFile;then
                                        echo "########Raid status is showing as BROKEN ###########" >> $reportlog
                                        else
                                        echo "This server does not use Raid" >> $reportlog
                                        fi
                        }
networkCheck()          {
                                        ping -c 1 8.8.8.8 &> /dev/null && echo "You have internet connection" >> $reportlog || echo "##### You do not have internet connection #####" >> $reportlog
                                        local gateWayIP=$(/sbin/ip route | awk '/default/ { print $3 }')
                                        ping -c 1 $gateWayIP &> /dev/null && echo "You can ping your gateway" >> $reportlog || echo "##### You can NOT ping your gateway #####" >> $reportlog
                        }
permissionsCheck()      {
                                                if [ $controlPanelVersion == "Plesk" ];then
                                                local numberOfFiles=$(find /var/www/ -type f -perm 0777 | wc -l)
                                                echo "There are $numberOfFiles files with 777 permissions in /var/www " >> $reportlog
                                                elif [ $controlPanelVersion == "cPanel" ];then
                                                local numberOfFiles=$(find /home/ -type f -perm 0777 | wc -l)
                                                echo "There are $numberOfFiles files with 777 permissions in /home" >> $reportlog
                                                else
                                                local numberOfFiles=$(find /var/www/ /home  -type f -perm 0777 | wc -l)
                                                echo "There are $numberOfFiles files with 777 permnissions in /home and /var/www" >> $reportlog
                                                fi
                                                        if [ $controlPanelVersion == "Plesk" ];then
                                                                        for i in $(find /var/www/ -type f -perm 0777);do
                                                                                echo "$i" >> $reportlog
                                                                        done
                                                        elif [ $controlPanelVersion == "cPanel" ];then
                                                                        for i in $(find /home -type f -perm 0777);do
                                                                                echo "$i" >> $reportlog
                                                                        done
                                                        else
                                                                        for i in $(find /var/www /home -type f -perm 0777);do
                                                                                echo "$i" >> $reportlog
                                                                        done
                                                        fi
                        }
checkMailQueue()        {
                                                if [ $controlPanelVersion == "Plesk" ];then
                                                local numberOfMail=$(mailq | wc -l)
                                                echo "There are $numberOfMail emails in the queue " >> $reportlog
                                                        firstArray=()
                                                        for i in $(cat $pleskMailQueue | grep X-Additional-Headers | grep php | cut -d: -f2);do
                                                        let count++
                                                        firstArray[$count - 1]+=$i
                                                        done
                                                                phpFileNames=($(for i in ${firstArray[*]};do
                                                                echo $i
                                                                done | sort -u))
                                                                updatedb
                                                for i in ${phpFileNames[*]};do
                                                count=$(cat $pleskMailQueue | grep X-Additional-Headers | grep php | cut -d: -f2 | grep $i | wc -l)
                                                location=$(locate $i)
                                                echo "##### The file $i has been used to send mail $count times | It is located here $location #####" >> $reportlog
                                                done
                                                elif [ $controlPanelVersion == "cPanel" ];then
                                                local numberOfMail=$(exim -bpc)
                                                echo "There are $numberOfMail in the queue " >> $reportlog
                                                local mailAge=$(exiqgrep -y 3600 | wc -l)
                                                echo "There are $mailAge mails in the queue younger than an hour, a high number indicates spam" >> $reportlog
                                                else
                                                echo "No mail information to show" >> $reportlog
                                                fi
                        }
checkResourceUsage()    {
                                                local freeMemory=$(free -m | awk 'NR==2{printf "Memory Usage: %s/%sMB (%.2f%%)\n", $3,$2,$3*100/$2 }')
                                                local freeDisk=$(df -h | awk '$NF=="/"{printf "Disk Usage: %d/%dGB (%s)\n", $3,$2,$5}')
                                                local cpuUsage=$(top -bn1 | grep load | awk '{printf "CPU Load: %.2f\n", $(NF-2)}')
                                                echo "Total $freeMemory" >> $reportlog
                                                echo "Total $freeDisk" >> $reportlog
                                                echo "Total $cpuUsage" >> $reportlog
                        }
checkWordpressVersions()	{		            updatedb
                                                installsArray=()
                                                for i in $(locate wp-includes/version.php);do
                                                let count++
                                                installsArray[count - 1]+=$i
                                                done
                                                for i in ${installsArray[*]};do
                                                latest=$(curl -s https://wordpress.org/download/ | grep "Version" | awk '{print $9}' | tr -d ')')
                                                curVersion=$(cat $i | grep wp_version | cut -d"'" -f2 | grep -v "*")
                                                if [ "$curVersion" != "$latest" ]; then
                                                    echo "$i is out of date" >> $reportlog
                                                elif [ "$curVersion" == "$latest" ]; then
                                                    echo "All WordPress installs up to date" >> $reportlog
                                                else
                                                    echo "There are no WordPress Installations" >> $reportlog
                                                fi
                                                done
                            }
checkDomainTotal()      {                       if [ "$controlPanelVersion" == "Plesk" ]; then
                                                    local howManyDomains=$(( ls -al /var/www/vhosts | wc -l ))
                                                    echo "There are $howManyDomains on this server" >> $reportlog
                                                elif [[ "$controlPanelVersion" == "cPanel" ]]; then
                                                    local howManyDomains=$(( /etc/localdomains | wc -l ))
                                                    echo "There are $howManyDomains on this server" >> $reportlog
                                                else
                                                    echo "Unable to check domain total"
                                                fi
                        }
checkDomainDNS()    {                           if [ "$controlPanelVersion" = "cPanel" ]; then
                                                    serverIPs=$(ifconfig | grep "inet addr:" | cut -d":" -f2 | grep -v "127.0.0.1" | tr -d "Bcast")
                                                    domainsArray=()
                                                    for i in $(cat /etc/localdomains);do
                                                    let count++
                                                    domainsArray[count - 1]+=$i
                                                    done
                                                    for i in ${domainsArray[*]};do
                                                    dig A $i
                                                    if [ "$i" != "$serverIPs" ]; then
                                                      echo "$i is not pointed here" >> $reportlog
                                                    fi
                                                    done
                                                elif [ "$controlPanelVersion" = "Plesk" ]; then
                                                    serverIPs=$(ifconfig | grep "inet addr:" | cut -d":" -f2 | grep -v "127.0.0.1" | tr -d "Bcast")
                                                    domainsArray=()
                                                    for i in $(MYSQL_PWD=`cat /etc/psa/.psa.shadow` mysql -u admin -Dpsa -e"SELECT dom.id, dom.name, ia.ipAddressId, iad.ip_address FROM domains dom LEFT JOIN DomainServices d ON (dom.id = d.dom_id AND d.type = 'web') LEFT JOIN IpAddressesCollections ia ON ia.ipCollectionId = d.ipCollectionId LEFT JOIN IP_Addresses iad ON iad.id = ia.ipAddressId" | cut -d"|" -f3 | awk '{print $2}');do
                                                    let count++
                                                    domainsArray[count - 1]+=$i
                                                    done
                                                    for i in ${domainsArray[*]};do
                                                    dig A $i
                                                    if [ "$i" != "$serverIPs" ]; then
                                                      echo "$i is not pointed here" >> $reportlog
                                                    fi
                                                    done
                                                else
                                                    echo "Cannot check DNS" >> $reportlog
                                                fi
}
############################################RUN THE CHECKS##################################################
echo "---------------------Apache Checks-------------------------" >> $reportlog
echo "Checking Apache logs for indication of common attacks"
checkForAttacksxmlrpc
echo "Checking how many open connections to the server"
checkConnections
echo "Checking for out of date WordPress Installations"
checkWordpressVersions
echo "Checking domain total"
checkDomainTotal
echo "Checking domain DNS records"
checkDomainDNS

echo "Checking Mail"
echo "----------------------Mail Checks---------------------------" >> $reportlog
checkMailQueue

echo "----------------------Hardware Checks----------------------------" >> $reportlog
echo "Checking for disk errors"
echo "Checking for RAID errors"
checkRaid
echo "Checking for I/O Warnings"
ioWarnings

echo "-----------------------Network Checks----------------------------" >> $reportlog
echo "Checking Network"
networkCheck

echo "------------------------Security Checks---------------------------" >> $reportlog
echo "Checking Permissions"
permissionsCheck

echo "----------------------------Resource Checks-----------------------" >> $reportlog
echo "Checking Resource Usage"
checkResourceUsage


echo "------------------------End Of Report-----------------------------" >> $reportlog
echo "---------------- Diagnostics completed, please use:  cat $reportlog to view results ---------------------"
