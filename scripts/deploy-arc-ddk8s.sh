# !/bin/bash

# Connect Existing Docker Desktop Single Node K8s to Azure Arc and Deploy Hello World on Local App Service

# FLAGS
# Alter these values to control how resources are deployed
LOCAL_HOST_NAME='' 
REGION=''
CREATE_ARC_DATA_SERVICES=false
HELP_FLAG=false
KUBECTX_FLAG='docker-desktop'

# These must be provided if choosing to deploy arc data services
PGSQL_ADMIN_PW='' # must be 8-128 characters long. Cannot contain 'citus'. Your password must contain characters from three of the following categories – English uppercase letters, English lowercase letters, numbers (0-9), and non-alphanumeric characters (!, $, #, %, etc.).
export AZDATA_USERNAME=''
SP_CLIENT_ID=''
SP_SECRET='' # Use this command if pw needs to be regenerated - $(az ad sp credential reset -n $SP_CLIENT_ID -o tsv --query password)

# CONSTANT SETUP
# Only change these if you know what you're doing
SERVICE_POLL_SECONDS=10 # Check every 10s for the envoy service to be created in the cluster
MAX_WAIT_SECONDS=1200   # Wait up to 20 minutes for the envoy service to be created in the cluster
LOG_RESOURCES=true
RAND="$(echo $RANDOM | tr '[0-9]' '[a-z]')" # Unique suffix
RESOURCE_GROUP="${RAND}"
WORKSPACE_NAME="${RAND}-workspace"
LOCAL_HOST_PUBLIC_IP=$(dig +short myip.opendns.com @resolver1.opendns.com) # ISP WAN IPv4 address for the local network - see http://whatismyip.com.

## Docker Desktop Kubernetes
CLUSTER_NAME=''
SUBSCRIPTION_ID=''
TENANT_ID=''
WORKSPACE_ID=''
WORKSPACE_ID_ENC=''
LOG_ANALYTICS_KEY=''
LOG_ANALYTICS_KEY_ENC_SPACE=''
LOG_ANALYTICS_KEY_ENC=''
CONNECTED_CLUSTER_ID=''
APPSERVICE_EXTENSION_ID=''
CUSTOM_LOCATION_ID=''
HOST=''
URL=''
LOCAL_STORAGE_YAML='data/local-storage.yml'

## Arc Data Controller
ARCDC_ARM_TEMPLATE='data/datacontroller.template.json'
ARCDC_ARM_PARAMETERS='data/datacontroller.ddk8s.parameters.json'
PGSQL_ARM_TEMPLATE='data/postgres-arc/psqlarc.template.json'
PGSQL_ARM_PARAMETERS='data/postgres-arc/psqlarc.parameters.json'
APPSERVICE_PGSQL_CONN_STR_KEY='ConnectionStrings__Npgsql' # Postgres Connection string name, Hello World webapp looks for this during startup
export AZDATA_PASSWORD="${PGSQL_ADMIN_PW}"
ARC_DATA_NAMESPACE='arcdata'
PGSQL_EV='12'       #or 11
PGSQL_ARC_WORKERS=0 # FOR DEMO ONLY USE CITUS NODE

## Arc PostgreSQL

## Arc App Service
NAMESPACE='appservice-ns'                                     # Namespace in the cluster to install the extension and provision resources, don't change this
WEBAPP_PATH='../artifacts/HelloWorld-sql.zip'                 # Relative path to compiled webapp bits
VOLUME_YAML_PATH='appservice-extensions/pv.yml'               # Relative path to a persistent volume yaml
VOLUME_CLAIM_YAML_PATH='appservice-extensions/pvc-ddk8s.yml'  # Relative path to persistent volume claim yaml
ENVOY_SVC_YAML_PATH='appservice-extensions/envoy-service.yml' # Relative path to envoy service yaml
SAVE_ENVOY_YAML=false                                         # Save the edited envoy service yaml file locally
APPSERVICE_EXTENSION_NAME="ddk8s-appservice-ext"
APPSERVICE_NAME=''
CUSTOM_LOCATION_NAME=''
APPSERVICE_KUBE_ENV_NAME=''
APPSERVICE_PLAN_NAME=''

# FUNCTION DECLARATIONS
#######################################
# Ensure dependencies are installed.
# Globals:
#   None
# Arguments:
#   None
#######################################
function check_prereqs() {
    local is_error=false
    local az_version=''

    echo -n 'Checking prerequisites are installed...'

    if ! az &>/dev/null; then
        echo ""
        is_error=true
        echo "Error: Could not find azure-cli installed. Double check azure cli is installed. https://aka.ms/install-azure-cli" >&2
    fi

    if [[ "${is_error}" == "false" ]]; then
        az_version=$(az version --query '"azure-cli"' -o tsv)
    fi

    # K8s extensions will not install properly with this version of azure-cli. See:https://github.com/Azure/azure-cli/issues/18797
    if [[ "${az_version}" == "2.26.0" ]]; then
        echo ""
        is_error=true
        echo 'Error: azure-cli version 2.26.0 is currently installed. There is a known issue with 2.26.0 installing connectedk8s extensions. Please downgrade to 2.25.0 https://aka.ms/install-azure-cli' >&2
    fi

    # check for azure subscription logged in
    if ! azAccount=$(az account show --query name -o tsv); then
        echo ''
        is_error=true
        echo 'Error: no azure subscription is logged in. Please run "az login" before executing the script.' >&2
        echo 'Please ensure the correct subscription is set by running "az account set -s <subscription-name-or-guid>"' >&2
        exit 1
    fi

    if [[ "${CREATE_ARC_DATA_SERVICES}" == 'true' ]]; then
        echo -n 'arc data services enabled...'
    fi

    # if subscription was found easily get the tenantId
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)
    TENANT_ID=$(az account show -o tsv --query tenantId)

    if ! helm &>/dev/null; then
        echo ""
        is_error=true
        echo 'Error: helm is not installed. Please ensure helm is installed https://helm.sh/docs/intro/install/' >&2
    fi

    if ! yq &>/dev/null; then
        echo ""
        is_error=true
        echo 'Error: yq is not installed. Please ensure yq is installed https://mikefarah.gitbook.io/yq/#install' >&2
    fi

    if ! kubectx &>/dev/null; then
        echo ""
        is_error=true
        echo 'Error: kubectx is not installed. Please ensure kubectx is installed.' >&2
    fi

    if ! kubectl &>/dev/null; then
        echo ""
        is_error=true
        echo 'Error: kubectl is not installed. Please ensure kubectl is installed.' >&2
    fi

    if ! docker &>/dev/null; then
        echo ""
        is_error=true
        echo 'Error: docker could not be found. Please ensure docker-desktop is installed.' >&2
    fi

    if [[ "${is_error}" == "true" ]]; then
        echo 'Please see prequisites for more informaion: https://github.com/Accenture/azure-arc-playground-builder/blob/main/prerequisites.md#setup-a-wsl2-based-azure-developer-machine' >&2
        exit 1
    fi

    echo 'done.'
}

##############################################################
# Prints the cleanup script for a user to execute afterwards.
# Globals:
#   None
# Arguments:
#   None
##############################################################
function echo_cleanup() {
    echo "################# BEGIN CLEANUP SCRIPT #################"
    echo az group delete --no-wait -y -n $RESOURCE_GROUP
    echo helm uninstall ddk8se-appservice-ext
    echo helm uninstall azure-arc
    echo kubectl delete pv task-pv-volume
    echo sudo rm -r /mnt/persistent-volume/*
    echo "################# END CLEANUP SCRIPT ###################"
}

##############################################################
# Prints the flags that control which k8s clusters are configured
# Globals:
# Arguments:
#   None
##############################################################
function echo_flags() {
    echo "Options:"
}

##############################################################
# Installs azure-cli extensions and registers providers
# Globals:
#   None
# Arguments:
#   None
##############################################################
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

    if ! az provider register --namespace Microsoft.DBforPostgreSQL --wait -o none --only-show-errors &> /dev/null; then
        echo 'Error failed to register Microsoft.DBforPostgreSQL' >&2
        exit 1
    fi
    echo 'done.'
}

##############################################################
# Waits for N seconds
# Globals:
#   None
# Arguments:
#   Number of seconds to wait
##############################################################
function go_to_sleep() {
    sleep $1 &
    process_id=$!
    wait $process_id
}

##############################################################
# Generates random unique string
# Globals:
#   None
# Arguments:
#   None
##############################################################
function get_rand(){
    local rand="$(echo $RANDOM | tr '[0-9]' '[a-z]')" # unique suffix
    echo "${rand}"
}

##############################################################
# Prints error message with reset message to stderr
# Globals:
#   None
# Arguments:
#   error message
##############################################################
function echo_reset_err() {
    echo $1 >&2
    echo 'Please reset and try executing this script again. If the issue persists, try running these steps manually.' >&2
}

##############################################################
# Echo resource id to output
# Globals:
#   LOG_RESOURCES
# Arguments:
#   resource id
##############################################################
function log_resource_id() {
    local resource_id=$1

    if [[ "${LOG_RESOURCES}"=="true" ]]; then
        echo "${resource_id}"
    fi
}

##############################################################
# Create local storage persistent volume provisioner
# Globals:
#   None
# Arguments:
#   None
##############################################################
function create_local_storage_provisioner(){
    echo -n 'Creating local storage provisioner on local cluster...'
    
    if ! kubectl apply -f $LOCAL_STORAGE_YAML >/dev/null; then
        echo_reset_err 'Failed to setup local storage provisioner on local cluster'
        exit 1
    fi

    if ! kubectl patch storageclass local-storage -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}' >/dev/null; then
        echo_reset_err 'Failed to setup local storage provisioner on local cluster'
        exit 1
    fi
    echo 'done.'
}

##############################################################
# Creates Arc Data Services with PostgreSQL Hyperscale
# Globals:
#   LOG_RESOURCES
# Arguments:
#   resource id
##############################################################
function create_arc_data_service() {
    local rg=${RESOURCE_GROUP}
    local custom_location_name=${LOCAL_HOST_NAME}
    local rand=${RAND}
    local region=${REGION}
    
    local cluster_name=${CLUSTER_NAME}
    local rg_id=$(az group show -n $rg -o tsv --query id --only-show-errors)
    local arc_ext_id=''
    local arc_custom_location_name="${custom_location_name}-${ARC_DATA_NAMESPACE}"
    local arc_custom_location_id=''
    local arc_dc_deployment="datacontroller-${custom_location_name}"
    local arc_dc_name="arc-dc-${custom_location_name}"
    local arc_dc_id=''
    local pgsql_deployment="pgsql-${custom_location_name}"
    local pgsql_server_name="psql${rand}"
    local pgsql_ip=''
    local pgsql_primary_endpoint=''
    local pgsql_id=''

    # deploy the arc data k8s extension
    echo -n "Installing Arc Data Services extension in namespace: ${ARC_DATA_NAMESPACE}..."
    arc_ext_id=$(
        az k8s-extension create \
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
        --only-show-errors
    )

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
    if ! arc_custom_location_id=$(az customlocation create -g $rg -n $arc_custom_location_name --host-resource-id $CONNECTED_CLUSTER_ID --namespace $ARC_DATA_NAMESPACE --cluster-extension-ids $arc_ext_id -o tsv --query id --only-show-errors) >/dev/null; then
        echo_reset_err "Error: failed to create arc data custom location ${arc_custom_location_name}"
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
    logAnalyticsWorkspaceId="${WORKSPACE_ID}" \
    logAnalyticsPrimaryKey="${LOG_ANALYTICS_KEY}" \
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

    # wait for the logsdb-0 pod to be Ready, psql install will fail ContainerConfigError if logsdb is not up
    local podwait=0
    while [[ $(kubectl get pods/logsdb-0 -n ${ARC_DATA_NAMESPACE} -o 'jsonpath={.status.phase}') != "Running" ]] && [[ $podwait -lt $MAX_WAIT_SECONDS ]]; do
        echo -ne "Waiting for pods/logsdb-0...${podwait} seconds"\\r
        go_to_sleep $SERVICE_POLL_SECONDS
        podwait=$((podwait + $SERVICE_POLL_SECONDS))
    done

    if [[ $(kubectl get pods/logsdb-0 -n ${ARC_DATA_NAMESPACE} -o 'jsonpath={.status.phase}') != "Running" ]]; then
        echo_reset_err "Error: max time (${MAX_SERVICE_WAIT_SECONDS}) seconds elapsed waiting for data controller logsdb pod to be Running."
        exit 1
    fi
    echo 'Waiting for Azure Arc Data Controller to be in ready state...done.'

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

    pgsql_primary_endpoint=$(az resource show -o tsv -g $rg -n $pgsql_server_name --resource-type microsoft.azurearcdata/postgresinstances --query properties.k8sRaw.status.primaryEndpoint --only-show-errors) >/dev/null
    pgsql_id=$(az resource show -o tsv -g $rg -n $pgsql_server_name --resource-type microsoft.azurearcdata/postgresinstances --query id --only-show-errors) >/dev/null

    if [[ -z "${pgsql_primary_endpoint}" ]] || [[ -z "${pgsql_id}" ]]; then
        echo_reset_err 'Error: failed to create hyperscale postgresql server on AKS cluster'
        exit 1
    fi
    echo 'Creating ARM template deployment for Azure Arc PostgreSQL Hyperscale in direct mode (this may take a few minutes)...done'
    log_resource_id ${pgsql_id}
    echo "PostgreSQL External Endpoint: ${pgsql_primary_endpoint}"

    echo -n 'Waiting for PostgreSQL to be in ready state...'
    if ! az resource wait -o none --only-show-errors --timeout $MAX_WAIT_SECONDS --ids $pgsql_id --resource-type 'microsoft.azurearcdata/postgresinstances' --custom "properties.k8sRaw.status.state=='Ready'" >/dev/null; then
        echo_reset_err 'Error: failed to wait for hyperscale postgresql server to finish creating on AKS cluster'
        exit 1
    fi
    echo 'Waiting for PostgreSQL to be in ready state...done.'

    # set the PostgreSQL connection string using K8s DNS, <service>.<namespace>
    POSTGRES_CONN_STRINGS[$rg]="Host=${pgsql_server_name}-external-svc.${ARC_DATA_NAMESPACE};Port=5432;Database=postgres;Username=postgres;Password=${AZDATA_PASSWORD};SslMode=Disable"
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
    echo '''Usage: ./deploy-arc-ddk8s.sh [arguments]
Arguments
  --location -l       [Required] : The azure region to deploy all resources.
                                   Valid values: eastus, westeurope.
  --cluster-name -n   [Required] : The name to describe the host machine running the Docker Desktop cluster.
  --create-arc-data              : Create arc data services in addition to appservice.
                                   Only use this argument if WSL2 has sufficient memory and processors.
  --spn-id                       : Service principal client id.
  --spn-secret                   : Service principal client secret.
  --sql-username                 : Sql admin username.
  --sql-password                 : Sql admin password.
  --kubectx -k        [Optional] : Name of existing kubernetes context to use.
                                   Default value is docker-desktop
  --help -h                      : Print the script usage message.

Examples
    Create an Azure WebApp on Arc-connected local Docker Desktop K8s clusterregistered to eastus region.
    ./deploy-arc-ddk8s.sh -l eastus --cluster-name my-laptop

    Create an Azure WebApp & Arc Postgres Hyperscale on Arc-connected local Docker Desktop K8s cluster registered to eastus region
    ./deploy-arc-ddk8s.sh \
    -l eastus \
    --cluster-name my-laptop \
    --create-arc-data \
    --spn-id $SERVICE_PRINCIPAL_ID \
    --spn-secret $SERVICE_PRINCIPAL_SECRET \
    --sql-username demoadmin \
    --sql-password $SQL_PASSWORD
'''
}


# BEGIN EXECUTION
PARSED_OPTIONS=$(getopt -a -n deploy-arc-ddk8s.sh -o l:hn:k: --long location:,help,cluster-name:,kubectx:,create-arc-data,spn-id:,spn-secret:,sql-username:,sql-password: -- "$@")

VALID_ARGUMENTS=$?
if [ "$VALID_ARGUMENTS" != "0" ]; then
usage
fi

eval set -- "$PARSED_OPTIONS"
while :
do
case "$1" in
    -l | --location)        REGION="$2" ; shift 2 ;;
    -n | --cluster-name)    LOCAL_HOST_NAME="$2" ; shift 2 ;;
    -h | --help)            print_usage  ; shift   ;;
    -k | --kubectx)         KUBECTX_FLAG="$2" ; shift 2 ;;
    --create-arc-data)      CREATE_ARC_DATA_SERVICES=true  ; shift   ;;
    --spn-id)               SP_CLIENT_ID="$2"  ; shift 2  ;;
    --spn-secret)           SP_SECRET="$2"  ; shift 2 ;;
    --sql-username)         export AZDATA_USERNAME="$2"  ; shift 2  ;;
    --sql-password)         PGSQL_ADMIN_PW="$2"  ; shift 2  ;;
    # -- means the end of the arguments; drop this, and break out of the while loop
    --) shift; break ;;
    # If invalid options were passed, then getopt should have reported an error,
    # which we checked as VALID_ARGUMENTS when getopt was called...
    *) echo "Unexpected option: $1 - this should not happen."
    print_usage ;;
esac
done

if [[ "${HELP_FLAG}" == 'true' ]]; then
    exit 0
fi

export AZDATA_PASSWORD="${PGSQL_ADMIN_PW}"
CLUSTER_NAME="ddk8s-${LOCAL_HOST_NAME}-${RAND}"
APPSERVICE_NAME="hello-world-web-${CLUSTER_NAME}"
CUSTOM_LOCATION_NAME="${LOCAL_HOST_NAME}-appservice-ns"
APPSERVICE_KUBE_ENV_NAME="${APPSERVICE_EXTENSION_NAME}"
APPSERVICE_PLAN_NAME="appplan-${CUSTOM_LOCATION_NAME}"

# Ensure pre-reqs are installed
if ! check_prereqs; then
    exit 1
fi

# Print the control flow flags
echo_flags

# Print the cleanup script
echo_cleanup

# Add Azure CLI Extensions
if ! install_azure_cli_extensions; then
    exit 1
fi

# Create resource group
echo -n "Creating Azure Resource Group ${RESOURCE_GROUP} in ${REGION} region..."

if ! rg_id=$(az group create -n $RESOURCE_GROUP --location $REGION -o tsv --query id --only-show-errors) >/dev/null; then
    echo "Error: failed to create resource group ${RESOURCE_GROUP}." >&2
    exit 1
fi

echo 'done.'

log_resource_id $rg_id

# Create the Log Analytics workspace
echo -n "Creating Log Analytics Workspace..."

log_create_success=0

if ! workspace_resource_id=$(az monitor log-analytics workspace create -g $RESOURCE_GROUP --workspace-name $WORKSPACE_NAME -o tsv --query id --only-show-errors) >/dev/null; then
    echo ''
    echo 'Error: failed to create log analytics workspace.' >&2
    exit 1
fi

WORKSPACE_ID=$(az monitor log-analytics workspace show -g $RESOURCE_GROUP --workspace-name $WORKSPACE_NAME --query customerId --output tsv)
WORKSPACE_ID_ENC=$(printf %s $WORKSPACE_ID | base64)
LOG_ANALYTICS_KEY=$(az monitor log-analytics workspace get-shared-keys -g $RESOURCE_GROUP --workspace-name $WORKSPACE_NAME --query primarySharedKey --output tsv)
LOG_ANALYTICS_KEY_ENC_SPACE=$(printf %s $LOG_ANALYTICS_KEY | base64)
LOG_ANALYTICS_KEY_ENC=$(echo -n "${LOG_ANALYTICS_KEY_ENC_SPACE//[[:space:]]/}")

echo "Creating Log Analytics Workspace...done."

log_resource_id $workspace_resource_id

# Create Arc-Enabled K8s CLuster
echo -n "Switching kubectx to ${KUBECTX_FLAG}..."
if ! kubectx ${KUBECTX_FLAG} >/dev/null; then
    echo "Error: failed to set kubectl context to ${KUBECTX_FLAG}. Please check docker desktop is installed correctly." >&2
    exit 1
fi
echo 'done.'

# Echo watch commands
echo '########################################################################################################'
echo '[Optional] Run these commands in separate terminals to watch the Arc and App Service K8s objects come up'
echo 'watch -n 5 kubectl get pods -n azure-arc'
echo 'watch -n 5 kubectl get svc,pods -n appservice-ns'
echo 'watch -n 5 kubectl get svc,pods -n arcdata'
echo '########################################################################################################'

# Connect docker desktop cluster to Azure Arc
echo -n "Connecting Docker Desktop cluster to Azure Arc (this will take a few minutes)..."
if ! az connectedk8s connect -g $RESOURCE_GROUP -n $CLUSTER_NAME -o none --only-show-errors >/dev/null; then
    echo 'Error: failed to install azure-arc on local kubernetes cluster' >&2
    exit 1
fi

CONNECTED_CLUSTER_ID=$(az connectedk8s show -g $RESOURCE_GROUP -n $CLUSTER_NAME --query id -o tsv) >/dev/null
echo 'Connecting DD K8s cluster to Azure Arc (this will take a few minutes)...done.'

if [[ "${CREATE_ARC_DATA_SERVICES}" == 'true' ]]; then
    if ! create_local_storage_provisioner; then
        exit 1
    fi

    if ! create_arc_data_service; then
        exit 1
    fi
fi

echo -n "Installing app service extensions in dd k8s cluster (this will take a few minutes)..."
APPSERVICE_EXTENSION_ID=$(
    az k8s-extension create \
    -g $RESOURCE_GROUP \
    -n $APPSERVICE_EXTENSION_NAME \
    --cluster-type connectedClusters \
    --cluster-name $CLUSTER_NAME \
    --extension-type 'Microsoft.Web.Appservice' \
    --release-train stable \
    --auto-upgrade-minor-version true \
    --scope cluster \
    --release-namespace $NAMESPACE \
    --configuration-settings "Microsoft.CustomLocation.ServiceAccount=default" \
    --configuration-settings "appsNamespace=${NAMESPACE}" \
    --configuration-settings "clusterName=${APPSERVICE_KUBE_ENV_NAME}" \
    --configuration-settings "loadBalancerIp=${LOCAL_HOST_PUBLIC_IP}" \
    --configuration-settings "keda.enabled=false" \
    --configuration-settings "buildService.storageClassName=default" \
    --configuration-settings "buildService.storageAccessMode=ReadWriteOnce" \
    --configuration-settings "customConfigMap=${NAMESPACE}/kube-environment-config" \
    --configuration-settings "logProcessor.appLogs.destination=log-analytics" \
    --configuration-protected-settings "logProcessor.appLogs.logAnalyticsConfig.customerId=${WORKSPACE_ID_ENC}" \
    --configuration-protected-settings "logProcessor.appLogs.logAnalyticsConfig.sharedKey=${LOG_ANALYTICS_KEY_ENC}" \
    --query id \
    -o tsv \
    --only-show-errors
) >/dev/null

if [[ -z "${APPSERVICE_EXTENSION_ID}" ]]; then
    echo_reset_err 'Error: could not create k8s-extension'
    exit 1
fi
echo 'done.'

log_resource_id $APPSERVICE_EXTENSION_ID

echo -n "Updating load balancer service with external IP ${LOCAL_HOST_PUBLIC_IP}..."

# Hacks below - the helm chart installed on DDK8s with the extension is missing three things
# 1. The envoy load balancer IP is not set as the external IP
# 2. The build-service requires a persistent volume
# 3. This script re-applies the persistent volume claim to kickstart the build-service
# These instructions are not currently documented on MSFT's preview docs, obtained through private internal channel with MSFT

# Hack #1 set the public ip on the load balancer service
# Wait for the envoy service to be created
# While the kubectl command is failing, wait for 10s and check again
# Wait a max of configured mins (default)
# Use yq to apply the external IP (home WAN IP) to the service yaml
SERVICE_WAIT=0
while ! kubectl get svc "${APPSERVICE_EXTENSION_NAME}-k8se-envoy" -n $NAMESPACE -o name &>/dev/null && [[ $SERVICE_WAIT -lt $MAX_WAIT_SECONDS ]]; do
    go_to_sleep $SERVICE_POLL_SECONDS
    SERVICE_WAIT=$((SERVICE_WAIT + $SERVICE_POLL_SECONDS))
done

if ! kubectl get svc "${APPSERVICE_EXTENSION_NAME}-k8se-envoy" -n $NAMESPACE -o name &>/dev/null; then
    echo_reset_err "Error: max time (${MAX_WAIT_SECONDS}) seconds elapsed waiting for envoy service to be creating."
    exit 1
fi

echo -n 'found the envoy service...'

# TODO: check for the envoy service has 'localhost' as an external IP provided from docker desktop
HAS_LOCALHOST_MAPPED=$(kubectl get svc/${APPSERVICE_EXTENSION_NAME}-k8se-envoy -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[?(@.hostname=="localhost")].hostname}')

if [[ "${HAS_LOCALHOST_MAPPED}" != 'localhost' ]]; then
    echo_reset_err 'Error: the app service extension service could not map localhost ingress as an External IP. Please reset K8s cluster and be sure to quit and start Docker Desktop.'
    exit 1
fi

# Get the envoy service yaml
if ! kubectl get svc "${APPSERVICE_EXTENSION_NAME}-k8se-envoy" -n $NAMESPACE -o yaml >$ENVOY_SVC_YAML_PATH; then
    echo_reset_err "Error: could not update the envoy service externalIPs."
    exit 1
fi
# Add the local machine public Ip as an external IP on the load balancer service
if ! yq eval ".spec.externalIPs += [\"$LOCAL_HOST_PUBLIC_IP\"]" -i $ENVOY_SVC_YAML_PATH &>/dev/null; then
    echo_reset_err "Error: could not update the envoy service externalIPs."
    exit 1
fi

if ! kubectl apply -f $ENVOY_SVC_YAML_PATH &>/dev/null; then
    echo_reset_err "Error: could not update the envoy service externalIPs."
    exit 1
fi

if [[ ${SAVE_ENVOY_YAML} != "true" ]]; then
    rm $ENVOY_SVC_YAML_PATH
fi
echo 'done.'

# Hack #2
# Create a persistent volume needed for app service builder service's pvc
# Currently in ddk8s the k8s extension does not do this
echo -n 'Creating persistent volume in ddk8s cluster...'
if ! kubectl apply -f $VOLUME_YAML_PATH &>/dev/null; then
    echo_reset_err "Error: Unable to apply ${VOLUME_YAML_PATH}"
    exit 1
fi
echo 'done.'

# Hack #3
# TODO: confirm if this is really needed
# Apply the persistent volume claim to trigger a rebuild of the builder pod
echo -n 'Creating persistent volume claim in ddk8s cluster...'
if ! kubectl apply -f $VOLUME_CLAIM_YAML_PATH &>/dev/null; then
    echo_reset_err "Error: Unable to apply ${VOLUME_CLAIM_YAML_PATH}"
    exit 1
fi
echo 'done.'

echo -n 'Waiting for app service kube extensions to finish install (this may take a few minutes)...'
if ! az resource wait --ids $APPSERVICE_EXTENSION_ID --custom "properties.installState!='Pending'" --api-version "2020-07-01-preview" -o none --only-show-errors >/dev/null; then
    echo_reset_err "Error: Unable to install app service extension in ddk8s cluster."
    exit 1
fi
echo 'Waiting for app service kube extensions to finish install (this may take a few minutes)...done.'

echo -n "Creating custom location ${CUSTOM_LOCATION_NAME}..."
if ! CUSTOM_LOCATION_ID=$(az customlocation create -g $RESOURCE_GROUP -n $CUSTOM_LOCATION_NAME --host-resource-id $CONNECTED_CLUSTER_ID --namespace $NAMESPACE --cluster-extension-ids $APPSERVICE_EXTENSION_ID -o tsv --query id --only-show-errors) >/dev/null; then
    echo_reset_err "Error: Unable to create custom location ${CUSTOM_LOCATION_NAME}."
    exit 1
fi

if ! az resource wait -o none --only-show-errors --timeout $MAX_WAIT_SECONDS --resource-type 'microsoft.extendedlocation/customlocations' --ids $CUSTOM_LOCATION_ID --custom "properties.provisioningState=='Succeeded'" >/dev/null; then
    echo_reset_err 'Error: failed to wait for custom location to finish creating on AKS cluster'
    exit 1
fi
echo "Creating custom location ${CUSTOM_LOCATION_NAME}...done."
log_resource_id $CUSTOM_LOCATION_ID

echo -n "Creating App Service Kubernetes Environment ${APPSERVICE_KUBE_ENV_NAME} (this may take a few minutes)..."
if ! KUBE_ENV_RESOURCE_ID=$(az appservice kube create -g $RESOURCE_GROUP -n $APPSERVICE_KUBE_ENV_NAME --custom-location $CUSTOM_LOCATION_ID --static-ip $LOCAL_HOST_PUBLIC_IP -o tsv --query id --only-show-errors) >/dev/null; then
    echo_reset_err "Error: Unable to create app service k8s environment ${APPSERVICE_KUBE_ENV_NAME}"
    exit 1
fi

if ! az resource wait -g $RESOURCE_GROUP --ids $KUBE_ENV_RESOURCE_ID --api-version '2021-01-15' --resource-type 'microsoft.web/kubeenvironments' --custom  "properties.provisioningState=='Succeeded'" >/dev/null; then
    echo_reset_err 'Error: failed to create K8se'
    exit 1
fi

# wait for the kubernenetes env to be linked with the custom location
if ! az resource wait -g $RESOURCE_GROUP --ids $KUBE_ENV_RESOURCE_ID --api-version '2021-01-15' --resource-type 'microsoft.web/kubeenvironments' --custom  "properties.extendedLocation.customLocation=='${CUSTOM_LOCATION_ID}'" >/dev/null; then
    echo_reset_err 'Error: failed to create K8se'
    exit 1
fi
echo "Creating App Service Kubernetes Environment ${APPSERVICE_KUBE_ENV_NAME} (this may take a few minutes)...done."
log_resource_id $KUBE_ENV_RESOURCE_ID

echo -n 'Creating App Service plan...'
if ! APPSERVICE_PLAN_RESOURCE_ID=$(az appservice plan create -g $RESOURCE_GROUP -n $APPSERVICE_PLAN_NAME --custom-location $CUSTOM_LOCATION_ID --per-site-scaling --is-linux --sku K1 -o tsv --query id --only-show-errors) >/dev/null; then
    echo_reset_err "Error: Unable to create app service plan ${APPSERVICE_PLAN_NAME}"
    exit 1
fi
echo 'Creating App Service plan...done.'
log_resource_id $APPSERVICE_PLAN_RESOURCE_ID

echo -n 'Creating App Service...'
if ! APPSERVICE_RESOURCE_ID=$(az webapp create --plan $APPSERVICE_PLAN_NAME -g $RESOURCE_GROUP -n $APPSERVICE_NAME --custom-location $CUSTOM_LOCATION_ID --runtime 'DOTNET|5.0' -o tsv --query id --only-show-errors) >/dev/null; then
    echo_reset_err "Error: Unable to create app service ${APPSERVICE_NAME}"
    exit 1
fi
echo 'Creating App Service...done'
log_resource_id $APPSERVICE_RESOURCE_ID

if [[ "${CREATE_ARC_DATA_SERVICES}" == 'true' ]]; then
    echo -n 'Adding PostgreSQL connection string to app service config...'
    if ! az webapp config appsettings set -g $RESOURCE_GROUP -n $APPSERVICE_NAME --settings $APPSERVICE_PGSQL_CONN_STR_KEY="${POSTGRES_CONN_STRINGS[$RESOURCE_GROUP]}" >/dev/null; then
        echo_reset_err "Error: failed to configure PostgreSQL connection string in App Service ${app_service_name}"
        exit 1
    fi
    echo 'done.'
fi

echo -n "Deploying Hello World web app to ${APPSERVICE_NAME} in ${CUSTOM_LOCATION_NAME}..."
if ! az webapp deployment source config-zip -g $RESOURCE_GROUP -n $APPSERVICE_NAME --src $WEBAPP_PATH -o none --only-show-errors >/dev/null; then
    echo_reset_err "Error: Unable to deploy hello world to ${APPSERVICE_NAME}"
    exit 1
fi
echo 'done.'

HOST=$(az webapp show -n $APPSERVICE_NAME -g $RESOURCE_GROUP -o tsv --query defaultHostName --only-show-errors) >/dev/null
URL="https://${HOST}"
echo "Hello World is now deployed in ${CUSTOM_LOCATION_NAME}."
echo "${URL}"

echo 'end.'

exit 0
