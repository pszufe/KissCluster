# KissCluster NetLogo integration

[NetLogo](https://ccl.northwestern.edu/netlogo/) is a agent-based simulation language and a modeling environment created and developed by Uri Wilensky.

The standard tool to model parameter sweeping with NetLogo is [BehaviorSpace](https://ccl.northwestern.edu/netlogo/docs/behaviorspace.html). 
This tutorial is for NetLogo's users who want to use KissCluster to distribute their BehaviorSpace simulation computations across a large group of computers. 

The standard KissCluster-NetLogo integration approach consists of the following steps:

1. In your NetLogo model add a global variable `JOB_ID` in this way you will be able to map KissCluster jobs to NetLogos's execution steps.
1. Use BehaviorSpace to define your model sweep.

    1. In *vary variables* field as the first variable add `["JOB_ID" 0]`.
    1. Add other variables that you wish to sweep over in the *vary variables* field. However we recommed to use only a single value for each variable and use bash script for variable sweeping instead (see `sample_app_netlogo/` folder for an example). 
    1. Set the *reporters* depending on your modelling needs.
    1. Define model termination condition.
    
1. Save the model 
1. Extract model setup xml from `*.nlogo` file (it is at the end of the file)
1. Create a script that will update your `*.xml` file with regard to `job_id` (see `sample_app_netlogo/` folder for an example)
1. Use `netlogo-headless.sh` to run the NetLogo simulation with your `*.xml` parametrization 
1. Prepare a cluster node with Java, NetLogo, xmlstartlet, jq and awscli 
1. Submit job to the cluster. 

Please node that many configurations are possible. 
In particular possible parameter space sweeping modes as well as simulation run iterations include:
BehaviorSpace-managed or KissCluster-managed or mixed modes. 


