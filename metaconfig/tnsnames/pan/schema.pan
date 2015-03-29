declaration template metaconfig/tnsnames/schema;

include 'pan/types';

# Protocol address section
type address_parameter = {
    'protocol' : string = 'TCP' with match(SELF,'^(TCP|UDP)$')
    'host' : type_hostname
    'port' : long(0..) = 1521
} = nlist();

type address_list = {
    'load_balance' ? string with match(SELF,'^(ON|OFF|YES|NO|TRUE|FALSE)$')
    'failover' ? string with match(SELF,'^(ON|OFF|YES|NO|TRUE|FALSE)$')
    'address' : address_parameter[]
} = nlist();

# Connect data section
type failover_parameter = {
    'backup' : string
    'type' : string with match(SELF,'^(SESSION|SELECT|NONE)$')
    'method' : string with match(SELF,'^(BASIC|PRECONNECT)$')
} = nlist();

type connect_data_parameter = {
    'service_name' : string
    'server' ? string with match(SELF,'^(DEDICATED|SHARED|POOLED)$')
    'failover_mode' ? failover_parameter[1]
} = nlist();

# Security section
type security_parameter = {
    'ssl_server_cert_dn' : string
} = nlist();

# Tnsnames.ora section
type tnsnames_service = {
    'net_service_name' : string
    'protocol_address' : address_list[]
    'connect_data' : connect_data_parameter[1]
    'security' ? security_parameter[1]
};
