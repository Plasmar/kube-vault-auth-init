#!/usr/bin/env bash

printf "\n************************\n"
printf "Running test: Test that dynamic secrets can be retrieved with multiple fields and stored in separate output variables\n"

################################################

# set up standard inputs required for running within the test framework
export KUBE_SA_TOKEN="eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJkZWZhdWx0Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZWNyZXQubmFtZSI6InRlc3Qtc2VydmljZS10b2tlbi10cWw3ZCIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50Lm5hbWUiOiJ0ZXN0LXNlcnZpY2UiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC51aWQiOiIwNTc5NGY2Yy1mOTY5LTExZTktYjkyYS0wNjBlNWNjYWRhMTYiLCJzdWIiOiJzeXN0ZW06c2VydmljZWFjY291bnQ6ZGVmYXVsdDp0ZXN0LXNlcnZpY2UifQ.0BQBfZKQx6eYZR4GyPHOYOvrYlcghpNJl9wkunoNdXF64wQDLQp7n42NWiClmRmIi54CRVokMSEhaDEphWpu1EM67NRP0V_9ww3IRSNlsERFhMJApeni-0EaWPSlOGUoG_5qJJGD8vqyKTKRcFDr94SP1pg0pwYao6tustYK9mQ85i-w4REj6-EOkuFIYu49rOpVd_7nBSqQbzlam7futTXOa3rfUwcrbtgU11m9L-CwgA5WI1Cr_H_ito2OBTvaZoZTtFXqGR3rue9crllrwme5vBEzg-NowbmJaKcP8O-5WzejMCRVMUVR_aQ77EvbM8_HFk5U_oVzV4dPK8yEdnWKn8_-32zq4kl_ieB7LGWa9Y9_lBQIcL6TWUQnVbuX3hEJhrgVq4NQU9HYv7RFYnRcUHqom1Vuo-UlCYkk36HMoIlDns0RR495AtccXEoJ3dP5zE0Y40phmORDKaiBvvsTb6helAmDW5Le7JiDeY2Rx-Yf19js7EP0y3EH96fCrbnuWSGEEuCL__vvKT5Io4S0OYYeGZneVCDzBBXyyjrY8ggNK-6P5e7ciDwm32M_1oHHCrUWCG2SvqRLNvnYbdMoZD-XL6pmJu3zgndmZ0NypAthpGMEmO-SV0GQuQq1IqsG8CJQprrT3RA-p6CAW6WecKv2ljuCviWucKNmtw"
export VAULT_LOGIN_ROLE=my-app-role
export VARIABLES_FILE=$(mktemp -d)/variables

################################################

# set up inputs for this test
VAULT_TOKEN=${SETUP_VAULT_TOKEN} vault write database/roles/my-role \
    db_name=my-mongodb-database \
    creation_statements='{ "db": "admin", "roles": [{ "role": "readWrite" }, {"role": "read", "db": "foo"}] }' \
    default_ttl="1h" \
    max_ttl="24h" > /dev/null
export SECRET_DB_USERNAME=database/creds/my-role?username
export SECRET_DB_PASSWORD=database/creds/my-role?password

/usr/src/init-token.sh  2>&1 >&1 | sed 's/^/>> /'
RESULT="${PIPESTATUS[0]}"
[ "${RESULT}" -gt "0" ] && printf "ERROR: Script returned a non-zero exit code\n"

################################################

# assert output
assertVaultToken "$(getOutputValue ${VARIABLES_FILE} VAULT_TOKEN)" || RESULT=1
assertStartsWith "DB_USERNAME should be set" "v-app-role-my-role-" "$(getOutputValue ${VARIABLES_FILE} DB_USERNAME)" || RESULT=1
assertNotEmpty "DB_PASSWORD should be set" "$(getOutputValue ${VARIABLES_FILE} DB_PASSWORD)" || RESULT=1
assertStartsWith "LEASE_IDS should contain the database lease" "database/creds/my-role/" "$(getOutputValue ${VARIABLES_FILE} LEASE_IDS)" || RESULT=1

################################################

# clean up
VAULT_TOKEN=${SETUP_VAULT_TOKEN} vault delete database/roles/my-role > /dev/null
VAULT_TOKEN=${SETUP_VAULT_TOKEN} vault token revoke "$(getOutputValue ${VARIABLES_FILE} VAULT_TOKEN)" > /dev/null

cleanEnv

[[ "${RESULT}" -eq 0 ]] && printf "Test passed\n"
return ${RESULT}
