class AWSEC2TungstenDirectoryProvider < TungstenDirectoryProvider
  def self.get_regex()
    "aws\.ec2.*"
  end
  
  def get_entries(aws_info)
    aws_entries = {}
    
    unless defined?(AWS)
      begin
        require 'aws/ec2'
      rescue LoadError
        raise "The aws-sdk Ruby gem or rubygem-aws-sdk package is required for this class"
      end
    end

    if aws_info.has_key?("access_key_id") && aws_info.has_key?("secret_access_key")
      AWS.config({
        :access_key_id => aws_info["access_key_id"],
        :secret_access_key => aws_info["secret_access_key"]
      })
    else
      AWS.config(:credential_provider => AWS::Core::CredentialProviders::EC2Provider.new)
    end

    ec2 = AWS::EC2.new()
    
    if aws_info.has_key?("hostname_tag")
      hostname_tag = aws_info["hostname_tag"]
    else
      hostname_tag = "Name"
    end

    region_index = -1
    region_threads = []
    region_results = []
    
    if aws_info.has_key?("regions")
      regions = aws_info["regions"]
      if regions.is_a?(String)
        regions = regions.split(",")
      end
    else
      regions = ec2.regions.map(&:name)
    end
    regions.each{|r|
      region_threads << Thread.new{
        index = Thread.exclusive{ (region_index = region_index+1) }
        region = regions[index]
        region_results[index] = {}
        TU.debug("Collect ec2_hosts from #{region}")
        
        region_ec2 = AWS::EC2.new(:region => region)
        instances = region_ec2.instances().filter('instance-state-name', "running")

        if aws_info.has_key?("tag_key")
          if aws_info.has_key?("tag_value")
            instances = instances.with_tag(aws_info["tag_key"], aws_info["tag_value"])
          else
            instances = instances.tagged(aws_info["tag_key"])
          end
        else
          instances = instances.tagged('tungsten-ServerType')
        end
        instances.each{
          |ins|
          tags = ins.tags.to_h()
          
          name = tags.to_h()[hostname_tag]
          if name.to_s() == ""
            TU.error("Unable to identify the hostname for #{ins.id} in #{region}")
          end
          
          
          if ins.vpc_id != nil
            location = ins.availability_zone + "." + ins.vpc_id
          else
            location = ins.availability_zone
          end
          
          TU.debug("Found #{ins.id}")
          region_results[index][name] = {
            'id' => ins.id.to_s(),
            'hostname' => name,
            'location' => location,
            'public-address' => ins.public_ip_address,
            'private-address' => ins.private_ip_address,
            'tags' => tags.to_h(),
            'provider' => "aws.ec2",
            'autodetect-key' => @key
          }
        }
      }
    }
    
    region_threads.each{|t| t.join() }

    region_results.each{
      |region_result|
      aws_entries.merge!(region_result)
    }
    
    aws_entries
  end
end