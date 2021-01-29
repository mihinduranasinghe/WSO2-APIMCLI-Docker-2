#!/bin/sh -l

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

if [ "$needAPIAccessToken" = true ]
    then 
        export username
        export password
        export APIName
        export APIVersion
        export username
        export needAPIAccessToken
        ./script_api_invoke.sh
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



