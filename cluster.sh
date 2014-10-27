#!/bin/bash

# PARAMETER 1 = ONLINE and 2 = OFFLINE; NO PARAMETER = 0 = MONITOR
# SCRIPT AUTHOR: FARHAN SABBIR SIDDIQUE; CONTACT: FSABBIR@GPITDOTCOM; CELL: +8801711504735
# LICENSED UNDER GPL 2.0
# DISCLAIMER
# THIS SCRIPT IS MEANT FOR PARTEXSTAR GROUP EBS PROJECT ONLY
# THIS SCRIPT IS MEANT TO INITIATE CLUSTER ENVIRONMENT FAILOVER IN CASE OF ANY ERROR IN SYSTEM
# THIS SCRIPT CANNOT HANDLE SYSTEM HANG OR PROCESS HANG ISSUE
#
#
GRACE=30; # THIS IS THE GRACE PERIOD THE SYSTEM WAITS BEFORE BRINGING RESOURCES ONLINE ON ITSELF
REBOOT=1; # THIS TRIGGERS IF SYSTEM WILL REBOOT IF ITSELF IS UNREACHABLE IN THE NETWORK OR THE OTHER NODE IS IF ITS A SLAVE NODE
VIP="10.120.110.28";
GW="10.120.110.1";
HOST1="10.120.110.26";
HOST2="10.120.110.27";
CLUSTERNAME="partex-ebs-db";
LOGFILE="/var/log/$CLUSTERNAME.log";
INTERFACE="bond0";
PROCESS="pmon";
PING="/bin/ping";
GREP="/bin/grep";
DF="/bin/df -h";
FILE_SYSTEMS="d1|d2|d3|d4|d5|ebsdbbkp";
EGREP="/bin/egrep";
PS="/bin/ps -ef";

{

        online_VIP ()
        {
                /sbin/ip addr add "$VIP/24" dev $INTERFACE;
                if [ $? -eq 0 ]
                then
                        /sbin/arping -b -c 3 -s $VIP -I bond0 $GW > /dev/null; # THIS IS A DUMP LINUX ARP BROADCAST;
                        return 0;
                else
                        return 1;
                fi
        }

        offline_VIP ()
        {
                /sbin/ip addr del "$VIP/24" dev $INTERFACE;
                if [ $? -eq 0 ]
                then
                        return 0;
                else
                        return 1;
                fi
        }

        online_FS ()
        {
                /usr/sbin/vgimport ebsdbvg01
                /usr/sbin/vgimport ebsdbvg02
                /usr/sbin/vgimport ebsdbvg03
                /usr/sbin/vgimport ebsdbvg04
                /usr/sbin/vgimport ebsdbvg05
                /usr/sbin/vgimport ebsdb_backupvg

                /usr/sbin/lvchange -ay /dev/ebsdbvg01/lvol0
                /usr/sbin/lvchange -ay /dev/ebsdbvg02/lvol0
                /usr/sbin/lvchange -ay /dev/ebsdbvg03/lvol0
                /usr/sbin/lvchange -ay /dev/ebsdbvg04/lvol0
                /usr/sbin/lvchange -ay /dev/ebsdbvg05/lvol0
                /usr/sbin/lvchange -ay /dev/ebsdb_backupvg/lvol0

#               /sbin/fsck -y /dev/ebsdbvg01/lvol0
#               /sbin/fsck -y /dev/ebsdbvg02/lvol0
#               /sbin/fsck -y /dev/ebsdbvg03/lvol0
#               /sbin/fsck -y /dev/ebsdbvg04/lvol0
#               /sbin/fsck -y /dev/ebsdbvg05/lvol0
#               /sbin/fsck -y /dev/ebsdb_backupvg/lvol0

                /bin/mount -t ext3 /dev/ebsdbvg01/lvol0 /d1
                STAT1=$?;
                /bin/mount -t ext3 /dev/ebsdbvg02/lvol0 /d2
                STAT2=$?;
                /bin/mount -t ext3 /dev/ebsdbvg03/lvol0 /d3
                STAT3=$?;
                /bin/mount -t ext3 /dev/ebsdbvg04/lvol0 /d4
                STAT4=$?;
                /bin/mount -t ext3 /dev/ebsdbvg05/lvol0 /d5
                STAT5=$?;
                /bin/mount -t ext3 /dev/ebsdb_backupvg/lvol0 /ebsdbbkp
                STAT6=$?;

                if [ $STAT1 -eq 0 -a $STAT2 -eq 0 -a $STAT3 -eq 0 -a $STAT4 -eq 0 -a $STAT5 -eq 0 -a $STAT6 -eq 0 ]
                then
                        return 0;
                else
                        return 1;
                fi
        }

        offline_FS ()
        {
                /bin/umount -l /dev/ebsdbvg01/lvol0
                if [ $? -eq 0 ]
                then
                        /bin/umount -l /dev/ebsdbvg02/lvol0;
                        if [ $? -eq 0 ]
                        then
                                /bin/umount -l /dev/ebsdbvg03/lvol0;
                                if [ $? -eq 0 ]
                                then
                                        /bin/umount -l /dev/ebsdbvg04/lvol0;
                                        if [ $? -eq 0 ]
                                        then
                                                /bin/umount -l /dev/ebsdbvg05/lvol0
                                                if [ $? -eq 0 ]
                                                then
                                                        /bin/umount -l /dev/ebsdb_backupvg/lvol0
                                                        /usr/sbin/lvchange -an /dev/ebsdbvg01/lvol0
                                                        /usr/sbin/lvchange -an /dev/ebsdbvg02/lvol0
                                                        /usr/sbin/lvchange -an /dev/ebsdbvg03/lvol0
                                                        /usr/sbin/lvchange -an /dev/ebsdbvg04/lvol0
                                                        /usr/sbin/lvchange -an /dev/ebsdbvg05/lvol0
                                                        /usr/sbin/lvchange -an /dev/ebsdb_backupvg/lvol0
                                                        /usr/sbin/vgexport ebsdbvg01
                                                        /usr/sbin/vgexport ebsdbvg02
                                                        /usr/sbin/vgexport ebsdbvg03
                                                        /usr/sbin/vgexport ebsdbvg04
                                                        /usr/sbin/vgexport ebsdbvg05
                                                        /usr/sbin/vgexport ebsdb_backupvg
                                                else
                                                        return 1;
                                                fi
                                        else
                                                return 1;
                                        fi
                                else
                                        return 1;
                                fi
                        else
                                return 1;
                        fi
                else
                        return 1;
                fi

                return 0;
        }

        online_app ()
        {
                /bin/su - oracle -c "/u1/oracle/PROD/db/tech_st/11.1.0/appsutil/scripts/PROD_dbebs/addbctl.sh start";
                if [ $? -eq 0 ]
                then
                        echo "`date` $HOSTNAME $CLUSTERNAME: Database started successfully.";
                        /bin/su - oracle -c "/u1/oracle/PROD/db/tech_st/11.1.0/appsutil/scripts/PROD_dbebs/addlnctl.sh start prod";
                        if [ $? -eq 0 ]
                        then
                                echo "`date` $HOSTNAME $CLUSTERNAME: Listener started successfully.";
                                return 0;
                        else
                                echo "`date` $HOSTNAME $CLUSTERNAME: Error! Could not start listener.";
                                return 1;
                        fi
                else
                        echo "`date` $HOSTNAME $CLUSTERNAME: Error! Could not start database.";
                        return 1;
                fi
        }

        offline_app ()
        {
                /bin/su - oracle -c "/u1/oracle/PROD/db/tech_st/11.1.0/appsutil/scripts/PROD_dbebs/addlnctl.sh stop prod";
                #/bin/su - oracle -c "/u1/oracle/PROD/db/tech_st/11.1.0/appsutil/scripts/PROD_db-prod-ebs/addlnctl.sh stop prod";
                if [ $? -eq 0 ]
                then
                        echo "`date` $HOSTNAME $CLUSTERNAME: Listener stopped successfully.";
                        /bin/su - oracle -c "/u1/oracle/PROD/db/tech_st/11.1.0/appsutil/scripts/PROD_dbebs/addbctl.sh stop immediate";
                        if [ $? -eq 0 ]
                        then
                                echo "`date` $HOSTNAME $CLUSTERNAME: Database stopped successfully.";
                                return 0;
                        else
                                echo "`date` $HOSTNAME $CLUSTERNAME: Error! Could not stop database.";
                                return 1;
                        fi
                else
                        echo "`date` $HOSTNAME $CLUSTERNAME: Error! Could not stop listener.";
                        return 1;
                fi
        }

        check_daemon ()
        {
                echo "`date` $HOSTNAME $CLUSTERNAME: APPLICATION MONITORING IS NOT IMPLEMENTED YET";
        }

        am_i_master ()
        {
                ip addr | $GREP $INTERFACE | $GREP $VIP > /dev/null;
                VIP_STATE=$?; # grep returns 1 if fails to find the VIP here; else returns 0 for success
                $DF | $EGREP "$FILE_SYSTEMS" > /dev/null;
                FS_STATE=$?; # grep returns 1 if fails to find the mount points; else returns 0 for success
                $PS | $GREP $PROCESS> /dev/null;
                PROC_STATE=$?; # grep returns 1 if fails to find the process; else returns 0 for success
                if [ $VIP_STATE -eq 0 -a $FS_STATE -eq 0 ]
                then
                        #echo "`date` $HOSTNAME $CLUSTERNAME: I am the master node!";
                        return 0; # I AM MASTER
                else
                        echo "`date` $HOSTNAME $CLUSTERNAME: This is not the master node!";
                        return 1; # I AM NOT MASTER
                fi
        }

        check_status ()
        {
                $PING -c 3 -i 1 -Q 0X04 $GW -s 20 -I $INTERFACE > /dev/null; # PINGING GATEWAY TO DOUBLE CHECK NETWORK;
                if [ $? -eq 0 ] # GATEWAY IS REACHABLE; SO I AM IN THE NETWORK; NOW CHECK THE OTHER NODE
                then
                        $PING -c 3 -i 1 -Q 0X04 $HOST2 -s 20 -I $INTERFACE > /dev/null; # PING THE OTHER NODE AND CHECK IF ITS ALIVE
                        if [ $? -eq 0 ] # YES, ITS ALIVE;
                        then
                                return 0; # JUST RETURN; NO NEED TO PANIC NOW
                        else
                                echo "`date` $HOSTNAME $CLUSTERNAME: I am on network.";
                                echo "`date` $HOSTNAME $CLUSTERNAME: but host $HOST2 is not reachable."; # SEEMS OTHER NODE IS NOT REACHABLE;
                                return 1; # I AM ON NETWORK; RETURN ERROR 1; OTHER HOST ISN'T; POTENTIAL RESOURCE TAKE-OVER CASE
                        fi
                else # I AM NOT ON NETWORK;
                        $PING -c 3 -i 1 -Q 0X04 $HOST2 -s 20 -I $INTERFACE > /dev/null; # PING THE OTHER NODE AND CHECK IF ITS ALIVE
                        if [ $? -eq 0 ] # YES, ITS ALIVE;
                        then
                                echo "`date` $HOSTNAME $CLUSTERNAME: This host $HOSTNAME is not on network, but other host is reachable.";
                                echo "`date` $HOSTNAME $CLUSTERNAME: For safety reasons, I need to release resources.";
                                return 2; # THIS IS A CONFUSING STATE; I AM NOT ON NETWORK, BUT OTHER HOST IS; THIS NEEDS MY REBOOT EVEN IF I AM MASTER NODE
                        else
                                echo "`date` $HOSTNAME $CLUSTERNAME: Host $HOST2 is not reachable."; # SEEMS OTHER NODE IS NOT REACHABLE EITHER;
                                return 2;
                        fi
                fi
        }

        ARG=$1;
        if [ -z $ARG ]
        then
                ARG=0;
        fi
        if [ $ARG -eq 1 ] # THIS IS ONLINE COMMAND
        then
                echo "`date` $HOSTNAME $CLUSTERNAME: Manual online initiated. Please wait...";
                am_i_master;
                MASTER_STATE=$?;
                if [ $MASTER_STATE -eq 1 ] # I AM NOT MASTER; I NEED TO BE; TRYING TO BRING EVERYTHING ONLINE HERE
                then
                       echo "`date` $HOSTNAME $CLUSTERNAME: Hopefully other node $HOST2 has rebooted. Still grace of $GRACE seconds...";
                       sleep $GRACE; # grace period for the other node to release the resources;
                       echo "`date` $HOSTNAME $CLUSTERNAME: Taking over resources now.";
                       echo "`date` $HOSTNAME $CLUSTERNAME: Bringing VIP $VIP online on this node.";
                       online_VIP; # online the VIP now
                       if [ $? -eq 0 ]
                       then
                                 echo "`date` $HOSTNAME $CLUSTERNAME: Brought $VIP on this node successfully.";
                                 echo "`date` $HOSTNAME $CLUSTERNAME: Bringing file system on this node.";
                                 online_FS # online the file-system now
                                 if [ $? -eq 0 ]
                                 then
                                          echo "`date` $HOSTNAME $CLUSTERNAME: File-system brought online on this node successfully";
                                          echo "`date` $HOSTNAME $CLUSTERNAME: Bringing application online on this node";
                                          online_app;
                                          if [ $? -eq 0 ]
                                          then
                                                  echo "`date` $HOSTNAME $CLUSTERNAME: Brought up application on this node successfully.";
                                                  echo "`date` $HOSTNAME $CLUSTERNAME: Service EBS-DB is online on $HOSTNAME successfully.";
                                          else
                                                  echo "`date` $HOSTNAME $CLUSTERNAME: Could not bring up the application. Rolling back...";
                                                  offline_FS;
                                                  offline_VIP;
                                                  exit 1;
                                          fi
                                  else
                                          echo "`date` $HOSTNAME $CLUSTERNAME: Could not bring up the file-system. Rolling back...";
                                          offline_VIP;
                                          exit 1;
                                  fi
                       fi
                else
                        echo "`date` $HOSTNAME $CLUSTERNAME: Host is already master. Nothing to do here.";
                fi

        elif [ $ARG -eq 2 ]
        then
                echo "`date` $HOSTNAME $CLUSTERNAME: Manual offline initiated. Please wait...";
                offline_app
                STAT_APP=$?; # get app offline status
                if [ $STAT_APP -eq 0 ]
                then
                        echo "`date` $HOSTNAME $CLUSTERNAME: Application shutdown successful.";
                else
                        echo "`date` $HOSTNAME $CLUSTERNAME: Error! Could not shutdown application. Exiting.";
                        exit 1;
                fi
                offline_FS; # offline the file-system now
                STAT_FS=$?; # get the file-system offline status
                if [ $STAT_FS -eq 0 ]
                then
                        echo "`date` $HOSTNAME $CLUSTERNAME: File system unmountted successfully.";
                else
                        echo "`date` $HOSTNAME $CLUSTERNAME: Error! Could not bring down mount points. Exiting.";
                        exit 1;
                fi
                offline_VIP; # offline the VIP now
                STAT_VIP=$?; # get VIP offline status
                if [ $STAT_VIP -eq 0 ]
                then
                        echo "`date` $HOSTNAME $CLUSTERNAME: VIP $VIP brought down successfully.";
                else
                        echo "`date` $HOSTNAME $CLUSTERNAME: Error! Could not bring down the VIP $VIP";
                        exit 1;
                fi
        else
                check_status;
                STAT=$?;
                if [ $STAT -eq 2 ] # THIS MEANS BOTH MYSELF AND THE OTHER NODE ARE NOT REACHABLE; POSSIBLY MY PROBLEM
                then
                        echo "`date` $HOSTNAME $CLUSTERNAME: NETWORK NOT REACHABLE AND HOST $HOST2 is not reachable either.";
                        ami_i_master;
                        MASTER_STATE=$?;
                        if [ $MASTER_STATE -eq 0 ]
                        then
                                echo "`date` $HOSTNAME $CLUSTERNAME: This is the master node. Releasing the resources";
                                offline_app # offline the application now
                                STAT_APP=$?; # get app offline status
                                offline_FS; # offline the file-system now
                                STAT_FS=$?; # get the file-system offline status
                                offline_VIP; # offline the VIP now
                                STAT_VIP=$?; # get VIP offline status
                        else
                                echo "`date` $HOSTNAME $CLUSTERNAME: This is not master. No resource to release.";
                        fi
                        if [ $REBOOT -eq 0 ]
                        then
                                echo "`date` $HOSTNAME $CLUSTERNAME: Reboot option is not selected.";
                                echo "`date` $HOSTNAME $CLUSTERNAME: System will remain as is.";
                        else
                                echo "`date` $HOSTNAME $CLUSTERNAME: Reboot option selected.";
                                echo "`date` $HOSTNAME $CLUSTERNAME: Initiating reboot of this host to hold cluster integrity...";
                                /sbin/reboot;
                        fi
                elif [ $STAT -eq 1 ] # THIS MEANS I AM ON NETWORK, OTHER HOST ISNT; I NEED TO BE MASTER IF I AM NOT ALREADY
                then
                        am_i_master;
                        MASTER_STATE=$?;
                        if [ $MASTER_STATE -eq 1 ] # I AM NOT MASTER; I NEED TO BE; TRYING TO BRING EVERYTHING ONLINE HERE
                        then
                                echo "`date` $HOSTNAME $CLUSTERNAME: Hopefully other node $HOST2 has rebooted. Still grace of $GRACE seconds...";
                                sleep $GRACE; # grace period for the other node to release the resources;
                                echo "`date` $HOSTNAME $CLUSTERNAME: Taking over resources now.";
                                echo "`date` $HOSTNAME $CLUSTERNAME: Bringing VIP $VIP online on this node.";
                                online_VIP; # online the VIP now
                                if [ $? -eq 0 ]
                                then
                                        echo "`date` $HOSTNAME $CLUSTERNAME: Brought $VIP on this node successfully.";
                                        echo "`date` $HOSTNAME $CLUSTERNAME: Bringing file system on this node.";
                                        online_FS # online the file-system now
                                        if [ $? -eq 0 ]
                                        then
                                                echo "`date` $HOSTNAME $CLUSTERNAME: File-system brought online on this node successfully";
                                                echo "`date` $HOSTNAME $CLUSTERNAME: Bringing application online on this node";
                                                online_app;
                                                if [ $? -eq 0 ]
                                                then
                                                        echo "`date` $HOSTNAME $CLUSTERNAME: Brought up application on this node successfully.";
                                                        echo "`date` $HOSTNAME $CLUSTERNAME: Service EBS-DB is online on $HOSTNAME successfully.";
                                                else
                                                        echo "`date` $HOSTNAME $CLUSTERNAME: Could not bring up the application. Rolling back...";
                                                        offline_FS;
                                                        offline_VIP;
                                                        exit 1;
                                                fi
                                        else
                                                echo "`date` $HOSTNAME $CLUSTERNAME: Could not bring up the file-system. Rolling back...";
                                                offline_VIP;
                                                exit 1;
                                        fi
                                fi
                        fi
                else
                        echo "`date` $HOSTNAME $CLUSTERNAME: System OK.";
                fi
        fi

} >> $LOGFILE;
