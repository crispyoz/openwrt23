#!/bin/sh
#
#set -x

default_interface="apcli0"
current_date_time=`date +"%Y-%m-%d_%T"`
#email_file=$(uci get tnscan.@$script_name[0].email_file)
email_to=$(uci get tnscan.@email[0].to)
email_from=$(uci get tnscan.@email[0].from)
email_server=$(uci get tnscan.@email[0].server)
email_server_port=$(uci get tnscan.@email[0].server_port)
email_subj=$(uci get tnscan.@email[0].subject)
email_msg=$(uci get tnscan.@email[0].message)
email_user=$(uci get tnscan.@email[0].user)
email_pass=$(uci get tnscan.@email[0].password)

send_email() {                                            
    email_file=$(uci get tnscan.@$script_name[0].email_file) 
    if [ -z "$email_file" ]; then
    	uci set tnscan.@$script_name[0].email_file='0' 
	logger -t $log_topic "email_file option Not Sent"
	email_file='0'
    else
	if [ "$email_file" == "1" ]; then
    	    result=$(mailsend -v -ct 10 -read-timeout 10 -f $email_from -t $email_to -smtp $email_server \
	    -port $email_server_port -starttls -auth-plain -user $email_user -pass $email_pass -subj "$email_subj" \
	    -M "$email_msg" -attach "$out_file")
	    logger -t $log_topic "Sending $out_file"
        else
	    logger -t $log_topic "Send file disabled"
        fi
    fi
}  



#Check the name of the script to run has been passed as a parameter
#if no parameters then show error and log using generic log topic
#since no log topic can be constructed
if [ "$#" -ne 1 ]; then
        echo "Missing script name parameter.">&2 
	echo "Usage run_script.sh <script name>">&2
	echo "where <script name> is a shell script">&2
        logger -t run_script "Missing script name parameter passed to $0"
        exit 0
fi

script_name=$1

# Get the maxium number of runs and how many runs have been done
# No need to keep running the same scans endlessly
max_runs=$(uci get tnscan.@$script_name[0].max_runs)
if [ -z "$max_runs" ]; then 
	max_runs=5
	uci set tnscan.@$script_name[0].max_runs=$max_runs              
fi

#Check how many time this script has previously run
run_count=$(uci get tnscan.@$script_name[0].run_count)
if [ -z "$run_count" ]; then                                      
        run_count=0                                                       
fi                                                  

# Get the script name for logging topic
log_topic=$(uci get tnscan.@$script_name[0].log_topic)

#If no log topic has been set, use the name of the script
if [ -z "$log_topic" ]; then
        cnt=$(echo $0 | grep -o "\/" | wc -l)
        cnt=$((cnt+1))   
        log_topic=$(echo $1 | cut -d\/ -f$cnt | cut -d. -f0)   
        uci set tnscan.@$script_name[0].log_topic=$log_topic
fi

# If max runs is set to -1 then there is no run limit
# Otherwise if there is a max runs set, check we have not exceeded
if [ "$max_runs" -ne "-1" ]; then
        if [ "$run_count" -ge "$max_runs" ]; then
                logger -t $log_topic "Maximum run count exceeded. Exiting..."
                exit 0 
        fi
fi

#Update the run count
run_count=$((run_count+1))                               
uci set tnscan.@$script_name[0].run_count=$run_count        

#Get the name of the interface we ar going to use
interface=$(uci get tnscan.@$script_name[0].interface)
if [ -z "$interface" ]; then
	interface=$default_interface
fi

disable_range=$(uci get tnscan.@$script_name[0].disable_range)
if [ -z "$disable_range" ]; then                                                    
        disable_range='0'                                            
fi                          

# Some scripts don't need an ip range so don't get it. 
if [ "$disable_range" == "0" ]; then  
	#Get the first 3 octants of our ip address
	addr=$(ip -o -4 a s $interface | awk '{ print $4 }' | cut -d/ -f1 | cut -d. -f1-3)
	#address range we want to scan, currently always /24 so cut to first 3 octants
	addr_range=$(uci get tnscan.@$script_name[0].range)
	if [ -z "$addr_range" ]; then
    		addr_range=$(ip -o -4 a s $interface | awk '{ print $4 }' | cut -d/ -f1)
    		uci set tnscan.@$script_name[0].range=$(echo $addr_range | cut -d. -f1-3).0
	fi
	temp_addr_range=$(echo $addr_range | cut -d. -f1-3)

	# Get the ip mask
	addr_mask=$(uci get tnscan.@$script_name[0].mask)
	if [ -z "$addr_mask" ]; then
    		addr_mask=24
    		uci set tnscan.@$script_name[0].mask=$addr_mask
	fi


	# Only run the scans if we are in the same address range as the target(s)
	if [ "$addr" != "$temp_addr_range" ]; then
    		logger -t $log_topic "Not this address range: $addr_range\/$addr_mask"
    		exit 1
	fi
fi
	
out_file=$(uci get tnscan.@$script_name[0].outfile)                         
if [ -z "$out_file" ]; then
       	cnt=$(echo $0 | grep -o "\/" | wc -l)                             
       	cnt=$((cnt+1))                                                        
	out_file="/etc/tube/data/$(echo $1 | cut -d\/ -f$cnt | cut -d. -f0)"
fi

out_file=$out_file.$current_date_time.".txt"

#Commit all the changes we have made to UCI config
uci commit tnscan  

run_script=/etc/tube/scripts/$1.sh
logger -t $log_topic "Running script $run_script"
$run_script  $log_topic $addr_range $addr_mask $out_file $interface
logger -t $log_topic "Completed running script $run_script"
send_email

exit 0


