# Arc enabled Kubernetes Workshop

This workshop will help you get hands on Arc enabled Kubernetes. It will start with the basics, and then give you pointers to go deeper on other areas - the Arc enabled services from Microsoft and more.

To get started, make sure you have the [prerequisites](prerequisites/README.md) completed.

The scripts and tutorials in this workshop make **extensive** use of environment variables. In Windows, you'll want to search for *environment* and choose **Edit environment variables for your account**. In bash/Linux, you'll want to edit ~/.profile, and at the end add lines for your environment variables like so, with your information updated.

```bash
# edit your profile
nano ~/.profile

# add the below to the bottom, then hit CTRL+X and say YES to save
export myAzureTenantId=
export myAzureSubscriptionId=
export myAzureResourceGroup=
export myAzureServicePrincipalId=
export myAzureServicePrincipalObjectId=
export myAzureServicePrincipalSecret=
export myAzureLocation=
```

Once you have those done, take a look at one of the scenarios below.

## Scenarios

- [Arc enabled Rancher Desktop](rancher-desktop/README.md)
