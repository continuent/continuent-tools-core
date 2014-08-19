Introduction
===

The tools are made up of two primary components:

* `tungsten_directory`
* `tungsten_manage_configuration`

The `tungsten_directory` script collects information about available servers and uses tags to determine which are part of the same cluster and their IP address information.

The `tungsten_manage_configuration` will read information from `tungsten_directory` and manage the local configuration based on the details for the current host. That includes:

* Writing `/etc/tungsten/tungsten.ini`
* Manage `/etc/hosts` entries
* Install and provision Continuent Tungsten
* Install and provision Tungsten Replicator
* Manage `users.map` entries

Prerequisites
===

* Each server must be prepared with the prerequisites for Continent Tungsten
* Install the `continuent-tools-core` Ruby Gem

Usage
===

Download Continuent Tungsten or Tungsten Replicator
---

The software packages you would like to use must be downloaded to every machine. Place them into the `/opt/continuent/software` directory and unpack them if needed.

Create `/etc/tungsten/directory.ini`
---

Create entries in the `directory.ini` file for each host or group that you would like to manage.

*Explicit Host Entries*

These entries define a single host and provide all information for the host in question.

    [db1.example.com]
    hostname=db1.example.com
    private-address=192.168.5.202
    public-address=45.24.78.23
    location=east1
    tags.tungsten-ClusterName=east
    tags.tungsten-ServerType=datasource,connector
    
*AWS EC2 Autodetect Entries*

These entries tell `tungsten_directory` to connect with the AWS API and find instances that have been tagged with the `tungsten-ServerType`.

    [autodetect.aws.ec2]
    access_key_id=XXXXXXX
    secret_access_key=XXXXXXXXXXXXXX
    
By default, the hostname for each instance will be based on the `Name` tag. If you would like to override that, you may specify a different tag in the `hostname_tag` setting.

If you would like to look for entries based on a different tag, you may specify a different tag in the `tag_key` setting. If you would like to search for a specific value, you may specify it in the `tag_value` setting.

Create `/etc/tungsten/manage_configuration.ini`
---

    [manage_configuration]
    continuent-tungsten-package=/opt/continuent/software/continuent-tungsten-2.0.3-520
    log=/etc/tungsten/tungsten_manage_configuration.log
    lastrun=/etc/tungsten/tungsten_manage_configuration.lastrun
    manage-etc-hosts=puppet

If you are managing DNS entries for your hosts then you may remove `manage-etc-hosts=puppet`. If you leave it in place, the script will use Puppet to update `/etc/hosts` with information returned from `tungsten_directory`.

Create `/etc/tungsten/defaults.tungsten.ini`
---

This file is based on the same options used for configuring Continuent Tungsten or Tungsten Replicator with INI files. Here is an example based on output from the Continuent Puppet module.

    [defaults]
    user=tungsten
    home-directory=/opt/continuent
    mysql-connectorj-path=/opt/mysql/mysql-connector-java-5.1.26-bin.jar
    datasource-user=tungsten
    datasource-password=secret
    application-port=3306
    application-user=app_user
    application-password=secret
    skip-validation-check=MySQLPermissionsCheck
    
    [defaults.replicator]
    home-directory=/opt/replicator
    rmi-port=10002

Run `tungsten_manage_configuration`
---

Running the script without any arguments will use the settings placed in `/etc/tungsten/manage_configuration.ini`. The results will be sent to the log file for later review.

This script should be put on some kind of schedule so that updates to directory information or `/etc/tungsten/defaults.tungsten.ini` are applied to the installed software.

Integrations
===

Integration with Puppet
---

TBD

Integration with Chef
---

TBD

Integration with AWS CloudFormation
---

TBD

Integration with AWS EC2
---

TBD