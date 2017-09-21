# KissCluster and Julia

We all know [Julia](https://julialang.org/) is great (if you do not know it just [try it](https://juliabox.com/)).

But it's even greatest when you can speed up your computations via [parallelization](https://docs.julialang.org/en/latest/manual/parallel-computing).

Let's see how to use KissCluster with Julia parallization functionality on AWS cloud.

1. Create KissCluster cluster with the serverless SSH option (remeber about `--passwordless_ssh` parameter and about AWS SecurityGroup)
1. Create the machine file:  `./kissc nodes --show_nproc yes myc@us-east-2 > ~/machinefile.txt`
1. Go to your home directory `cd ~`
1. Run Julia `julia --machinefile machinefile.txt` 

