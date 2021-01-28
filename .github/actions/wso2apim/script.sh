#!/bin/sh -l

    # $1 - usernameTargettedTenant
    # $2 - passwordTargettedTenant
    # $3 - APIProjectName
    # $4 - APIVersion
    # $5 - PostmanCollectionTestFile

echo "::group::WSO2 APIMCLI Version"
    apimcli version
echo "::end-group"

echo "::group::WSO2 APIMCLI Help"
    apimcli --help
echo "::end-group"

echo "::group::WSO2 APIMCloud Tenants"
    echo Targeted Tenant  - $1
echo "::end-group"

echo "::group::Add environment wso2apicloud"
apimcli add-env -n wso2apicloud \
                      --registration https://gateway.api.cloud.wso2.com/client-registration/register \
                      --apim https://gateway.api.cloud.wso2.com/pulisher \
                      --token https://gateway.api.cloud.wso2.com/token \
                      --import-export https://gateway.api.cloud.wso2.com/api-import-export \
                      --admin https://gateway.api.cloud.wso2.com/api/am/admin/ \
                      --api_list https://gateway.api.cloud.wso2.com/api/am/publisher/apis \
                      --app_list https://gateway.api.cloud.wso2.com/api/am/store/applications

apimcli list envs          
echo "::end-group"



echo "::group::Init API iproject with given API definition"
# apictl import-api -f $API_DIR -e $DEV_ENV -k --preserve-provider --update --verbose
# apimcli init SampleStore --oas petstore.json --definition api_template.yaml
# apimcli init ./$3/$6 --oas $
# apimcli init -f ./$3/$6 --oas $ --definition $
apimcli init ./$3/$4 
mkdir ./$3/$4/Sequences/fault-sequence/Custom
mkdir ./$3/$4/Sequences/in-sequence/Custom
mkdir ./$3/$4/Sequences/out-sequence/Custom
mkdir ./$3/$4/Testing
touch ./$3/$4/Docs/docs.json
ls ./$3/$4
echo "::end-group"


echo "::group::Push API project into the GIT repo from VM"
git config --global user.email "my-bot@bot.com"
git config --global user.name "my-bot"
#This shell script will find all empty directories and sub-directories in a project folder and creates a .gitkeep file, so that the empty directory 
#can be added to the git index. 
find * -type d -empty -exec touch '{}'/.gitkeep \;
git add . 
git commit -m "API project initialized"
git push
echo "::end-group"


echo "::group::Testing With Postman Collection"
if [ $5 ]
then
newman run ./$3/$4/Testing/$5 --insecure 
else
echo "You have not given a postmanfile to run."
fi
echo "::end-group"


echo "::group::Import API project to targetted Tenant"
apimcli login wso2apicloud -u $1 -p $2 -k
apimcli import-api -f ./$3/$4 -e wso2apicloud --preserve-provider=false --update --verbose -k
# apimcli logout wso2apicloud 
echo "::end-group"


echo "::group::List APIS in targetted Tenant"
# apimcli list apis -e <environment> -k
# apimcli list apis --environment <environment> --insec# echo "::set-env name=HELLO::hello"ure
apimcli list apis -e wso2apicloud -k
echo "::end-group"


#-------------------------------
# Invoking and testing automation


echo "::group::Client Registration"
# curl -X POST -H "Authorization: Basic base64encode(<email_username@Org_key>:<password>)" -H "Content-Type: application/json" -d @payload.json https://gateway.api.cloud.wso2.com/client-registration/register
# base64key1 = Authorization: Basic  <username@wso2.com@organizationname:password>base64
base64key1=`echo -n "$1:$2" | base64`

rest_client_object=`curl -s --location -g --request POST 'https://gateway.api.cloud.wso2.com/client-registration/register' \
--header "Authorization: Basic $base64key1" \
--header "Content-Type: application/json" \
--data-raw '{
    "callbackUrl": "www.google.lk",
    "clientName": "rest_api_store",
    "tokenScope": "Production",
    "owner": "'$1'",
    "grantType": "password refresh_token",
    "saasApp": true
}'`

rest_clientId=`echo "$rest_client_object" | jq --raw-output '.clientId'`
rest_clientSecret=`echo "$rest_client_object" | jq --raw-output '.clientSecret'`

echo $rest_clientId
echo $rest_clientSecret 
echo "::end-group"


echo "::group::Client Access Token Generate"
# curl -k -d "grant_type=password&username=email_username@Org_key&password=admin&scope=apim:subscribe" -H "Authorization: Basic SGZFbDFqSlBkZzV0YnRyeGhBd3liTjA1UUdvYTpsNmMwYW9MY1dSM2Z3ZXpIaGM3WG9HT2h0NUFh" https://gateway.api.cloud.wso2.com/token
# base64key2 = Authorization: Basic <rest-client-id:rest-client-secret>base64
base64key2=`echo -n "$rest_clientId:$rest_clientSecret" | base64`

rest_access_token_scope_view=`curl -s --location -g --request POST 'https://gateway.api.cloud.wso2.com/token' \
--header "Content-Type: application/x-www-form-urlencoded" \
--header "Authorization: Basic $base64key2" \
--data-urlencode "grant_type=password" \
--data-urlencode "username=$1" \
--data-urlencode "password=$2" \
--data-urlencode "scope=apim:api_view" | jq --raw-output '.access_token'`

rest_access_token_subscribe=`curl -s --location -g --request POST 'https://gateway.api.cloud.wso2.com/token' \
--header "Content-Type: application/x-www-form-urlencoded" \
--header "Authorization: Basic $base64key2" \
--data-urlencode "grant_type=password" \
--data-urlencode "username=$1" \
--data-urlencode "password=$2" \
--data-urlencode "scope=apim:subscribe" | jq --raw-output '.access_token'`

echo $rest_access_token_scope_view
echo $rest_access_token_subscribe
echo "::end-group"


echo "::group::Finding the API identifier"
API_response=`curl -s --location -g --request GET 'https://gateway.api.cloud.wso2.com/api/am/publisher/apis' \
--header "Authorization: Bearer $rest_access_token_scope_view"`

all_APIs_list=`echo "$API_response" | jq '.list'`
relevant_api=`echo "$all_APIs_list" | jq '.[] | select(.name=="'$3'" and .version=="'$4'")'`
api_identifier=`echo "$relevant_api" | jq --raw-output '.id'`
# echo $APIs
# echo $all_APIs_list
# echo $relevant_api
echo $api_identifier
echo "::end-group"


echo "::group::Create new Application"
# curl -k -H "Authorization: Bearer ae4eae22-3f65-387b-a171-d37eaa366fa8" -H "Content-Type: application/json" -X POST -d @data.json "https://gateway.api.cloud.wso2.com/api/am/store/applications"
new_test_automation_application=`curl -s --location -g --request POST 'https://gateway.api.cloud.wso2.com/api/am/store/applications' \
--header "Authorization: Bearer $rest_access_token_subscribe" \
--header "Content-Type: application/json" \
--data-raw '{
    "throttlingTier": "Unlimited",
    "description": "Automatic generated app for automated testing purpose",
    "name": "TestAutomationApp",
    "callbackUrl": "http://my.server.com/callback"
}'`

application_id=`echo "$new_test_automation_application" | jq --raw-output '.applicationId'`

echo $application_id
echo "::end-group"


echo "::group::Add a new subscription"
# curl -k -H "Authorization: Bearer ae4eae22-3f65-387b-a171-d37eaa366fa8" -H "Content-Type: application/json" -X POST  -d @data.json "https://gateway.api.cloud.wso2.com/api/am/store/subscriptions"

add_subscription=`curl -s --location -g --request POST 'https://gateway.api.cloud.wso2.com/api/am/store/subscriptions' \
--header "Authorization: Bearer $rest_access_token_subscribe" \
--header "Content-Type: application/json" \
--data-raw '{
    "tier": "Unlimited",
    "apiIdentifier": "'$api_identifier'",
    "applicationId": "'$application_id'"
}'`

echo $add_subscription
echo "::end-group"



echo "::group::Generate consumer Keys(client keys) and secrets for for the Testing Automation Application"
# curl -k -H "Authorization: Bearer ae4eae22-3f65-387b-a171-d37eaa366fa8" -H "Content-Type: application/json" -X POST -d @data.json  "https://gateway.api.cloud.wso2.com/api/am/store/applications/generate-keys?applicationId=c30f3a6e-ffa4-4ae7-afce-224d1f820524"

application_access_response=`curl -s --location -g --request POST "https://gateway.api.cloud.wso2.com/api/am/store/applications/generate-keys?applicationId=$application_id" \
--header "Authorization: Bearer $rest_access_token_subscribe" \
--header "Content-Type: application/json" \
--data-raw '{    
  "validityTime": "3600",
  "keyType": "PRODUCTION",
  "accessAllowDomains": ["ALL"]
}'`

consumer_key=`echo "$application_access_response" | jq --raw-output '.consumerKey'`
consumer_secret=`echo "$application_access_response" | jq --raw-output '.consumerSecret'`
# echo $application_access_response
echo $consumer_key
echo $consumer_secret
echo "::end-group"



echo "::group::Generate access token for your API"
# curl -u <client id>:<client secret> -k -d "grant_type=client_credentials&validity_period=3600" -H "Content-Type:application/x-www-form-urlencoded" https://gateway.api.cloud.wso2.com:443/token
# base64 encode<consumer-key:consumer-secret>
base64key3=`echo -n "$consumer_key:$consumer_secret" | base64`

api_access_response=`curl -s --location -g --request POST 'https://gateway.api.cloud.wso2.com:443/token' \
--header "Content-Type: application/x-www-form-urlencoded" \
--header "Authorization: Basic $base64key3" \
--data-urlencode "grant_type=client_credentials" \
--data-urlencode "validity_period=3600"`

api_access_token=`echo "$api_access_response" | jq --raw-output '.access_token'`
# echo $api_access_response
echo $api_access_token
echo "::end-group"

#-------------------------------


echo "::group::Testing With Postman Collection"
# newman run $5 --insecure
echo "::end-group"


# ------------------------------Malith

# Client Registration

# curl --location -g --request POST 'https://{{url}}/client-registration/register' \
# --header 'Content-Type: application/json' \
# --header 'Authorization: Basic e3t1c2VybmFtZX19Ont7cGFzc3dvcmR9fQ==' \
# --data-raw '{
#     "callbackUrl": "www.google.lk",
#     "clientName": "rest_api_publisher-new",
#     "tokenScope": "Production",
#     "owner": {{applicationowner}},
#     "grantType": "password refresh_token",
#     "saasApp": true
# }'



# Client Access Token

# curl --location -g --request POST 'https://{{url}}/token' \
# --header 'Content-Type: application/x-www-form-urlencoded' \
# --header 'Authorization: Basic e3tyZXN0LWNsaWVudC1pZH19Ont7cmVzdC1jbGllbnQtc2VjcmV0fX0=' \
# --data-urlencode 'grant_type=password' \
# --data-urlencode 'username={{username}}' \
# --data-urlencode 'password={{password}}' \
# --data-urlencode 'scope=apim:api_view'

#---------------------------------------

apimcli logout wso2apicloud 


# echo "::group::Export API from current Tenant"
# # apimcli export-api -n <API-name> -v <version> -r <provider> -e <environment> -u <username> -p <password> -k
# # apimcli export-api --name <API-name> --version <version> --provider <provider> --environment <environment> --username <username> --password <password> --insecure
# # apimcli export-api -n TeamMasterAPI -v v1.0.0 -r mihindu@wso2.com@development -e wso2apicloud -k
# echo "::end-group"



# apimcli login wso2apicloud -u $3 -p $4 -k
# echo "::group::Import API to Prod Tenant"
# # apimcli import-api -f <environment>/<file> -e <environment> -u <username> -p <password> --preserve-provider <preserve_provider> -k
# # apimcli import-api --file <environment>/<file> --environment <environment> --username <username> --password <password> --preserve-provider <preserve_provider> --insecure
# # apimcli import-api -f wso2apicloud/TeamMasterAPI_v1.0.0.zip -e wso2apicloud --preserve-provider=false -k
# apimcli import-api -f wso2apicloud/$5_$8.zip -e wso2apicloud --preserve-provider=false --update --verbose -k
# # apimcli logout wso2apicloud 
# echo "::end-group"

# echo "::group::List APIS in a Prod Tenant"
# # apimcli list apis -e <environment> -k
# # apimcli list apis --environment <environment> --insecure
# apimcli list apis -e wso2apicloud -k
# echo "::end-group"
# apimcli logout wso2apicloud 



# echo "::group::Export an *App from current tenant"
# # apimcli export-app -n <application-name> -o <owner> -e <environment> -k
# # apimcli export-app --name <application-name> --owner <owner> --environment <environment> --insecure
# # apimcli export-app -n TestApp -o kim@wso2.com@testorg1 -e wso2apicloud -k
# echo "::end-group"

# echo "::group::Export an *App from current tenant"
# # apimcli export-app -n <application-name> -o <owner> -e <environment> -k
# # apimcli export-app --name <application-name> --owner <owner> --environment <environment> --insecure
# # apimcli export-app -n TestApp -o kim@wso2.com@testorg1 -e wso2apicloud -k
# echo "::end-group"

# echo "::group::List *Apps in a perticular environment"
# # apimcli list apps -e <environment> -o <owner> -k
# # apimcli list apps --environment <environment> --owner <owner> --insecure
# # apimcli list apps -e wso2apicloud -o admin -k
# echo "::end-group"

# echo "::group:: Reset Users"
# # If you want to list APIs or applications that belong to a particular tenant, 
# # you need to first reset the user before listing APIs or applications for the particular tenant.

# # apimcli reset-user -e <environment>
# # apimcli reset-user --environment <environment>
# # apimcli reset-user -e wso2apicloud
# echo "::end-group"

# echo "::group:: Set HTTP request timeout "
# # apimcli set --http-request-timeout <http-request-timeout>
# # apimcli set --http-request-timeout 10000
# echo "::end-group"

# echo "::group:: Set export directory "
# #Run the following CLI command to the change the default location of the export directory.
# # apimcli set --export-directory <export-directory-path>
# # apimcli set --export-directory /Users/kim/Downloads/MyExports
# echo "::end-group"

