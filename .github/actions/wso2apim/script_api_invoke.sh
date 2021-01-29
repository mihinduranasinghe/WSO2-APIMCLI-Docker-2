
#!/bin/sh -l

################~~ Invoking an API Access Token ~~################

  # If client requested APIAccessToken ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  #
  #   1.Register a WSO2 Cloud REST API client                                  
  #   2.Generate access tokens for the REST Client for different scopes 
  #     (api_view, subscribe, subscription_view, ...) 
  #   3.Finding The API Identifier(apiId) of the user's respective API      
  #   4.Create A New Application named "TestingAutomationApp" for testing purpose              
  #   5.Creating A New Application named "TestingAutomationApp" for testing purpose                 
  #   6.Add a new subscription from newly created "TestingAutomationApp" to the current API    
  #   7.Generate consumer Keys(client key and secret) for for the Testing Automation Application 
  #   8.Generate access token for your API
  #   9.Creating a text file with important records  
  #                  
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  
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


## Generate consumer Keys(client key and secret) for for the Testing Automation Application
echo "::group::Generate consumer Keys(client key and secret) for for the Testing Automation Application"

view_application_access_keys_response=`curl -s --location -g --request GET "https://gateway.api.cloud.wso2.com/api/am/store/applications/$application_id/keys/PRODUCTION" \
--header "Authorization: Bearer $rest_access_token_subscribe"`
# curl -k -H "Authorization: Bearer ae4eae22-3f65-387b-a171-d37eaa366fa8" -H "Content-Type: application/json" -X POST -d @data.json  "https://gateway.api.cloud.wso2.com/api/am/store/applications/generate-keys?applicationId=c30f3a6e-ffa4-4ae7-afce-224d1f820524"

if [ "$view_application_access_keys_response" ]
    then
    consumer_key=`echo "$view_application_access_keys_response" | jq --raw-output '.consumerKey'`
    consumer_secret=`echo "$view_application_access_keys_response" | jq --raw-output '.consumerSecret'`

    else
    application_access_response=`curl -s --location -g --request POST "https://gateway.api.cloud.wso2.com/api/am/store/applications/generate-keys?applicationId=$application_id" \
    --header "Authorization: Bearer $rest_access_token_subscribe" \
    --header "Content-Type: application/json" \
    --data-raw '{    
    "validityTime": "3600",
    "keyType": "PRODUCTION",
    "accessAllowDomains": ["ALL"]
    }'`

    # echo $application_access_response
    consumer_key=`echo "$application_access_response" | jq --raw-output '.consumerKey'`
    consumer_secret=`echo "$application_access_response" | jq --raw-output '.consumerSecret'`
        fi 

            echo consumer_key    - $consumer_key
            echo consumer_secret - $consumer_secret
    echo "::end-group"


    ## Generate access token for your API
    echo "::group::Generate access token for your API"            
        # base64 encode<consumer-key:consumer-secret>
        base64key3=`echo -n "$consumer_key:$consumer_secret" | base64`

        # curl -u <client id>:<client secret> -k -d "grant_type=client_credentials&validity_period=3600" -H "Content-Type:application/x-www-form-urlencoded" https://gateway.api.cloud.wso2.com:443/token
        api_access_response=`curl -s --location -g --request POST 'https://gateway.api.cloud.wso2.com:443/token' \
        --header "Content-Type: application/x-www-form-urlencoded" \
        --header "Authorization: Basic $base64key3" \
        --data-urlencode "grant_type=client_credentials" \
        --data-urlencode "validity_period=3600"`

        api_access_token=`echo "$api_access_response" | jq --raw-output '.access_token'`
    
        # echo $api_access_response
        echo API ACCESS TOKEN - $api_access_token

    echo "::end-group"


    ## Creating a text file with important records
    echo "::group::Create a file with important records"

    echo "::end-group"


    
