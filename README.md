continuent-tools-core
=====================

The continuent-tools-core is a package of libraries that are found in Tungsten Replicator. When the gem is built, these files are automatically exported from [https://code.google.com/p/tungsten-replicator/](https://code.google.com/p/tungsten-replicator/).

    gem install continuent-tools-core

Script Structure
---

Every Tungsten script should create a new class and include the 'TungstenScript' module. To execute the class, run 'YourClassScript.new().run()'.

The class must at least define the 'main' and 'script_name' methods. All other methods have a base definition and aren't required.

Accepting Arguments
---

Inside of the configure command, you may define options that will be accepted from the command line.

    add_option(:option_name, {
      :on => "--option-name String",
      :aliases => ["-o String"],
      :help => "A description of the option",
      :default => "Default Value"
    })
    
In order to access this value, you may run the opt() command.

    opt(:option_name)

Samples
---

The first two examples show the base script outline for running against Continuent Tungsten, and running a script that doesn't require Continuent Tungsten.

* samples/active-tungsten-script
  
  This script will look for $CONTINUENT_ROOT and load the configuration associated with that directory. If the environment variable isn't available, the --directory option is required to locate the right path.
* samples/independent-script
  
  This script will still look for $CONTINUENT_ROOT but it will not fail if Continuent Tungsten is not found.

Viewing The Source Code
---

The source code for this gem is available at [code.google.com project](https://code.google.com/p/tungsten-replicator/source/browse/#svn%2Ftrunk%2Fbuilder%2Fextra%2Fcluster-home%2Flib%2Fruby%253Fstate%253Dclosed). The tungsten.rb and tungsten directory are packaged into the gem. All other files are required via the gemspec.
