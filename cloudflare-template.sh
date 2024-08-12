#!/bin/bash

###########################################
## Check if we have a public IP
###########################################
ipv4_regex='([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\.([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\.([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\.([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])'
# ip=$(curl -s -4 https://cloudflare.com/cdn-cgi/trace | grep -E '^ip'); ret=$?
# if [[ ! $ret == 0 ]]; then # In the case that cloudflare failed to return an ip.
#     # Attempt to get the ip from other websites.
#     ip=$(curl -s https://api.ipify.org || curl -s https://ipv4.icanhazip.com)
# else
#     # Extract just the ip from the ip line from cloudflare.
#     ip=$(echo "$ip" | sed -E "s/^ip=($ipv4_regex)$/\1/")
# fi
ip=$(curl -s https://ipv4.icanhazip.com)

# Use regex to check for proper IPv4 format.
if [[ ! $ip =~ ^$ipv4_regex$ ]]; then
    logger -s "DDNS Updater: Failed to find a valid IP."
    exit 2
fi

###########################################
## Set the proper auth header
###########################################
auth_header="Authorization: Bearer"

###########################################
## Seek for the A record
###########################################

logger "DDNS Updater: Check Initiated"
record=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_IDENTIFIER/dns_records?type=A&name=$CF_RECORD_NAME" \
                      -H "$auth_header $CF_AUTH_KEY" \
                      -H "Content-Type: application/json")

###########################################
## Check if the domain has an A record
###########################################
if [[ $record == *"\"count\":0"* ]]; then
  logger -s "DDNS Updater: Record does not exist, perhaps create one first? (${ip} for ${CF_RECORD_NAME})"
  exit 1
fi

###########################################
## Get existing IP
###########################################
old_ip=$(echo "$record" | sed -E 's/.*"content":"(([0-9]{1,3}\.){3}[0-9]{1,3})".*/\1/')
# Compare if they're the same
if [[ $ip == $old_ip ]]; then
  logger "DDNS Updater: IP ($ip) for ${CF_RECORD_NAME} has not changed."
  exit 0
fi

###########################################
## Set the record identifier from result
###########################################
record_identifier=$(echo "$record" | sed -E 's/.*"id":"([A-Za-z0-9_]+)".*/\1/')

###########################################
## Change the IP@Cloudflare using the API
###########################################
curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_IDENTIFIER/dns_records/$record_identifier" \
                     -H "$auth_header $CF_AUTH_KEY" \
                     -H "Content-Type: application/json" \
                     --data "{\"type\":\"A\",\"name\":\"$CF_RECORD_NAME\",\"content\":\"$ip\",\"ttl\":$CF_TTL,\"proxied\":$CF_PROXY}"
                     