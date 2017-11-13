Testing PostgreSQL `pgbench` on Cloud Providers
===============================================

This set of scripts automates the process of benchmarking PostgreSQL on Google Cloud and Microsoft Azure using managed Postgres offerings as well as directly on VMs on the platforms.

Test scenarios
--------------

There are five scripts covering five different scenarios. Each creates a server (either managed Postgres or a server VM on which the script starts a "self-hosted" Postgres instance) and a client, and runs pgbench from the client for a range of simultaneous client connections. In the end, a report text file is transferred back to the host running the scripts with the output of the various pgbench commands.

The scenarios are:

 - `azure.sh`: Azure managed Postgres service.
 - `azure-self.sh`: Azure VM running Postgres.
 - `google.sh`: Google managed Postgres service.
 - `google-ha.sh`: Google managed Postgres service with synchronous high-availability enabled. (Since it isn't clear what the replication strategy, if there is one, of Azure is, this test provides a "worst case" test of syncronous replcation to ensure that if Azure is also doing something similar, the numbers are fair to compare. Spoiler alert: there was no meaningful difference between this and `google.sh`.)
 - `google-self.sh`: Google VM running Postgres.

Usage
-----

The Azure scripts assume the Azure CLI is installed, logged in, and associated with the subscription you wish to use. The Google scripts assume the Google Cloud SDK client is installed, logged in, and configured with the project you with to use. There isn't any particular error handling for when these assumptions aren't true.

From a shell on a system with the appropriate clients installed and configured, simply run the `azure.sh`, `azure-self.sh`, `google.sh`, `google-ha.sh`, or `google-self.sh` script and wait. The scripts will provision the necessary cloud resources, run the benchmarks, then delete the cloud resources. The report will be in the file report-*scenario*-*nonce*.txt, where *nonce* is a unique string generated per run.

The `pgbench.sh` and `pgserver.sh` scripts are not meant to be run directly; they are used by the scenario scripts.

Warnings and disclaimers
------------------------

If anything goes wrong, these scripts will **not** delete the cloud resources that they provision. If you don't want to be on the hook with unexpected cloud costs, **you should always manually check your cloud services to ensure that the resources are deleted when you're done with the scripts**. This is good practice even if everything goes well.

As with all benchmarks, the results are only as good as your understanding of the tests and the implications of the choices in setting up the tests. Note that as the scripts exist in this repository, there are several areas that prevent the scenarios from being truly comparable. This includes a difference in CPU resources assigned to the managed databases versus the self-hosted databases. I made these tests for my specific needs, but you'll need to change them for yours.

To-do
-----

 - It would be nice to factor out some of the commonalities between the scripts to reduce duplication of code between them.
 - Perhaps add Amazon cloud support?
