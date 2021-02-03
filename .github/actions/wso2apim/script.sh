#!/bin/sh -l
set -e
# set -e -o pipefail

        # User Inputs Array~~~~~~~~~~~~~~~~~~~~~~~~
        #                                         | 
        #     $1 - usernameTargettedTenant        |
        #     $2 - passwordTargettedTenant        |
        #     $3 - APIProjectName                 |
        #     $4 - APIVersion                     |
        #     $5 - PostmanCollectionTestFile      |  
        #     $6 - needAPIAccessToken             |
        #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

## Re-assigning user inputs into variables
    username=`echo "$1"`
    password=`echo "$2"`
    APIName=`echo "$3"`
    APIVersion=`echo "$4"`
    PostmanCollectionTestFile=`echo "$5"`
    needAPIAccessToken=`echo $6`

## Echo user inputs
echo "::group::WSO2 APIMCloud - Your Inputs"
    echo Username Targeted tenant  - $username
    echo Password                  - $password
    echo APIName                   - $APIName
    echo APIVersion                - $APIVersion
    echo PostmanCollectionTestFile - $PostmanCollectionTestFile 
    echo needAPIAccessToken        - $needAPIAccessToken 
echo "::end-group"

## Confiduring WSO2 API Cloud gateway environment in VM
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

set +e
    ## Init API iproject with given API definition
    echo "::group::Init API iproject with given API definition"
        apimcli init ./$APIName/$APIVersion 
        mkdir ./$APIName/$APIVersion/Sequences/fault-sequence/Custom
        mkdir ./$APIName/$APIVersion/Sequences/in-sequence/Custom
        mkdir ./$APIName/$APIVersion/Sequences/out-sequence/Custom
        mkdir ./$APIName/$APIVersion/Testing
        touch ./$APIName/$APIVersion/Docs/docs.json
        ls ./$APIName/$APIVersion
    echo "::end-group"
set -e

## Push newly initialized API project into the GIT repo again from VM
echo "::group::Push API project into the GIT repo from VM"
    git config --global user.email "my-bot@bot.com"
    git config --global user.name "my-bot"

    #Search for all empty directories/sub-directories and creates a ".gitkeep" file, 
    find * -type d -empty -exec touch '{}'/.gitkeep \;

    git add . 
    git commit -m "API project initialized"
    git push
echo "::end-group"


## Import/deploy API project to the targetted Tenant
echo "::group::Import API project to targetted Tenant"
    apimcli login wso2apicloud -u $username -p $password -k
    apimcli import-api -f ./$APIName/$APIVersion -e wso2apicloud --preserve-provider=false --update --verbose -k
echo "::end-group"


#wait for 40s until the API is deployed because it might take some time to deploy in background.                                                
    echo "Please wait ... "
    sleep 40s     


## Listing the APIS in targeted Tenant
echo "::group::List APIS in targeted Tenant"
    # apimcli list apis -e <environment> -k
    # apimcli list apis --environment <environment> --insec
    apimcli list apis -e wso2apicloud -k
echo "::end-group"


################~~ Invoking an API Access Token ~~################

  # If client requested APIAccessToken ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  #
  #   1.Register a WSO2 Cloud REST API client                                  
  #   2.Generate access tokens for the REST Client for different scopes 
  #     (api_view, subscribe, subscription_view, ...) 
  #   3.Finding The API Identifier(apiId) of the user's respective API      
  #   4.Create A New Application named "TestingAutomationApp" for testing purpose                 
  #   5.Add a new subscription from newly created "TestingAutomationApp" to the current API    
  #   6.Generate consumer Keys(client key and secret) for PRODUCTION API 
  #   7.Generate consumer Keys(client key and secret) for SANDBOX API
  #   8.Generate access token for your PRODUCTION API
  #   9.Generate access token for your SANDBOX API
  #  10.Creating a text file with important records  
  #                  
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

if [ "$needAPIAccessToken" = true ]
    then   
        ## Register a WSO2 Cloud REST API client
        echo "::group::REST Client Registration"
            
            # base64key1 = Authorization: Basic  <username@wso2.com@organizationname:password>base64
            base64key1=`echo -n "$username:$password" | base64`

            # curl -X POST -H "Authorization: Basic base64encode(<email_username@Org_key>:<password>)" -H "Content-Type: application/json" -d @payload.json https://gateway.api.cloud.wso2.com/client-registration/register
            rest_client_object=`curl -s --location -g --request POST 'https://gateway.api.cloud.wso2.com/client-registration/register' \
            --header "Authorization: Basic $base64key1" \
            --header "Content-Type: application/json" \
            --data-raw '{
                "callbackUrl": "www.google.lk",
                "clientName": "rest_api_store",
                "tokenScope": "Production",
                "owner": "'$username'",
                "grantType": "password refresh_token",
                "saasApp": true
            }'`

            rest_clientId=`echo "$rest_client_object" | jq --raw-output '.clientId'`
            rest_clientSecret=`echo "$rest_client_object" | jq --raw-output '.clientSecret'`

            # echo $rest_clientId
            # echo $rest_clientSecret 
        echo "::end-group"


        ## Generate access tokens for the REST Client for different scopes (api_view, subscribe, subscription_view, ...)
        echo "::group::REST Client Access Token Generate"
            
            # base64key2 = Authorization: Basic <rest-client-id:rest-client-secret>base64
            base64key2=`echo -n "$rest_clientId:$rest_clientSecret" | base64`

            # curl -k -d "grant_type=password&username=email_username@Org_key&password=admin&scope=apim:subscribe" -H "Authorization: Basic SGZFbDFqSlBkZzV0YnRyeGhBd3liTjA1UUdvYTpsNmMwYW9MY1dSM2Z3ZXpIaGM3WG9HT2h0NUFh" https://gateway.api.cloud.wso2.com/token
            rest_access_token_api_view=`curl -s --location -g --request POST 'https://gateway.api.cloud.wso2.com/token' \
            --header "Content-Type: application/x-www-form-urlencoded" \
            --header "Authorization: Basic $base64key2" \
            --data-urlencode "grant_type=password" \
            --data-urlencode "username=$username" \
            --data-urlencode "password=$password" \
            --data-urlencode "scope=apim:api_view" | jq --raw-output '.access_token'`

            rest_access_token_subscribe=`curl -s --location -g --request POST 'https://gateway.api.cloud.wso2.com/token' \
            --header "Content-Type: application/x-www-form-urlencoded" \
            --header "Authorization: Basic $base64key2" \
            --data-urlencode "grant_type=password" \
            --data-urlencode "username=$username" \
            --data-urlencode "password=$password" \
            --data-urlencode "scope=apim:subscribe" | jq --raw-output '.access_token'`

            rest_access_token_subscription_view=`curl -s --location -g --request POST 'https://gateway.api.cloud.wso2.com/token' \
            --header "Content-Type: application/x-www-form-urlencoded" \
            --header "Authorization: Basic $base64key2" \
            --data-urlencode "grant_type=password" \
            --data-urlencode "username=$username" \
            --data-urlencode "password=$password" \
            --data-urlencode "scope=apim:subscription_view" | jq --raw-output '.access_token'`

            # echo $rest_access_token_api_view
            # echo $rest_access_token_subscribe
            # echo $rest_access_token_subscription_view
        echo "::end-group"


        ## Finding The API Identifier(apiId) of the user's respective API
        echo "::group::Finding The API Identifier(apiId)"

            GET_APIs_response=`curl -s --location -g --request GET 'https://gateway.api.cloud.wso2.com/api/am/publisher/apis' \
            --header "Authorization: Bearer $rest_access_token_api_view"`
            
            all_APIs_list=`echo "$GET_APIs_response" | jq '.list'`
            relevant_api=`echo "$all_APIs_list" | jq '.[] | select(.name=="'$APIName'" and .version=="'$APIVersion'")'`
            
            api_identifier=`echo "$relevant_api" | jq --raw-output '.id'`

            # echo $GET_APIs_response
            # echo $all_APIs_list
            # echo $relevant_api
            echo API Identifier - $api_identifier

        echo "::end-group"


        ## Creating A New Application named "TestingAutomationApp" for testing purpose
        echo "::group::Create A New Application - TestingAutomationApp"

            new_app_name="TestingAutomationApp"

            view_applications_response=`curl -s --location -g --request GET 'https://gateway.api.cloud.wso2.com/api/am/store/applications' \
            --header "Authorization: Bearer $rest_access_token_subscribe"`
            # curl -k -H "Authorization: Bearer ae4eae22-3f65-387b-a171-d37eaa366fa8" -H "Content-Type: application/json" -X POST -d @data.json "https://gateway.api.cloud.wso2.com/api/am/store/applications"

            applications_list=`echo "$view_applications_response" | jq '.list'`
            testing_automation_application=`echo "$applications_list" | jq '.[] | select(.name=="'$new_app_name'")'`
            application_id=`echo "$testing_automation_application" | jq --raw-output '.applicationId'`
            
            # echo $view_applications_response
            # echo $applications_list
            # echo $testing_automation_application
            echo ApplicationID - $application_id

            if [ -z "$application_id" ]
                then
                new_testing_automation_application=`curl -s --location -g --request POST 'https://gateway.api.cloud.wso2.com/api/am/store/applications' \
                --header "Authorization: Bearer $rest_access_token_subscribe" \
                --header "Content-Type: application/json" \
                --data-raw '{
                    "throttlingTier": "Unlimited",
                    "description": "Automatic generated app for automated testing purpose",
                    "name": "'$new_app_name'",
                    "callbackUrl": "http://my.server.com/callback"
                }'`

                application_id=`echo "$new_testing_automation_application" | jq --raw-output '.applicationId'`
                echo ApplicationID - $application_id
            fi
        echo "::end-group"


        ## Add a new subscription from newly created "TestingAutomationApp" to the current API
        echo "::group::Add a new subscription"

            # curl -k -H "Authorization: Bearer ae4eae22-3f65-387b-a171-d37eaa366fa8" -H "Content-Type: application/json" -X POST  -d @data.json "https://gateway.api.cloud.wso2.com/api/am/store/subscriptions"
            view_api_subscriptions_response=`curl -s --location -g --request GET "https://gateway.api.cloud.wso2.com/api/am/publisher/subscriptions?apiId=$api_identifier" \
            --header "Authorization: Bearer $rest_access_token_subscription_view"`
            
            api_subscriptions_list=`echo "$view_api_subscriptions_response" | jq '.list'`
            testing_automation_app_subscription=`echo "$api_subscriptions_list" | jq '.[] | select(.applicationId=="'$application_id'")'`
            subscription_id=`echo "$testing_automation_app_subscription" | jq --raw-output '.subscriptionId'`
            
            # echo $view_api_subscriptions_response
            # echo $api_subscriptions_list
            # echo $testing_automation_app_subscription
            # echo $subscription_id
            
            if [ -z "$subscription_id" ]
                then
                add_subscription_response=`curl -s --location -g --request POST 'https://gateway.api.cloud.wso2.com/api/am/store/subscriptions' \
                --header "Authorization: Bearer $rest_access_token_subscribe" \
                --header "Content-Type: application/json" \
                --data-raw '{
                    "tier": "Unlimited",
                    "apiIdentifier": "'$api_identifier'",
                    "applicationId": "'$application_id'"
                }'`

                echo $add_subscription_response
            fi 
            # echo $subscription_id
            # echo $application_id
        echo "::end-group"


        ## Generate consumer Keys(client key and secret) for PRODUCTION for the Testing Automation Application
        echo "::group::Generate consumer Keys(client key and secret) for PRODUCTION API for the Testing Automation Application"

            view_application_access_keys_response=`curl -s --location -g --request GET "https://gateway.api.cloud.wso2.com/api/am/store/applications/$application_id/keys/PRODUCTION" \
            --header "Authorization: Bearer $rest_access_token_subscribe"`
            # curl -k -H "Authorization: Bearer ae4eae22-3f65-387b-a171-d37eaa366fa8" -H "Content-Type: application/json" -X POST -d @data.json  "https://gateway.api.cloud.wso2.com/api/am/store/applications/generate-keys?applicationId=c30f3a6e-ffa4-4ae7-afce-224d1f820524"

            if [ "$view_application_access_keys_response" ]
                then
                consumer_key_PRODUCTION=`echo "$view_application_access_keys_response" | jq --raw-output '.consumerKey'`
                consumer_secret_PRODUCTION=`echo "$view_application_access_keys_response" | jq --raw-output '.consumerSecret'`

                else
                application_access_response_PRODUCTION=`curl -s --location -g --request POST "https://gateway.api.cloud.wso2.com/api/am/store/applications/generate-keys?applicationId=$application_id" \
                --header "Authorization: Bearer $rest_access_token_subscribe" \
                --header "Content-Type: application/json" \
                --data-raw '{    
                "validityTime": "3600",
                "keyType": "PRODUCTION",
                "accessAllowDomains": ["ALL"]
                }'`

                # echo $application_access_response_PRODUCTION
                consumer_key_PRODUCTION=`echo "$application_access_response_PRODUCTION" | jq --raw-output '.consumerKey'`
                consumer_secret_PRODUCTION=`echo "$application_access_response_PRODUCTION" | jq --raw-output '.consumerSecret'`
            fi 

                echo consumer_key_PRODUCTION    - $consumer_key_PRODUCTION
                echo consumer_secret_PRODUCTION - $consumer_secret_PRODUCTION
        echo "::end-group"


        ## Generate access token for your PRODUCTION API
        echo "::group::Generate access token for your PRODUCTION API"            
            # base64 encode<consumer-key:consumer-secret>
            base64key3=`echo -n "$consumer_key_PRODUCTION:$consumer_secret_PRODUCTION" | base64`

            # curl -u <client id>:<client secret> -k -d "grant_type=client_credentials&validity_period=3600" -H "Content-Type:application/x-www-form-urlencoded" https://gateway.api.cloud.wso2.com:443/token
            api_access_response_PRODUCTION=`curl -s --location -g --request POST 'https://gateway.api.cloud.wso2.com:443/token' \
            --header "Content-Type: application/x-www-form-urlencoded" \
            --header "Authorization: Basic $base64key3" \
            --data-urlencode "grant_type=client_credentials" \
            --data-urlencode "validity_period=3600"`

            api_access_token_PRODUCTION=`echo "$api_access_response_PRODUCTION" | jq --raw-output '.access_token'`
        
            # echo $api_access_response_PRODUCTION
            echo PRODUCTION API ACCESS TOKEN - $api_access_token_PRODUCTION

        echo "::end-group"


        ## Generate consumer Keys(client key and secret) for SANDBOX for the Testing Automation Application
        echo "::group::Generate consumer Keys(client key and secret) for SANDBOX API for the Testing Automation Application"

            view_application_access_keys_response_SANDBOX=`curl -s --location -g --request GET "https://gateway.api.cloud.wso2.com/api/am/store/applications/$application_id/keys/SANDBOX" \
            --header "Authorization: Bearer $rest_access_token_subscribe"`
            # curl -k -H "Authorization: Bearer ae4eae22-3f65-387b-a171-d37eaa366fa8" -H "Content-Type: application/json" -X POST -d @data.json  "https://gateway.api.cloud.wso2.com/api/am/store/applications/generate-keys?applicationId=c30f3a6e-ffa4-4ae7-afce-224d1f820524"

            if [ "$view_application_access_keys_response_SANDBOX" ]
                then
                consumer_key_SANDBOX=`echo "$view_application_access_keys_response_SANDBOX" | jq --raw-output '.consumerKey'`
                consumer_secret_SANDBOX=`echo "$view_application_access_keys_response_SANDBOX" | jq --raw-output '.consumerSecret'`

                else
                application_access_response_SANDBOX=`curl -s --location -g --request POST "https://gateway.api.cloud.wso2.com/api/am/store/applications/generate-keys?applicationId=$application_id" \
                --header "Authorization: Bearer $rest_access_token_subscribe" \
                --header "Content-Type: application/json" \
                --data-raw '{    
                "validityTime": "3600",
                "keyType": "SANDBOX",
                "accessAllowDomains": ["ALL"]
                }'`

                # echo $application_access_response_SANDBOX
                consumer_key_SANDBOX=`echo "$application_access_response_SANDBOX" | jq --raw-output '.consumerKey'`
                consumer_secret_SANDBOX=`echo "$application_access_response_SANDBOX" | jq --raw-output '.consumerSecret'`
            fi 

                echo consumer_key_SANDBOX    - $consumer_key_SANDBOX
                echo consumer_secret_SANDBOX - $consumer_secret_SANDBOX
        echo "::end-group"


        ## Generate access token for your SANDBOX API
        echo "::group::Generate access token for your SANDBOX API"            
            # base64 encode<consumer-key:consumer-secret>
            base64key3=`echo -n "$consumer_key_SANDBOX:$consumer_secret_SANDBOX" | base64`

            # curl -u <client id>:<client secret> -k -d "grant_type=client_credentials&validity_period=3600" -H "Content-Type:application/x-www-form-urlencoded" https://gateway.api.cloud.wso2.com:443/token
            api_access_response_SANDBOX=`curl -s --location -g --request POST 'https://gateway.api.cloud.wso2.com:443/token' \
            --header "Content-Type: application/x-www-form-urlencoded" \
            --header "Authorization: Basic $base64key3" \
            --data-urlencode "grant_type=client_credentials" \
            --data-urlencode "validity_period=3600"`

            api_access_token_SANDBOX=`echo "$api_access_response_SANDBOX" | jq --raw-output '.access_token'`
        
            # echo $api_access_response_SANDBOX
            echo SANDBOX API ACCESS TOKEN - $api_access_token_SANDBOX

        echo "::end-group"


        ## Creating a text file with important records
        echo "::group::Create a file with important API Tokens records"
            # rm ./$APIName/$APIVersion/Testing/ACCESS_TOKENS.txt
            echo "
                Here we have generated API access tokens for you to test your API with your own postman collection
                --------------------------------------------------------------------------------------------------
                SANDBOX API ACCESS TOKEN    - $api_access_token_SANDBOX
                PRODUCTION API ACCESS TOKEN - $api_access_token_PRODUCTION
            " >./$APIName/$APIVersion/Testing/ACCESS_TOKENS.txt

            echo "Please navigate to $APIName/$APIVersion/Testing/ACCESS_TOKENS.txt to claim you API tokens"
        echo "::end-group"


        ## Push newly initialized API project into the GIT repo again from VM
        echo "::group::Push API project into the GIT repo from VM"
            git config --global user.email "my-bot@bot.com"
            git config --global user.name "my-bot"

            #Search for all empty directories/sub-directories and creates a ".gitkeep" file, 
            find * -type d -empty -exec touch '{}'/.gitkeep \;

            git add . 
            git commit -m "API project initialized"
            git push
        echo "::end-group"      


    else
        echo "::group:: Do you need an API Access Token for automated testing ?"
            echo "You have not requested an API Access Token."
            echo "Provide the following input with the value as TRUE in your code chunk, to generate API Access Token for testing with your own postman collection"
            echo "'needAPIAccessToken' : TRUE"    
        echo "::end-group"
fi


## Testing API With a user given Postman Collection
echo "::group::Testing With Postman Collection"
    if [ $PostmanCollectionTestFile ]
        then
            newman run ./$APIName/$APIVersion/Testing/$PostmanCollectionTestFile --insecure 
        else
            echo "You have not given a postmanfile to run."
    fi
echo "::end-group"



