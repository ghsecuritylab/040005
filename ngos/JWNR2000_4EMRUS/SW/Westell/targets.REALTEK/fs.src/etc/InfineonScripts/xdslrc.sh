#!/bin/sh

# This script has been enhanced to handle the XDSL Events for Multimode FSM
# and subsequent DSL Link bringup handling.

# Include model information
if [ ! "$ENVLOADED" ]; then
	if [ -r /etc/rc.conf ]; then
		 . /etc/rc.conf 2> /dev/null
		ENVLOADED="1"
	fi
fi

if [ ! "$CONFIGLOADED" ]; then
	if [ -r /etc/rc.d/config.sh ]; then
		. /etc/rc.d/config.sh 2>/dev/null
		CONFIGLOADED="1"
	fi
fi

# Define interface types
	# NOTE: These values should match with the values in the enum 
        QOS_INTF_LAN=0
        QOS_INTF_LOCAL=7
        QOS_INTF_ALL=13
	QOS_INTF_WAN_ATM=9
	QOS_INTF_WAN_PTM=10
	QOS_INTF_WAN_ETH_0=11
	QOS_INTF_WAN_ETH_1=12
        QOS_INTF_LAN_SPECIFIC=14

case "$wanphy_phymode" in
	0)
		case "$wanphy_tc" in
			0)
				#wan mode is ATM
				qIfTypeActive=$QOS_INTF_WAN_ATM;
				;;
			1)
				#wan mode is PTM
				qIfTypeActive=$QOS_INTF_WAN_PTM;
				;;
		esac
		;;
	1)
		#wan mode is MII0
		qIfTypeActive=$QOS_INTF_WAN_ETH_0;
		;;
	2)
		#wan mode is MII1
		qIfTypeActive=$QOS_INTF_WAN_ETH_1;
		;;
	3)
		#wan mode is PTM
		qIfTypeActive=$QOS_INTF_WAN_PTM;
		;;
esac



# DSL Event handling script - Triggered from DSL CPE control Application
case "$DSL_NOTIFICATION_TYPE" in
	DSL_STATUS)
	# Handles the DSL Link Bringup sequence
		echo "DSL_STATUS Notification"
		if [ "$DSL_XTU_STATUS" = "VDSL" ]; then
			echo "Negotiated DSL Status = $DSL_XTU_STATUS "
			# Check if the inserted TC Layer (with which the initial DSL FSM 
			# negotiation has started) is comptabile with this current trained Mode
			if [ "$Next_xTM_Mode" = "PTM" ]; then 	
				# Here the xDSL Mode and xTM Mode matches, hence doesn't require any reboot of the CPE

				# Save the updated configuration to temp/system_status file
				# i.e, Current DSL Mode, xTM Status, SW Reboot
				# These values will be used to verify or cross-check against DSL_TC_LAYER_STATUS
				/usr/sbin/status_oper SET "xdsl_config_status" "status_Next_xDSL_Mode" $DSL_XTU_STATUS \
						"status_Next_xTM_Mode" $Next_xTM_Mode "status_xDSL_SW_Forced_Reboot" "0"
			else
				echo "Next TC Mode = $Next_xTM_Mode. Should be ATM for VR9. Rebooting..."
				# The inserted TC mode doesn't match with the current trained Mode
				# Update the configuration in flash and reboot to restart the DSL
				# FSM over again. This is because we only support PTM-TC for VDSL

				# Update Next_xTM_Mode(PTM), xDSL_SW_Forced_Reboot(true=1)
				# and Next_xDSL_Mode(VDSL=2) in flash
				/usr/sbin/status_oper -u -f /etc/rc.conf SET "wan_phy_cfg" "wanphy_phymode" "3" \
						"wanphy_tc" "1"
				/usr/sbin/status_oper -u -f /etc/rc.conf SET "xDSL_Config" "Next_xDSL_Mode" "2" \
						"Next_xTM_Mode" "PTM" "xDSL_SW_Forced_Reboot" "1"
				#Modify default WAN setting of upcoming mode
				/usr/sbin/ifx_event_util "DEFAULT_WAN" "MOD"
				# Reboot the CPE as the xDSL Mode and xTM Modes doesn't match
				# These new values will take effect on DSL bringup
				/sbin/reboot
			fi
		else
			echo "Negotiated DSL Status = $DSL_XTU_STATUS "
			# ATM Mode Configuration, so just save the xDSL_Mode to system status file
			/usr/sbin/status_oper SET "xdsl_config_status" "status_Next_xDSL_Mode" $DSL_XTU_STATUS \
						"status_Next_xTM_Mode" $Next_xTM_Mode "status_xDSL_SW_Forced_Reboot" $xDSL_SW_Forced_Reboot
		fi
		# Handle the TC Layer Status Event - verify against the modes during DSL_XTU_STATUS events
		neg_xdsl_mode=`/usr/sbin/status_oper GET xdsl_config_status status_Next_xDSL_Mode`

		# For Negotiated xDSL Mode as "ADSL", check on the TC Layer for ATM (or) PTM
		# VDSL has already been handled as given above
		if [ "$neg_xdsl_mode" = "ADSL" ]; then
			if [ "$DSL_TC_LAYER_STATUS" = "ATM" -a "$Next_xTM_Mode" = "ATM" ] || 
    	         [ "$DSL_TC_LAYER_STATUS" = "EFM" -a "$Next_xTM_Mode" = "PTM" ]; then
				# EVERYTHING MATCHES - Do nothing as we have already inserted & started the DSL SM with 
				# the correct parameters
				echo -n
			else
				if [ "$xTM_Mgmt_Mode" = "Auto" ]; then
					echo "neg_xdsl_mode = $neg_xdsl_mode, Next_xTM_Mode = $Next_xTM_Mode DSL_TC_LAYER_STATUS = $DSL_TC_LAYER_STATUS"
					# Save the Trained xTM Mode along with negotiated xDSL Mode and
					# set the SW Forced Reboot flag to true
					# Update the configuration in flash and reboot to restart the DSL
					# FSM over again. 

					# Update Next_xTM_Mode(DSL_TC_LAYER_STATUS), xDSL_SW_Forced_Reboot(true=1)
					# and Next_xDSL_Mode(ADSL=1) in flash
					if [ "$DSL_TC_LAYER_STATUS" = "EFM" ]; then
						neg_xTM_Mode="PTM"
						tc=1
					elif [ "$DSL_TC_LAYER_STATUS" = "ATM" ]; then
						neg_xTM_Mode="ATM"
						tc=0
					else 
						echo "neg_xTM_Mode = $DSL_TC_LAYER_STATUS "
					fi
					/usr/sbin/status_oper -u -f /etc/rc.conf SET "wan_phy_cfg" "wanphy_phymode" "0" \
							"wanphy_tc" $tc
					/usr/sbin/status_oper -u -f /etc/rc.conf SET "xDSL_Config" "Next_xDSL_Mode" "1" \
							"Next_xTM_Mode" $neg_xTM_Mode "xDSL_SW_Forced_Reboot" "0"

					#Modify default WAN setting of upcoming mode
					/usr/sbin/ifx_event_util "DEFAULT_WAN" "MOD"
					# Reboot the CPE with the modified values
					# These new values will take effect on DSL bringup
					/sbin/reboot
				else
					echo "$DSL_TC_LAYER_STATUS not supported for $xTM_Mgmt_Mode Management Mode"
					/usr/sbin/status_oper -u -f /etc/rc.conf SET "wan_phy_cfg" "wanphy_phymode" "0" 
					/usr/sbin/status_oper -u -f /etc/rc.conf SET "xDSL_Config" "Next_xDSL_Mode" "1" 
				fi
			fi
		fi
	echo "xDSL Mode = $DSL_XTU_STATUS"
	echo "DSL TC Mode = $DSL_TC_LAYER_STATUS"
	;;
	# This Notification type is valid only for VRX Platform
	DSL_MULTIMODE_FSM_STATUS)
	if [ "$DSL_NEXT_MODE" = "VDSL" ]; then
	echo "Event DSL NEXT MODE = $DSL_NEXT_MODE"
		# Save the updated configuration to temp/system_status file
			
		# Store the xDSL_ADSL_Sub_Prefix from the DSL SM Environment
		AdslSubPref=0
		if [ "$DSL_ADSL_SUB_PREF" = "ADSL" ]; then
			AdslSubPref=1
		fi
		# i.e, Current DSL Mode, xTM Status, ADSL Sub Prefix
		/usr/sbin/status_oper SET "xdsl_config_status" "status_Next_xDSL_Mode" "VDSL" \
				"status_Next_xTM_Mode" "PTM" "status_xDSL_ADSL_Sub_Prefix" $AdslSubPref

		# If Next_xTM_Mode is PTM, then set the Multimode Configuration via
		# DSL CLI interface, else save the above parameters to rc.conf and Reboot
		if [ "$Next_xTM_Mode" = "PTM" ]; then
			# Send the Multimode FSM to DSL Application with VDSL (=2 as NextMode)
			/opt/ifx/bin/dsl_cpe_pipe.sh mfcs 2 $AdslSubPref
		else
			echo " REBOOTING in $Next_xDSL_Mode/$Next_xTM_Mode" 
			# Save the parameters to rc.conf and Reboot
			/usr/sbin/status_oper -u -f /etc/rc.conf SET "wan_phy_cfg" "wanphy_phymode" "3" \
					"wanphy_tc" "1"
			/usr/sbin/status_oper -u -f /etc/rc.conf SET "xDSL_Config" "Next_xDSL_Mode" "2" \
					"Next_xTM_Mode" "PTM" "xDSL_SW_Forced_Reboot" "1" "xDSL_ADSL_Sub_Prefix" $AdslSubPref
			#Modify default WAN setting of upcoming mode
			/usr/sbin/ifx_event_util "DEFAULT_WAN" "MOD"
			# Reboot the CPE with the modified values
			# These new values will take effect on DSL bringup
			/sbin/reboot
		fi
	elif [ "$DSL_NEXT_MODE" = "ADSL" ]; then
		echo "Event DSL NEXT MODE = $DSL_NEXT_MODE"
		# Store the xDSL_ADSL_Sub_Prefix from the DSL SM Environment
		AdslSubPref=0
		if [ "$DSL_ADSL_SUB_PREF" = "ADSL" ]; then
			AdslSubPref=1
		fi

		# ADSL Mode Negotiated by Multimode FSM
		# Save the updated configuration to temp/system_status file
		# i.e, Current DSL Mode, xTM Status, SW Reboot
		/usr/sbin/status_oper SET "xdsl_config_status" "status_Next_xDSL_Mode" "ADSL" \
				"status_Next_xTM_Mode" $Next_xTM_Mode "status_xDSL_SW_Forced_Reboot" "0"
				

		# Send the Multimode FSM to DSL Application with ADSL (=1 as NextMode)
		/opt/ifx/bin/dsl_cpe_pipe.sh mfcs 1 $AdslSubPref
	fi
	echo "DSL NEXT MODE = $DSL_NEXT_MODE"
	echo "ADSL SUB PREF = $DSL_ADSL_SUB_PREF"
	;;

	DSL_INTERFACE_STATUS)
	case "$DSL_INTERFACE_STATUS" in 
	"UP")
		# DSL link up trigger
		if [ "$CONFIG_FEATURE_LED" = "1" ]; then
			echo none > /sys/class/leds/broadband_led/trigger
			echo 1 > /sys/class/leds/broadband_led/brightness
		fi	
		echo "xDSL Enter SHOWTIME!!"
		. /etc/rc.d/adsl_up
		# Enable Far-End Parameter Request
		/usr/sbin/dsl_cpe_pipe.sh ifcs 0 0 0 0 0 0

		# Adjust the upstream/downstream rates of the queues created in the system
		UPSTREAM_RATE=$(( $DSL_DATARATE_US_BC0 / 1000 ))
		#echo "US Rate $UPSTREAM_RATE kbps"
		DOWNSTREAM_RATE=$(( $DSL_DATARATE_DS_BC0 / 1000 ))
		#echo "DS Rate $DOWNSTREAM_RATE kbps"
		if [ $qIfTypeActive -eq $QOS_INTF_WAN_ATM -o  $qIfTypeActive -eq $QOS_INTF_WAN_PTM ]; then
			. /etc/rc.d/ipqos_rate_update $UPSTREAM_RATE $DOWNSTREAM_RATE
		fi

		[ "$Next_xTM_Mode" = "PTM" ] && ( [ -z $CONFIG_FEATURE_LQ_OPTIMIZATION ] || ifconfig ptm0 txqueuelen 400 )
		;;

	"DOWN")
		# DSL link down trigger
		if [ "$CONFIG_FEATURE_LED" = "1" ]; then
			echo none > /sys/class/leds/broadband_led/trigger
			echo 0 > /sys/class/leds/broadband_led/brightness
		fi	
		echo "xDSL Leave SHOWTIME!!"
		. /etc/rc.d/adsl_down 
		;;

	"READY")
		# DSL Handshake 2 HZ
		if [ "$CONFIG_FEATURE_LED" = "1" ]; then
			echo timer > /sys/class/leds/broadband_led/trigger
			echo 1 > /sys/class/leds/broadband_led/brightness
			echo 250 > /sys/class/leds/broadband_led/delay_on
			echo 250 > /sys/class/leds/broadband_led/delay_off
		fi	
		#echo "xDSL Handshake!!"
		;;

	"TRAINING")
		# DSL Training 4 HZ
		if [ "$CONFIG_FEATURE_LED" = "1" ]; then
			echo timer > /sys/class/leds/broadband_led/trigger
			echo 1 > /sys/class/leds/broadband_led/brightness
			echo 125 > /sys/class/leds/broadband_led/delay_on
			echo 125 > /sys/class/leds/broadband_led/delay_off
		fi	
		#echo "xDSL Training !!"
		;;
	esac
	;;

	DSL_DATARATE_STATUS)
	echo "DSL US Data Rate = "`expr $DSL_DATARATE_US_BC0 / 1000`" kbps"
	echo $DSL_DATARATE_US_BC0 > /tmp/dsl_us_rate
	echo "DSL DS Data Rate = "`expr $DSL_DATARATE_DS_BC0 / 1000`" kbps"
	echo $DSL_DATARATE_DS_BC0 > /tmp/dsl_ds_rate
	# Adjust ATM and IP QoS Rate shaping parameters based on line rate
	#. /etc/rc.d/init.d/qos_rate_update 
	# This is handled in ADSL UP Event
	;;

	DSL_DATARATE_STATUS_US)
	echo "DSL US Data Rate = "$(( $DSL_DATARATE_US_BC0 / 1000 ))" kbps"
	# echo "DSL DS Data Rate = "$(( $DSL_DATARATE_DS_BC0 / 1000 ))" kbps"
	# convert the upstream data rate in kbps to cells/sec and store in running config file
	# this will be used for bandwidth allocation during wan connection creation
	# 8 * 53 = 424
	DSL_DATARATE_US_CPS=$(( ${DSL_DATARATE_US_BC0} / 424 ))
	/usr/sbin/status_oper SET BW_INFO max_us_bw "${DSL_DATARATE_US_CPS}"
	# Adjust ATM and IP QoS Rate shaping parameters based on line rate
	UPSTREAM_RATE=$(( $DSL_DATARATE_US_BC0 / 1000 ))
	DOWNSTREAM_RATE=$(( $DSL_DATARATE_DS_BC0 / 1000 ))
	if [ $qIfTypeActive -eq $QOS_INTF_WAN_ATM -o  $qIfTypeActive -eq $QOS_INTF_WAN_PTM ]; then
		. /etc/rc.d/ipqos_rate_update $UPSTREAM_RATE $DOWNSTREAM_RATE
	fi

	[ "$Next_xTM_Mode" = "PTM" ] && ( [ -z $CONFIG_FEATURE_LQ_OPTIMIZATION ] || ifconfig ptm0 txqueuelen 400 )
	# This is handled in ADSL UP Event
	;;
esac

