# !/bin/bash

# Deploy Azure Arc-connected AKS clusters and deploy app service on K8s hello world connecting Arc Data Services SQL MI or PGSQL Hyperscale

# FLAGS
SQL_ADMIN_PW=''
SP_CLIENT_ID=''
SP_SECRET=''
HELP_FLAG=false
ARC_SQL_DB_TYPE_FLAG='sqlmi'
LOCATION_FLAG=''
CUSTOM_LOCATION_NAME_FLAG=''

# CONSTANT SETUP
# Only change these if you know what you are doing.
SUBSCRIPTION_ID=''
TENANT_ID=''
LOG_RESOURCES=true
MAX_WAIT_SECONDS=1200 # wait up to 20 minutes for the resources to be created in the cluster
SERVICE_POLL_SECONDS=10

## AKS Cluster
AKS_NODE_COUNT=3 # need at least 3 STD_DS3_v2 to run SQL MI + App service
AKS_NODE_SIZE='Standard_DS3_v2'

## Arc Data Controller
ARC_DATA_NAMESPACE='arcdata'
ARCDC_ARM_TEMPLATE='data/datacontroller.template.json'
ARCDC_ARM_PARAMETERS='data/datacontroller.parameters.json'

## Arc Sql MI
SQLMI_ARM_TEMPLATE='data/sqlmi-arc/sqlmiarc.template.json'
SQLMI_ARM_PARAMETERS='data/sqlmi-arc/sqlmiarc.parameters.json'
LOCAL_HOST_PUBLIC_IP=$(dig +short myip.opendns.com @resolver1.opendns.com) # ISP WAN IPv4 address for the local network - see http://whatismyip.com.
APPSERVICE_SQLMI_CONN_STR_KEY='ConnectionStrings__Sql' # Connection string name, Hello World webapp looks for this during startup

## Arc Pgsql
PGSQL_ARM_TEMPLATE='data/postgres-arc/psqlarc.template.json'
PGSQL_ARM_PARAMETERS='data/postgres-arc/psqlarc.parameters.json'
PGSQL_EV='12' #or 11
PGSQL_ARC_WORKERS=0 # FOR DEMO ONLY USE CITUS NODE
APPSERVICE_PGSQL_CONN_STR_KEY='ConnectionStrings__Npgsql' # Connection string name, Hello World webapp looks for this during startup

## Arc App Service on AKS
NAMESPACE="appservice-ns"                              # Namespace in your cluster to install the extension and provision resources, don't change this
WEBAPP_PATH="../artifacts/HelloWorld-sql.zip"          # path to pre-compiled webapp zip

# VARIABLES
declare -A RESOURCE_GROUPS                 # Key: region, Value: resourceGroupName
declare -A LOG_ANALYTICS_KEYS              # Key: resourceGroupName, Value: key
declare -A LOG_ANALYTICS_KEYS_ENC          # Key: resourceGroupName, Value: key_enc
declare -A LOG_ANALYTICS_WORKSPACE_IDS     # Key: resourceGroupName, Value: #workspace_id
declare -A LOG_ANALYTICS_WORKSPACE_IDS_ENC # Key: resourceGroupName, Value: #workspace_id_enc
declare -A CONN_STRINGS                    # Key: resourceGroupName, Value: #conn_str

# FUNCTION DECLARATIONS
####################################################################
# Ensure dependencies are installed.
# Globals:
#   SUBSCRIPTION_ID
# Arguments:
#   None
####################################################################
function check_prereqs() {
    echo -n 'Checking prerequisites are installed...'

    local is_error=false
    local az_version=""

    if ! az &>/dev/null; then
        echo ""
        is_error=true
        echo "Error: Could not find azure-cli installed. Double check azure cli is installed. https://aka.ms/install-azure-cli" >&2
    fi

    if [[ "${is_error}" == "false" ]]; then
        az_version=$(az version --query '"azure-cli"' -o tsv)
    fi

    # K8s extensions will not install properly with this version of azure-cli. See:https://github.com/Azure/azure-cli/issues/18797
    if [[ "${az_version}" == "2.26.0" ]] || [[ "${az_version}" == "2.26.1" ]]; then
        echo ""
        is_error=true
        echo "Error: azure-cli version ${az_version} is currently installed. There is a known issue with ${az_version} installing connectedk8s extensions. Please downgrade to 2.25.0 https://aka.ms/install-azure-cli" >&2
    fi

    # check for azure subscription logged in
    if ! SUBSCRIPTION_ID=$(az account show --query id -o tsv) &>/dev/null; then
        echo ''
        is_error=true
        echo 'Error: no azure subscription is logged in. Please run "az login" before executing the script.' >&2
        echo 'Please ensure the correct subscription is set by running "az account set -s <subscription-name-or-guid>"' >&2
        exit 1
    fi

    # if subscription was found easily get the tenantId
    TENANT_ID=$(az account show -o tsv --query tenantId)

    if ! kubectl &>/dev/null; then
        echo ""
        is_error=true
        echo 'Error: kubectl is not installed. Please ensure kubectl is installed.' >&2
    fi

    if [[ "${is_error}" == "true" ]]; then
        echo 'Please see prequisites for more informaion: https://github.com/Accenture/azure-arc-playground-builder/blob/main/prerequisites.md#setup-a-wsl2-based-azure-developer-machine' >&2
        exit 1
    fi

    echo 'done.'
}

####################################################################
# Generates aks cluster name string
# Globals:
#   None
# Arguments:
#   location_name - name of the custom location
####################################################################
function get_aks_name() {
    local location_name=$1
    echo "aks-${location_name}"
}

####################################################################
# Prints the cleanup script for a user to execute afterwards.
# Globals:
#   CUSTOM_LOCATION_NAMES
#   LOCATIONS
#   RESOURCE_GROUPS
# Arguments:
#   None
####################################################################
function echo_cleanup() {
    local rg=''
    local aks_name=''
    local region=''

    echo "############################ CLEANUP SCRIPT #######################################"
    for ((i = 0; i < ${#CUSTOM_LOCATION_NAMES[@]}; i++)); do
        aks_name=$(get_aks_name ${CUSTOM_LOCATION_NAMES[$i]})
        region="${LOCATIONS[$i]}"
        rg="${RESOURCE_GROUPS[$region]}"

        echo az group delete --no-wait -y -n "MC_${rg}_${aks_name}_${region}"
        echo az group delete --no-wait -y -n $rg
        echo kubectx -d ${aks_name}-admin
    done
    echo "###################################################################################"
}

####################################################################
# Prints the flags that control which k8s clusters are configured
# Globals:
#   CUSTOM_LOCATION_NAMES
#   LOCATIONS
# Arguments:
#   None
####################################################################
function echo_flags() {
    local location_name=''
    local region=''
    local num=0

    echo '#################### PARAMETERS ####################'

    for ((i = 0; i < ${#CUSTOM_LOCATION_NAMES[@]}; i++)); do
        location_name="${CUSTOM_LOCATION_NAMES[$i]}"
        region="${LOCATIONS[$i]}"
        num=$((i + 1))

        echo "Custom AKS Location #${num} | Location Name: '${location_name}', Region: '${region}'"
    done

    echo '#################################################################################'
}

####################################################################
# Installs azure-cli extensions and registers providers
# Globals:
#   None
# Arguments:
#   None
####################################################################
function install_azure_cli_extensions() {
    echo -n 'Installing Azure CLI extensions...'

    if ! az extension add --upgrade --yes -n connectedk8s -o none --only-show-errors &>/dev/null; then
        echo 'Error: failed to install connectedk8s azure-cli extension' >&2
        exit 1
    fi

    if ! az extension add --upgrade --yes -n k8s-extension -o none --only-show-errors &>/dev/null; then
        echo 'Error: failed to install k8s-extension azure-cli extension' >&2
        exit 1
    fi

    if ! az extension add --upgrade --yes -n customlocation -o none --only-show-errors &>/dev/null; then
        echo 'Error: failed to install customlocation azure-cli extension' >&2
        exit 1
    fi

    if ! az extension add --upgrade --yes -n arcdata -o none --only-show-errors &>/dev/null; then
        echo 'Error: failed to install arcdata azure-cli extension' >&2
        exit 1
    fi

    # remove appservice-kube if it is installed
    if az extension show -n appservice-kube &>/dev/null; then
        echo -n 'removing appservice-kube...'
        if ! az extension remove -n appservice-kube -o none --only-show-errors &>/dev/null; then
            echo 'Error failed to remove appservice-kube extension' >&2
        fi
        echo -n 're-installing appservice-kube...'
    fi

    if ! az extension add --yes --source "https://aka.ms/appsvc/appservice_kube-latest-py2.py3-none-any.whl" -o none --only-show-errors &>/dev/null; then
        echo 'Error failed to install appservice-kube azure-cli extension' >&2
        exit 1
    fi
    echo 'done.'

    echo -n 'Registering Providers...'
    if ! az provider register --namespace Microsoft.ExtendedLocation --wait -o none --only-show-errors &>/dev/null; then
        echo 'Error failed to register Microsoft.ExtendedLocation' >&2
        exit 1
    fi

    if ! az provider register --namespace Microsoft.Web --wait -o none --only-show-errors &>/dev/null; then
        echo 'Error failed to register Microsoft.Web' >&2
        exit 1
    fi

    if ! az provider register --namespace Microsoft.KubernetesConfiguration --wait -o none --only-show-errors &>/dev/null; then
        echo 'Error failed to register Microsoft.KubernetesConfiguration' >&2
        exit 1
    fi

    echo "done."
}

####################################################################
# Waits for N seconds
# Globals:
#   None
# Arguments:
#   Number of seconds to wait
####################################################################
function go_to_sleep() {
    sleep $1 &
    process_id=$!
    wait $process_id
}

####################################################################
# Prints error message with reset message to stderr
# Globals:
#   None
# Arguments:
#   error message
####################################################################
function echo_reset_err() {
    echo $1 >&2
    echo 'Please reset and try executing this script again. If the issue persists, try running these steps manually.' >&2
}

####################################################################
# Prints resource id
# Globals:
#   LOG_RESOURCES
# Arguments:
#   resource_id
####################################################################
function log_resource_id() {
    local resource_id=$1

    if [[ "${LOG_RESOURCES}"=="true" ]]; then
        echo "${resource_id}"
    fi
}

####################################################################
# Generates random unique string
# Globals:
#   None
# Arguments:
#   None
####################################################################
function get_rand() {
    local rand="$(echo $RANDOM | tr '[0-9]' '[a-z]')" # unique suffix
    echo "${rand}"
}

####################################################################
# Create azure resource group, and print messages
# Globals:
#   None
# Arguments:
#   rg -  resource group name
#   region - region name
####################################################################
function create_rg() {
    local rg=$1
    local region=$2
    local rg_id=''

    echo -n "Creating Azure Resource Group ${rg} in ${region} region..."

    if ! rg_id=$(az group create -n $rg --location $region -o tsv --query id --only-show-errors) >/dev/null; then
        echo "Error: failed to create resource group ${rg}." >&2
        exit 1
    fi

    echo "done."

    log_resource_id $rg_id
}

####################################################################
# Create log analytics workspace in the specified resource group
# Globals:
#   LOG_ANALYTICS_WORKSPACE_IDS_ENC
#   LOG_ANALYTICS_KEYS_ENC
#   LOG_ANALYTICS_WORKSPACE_IDS
#   LOG_ANALYTICS_KEYS
# Arguments:
#   Resource Group Name
####################################################################
function create_log_analytics_workspace() {
    local rg=$1
    local name="${rg}-workspace"
    local workspace_resource_id=''

    echo -n "Creating Log Analytics Workspace..."

    if ! workspace_resource_id=$(az monitor log-analytics workspace create -g $rg --workspace-name $name -o tsv --query id --only-show-errors) >/dev/null; then
        echo
        echo 'Error: failed to create log analytics workspace.' >&2
        exit 1
    fi

    local workspace_id=$(az monitor log-analytics workspace show -g $rg --workspace-name $name --query customerId -o tsv)
    local key=$(az monitor log-analytics workspace get-shared-keys -g $rg --workspace-name $name --query primarySharedKey -o tsv)
    local key_enc_with_space=$(printf %s $key | base64)

    # add to global dictionaries for later use
    LOG_ANALYTICS_WORKSPACE_IDS[$rg]="${workspace_id}"
    LOG_ANALYTICS_WORKSPACE_IDS_ENC[$rg]=$(printf %s $workspace_id | base64)
    LOG_ANALYTICS_KEYS[$rg]="${key}"
    LOG_ANALYTICS_KEYS_ENC[$rg]=$(echo -n "${key_enc_with_space//[[:space:]]/}")

    echo "Creating Log Analytics Workspace...done."

    log_resource_id $workspace_resource_id
}

####################################################################
# Create Azure Arc Sql Managed Instance database
# Globals:
#   SQLMI_ARM_TEMPLATE
#   SQLMI_ARM_PARAMETERS
#   AZDATA_USERNAME
#   AZDATA_PASSWORD
#   ARC_DATA_NAMESPACE
#   SUBSCRIPTION_ID
#   MAX_WAIT_SECONDS
#   CONN_STRINGS
# Arguments:
#   rg
#   customName
#   rand
#   region
#   arc_dc_custom_location_id
####################################################################
function create_sql_mi(){
    local rg=$1
    local custom_location_name=$2
    local rand=$3
    local region=$4
    local arc_custom_location_id=$5

    local arc_dc_name="arc-dc-${custom_location_name}"
    local sqlmi_deployment="sqlmi-${custom_location_name}"
    local sqlmi_server_name="sql${rand}"
    local sqlmi_primary_endpoint=''
    local sqlmi_id=''

    # Create arc sql server managed isntance
    echo -n 'Deploying Arc SQL Managed Instance in direct mode (this may take a few minutes)...'
    az group deployment create \
        -n $sqlmi_deployment \
        -g $rg \
        -o none \
        --only-show-errors \
        --template-file "${SQLMI_ARM_TEMPLATE}" \
        --parameters "@${SQLMI_ARM_PARAMETERS}" \
        --parameters \
        dataControllerId="${arc_dc_name}" \
        customLocation="${arc_custom_location_id}" \
        location="${region}" \
        admin="${AZDATA_USERNAME}" \
        password="${AZDATA_PASSWORD}" \
        namespace="${ARC_DATA_NAMESPACE}" \
        subscription="${SUBSCRIPTION_ID}" \
        resourceGroup="${rg}" \
        resourceName="${sqlmi_server_name}"

    echo 'Deploying Arc SQL Managed Instance in direct mode (this may take a few minutes)...done.'

    echo -n 'Waiting for SQL Managed Instance to be in ready state...'

    sqlmi_id=$(az resource show -o tsv -g $rg -n $sqlmi_server_name --resource-type microsoft.azurearcdata/sqlmanagedinstances --api-version 2021-07-01-preview --query id --only-show-errors) >/dev/null

    if ! az resource wait -o none --only-show-errors --timeout $MAX_WAIT_SECONDS --ids $sqlmi_id --resource-type 'microsoft.azurearcdata/sqlmanagedinstances' --custom "properties.k8sRaw.status.state=='Ready'" --api-version 2021-07-01-preview >/dev/null; then
        echo_reset_err 'Error: failed to wait for sql managed instance to finish creating on AKS cluster'
        exit 1
    fi
    echo 'Waiting for SQL Managed Instance to be in ready state...done.'

    sqlmi_primary_endpoint=$(az resource show -o tsv -g $rg -n $sqlmi_server_name --resource-type microsoft.azurearcdata/sqlmanagedinstances --query properties.k8sRaw.status.primaryEndpoint --only-show-errors --api-version 2021-07-01-preview) >/dev/null

    if [[ -z "${sqlmi_primary_endpoint}" ]] || [[ -z "${sqlmi_id}" ]]; then
        echo_reset_err 'Error: failed to create sql managed instance on AKS cluster'
        exit 1
    fi
    log_resource_id ${sqlmi_id}
    echo "SQL Managed Instance External Endpoint: ${sqlmi_primary_endpoint}"

    # set the SQL MI connection string using K8s DNS, <service>.<namespace>
    CONN_STRINGS[$rg]="Data Source=${sqlmi_server_name}-external-svc.${ARC_DATA_NAMESPACE};Database=Todo;User Id=${AZDATA_USERNAME};Password=${AZDATA_PASSWORD};Encrypt=true;TrustServerCertificate=true"
}

####################################################################
# Create Azure Arc PostgreSQL Hyperscale database
# Globals:
#   PGSQL_ARM_TEMPLATE
#   PGSQL_ARM_PARAMETERS
#   AZDATA_USERNAME
#   AZDATA_PASSWORD
#   ARC_DATA_NAMESPACE
#   PGSQL_EV
#   SUBSCRIPTION_ID
#   MAX_WAIT_SECONDS
#   CONN_STRINGS
# Arguments:
#   rg
#   customName
#   rand
#   region
#   arc_custom_location_id
#   arc_dc_id
####################################################################
function create_pgsql(){
    local rg=$1
    local custom_location_name=$2
    local rand=$3
    local region=$4
    local arc_custom_location_id=$5
    local arc_dc_id=$6

    local pgsql_deployment="pgsql-${custom_location_name}"
    local pgsql_server_name="psql${rand}"
    local pgsql_primary_endpoint=''
    local pgsql_id=''

    # Create postgresql hyperscale server 
    echo -n 'Creating ARM template deployment for Azure Arc PostgreSQL Hyperscale in direct mode (this may take a few minutes)...'
    az group deployment create \
        -n $pgsql_deployment \
        -g $rg \
        -o none \
        --only-show-errors \
        --template-file "${PGSQL_ARM_TEMPLATE}" \
        --parameters "@${PGSQL_ARM_PARAMETERS}" \
        --parameters \
            dataControllerId="${arc_dc_id}" \
            customLocation="${arc_custom_location_id}" \
            location="${region}" \
            password="${AZDATA_PASSWORD}" \
            namespace="${ARC_DATA_NAMESPACE}" \
            postgresEngineVersion="${PGSQL_EV}" \
            subscription="${SUBSCRIPTION_ID}" \
            resourceGroup="${rg}" \
            resourceName="${pgsql_server_name}"
    
    pgsql_id=$(az resource show -o tsv -g $rg -n $pgsql_server_name --resource-type microsoft.azurearcdata/postgresinstances --query id --only-show-errors) >/dev/null

    echo -n 'Waiting for PostgreSQL to be in ready state...'
    if ! az resource wait -o none --only-show-errors --timeout $MAX_WAIT_SECONDS --ids $pgsql_id --resource-type 'microsoft.azurearcdata/postgresinstances' --custom "properties.k8sRaw.status.state=='Ready'" >/dev/null; then
        echo_reset_err 'Error: failed to wait for hyperscale postgresql server to finish creating on AKS cluster'
        exit 1
    fi
    echo 'Waiting for PostgreSQL to be in ready state...done.'

    pgsql_primary_endpoint=$(az resource show -o tsv -g $rg -n $pgsql_server_name --resource-type microsoft.azurearcdata/postgresinstances --query properties.k8sRaw.status.primaryEndpoint --only-show-errors) >/dev/null

    if [[ -z "${pgsql_primary_endpoint}" ]] || [[ -z "${pgsql_id}" ]]; then
        echo_reset_err 'Error: failed to create hyperscale postgresql server on AKS cluster'
        exit 1
    fi
    echo 'Creating ARM template deployment for Azure Arc PostgreSQL Hyperscale in direct mode (this may take a few minutes)...done'
    log_resource_id ${pgsql_id}
    echo "PostgreSQL External Endpoint: ${pgsql_primary_endpoint}"
    
    # set the PostgreSQL connection string using K8s DNS, <service>.<namespace>
    CONN_STRINGS[$rg]="Host=${pgsql_server_name}-external-svc.${ARC_DATA_NAMESPACE};Port=5432;Database=postgres;Username=postgres;Password=${AZDATA_PASSWORD};SslMode=Disable"
}

####################################################################
# Creates azure-arc, appservice ext aks cluster
# Globals:
#   NAMESPACE
#   WEBAPP_PATH
#   MAX_WAIT_SECONDS
# Arguments:
#   rg
#   customName
#   rand
#   region
####################################################################
function create_arc_aks_appservice() {
    local rg=$1
    local custom_location_name=$2
    local rand=$3
    local region=$4

    local rg_id=$(az group show -n $rg -o tsv --query id --only-show-errors)
    local cluster_name="aks-${custom_location_name}"
    local aks_ext_name="aks-appservice-ext"
    local app_service_kube_env_name="k8se-${custom_location_name}"
    local app_service_plan_name="appplan-${custom_location_name}"
    local app_service_name="hello-world-${cluster_name}"
    local public_ip_name="public-ip-${custom_location_name}"
    local public_ip_resource_id=''
    local arc_ext_id=''
    local arc_custom_location_name="${custom_location_name}-${ARC_DATA_NAMESPACE}"
    local arc_custom_location_id=''
    local arc_dc_deployment="datacontroller-${custom_location_name}"
    local arc_dc_name="arc-dc-${custom_location_name}"
    local arc_dc_id=''
    local infra_rg=''
    local static_ip=''
    local connected_cluster_id=''
    local aks_extension_id=''
    local custom_location_id=''
    local host=''
    local url=''
    local aks_resource_id=''

    echo -n "Creating Azure multitenant AKS cluster in resource group ${rg} (this will take a few minutes)..."

    if ! aks_resource_id=$(az aks create -g $rg -n $cluster_name -c $AKS_NODE_COUNT -s $AKS_NODE_SIZE --enable-aad --generate-ssh-keys -o tsv --query id --only-show-errors) >/dev/null; then
        echo_reset_err "Error: Failed to create AKS cluster ${cluster_name}"
        exit 1
    fi

    if ! infra_rg=$(az aks show -g $rg -n $cluster_name -o tsv --query nodeResourceGroup --only-show-errors) >/dev/null || [[ -z "${infra_rg}" ]]; then
        echo_reset_err "Error: Failed to create AKS cluster ${cluster_name}"
        exit 1
    fi

    echo "Creating Azure multitenant AKS cluster in resource group ${rg} (this will take a few minutes)...done."

    log_resource_id ${aks_resource_id}

    echo -n "Creating Azure Public IP Address..."

    if ! public_ip_resource_id=$(az network public-ip create -g $infra_rg -n $public_ip_name --sku STANDARD -o json --query publicIp.id --only-show-errors) >/dev/null; then
        echo_reset_err "Error: Failed to create public ip ${public_ip_name}"
        exit 1
    fi

    if ! static_ip=$(az network public-ip show -g $infra_rg -n $public_ip_name -o tsv --query ipAddress --only-show-errors) >/dev/null || [[ -z "${static_ip}" ]]; then
        echo_reset_err "Error: Failed to create public ip ${public_ip_name}"
        exit 1
    fi

    echo "${static_ip}...done."

    log_resource_id $public_ip_resource_id

    echo -n 'Connecting to AKS cluster...'

    if ! az aks get-credentials -g $rg -n $cluster_name --admin --overwrite-existing -o none --only-show-errors >/dev/null; then
        echo_reset_err 'Error: Failed to connect to AKS cluster.'
        exit 1
    fi

    echo "done."

    kubectl get ns

    echo '##################################################################################################################################################################'
    echo '[Optional] Run these commands in separate terminals to watch the Arc and App Service K8s objects come up'
    echo 'watch -n 5 kubectl get pods -n azure-arc'
    echo 'watch -n 5 kubectl get svc,pods -n appservice-ns'
    echo 'watch -n 5 kubectl get svc,pods -n arcdata'
    echo '##################################################################################################################################################################'

    echo -n "Connecting AKS cluster to Azure Arc (this may take a few minutes)..."

    if ! az connectedk8s connect -g $rg -n $cluster_name -o none --only-show-errors >/dev/null; then
        echo_reset_err 'Error: failed to install Azure Arc on AKS cluster'
        exit 1
    fi

    connected_cluster_id=$(az connectedk8s show -g $rg -n $cluster_name -o tsv --query id --only-show-errors) >/dev/null

    echo "Connecting AKS cluster to Azure Arc (this may take a few minutes)...done."

    # deploy the arc data k8s extension
    echo -n "Installing Arc Data Services extension in namespace: ${ARC_DATA_NAMESPACE}..."

    arc_ext_id=$(az k8s-extension create \
        -c $cluster_name \
        -g $rg \
        --name "arcdataservices" \
        --cluster-type "connectedClusters" \
        --extension-type "microsoft.arcdataservices" \
        --scope "cluster" \
        --auto-upgrade false \
        --release-namespace $ARC_DATA_NAMESPACE \
        --config "Microsoft.CustomLocation.ServiceAccount=sa-bootstrapper" \
        -o tsv \
        --query id \
        --only-show-errors)

    if [[ -z "${arc_ext_id}" ]]; then
        echo_reset_err 'Error: failed to install Azure Arc Data Services extension on AKS cluster'
        exit 1
    fi

    # wait for the arc data service extensions to finish installing
    if ! az resource wait --ids $arc_ext_id --custom "properties.installState!='Pending'" --api-version "2020-07-01-preview" --timeout $MAX_WAIT_SECONDS -o none --only-show-errors >/dev/null; then
        echo_reset_err 'Error: failed to install Azure Arc Data Services extension on AKS cluster'
        exit 1
    fi

    echo "Installing Arc Data Services extension in namespace: ${ARC_DATA_NAMESPACE}...done."

    log_resource_id $arc_ext_id

    echo -n "Creating arc data custom location ${arc_custom_location_name}..."

    if ! arc_custom_location_id=$(az customlocation create -g $rg -n $arc_custom_location_name --host-resource-id $connected_cluster_id --namespace $ARC_DATA_NAMESPACE --cluster-extension-ids $arc_ext_id -o tsv --query id --only-show-errors) >/dev/null; then
        echo_reset_err "Error: failed to create arc data custom location ${custom_location_name}"
        exit 1
    fi

    echo "Creating arc data custom location ${arc_custom_location_name}...done."

    log_resource_id $arc_custom_location_id

    echo -n 'Waiting for arc data custom location to be in ready state...'
    if ! az resource wait -o none --only-show-errors --timeout $MAX_WAIT_SECONDS --resource-type 'microsoft.extendedlocation/customlocations' --ids $arc_custom_location_id --custom "properties.provisioningState=='Succeeded'" >/dev/null; then
        echo_reset_err 'Error: failed to wait for arc data custom location to finish creating on AKS cluster'
        exit 1
    fi
    echo 'Waiting for arc data custom location to be in ready state...done'

    # Add Contributor and Monitor Metrics Publisher roles to sp scoped to the resource group
    echo -n "Adding role assignments Contributor & MonitoringMetricsPublisher to sp scoped to resource group ${rg}..."
    if ! az role assignment create --assignee $SP_CLIENT_ID --role 'Contributor' --scope $rg_id -o none --only-show-errors >/dev/null; then
        echo_reset_err "Error: failed to add Contributor role to resource group ${rg}"
        exit 1
    fi

    if ! az role assignment create --assignee $SP_CLIENT_ID --role 'Monitoring Metrics Publisher' --scope $rg_id --only-show-errors >/dev/null; then
        echo_reset_err "Error: failed to add Monitoring Metrics Publisher role to resource group ${rg}"
        exit 1
    fi
    echo "done."

    echo -n 'Deploying ARM template for Azure Data Controller in Directly Connected Mode (this may take a few minutes)...'
    az group deployment create \
        -n $arc_dc_deployment \
        -g $rg \
        -o none \
        --only-show-errors \
        --template-file "${ARCDC_ARM_TEMPLATE}" \
        --parameters "@${ARCDC_ARM_PARAMETERS}" \
        --parameters \
        namespace="${ARC_DATA_NAMESPACE}" \
        controllerName="${arc_dc_name}" \
        administratorLogin="${AZDATA_USERNAME}" \
        administratorPassword="${AZDATA_PASSWORD}" \
        customLocation="${arc_custom_location_id}" \
        uspClientId="${SP_CLIENT_ID}" \
        uspTenantId="${TENANT_ID}" \
        uspClientSecret="${SP_SECRET}" \
        logAnalyticsWorkspaceId="${LOG_ANALYTICS_WORKSPACE_IDS[$rg]}" \
        logAnalyticsPrimaryKey="${LOG_ANALYTICS_KEYS[$rg]}" \
        subscription="${SUBSCRIPTION_ID}" \
        resourceGroup="${rg}" \
        location="${region}" \
        resourceName="${arc_dc_name}"

    arc_dc_id=$(az resource show -g $rg -n $arc_dc_name --resource-type 'microsoft.azurearcdata/datacontrollers' --query id -o tsv --only-show-errors)

    if [[ -z "${arc_dc_id}" ]]; then
        echo_reset_err "Error: failed to create Azure Arc Data Controller ${arc_dc_name} on AKS cluster"
        exit 1
    fi
    echo 'Deploying ARM template for Azure Data Controller in Directly Connected Mode (this may take a few minutes)...done.'

    log_resource_id ${arc_dc_id}

    echo -n 'Waiting for Azure Arc Data Controller to be in ready state...'
    if ! az resource wait -o none --only-show-errors --timeout $MAX_WAIT_SECONDS --resource-type 'microsoft.azurearcdata/datacontrollers' --ids $arc_dc_id --custom "properties.k8sRaw.status.state=='Ready'" >/dev/null; then
        echo_reset_err 'Error: failed to wait for Azure Arc Data Controller to finish creating on AKS cluster'
        exit 1
    fi

    # wait for the logsdb-0 pod to be Ready, sqlmi install will fail ContainerConfigError if logsdb is not up
    local podwait=0
    while [[ $(kubectl get pods/logsdb-0 -n ${ARC_DATA_NAMESPACE} -o 'jsonpath={.status.phase}') != "Running" ]] && [[ $podwait -lt $MAX_WAIT_SECONDS ]]; do
        echo -ne "Waiting for pods/logdb-0...${podwait} seconds"\\r
        go_to_sleep $SERVICE_POLL_SECONDS
        podwait=$((podwait + $SERVICE_POLL_SECONDS))
    done

    if [[ $(kubectl get pods/logsdb-0 -n arcdata -o 'jsonpath={.status.phase}') != "Running" ]]; then
        echo_reset_err "Error: max time (${MAX_SERVICE_WAIT_SECONDS}) seconds elapsed waiting for data controller logsdb pod to be Running."
        exit 1
    fi

    echo 'Waiting for Azure Arc Data Controller to be in ready state...done.'

    # create the database based on the flag passed in
    if [[ "${ARC_SQL_DB_TYPE_FLAG}" == 'sqlmi' ]]; then
        if ! create_sql_mi $rg $custom_location_name $rand $region $arc_custom_location_id; then
            exit 1
        fi
    else
        if ! create_pgsql $rg $custom_location_name $rand $region $arc_custom_location_id $arc_dc_id; then
            exit 1
        fi
    fi

    # install app service extension on AKS, and create app service
    echo -n "Installing app service extensions in AKS cluster (this will take a few minutes)..."
    local workspace_id_enc="${LOG_ANALYTICS_WORKSPACE_IDS_ENC[$rg]}"
    local key_enc="${LOG_ANALYTICS_KEYS_ENC[$rg]}"

    aks_extension_id=$(az k8s-extension create \
        -g $rg \
        -n $aks_ext_name \
        --cluster-type connectedClusters \
        --cluster-name $cluster_name \
        --extension-type 'Microsoft.Web.Appservice' \
        --release-train stable \
        --auto-upgrade-minor-version true \
        --scope cluster \
        --release-namespace $NAMESPACE \
        --configuration-settings "Microsoft.CustomLocation.ServiceAccount=default" \
        --configuration-settings "appsNamespace=${NAMESPACE}" \
        --configuration-settings "clusterName=${cluster_name}" \
        --configuration-settings "loadBalancerIp=${static_ip}" \
        --configuration-settings "keda.enabled=true" \
        --configuration-settings "buildService.storageClassName=default" \
        --configuration-settings "buildService.storageAccessMode=ReadWriteOnce" \
        --configuration-settings "customConfigMap=${NAMESPACE}/kube-environment-config" \
        --configuration-settings "envoy.annotations.service.beta.kubernetes.io/azure-load-balancer-resource-group=${rg}" \
        --configuration-settings "logProcessor.appLogs.destination=log-analytics" \
        --configuration-protected-settings "logProcessor.appLogs.logAnalyticsConfig.customerId=${workspace_id_enc}" \
        --configuration-protected-settings "logProcessor.appLogs.logAnalyticsConfig.sharedKey=${key_enc}" \
        -o tsv \
        --query id \
        --only-show-errors)

    if [[ -z "${aks_extension_id}" ]]; then
        echo_reset_err 'Error: failed to install App Service extensions on AKS cluster'
        exit 1
    fi

    # wait for the app service extensions to finish installing
    if ! az resource wait --ids $aks_extension_id --custom "properties.installState!='Pending'" --api-version "2020-07-01-preview" --timeout $MAX_WAIT_SECONDS -o none --only-show-errors >/dev/null; then
        echo_reset_err 'Error: failed to install App Service extensions on AKS cluster'
        exit 1
    fi

    echo 'Installing app service extensions in AKS cluster (this will take a few minutes)...done'

    log_resource_id $aks_extension_id

    echo -n "Creating app service custom location ${custom_location_name}..."

    if ! custom_location_id=$(az customlocation create -g $rg -n $custom_location_name --host-resource-id $connected_cluster_id --namespace $NAMESPACE --cluster-extension-ids $aks_extension_id -o tsv --query id --only-show-errors) >/dev/null; then
        echo_reset_err "Error: failed to create custom location ${custom_location_name}"
        exit 1
    fi

    echo "Creating app service custom location ${custom_location_name}...done."

    log_resource_id $custom_location_id

    echo -n "Creating App Service K8s Environment in ${custom_location_name} (this may take a few minutes)..."

    if ! k8se_id=$(az appservice kube create -g $rg -n $app_service_kube_env_name --custom-location $custom_location_id --static-ip $static_ip -o tsv --query id --only-show-errors) >/dev/null; then
        echo_reset_err "Error: failed to create App Service K8s Envrionment ${app_service_kube_env_name}"
        exit 1
    fi

    if ! az resource wait -g $rg --ids $k8se_id --api-version '2021-01-15' --resource-type 'microsoft.web/kubeenvironments' --custom "properties.provisioningState=='Succeeded'" >/dev/null; then
        echo_reset_err 'Error: failed to create K8se'
        exit 1
    fi

    # wait for the kubernenetes env to be linked with the custom location
    if ! az resource wait -g $rg --ids $k8se_id --api-version '2021-01-15' --resource-type 'microsoft.web/kubeenvironments' --custom "properties.extendedLocation.customLocation=='${custom_location_id}'" >/dev/null; then
        echo_reset_err 'Error: failed to create K8se'
        exit 1
    fi

    echo "Creating App Service K8s Environment in ${custom_location_name} (this may take a few minutes)...done."

    log_resource_id $k8se_id

    echo -n "Creating App Service Plan ${app_service_plan_name} in ${custom_location_name}..."

    if ! app_service_plan_id=$(az appservice plan create -g $rg -n $app_service_plan_name --custom-location $custom_location_id --per-site-scaling --is-linux --sku K1 -o tsv --query id --only-show-errors) >/dev/null; then
        echo_reset_err "Error: failed to create App Service Plan ${app_service_plan_name}"
        exit 1
    fi

    echo "Creating App Service Plan ${app_service_plan_name} in ${custom_location_name}...done."

    log_resource_id $app_service_plan_id

    echo -n "Creating App Service ${app_service_name} in ${custom_location_name}..."

    if ! app_service_id=$(az webapp create --plan $app_service_plan_name -g $rg -n $app_service_name --custom-location $custom_location_id --runtime "DOTNET|5.0" -o tsv --query id --only-show-errors) >/dev/null; then
        echo_reset_err "Error: failed to create App Service ${app_service_name}"
        exit 1
    fi

    echo "Creating App Service ${app_service_name} in ${custom_location_name}...done."

    log_resource_id $app_service_id

    local appservice_sql_key="${APPSERVICE_SQLMI_CONN_STR_KEY}"
    if [[ "${ARC_SQL_DB_TYPE_FLAG}" == 'pgsql' ]]; then
        appservice_sql_key="${APPSERVICE_PGSQL_CONN_STR_KEY}"
    fi

    echo -n "Adding ${ARC_SQL_DB_TYPE_FLAG} connection string to app service config..."

    if ! az webapp config appsettings set -g $rg -n $app_service_name --settings $appservice_sql_key="${CONN_STRINGS[$rg]}" ASPNETCORE_ENVIRONMENT="Development" >/dev/null; then
        echo_reset_err "Error: failed to configure ${ARC_SQL_DB_TYPE_FLAG} connection string in App Service ${app_service_name}"
        exit 1
    fi

    echo 'done.'

    echo -n "Deploying Hello World web app to ${app_service_name} in ${custom_location_name}..."
    if ! az webapp deployment source config-zip -g $rg -n $app_service_name --src $WEBAPP_PATH -o none --only-show-errors >/dev/null; then
        echo_reset_err "Error: failed to deploy Hello World to to ${app_service_name} in custom location ${custom_location_name}"
        exit 1
    fi
    echo "done."

    host=$(az webapp show -n $app_service_name -g $rg -o tsv --query defaultHostName --only-show-errors) &>/dev/null
    url="https://${host}"
    echo "Hello World is now deployed in ${custom_location_name}."
    echo "${url}"
}

##############################################################
# Print the usage message to the terminal
# Globals:
#   HELP_FLAG
# Arguments:
#   None
##############################################################
function print_usage(){
    HELP_FLAG=true
    echo '''
Usage
    ./deploy-arc-aks.sh [arguments] : Creates an Arc connected AKS cluster(s).
                                         Creates Arc App Service.
                                         Creates Arc Sql (PostgreSQL or SQL Managed Instance).
                                         Deploys Hello World to Arc App Service.

Arguments
  --location -l               [Required] : The azure region to deploy all resources.
                                           Allowed values: eastus, westeurope.
                                           You may set the environment array variable LOCATIONS if you wish to create multiple instances.
                                           This location argument takes precendence over declared environment array variable.
                                           Do not pass this argument if setting environment variables.
  --custom-location-name -n   [Required] : The logical location name to describe the AKS cluster.
                                           You may set the environment array variable CUSTOM_LOCATION_NAMES if you wish to create multiple instances.
                                           This custom location name argument takes precendence over declared environment array variable.
                                           Do not pass this argument if setting environment variables.
  --arc-sql-db-type           [Required] : The type of Azure Arc database backend.
                                           Default is "sqlmi". Allowed values: pgsql, sqlmi.
  --spn-id                    [Required] : Service principal client id.
  --spn-secret                [Required] : Service principal client secret.
                                           This command may be used to regenerate sp password. Output must be protected. 
                                           $(az ad sp credential reset -n $SERVICE_PRINCIPAL_ID -o tsv --query password)
  --sql-username              [Required] : Sql admin username.
  --sql-password              [Required] : Sql admin password.
                                           Password must be 8-128 characters long. 
                                           Your password must contain characters from three of the following categories 
                                               – English uppercase letters
                                               - English lowercase letters, numbers (0-9)
                                               - Non-alphanumeric characters (!, $, #, %, etc.).
  --help -h                              : Print the script usage message.

Examples
    Create an Azure WebApp & Arc Postgres Hyperscale on Arc-connected AKS cluster registered to eastus region
    ./deploy-arc-aks.sh --location eastus \
        --custom-location-name demo-site-virginia \
        --spn-id $SERVICE_PRINCIPAL_ID \
        --spn-secret $SERVICE_PRINCIPAL_SECRET \
        --sql-username demoadmin \
        --sql-password $SQL_PASSWORD \
        --arc-sql-db-type pgsql

    Create an Azure WebApp & Arc Sql Mnaged Instance on Arc-connected AKS clusters in eastus and westeurope regions
    CUSTOM_LOCATION_NAMES=( "demo-site-virgina" "demo-site-netherlands" )
    LOCATIONS=( "eastus" "westeurope" )

    ./deploy-arc-aks.sh \
        --spn-id $SERVICE_PRINCIPAL_ID \
        --spn-secret $SERVICE_PRINCIPAL_SECRET \
        --sql-username demoadmin \
        --sql-password $SQL_PASSWORD \
        --arc-sql-db-type misql
'''
}

##############################################################
# Validate and setup LOCATIONS & CUSTOM_LOCATION_NAMES arguments
# Globals:
#   LOCATIONS
#   LOCATION_FLAG
#   CUSTOM_LOCATION_NAME_FLAG
#   CUSTOM_LOCATION_NAMES
# Arguments:
#   None
##############################################################
function check_inputs(){
    # location and custom-location-name flags take precedence over the array env vars
    if [[ -n "${LOCATION_FLAG}" ]]; then

        if [[ -n "${CUSTOM_LOCATION_NAME_FLAG}" ]]; then
            # both were passed
            LOCATIONS=("${LOCATION_FLAG}")
            CUSTOM_LOCATION_NAMES=("${CUSTOM_LOCATION_NAME_FLAG}")
        else
            # invalid, need to pass a custom location
            echo_reset_err 'Invalid arguments. --custom-location-name is required if --location -l is passed.'
            print_usage
            exit 1
        fi
    elif [[ -z "${LOCATION_FLAG}" && -z "${CUSTOM_LOCATION_NAME_FLAG}" ]]; then
        # check env arrays
        if [[ ${#LOCATIONS[@]} -le 0 ]]; then
            echo_reset_err 'Invalid arguments. --location is not passed and LOCATIONS array environment variable is empty.'
            print_usage
            exit 1
        fi

        if [[ ${#CUSTOM_LOCATION_NAMES[@]} -le 0 ]]; then
            echo_reset_err 'Invalid arguments. --custom-location-name is not passed and CUSTOM_LOCATION_NAMES array environment variable is empty.'
            print_usage
            exit 1
        fi

        if [[ ${#CUSTOM_LOCATION_NAMES[@]} -ne ${#LOCATIONS[@]} ]]; then
            echo_reset_err "Invalid arguments. LOCATIONS contains ${#LOCATIONS[@]} elements. CUSTOM_LOCATION_NAMES contains ${#CUSTOM_LOCATION_NAMES[@]} elements. Both array environment variables should contain the same number of arguments."
            print_usage
            exit 1
        fi
        # both arrays are valid
    else
        echo_reset_err "Invalid --location -l argument."
        print_usage
        exit 1
    fi

}

# BEGIN EXECUTION
PARSED_OPTIONS=$(getopt -a -n deploy-arc-aks.sh -o l:hn: --long location:,help,custom-location-name:,arc-sql-db-type:,spn-id:,spn-secret:,sql-username:,sql-password: -- "$@")

VALID_ARGUMENTS=$?
if [ "$VALID_ARGUMENTS" != "0" ]; then
    usage
fi

eval set -- "$PARSED_OPTIONS"
while :; do
    case "$1" in
    -l | --location)
        LOCATION_FLAG="$2"
        shift 2
        ;;
    -n | --custom-location-name)
        CUSTOM_LOCATION_NAME_FLAG="$2"
        shift 2
        ;;
    -h | --help)
        print_usage
        shift
        ;;
    --arc-sql-db-type)
        ARC_SQL_DB_TYPE_FLAG="$2"
        shift 2
        ;;
    --spn-id)
        SP_CLIENT_ID="$2"
        shift 2
        ;;
    --spn-secret)
        SP_SECRET="$2"
        shift 2
        ;;
    --sql-username)
        export AZDATA_USERNAME="$2"
        shift 2
        ;;
    --sql-password)
        SQL_ADMIN_PW="$2"
        shift 2
        ;;
    # -- means the end of the arguments; drop this, and break out of the while loop
    --)
        shift
        break
        ;;
    # If invalid options were passed, then getopt should have reported an error,
    # which we checked as VALID_ARGUMENTS when getopt was called...
    *)
        echo "Unexpected option: $1 - this should not happen."
        print_usage
        break
        ;;
    esac
done

if [[ "${HELP_FLAG}" == 'true' ]]; then
    exit 0
fi

export AZDATA_PASSWORD="${SQL_ADMIN_PW}"

if [[ "${ARC_SQL_DB_TYPE_FLAG}" == "pgsql" ]]; then
    # DS2 is sufficient for pgsql, sqlmi requires at least DS3
    AKS_NODE_SIZE='Standard_DS2_v2'
fi

# check locations and custom-location-name
if ! check_inputs; then
    exit 1
fi

# Ensure pre-reqs are installed
if ! check_prereqs; then
    exit 1
fi

# Print the control flow flags
echo_flags

# Add Azure CLI Extensions
if ! install_azure_cli_extensions; then
    exit 1
fi

# loop through the LOCATIONS array and get the distinct regions, add RG names for each distinct azureRegion
for r in "${LOCATIONS[@]}"; do
    if [ ! -v RESOURCE_GROUPS[$r] ]; then
        RESOURCE_GROUPS[$r]=$(get_rand)
    fi
done

# Print the cleanup script
echo_cleanup

# Create resource group(s)
for r in "${!RESOURCE_GROUPS[@]}"; do
    if ! create_rg ${RESOURCE_GROUPS[$r]} $r; then
        exit 1
    fi
done

# Create log analytics
for r in "${!RESOURCE_GROUPS[@]}"; do
    if ! create_log_analytics_workspace ${RESOURCE_GROUPS[$r]}; then
        exit 1
    fi
done

# foreach custom location, create an AKS Arc connected K8s
for ((i = 0; i < ${#CUSTOM_LOCATION_NAMES[@]}; i++)); do

    region="${LOCATIONS[$i]}"
    rg_name="${RESOURCE_GROUPS[$region]}"
    location_name="${CUSTOM_LOCATION_NAMES[$i]}"
    random_string=$(get_rand)

    if ! create_arc_aks_appservice $rg_name $location_name $random_string $region; then
        exit 1
    fi
done

unset $RESOURCE_GROUPS
unset $LOG_ANALYTICS_KEYS_ENC
unset $LOG_ANALYTICS_WORKSPACE_IDS_ENC
unset $LOG_ANALYTICS_KEYS
unset $LOG_ANALYTICS_WORKSPACE_IDS
unset $CONN_STRINGS

echo 'end.'

exit 0